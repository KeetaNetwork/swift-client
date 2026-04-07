import Foundation

public enum UsernameAnchorError: Error {
    case metaDataProviderMissing
    case metaDataProviderInvalidObject
    case accountMissingPrivateKey
    case responseNotOk
    case notSupported
    case invalidUsername(String)
    case resolvedAccountMismatch
    case resolvedUsernameMismatch
    case providerIdMismatch
    case authenticationNotSupported
}

public final class UsernameAnchor: Anchor {

    public enum Operation: String, OperationIdentifiable {
        case resolve
        case claim
        case release
        case search
    }

    public let name: String
    public let usernamePattern: String?
    public let operations: [Operation: AnchorOperation]

    public init(name: String, usernamePattern: String?, operations: [Operation: AnchorOperation]) throws {
        self.name = name
        self.usernamePattern = usernamePattern
        self.operations = operations

        try validateOperations([.claim, .release, .search])
    }

    public static func parse(metadata: JSON) throws -> [UsernameAnchor] {
        guard let username = metadata["username"] as? JSON else {
            throw UsernameAnchorError.metaDataProviderMissing
        }

        var anchors = [UsernameAnchor]()

        for providerName in username.keys {
            guard let provider = username[providerName] as? JSON else {
                throw UsernameAnchorError.metaDataProviderInvalidObject
            }

            let usernamePattern = provider["usernamePattern"] as? String
            let operations: [Operation: AnchorOperation] = try AnchorOperation.parse(from: provider)

            let anchor = try UsernameAnchor(name: providerName, usernamePattern: usernamePattern, operations: operations)
            anchors.append(anchor)
        }

        return anchors
    }

    // MARK: - Validation

    static let delimiter: Character = "$"
    static let usernameMinLength = 1
    static let usernameMaxLength = 256

    public func validateUsername(_ username: String) throws {
        if username.count < Self.usernameMinLength || username.count > Self.usernameMaxLength {
            throw UsernameAnchorError.invalidUsername("Username must be between \(Self.usernameMinLength)-\(Self.usernameMaxLength) characters")
        }

        if username.contains(Self.delimiter) {
            throw UsernameAnchorError.invalidUsername("Username must not contain \"\(Self.delimiter)\" character")
        }

        if let pattern = usernamePattern {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(username.startIndex..., in: username)
            if regex.firstMatch(in: username, range: range) == nil {
                throw UsernameAnchorError.invalidUsername("Provider issued name does not match required pattern")
            }
        }
    }

    public static func isGloballyIdentifiable(_ input: String) -> Bool {
        input.contains(delimiter)
    }

    public static func formatGloballyIdentifiable(username: String, providerID: String) -> String {
        "\(username)\(delimiter)\(providerID)"
    }

    public static func parseGloballyIdentifiable(_ input: String) -> (username: String, providerID: String)? {
        guard let separatorIndex = input.lastIndex(of: delimiter) else { return nil }
        let username = String(input[input.startIndex..<separatorIndex])
        let providerID = String(input[input.index(after: separatorIndex)...])
        guard !username.isEmpty, !providerID.isEmpty else { return nil }
        return (username: username, providerID: providerID)
    }

    private func isPublicKeyString(_ input: String) -> Bool {
        (try? AccountBuilder.create(fromPublicKey: input)) != nil
    }

    // MARK: - Operations

    public func resolve(_ toResolve: String) async throws -> UsernameResolution? {
        if authenticationType(for: .resolve) == .required {
            throw UsernameAnchorError.authenticationNotSupported
        }

        if !isPublicKeyString(toResolve) {
            try validateUsername(toResolve)
        }

        let url = try url(for: .resolve, parameters: ["toResolve": toResolve])
        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .get)

        let response: ResolveHTTPResponse
        do {
            response = try await sendRequest(to: endpoint, error: AnchorError.self, decoder: JSONDecoder())
        } catch RequestError<AnchorError>.error(_, let error) where error.name == "KeetaUsernameAnchorUserNotFoundError" {
            return nil
        }

        guard response.ok else { throw UsernameAnchorError.responseNotOk }

        let resolution = UsernameResolution(
            username: response.username,
            account: response.account,
            providerID: name,
            globallyIdentifiableUsername: Self.formatGloballyIdentifiable(username: response.username, providerID: name)
        )

        if isPublicKeyString(toResolve) {
            guard resolution.account == toResolve else {
                throw UsernameAnchorError.resolvedAccountMismatch
            }
        } else {
            guard resolution.username == toResolve else {
                throw UsernameAnchorError.resolvedUsernameMismatch
            }
        }

        return resolution
    }

    public func resolve(account: Account) async throws -> UsernameResolution? {
        try await resolve(account.publicKeyString)
    }

    public enum TransferOption {
        case fromSigner(Account)
        case preSigned(from: Account, signed: AnchorSigning.SignedResult)
    }

    @discardableResult
    public func claim(for account: Account, username usernameInput: String, transfer: TransferOption? = nil) async throws -> Bool {
        let requiresSigning = authenticationType(for: .claim) != .none

        if requiresSigning {
            guard account.canSign else { throw UsernameAnchorError.accountMissingPrivateKey }
        }

        let username: String
        if Self.isGloballyIdentifiable(usernameInput) {
            guard let parsed = Self.parseGloballyIdentifiable(usernameInput) else {
                throw UsernameAnchorError.invalidUsername("Invalid globally identifiable username")
            }
            guard parsed.providerID == name else {
                throw UsernameAnchorError.providerIdMismatch
            }
            username = parsed.username
        } else {
            username = usernameInput
        }

        try validateUsername(username)

        let url = try url(for: .claim)

        var body: JSON = [
            "username": username,
            "account": account.publicKeyString
        ]

        if requiresSigning {
            var resolvedTransfer: (from: Account, signed: AnchorSigning.SignedResult)?
            if let transfer {
                switch transfer {
                case .fromSigner(let from):
                    let transferSigned = try Self.signTransfer(username: username, from: from, to: account)
                    resolvedTransfer = (from: from, signed: transferSigned)
                case .preSigned(let from, let signed):
                    resolvedTransfer = (from: from, signed: signed)
                }
            }

            let signed = try Self.signClaim(account: account, username: username, transfer: resolvedTransfer)
            body["signed"] = AnchorSigning.signedField(signed)

            if let resolvedTransfer {
                body["transfer"] = [
                    "from": resolvedTransfer.from.publicKeyString,
                    "signed": AnchorSigning.signedField(resolvedTransfer.signed)
                ] as JSON
            }
        }

        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .post, body: body)

        let response: ClaimHTTPResponse = try await sendRequest(to: endpoint, error: AnchorError.self, decoder: JSONDecoder())

        guard response.ok else { throw UsernameAnchorError.responseNotOk }

        return response.ok
    }

    @discardableResult
    public func release(for account: Account) async throws -> Bool {
        let requiresSigning = authenticationType(for: .release) != .none

        if requiresSigning {
            guard account.canSign else { throw UsernameAnchorError.accountMissingPrivateKey }
        }

        let url = try url(for: .release)

        var body: JSON = [
            "account": account.publicKeyString
        ]

        if requiresSigning {
            let signed = try Self.signRelease(account: account)
            body["signed"] = AnchorSigning.signedField(signed)
        }

        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .post, body: body)

        let response: ReleaseHTTPResponse = try await sendRequest(to: endpoint, error: AnchorError.self, decoder: JSONDecoder())

        guard response.ok else { throw UsernameAnchorError.responseNotOk }

        return response.ok
    }

    public func search(query: String) async throws -> [UsernameResolution] {
        if authenticationType(for: .search) != .none {
            throw UsernameAnchorError.authenticationNotSupported
        }

        let url = try url(for: .search)

        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .get, query: ["search": query])

        let response: SearchHTTPResponse = try await sendRequest(to: endpoint, error: AnchorError.self, decoder: JSONDecoder())

        guard response.ok else { throw UsernameAnchorError.responseNotOk }

        return try response.results.map {
            try validateUsername($0.username)
            return UsernameResolution(
                username: $0.username,
                account: $0.account,
                providerID: name,
                globallyIdentifiableUsername: Self.formatGloballyIdentifiable(username: $0.username, providerID: name)
            )
        }
    }
    
    // MARK: - Signing

    private static let namespace = "c26e65bf-ad9f-4000-bc81-12c31dc86b8b"

    private static func signClaim(
        account: Account,
        username: String,
        transfer: (from: Account, signed: AnchorSigning.SignedResult)?
    ) throws -> AnchorSigning.SignedResult {
        var data: [AnchorSigning.SignableItem] = [
            .string(namespace),
            .string("CLAIM_USERNAME"),
            .string(username),
            .string(account.publicKeyString)
        ]

        if let transfer {
            data.append(contentsOf: [
                .account(transfer.from),
                .string(transfer.signed.signature),
                .string(transfer.signed.nonce),
                .string(transfer.signed.timestamp)
            ])
        } else {
            data.append(contentsOf: [
                .integer(0), .integer(0), .integer(0), .integer(0)
            ])
        }

        return try AnchorSigning.sign(account: account, data: data)
    }

    private static func signTransfer(username: String, from: Account, to: Account) throws -> AnchorSigning.SignedResult {
        try AnchorSigning.sign(account: from, data: [
            .string(namespace),
            .string("TRANSFER_USERNAME"),
            .string(username),
            .account(from),
            .account(to)
        ])
    }

    private static func signRelease(account: Account) throws -> AnchorSigning.SignedResult {
        try AnchorSigning.sign(account: account, data: [
            .string(namespace),
            .string("RELEASE_USERNAME"),
            .account(account)
        ])
    }
}

// MARK: - Public Model Types

public struct UsernameResolution {
    public let username: String
    public let account: String
    public let providerID: String
    public let globallyIdentifiableUsername: String
}

// MARK: - Internal Responses

struct ResolveHTTPResponse: Decodable {
    let ok: Bool
    let username: String
    let account: String
}

struct ClaimHTTPResponse: Decodable {
    let ok: Bool
}

struct ReleaseHTTPResponse: Decodable {
    let ok: Bool
}

struct SearchHTTPResponse: Decodable {
    let ok: Bool
    let results: [SearchResult]

    struct SearchResult: Decodable {
        let username: String
        let account: String
    }
}

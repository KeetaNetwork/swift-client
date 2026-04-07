import Foundation

public enum IdentityAnchorError: Error {
    case metaDataKycProviderMissing
    case metaDataKycProviderInvalidObject
    case metaDataKycProviderMissingCountryCodes
    case metaDataKycProviderMissingCA
    case accountMissingPrivateKey
    case responseNotOk
    case invalidUrl(String)
}

public final class IdentityAnchor: Anchor {
    
    public enum Operation: String, OperationIdentifiable {
        case createVerification
        case getCertificates
    }
    
    public let name: String
    public let countryCodes: [String]
    public let ca: Certificate
    public let operations: [Operation: AnchorOperation]
    
    public init(name: String, countryCodes: [String], ca: Certificate, operations: [Operation: AnchorOperation]) throws {
        self.name = name
        self.countryCodes = countryCodes
        self.ca = ca
        self.operations = operations
        
        try validateOperations()
    }
    
    public static func parse(metadata: JSON) throws -> [IdentityAnchor] {
        guard let kyc = metadata["kyc"] as? JSON else {
            throw IdentityAnchorError.metaDataKycProviderMissing
        }
        
        var anchors = [IdentityAnchor]()
        
        for providerName in kyc.keys {
            guard let provider = kyc[providerName] as? JSON else {
                throw IdentityAnchorError.metaDataKycProviderInvalidObject
            }
            
            let countryCodes = provider["countryCodes"] as? [String] ?? []
            guard let rawCA = provider["ca"] as? String else {
                throw IdentityAnchorError.metaDataKycProviderMissingCA
            }
            let ca = try Certificate.create(from: rawCA)
            
            let operations: [Operation: AnchorOperation] = try AnchorOperation.parse(from: provider)
            
            let anchor = try IdentityAnchor(name: providerName, countryCodes: countryCodes, ca: ca, operations: operations)
            anchors.append(anchor)
        }
        
        return anchors
    }
    
    /// If no country codes are supplied, all country codes are acceptable
    public func supports(countryCode: String) -> Bool {
        countryCodes.isEmpty || countryCodes.contains(countryCode)
    }
    
    public func createVerification(for account: Account, countryCodes: [String], redirectURL: String? = nil) async throws -> Verification {
        guard account.canSign else { throw IdentityAnchorError.accountMissingPrivateKey }
        
        let url = try url(for: .createVerification)

        let signed = try AnchorSigning.sign(account: account, data: []) // TODO: sign data once anchor is updated

        var request: JSON = [
            "countryCodes": countryCodes,
            "account": account.publicKeyString,
            "signed": AnchorSigning.signedField(signed)
        ]

        if let redirectURL {
            request["redirectURL"] = redirectURL
        }

        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .post, body: ["request": request])
        
        let response: CreateVerificationResponse = try await sendRequest(to: endpoint, decoder: JSONDecoder())
        
        guard response.ok else { throw IdentityAnchorError.responseNotOk }
        
        guard let webUrl = URL(string: response.webURL) else { throw IdentityAnchorError.invalidUrl(response.webURL) }
        
        return Verification(id: response.id, expectedCost: response.expectedCost, webUrl: webUrl)
    }
    
    public func certificates(for verificationId: String) async throws -> [Certificate] {
        let url = try url(for: .getCertificates, parameters: ["id": verificationId])
        
        let endpoint = KeetaEndpoint(url: url.absoluteString, method: .get)
        
        let response: VerificationCertificatesResponse = try await sendRequest(to: endpoint, decoder: JSONDecoder())
        
        guard response.ok else { throw IdentityAnchorError.responseNotOk }
        
        return try response.results.map { try Certificate.create(from: $0.certificate, intermediates: $0.intermediates) }
    }
}

// MARK: Responses

struct CreateVerificationResponse: Decodable {
    let ok: Bool
    let id: String
    let expectedCost: Cost
    let webURL: String
}

struct VerificationCertificatesResponse: Decodable {
    let ok: Bool
    let results: [CertificateResponse]
}

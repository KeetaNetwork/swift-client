import Foundation

public enum AccountError: Error, Equatable {
    case invalidPublicKeyAlgo(key: String)
    case invalidPublicKeyLength(length: Int)
    case invalidDataLength
    case invalidIdentifierAccount
    case invalidIdentifierAlgorithm
}

public struct Account: Codable, Hashable {
    
    public typealias PublicKeyAndType = [UInt8]
    
    public init(keyPair: KeyPair, keyAlgorithm: KeyAlgorithm) throws {
        self.keyPair = keyPair
        self.keyAlgorithm = keyAlgorithm
        
        publicKeyString = try Self.publicKeyString(from: keyPair.publicKey, algorithm: keyAlgorithm)
        publicKeyAndType = try Self.publicKeyAndType(from: keyPair.publicKey, algorithm: keyAlgorithm)
    }
    
    public init(data: Data) throws {
        let publicKey = try Self.publicKeyString(from: data.bytes)
        self = try AccountBuilder.create(fromPublicKey: publicKey)
    }
    
    public init(publicKeyAndType: PublicKeyAndType) throws {
        try self.init(data: .init(publicKeyAndType))
    }
    
    /**
     * 32 bytes or 33 bytes for the public key,
     * 5 bytes for the checksum,
     * 1 byte for the 4 bits which store the account type
     */
    static let publicKeyLengths = [61: 32 + 5 + 1, 63: 33 + 5 + 1]
    static let accountPrefixes = ["keeta_"]
    static let checksumLength = 5
    
    public let keyPair: KeyPair
    public let publicKeyString: String
    public let publicKeyAndType: PublicKeyAndType
    public let keyAlgorithm: KeyAlgorithm
    
    public var canSign: Bool {
        guard keyPair.hasPrivateKey else { return false }
        
        // Not all key pair implementation support signing e.g. IdentifierKeyPair
        do {
            _ = try keyAlgorithm.utils
            return true
        } catch {
            return false
        }
    }
    
    public var isIdentifier: Bool {
        [.TOKEN, .NETWORK].contains(keyAlgorithm)
    }
    
    public func sign(data: Data, options: SigningOptions = .default) throws -> [UInt8] {
        let data = try prepare(data: data, options: options)
        return try keyPair.sign(data: data, using: try keyAlgorithm.utils)
    }
    
    public func verify(data: Data, signature: [UInt8], options: SigningOptions = .default) throws -> Bool {
        let data = try prepare(data: data, options: options)
        let verifier = try keyAlgorithm.utils
        
        let signature = if options.forCert {
            // When handling X.509 certificates, we must process DER encoded data
            try verifier.signatureFromDER(signature)
        } else {
            signature
        }
        
        return try keyPair.verify(data: data, signature: signature, using: verifier)
    }
    
    public func generateIdentifier(index: Int = 0, previous: String? = nil, type: KeyAlgorithm = .TOKEN) throws -> Account {
        if isIdentifier {
            guard keyAlgorithm == .NETWORK else {
                throw AccountError.invalidIdentifierAccount
            }
            guard type == .TOKEN else {
                throw AccountError.invalidIdentifierAlgorithm
            }
        }
        
        let blockHash = try (previous ?? Block.accountOpeningHash(for: self)).toBytes()
        let seed: String = Hash.create(from: publicKeyAndType + blockHash)
        
        return try AccountBuilder.create(fromSeed: seed, index: index, algorithm: type)
    }
    
    private func prepare(data: Data, options: SigningOptions) throws -> [UInt8] {
        if options.raw {
            let data = data.toBytes()
            if data.count != Hash.digestLength {
                throw AccountError.invalidDataLength
            }
            return data
        } else {
            return Hash.create(from: data.bytes)
        }
    }
}

extension Account {
    
    public enum KeyAlgorithm: Int, Codable, Hashable {
        case ECDSA_SECP256K1
        case ED25519
        case NETWORK
        case TOKEN
        case STORAGE
        case MULTISIG = 7
        
        var utils: (KeyCreateable & Signable & Verifiable).Type {
            get throws {
                switch self {
                case .ECDSA_SECP256K1: EcDSA.self
                case .ED25519: Ed25519.self
                case .NETWORK, .TOKEN, .STORAGE: IdentifierKeyPair.self
                case .MULTISIG: MultiSignatureKeyPair.self
                }
            }
        }
    }
    
    public static func publicKeyAndType(from publicKey: String, algorithm: Account.KeyAlgorithm) throws -> [UInt8] {
        try [UInt8(algorithm.rawValue)] + publicKey.toBytes()
    }
    
    public static func publicKeyString(from publicKey: String, algorithm: Account.KeyAlgorithm) throws -> String {
        /*
         * Construct the array of public key bytes
         */
        let keyBytes = try publicKey.toBytes()
        let pubKeyValues = [UInt8(algorithm.rawValue)] + keyBytes
        
        return try publicKeyString(from: pubKeyValues)
    }
    
    public static func publicKeyString(from keyBytes: [UInt8]) throws -> String {
        var pubKeyValues = keyBytes
        
        /*
         * Append the checksum
         */
        let checksumBytes: [UInt8] = Hash.create(from: pubKeyValues, length: checksumLength)
        pubKeyValues.append(contentsOf: checksumBytes)
        
        /*
         * Ensure we have the right size
         */
        if publicKeyLengths.values.allSatisfy({ pubKeyValues.count != $0 }) {
            throw AccountError.invalidPublicKeyLength(length: pubKeyValues.count)
        }
        
        let accountPrefix = accountPrefixes[0]
        let output = Base32Encoder.encode(bytes: pubKeyValues)
        
        return "\(accountPrefix)\(output)"
    }
}

import Foundation

protocol KeyCreateable {
    static func create(from seed: String) throws -> KeyPair
    static func keypair(from privateKey: String) throws -> KeyPair
}

protocol Signable {
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8]
}

protocol Verifiable {
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool
    static func signatureFromDER(_ signature: Signature) throws -> Signature
}

public enum KeyPairError: Error {
    case noPrivateKeyToSign
}

public struct KeyPair: Equatable, Codable, Hashable {
    public init(publicKey: String, privateKey: String?) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
    
    public let publicKey: String
    private let privateKey: String?
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.publicKey.lowercased() == rhs.publicKey.lowercased()
        && lhs.privateKey?.lowercased() == rhs.privateKey?.lowercased()
    }
    
    public var hasPrivateKey: Bool {
        privateKey != nil
    }
    
    func sign(data: [UInt8], using signer: Signable.Type) throws -> [UInt8] {
        guard let privateKey = privateKey else {
            throw KeyPairError.noPrivateKeyToSign
        }
        let privateKeyBytes = try privateKey.toBytes()
        
        return try signer.sign(data: data, key: privateKeyBytes)
    }
    
    func verify(data: [UInt8], signature: [UInt8], using verifier: Verifiable.Type) throws -> Bool {
        let publicKeyBytes = try publicKey.toBytes()
        
        return try verifier.verify(data: data, signature: signature, key: publicKeyBytes)
    }
}

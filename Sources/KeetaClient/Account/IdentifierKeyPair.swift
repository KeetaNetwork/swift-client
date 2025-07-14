public enum IdentifierKeyPairError: Error {
    case signingNotSupported
    case verifyingNotSupported
    case noPrivateKey
}

public struct IdentifierKeyPair: KeyCreateable, Signable, Verifiable {
    static func create(from seed: String) throws -> KeyPair {
        let privateKey: String = Hash.create(from: try seed.toBytes())
        return try keypair(from: privateKey)
    }
    
    static func keypair(from privateKey: String) throws -> KeyPair {
        .init(publicKey: privateKey, privateKey: privateKey)
    }
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        throw IdentifierKeyPairError.signingNotSupported
    }
    
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        throw IdentifierKeyPairError.verifyingNotSupported
    }
    
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        throw IdentifierKeyPairError.noPrivateKey
    }
}

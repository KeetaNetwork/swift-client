import Foundation
import ed25519swift

struct Ed25519: KeyCreateable, Signable, Verifiable {
    static func create(from seed: String) throws -> KeyPair {
        let bytes = try seed.toBytes()
        let hash: String = Hash.create(from: bytes)
        return try keypair(from: hash)
    }
    
    static func keypair(from privateKey: String) throws -> KeyPair {
        var privateKeyBytes = try privateKey.toBytes()
        
        privateKeyBytes[0] &= 248;
        privateKeyBytes[31] &= 127;
        privateKeyBytes[31] |= 64;
        
        let privateKey = String(bytes: privateKeyBytes)
        let publicKeyBytes = ed25519swift.Ed25519.calcPublicKey(secretKey: privateKeyBytes)
        let publicKey = String(bytes: publicKeyBytes)
        
        return .init(publicKey: publicKey, privateKey: privateKey)
    }
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        ed25519swift.Ed25519.sign(message: data, secretKey: key)
    }

    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        ed25519swift.Ed25519.verify(signature: signature, message: data, publicKey: key)
    }
    
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        signature
    }
}

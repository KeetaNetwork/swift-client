import Foundation
import SwiftASN1
import P256K

struct EcDSA_P256K: KeyCreateable, Signable, Verifiable {
    
    // MARK: - Key Creation
    
    static func create(from seed: String) throws -> KeyPair {
        try create(from: try seed.toBytes())
    }
    
    static func create(from bytes: [UInt8]) throws -> KeyPair {
        let privateKey = try Hash.hkdf(bytes)
        return try keypair(from: privateKey)
    }
    
    static func keypair(from privateKey: String) throws -> KeyPair {
        let privateBytes = try privateKey.toBytes()
        let keyResult = try P256K.Signing.PrivateKey(dataRepresentation: privateBytes)
        let publicKey = String(bytes: keyResult.publicKey.dataRepresentation).uppercased()
        
        return .init(publicKey: publicKey, privateKey: privateKey)
    }
    
    // MARK: - Signing
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: key)
        let signature = try privateKey.signature(for: HashDigest(data.bytes))
        
        return try signature.compactRepresentation.bytes
    }
    
    // MARK: - Verification
    
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        let signature = try P256K.Signing.ECDSASignature(compactRepresentation: signature)
        let publicKey = try P256K.Signing.PublicKey(dataRepresentation: key, format: .compressed)
        
        return publicKey.isValidSignature(signature, for: HashDigest(data.bytes))
    }
    
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        try EcDSA.signatureFromDER(signature)
    }
}

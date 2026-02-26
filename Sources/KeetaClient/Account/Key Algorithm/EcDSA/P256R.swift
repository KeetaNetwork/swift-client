import Foundation
import CryptoKit
import SwiftASN1

struct EcDSA_P256R: KeyCreateable, Signable, Verifiable {
    
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
        let privateKeyResult = try P256.Signing.PrivateKey(rawRepresentation: privateBytes)
        let publicKey = String(bytes: privateKeyResult.publicKey.compressedRepresentation).uppercased()
        
        return .init(publicKey: publicKey, privateKey: privateKey)
    }
    
    // MARK: - Signing
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: key)
        let digest = SHA256.hash(data: data.bytes)
        let signature = try privateKey.signature(for: digest)
        
        return signature.rawRepresentation.toBytes()
    }
    
    // MARK: - Verification
    
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        let publicKey = try P256.Signing.PublicKey(compressedRepresentation: key)
        
        return publicKey.isValidSignature(signature, for: data)
    }
    
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        try EcDSA.signatureFromDER(signature)
    }
}

import Foundation
import P256K
import SwiftASN1

enum EcDSAError: Error {
    case invalidDERSignature
}

struct ECDSASignature: DERParseable {
    let r: ArraySlice<UInt8>
    let s: ArraySlice<UInt8>
    
    init(r: ArraySlice<UInt8>, s: ArraySlice<UInt8>) {
        self.r = r
        self.s = s
    }
    
    init(derEncoded rootNode: SwiftASN1.ASN1Node) throws {
        self = try DER.sequence(rootNode, identifier: .sequence) { nodes in
            let r = try ArraySlice<UInt8>(derEncoded: &nodes)
            let s = try ArraySlice<UInt8>(derEncoded: &nodes)
            return ECDSASignature(r: r, s: s)
        }
    }
}

struct EcDSA: KeyCreateable, Signable, Verifiable {
    
    static func create(from seed: String) throws -> KeyPair {
        let bytes = try seed.toBytes()
        let privateKey = try Hash.hkdf(bytes)
        return try keypair(from: privateKey)
    }
    
    static func keypair(from privateKey: String) throws -> KeyPair {
        let privateBytes = try privateKey.toBytes()
        let keyResult = try P256K.Signing.PrivateKey(dataRepresentation: privateBytes)
        let publicKey = String(bytes: keyResult.publicKey.dataRepresentation).uppercased()
        
        return .init(publicKey: publicKey, privateKey: privateKey)
    }
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: key)
        let signature = try privateKey.signature(for: HashDigest(data.bytes))
        
        return try signature.compactRepresentation.bytes
    }
    
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        let signature = try P256K.Signing.ECDSASignature(compactRepresentation: signature)
        let publicKey = try P256K.Signing.PublicKey(dataRepresentation: key, format: .compressed)
        
        return publicKey.isValidSignature(signature, for: HashDigest(data.bytes))
    }
    
    /// Construct an SEC-like signature from a DER encoded EcDSA [R,S] structure
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        let asn1 = try DER.parse(signature)
        let signature = try ECDSASignature(derEncoded: asn1)
        
        // ASN.1 encoded Integers are arbitrary sized, force it to fit into an exactly 32-byte buffer
        var sigSECValues: [Signature] = [Signature(signature.r), Signature(signature.s)]

        // Normalize each value to exactly 32 bytes
        for i in 0..<sigSECValues.count {
            let value = sigSECValues[i]
            
            if value.count > 32 {
                // Truncate to the last 32 bytes
                sigSECValues[i] = value.suffix(32)
            } else if value.count < 32 {
                // Pad with zeros at the beginning
                let padding = Data(repeating: 0, count: 32 - value.count)
                sigSECValues[i] = padding + value
            }
        }

        // Combine both values into a 64-byte array
        let sigSEC = sigSECValues[0] + sigSECValues[1]
        guard sigSEC.count == 64 else {
            throw EcDSAError.invalidDERSignature
        }
        return sigSEC
    }
}

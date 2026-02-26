import Foundation
import SwiftASN1

final class EcDSA {
    /// Construct an SEC-like signature from a DER encoded EcDSA [R,S] structure
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        let asn1 = try DER.parse(signature)
        let signature = try EcDSASignature(derEncoded: asn1)
        
        var sigSECValues: [Signature] = [
            Signature(signature.r),
            Signature(signature.s)
        ]
        
        for i in 0..<sigSECValues.count {
            let value = sigSECValues[i]
            
            if value.count > 32 {
                sigSECValues[i] = value.suffix(32)
            } else if value.count < 32 {
                let padding = Data(repeating: 0, count: 32 - value.count)
                sigSECValues[i] = padding + value
            }
        }
        
        let sigSEC = sigSECValues[0] + sigSECValues[1]
        guard sigSEC.count == 64 else {
            throw EcDSAError.invalidDERSignature
        }
        return sigSEC
    }
}

struct EcDSASignature: DERParseable {
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
            return EcDSASignature(r: r, s: s)
        }
    }
}

enum EcDSAError: Error {
    case invalidDERSignature
}

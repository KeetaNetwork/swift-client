import Foundation
import SwiftASN1

enum X509CertificateError: Error {
    case invalidData
}

final class X509Certificate {
    static func signedArea(from data: Data) throws -> Data {
        let rootNode = try DER.parse(data.bytes)
        
        return try DER.sequence(rootNode, identifier: .sequence) { nodes in
            // The contents of the X.509 certificate signed area
            guard let content = nodes.next() else {
                throw X509CertificateError.invalidData
            }
            // consume remaining, unused nodes
            while nodes.next() != nil {
                _ = nodes.next()
            }
            
            var serializer = DER.Serializer()
            serializer.serialize(content)
            let hex = serializer.serializedBytes.toHexString()
            return Data(hex: hex)
        }
    }
}

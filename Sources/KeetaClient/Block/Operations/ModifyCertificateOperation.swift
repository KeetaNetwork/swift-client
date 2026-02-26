import Foundation
import PotentASN1
import BigInt

/*
 -- MODIFY_CERTIFICATE operation
     modifycertificate [8] SEQUENCE {
         -- Method to adjust the certificate
         method              AdjustMethodRelative,
         -- Certificate to add if method is add,
         -- CertificateHash to remove if method is remove
         certificateOrHash   OCTET STRING,
         -- May only be supplied if method is add, in which
         -- case it is mandatory
         intermediates CHOICE {
             intermediateCertificates SEQUENCE OF OCTET STRING,
             none NULL
         } OPTIONAL
     }
 */

public enum ModifyCertificateOperationError: Error {
    case invalidSequenceLength
    case invalidAdjustMethod
    case invalidCertificateData
    case invalidIntermediateCertificateData
    case invalidCertificateHashData
}

public enum ModifyCertificateAdjustMethod: BigInt {
    case add = 0
    case remove = 1
}

public struct ModifyCertificateOperation: BlockOperation {
    public enum Operation {
        case add(Certificate, intermediates: [Certificate]? = nil)
        case remove(hash: String)
        
        public var method: ModifyCertificateAdjustMethod {
            switch self {
            case .add: .add
            case .remove: .remove
            }
        }
    }
    
    public let operationType: BlockOperationType = .modifyCertificate
    
    public let operation: Operation
    
    public init(operation: Operation) {
        self.operation = operation
    }
    
    public init(from sequence: [ASN1]) throws {
        guard sequence.count == 2 || sequence.count == 3 else {
            throw ModifyCertificateOperationError.invalidSequenceLength
        }
        
        guard let methodRaw = sequence[0].integerValue,
              let method = ModifyCertificateAdjustMethod(rawValue: methodRaw) else {
            throw ModifyCertificateOperationError.invalidAdjustMethod
        }
        
        switch method {
        case .add:
            guard let certificateData = sequence[1].octetStringValue else {
                throw ModifyCertificateOperationError.invalidCertificateData
            }
            let certificate = try Certificate(from: certificateData)
            
            let intermediates: [Certificate]?
            if let intermediatesSequence = sequence[2].sequenceValue {
                intermediates = try intermediatesSequence.map {
                    guard let certificateData = $0.octetStringValue else {
                        throw ModifyCertificateOperationError.invalidIntermediateCertificateData
                    }
                    return try Certificate(from: certificateData)
                }
            } else {
                intermediates = nil
            }
            
            self.init(operation: .add(certificate, intermediates: intermediates))
            
        case .remove:
            guard let certificateHashData = sequence[1].octetStringValue else {
                throw ModifyCertificateOperationError.invalidCertificateHashData
            }
            self.init(operation: .remove(hash: certificateHashData.toHexString()))
        }
    }
    
    public func asn1Values() throws -> [ASN1] {
        switch operation {
        case .add(let certificate, let intermediates):
            [
                .integer(operation.method.rawValue),
                .octetString(certificate.toData()),
                intermediates.map { ASN1.sequence($0.map { .octetString($0.toData()) }) } ?? .null
            ].compactMap { $0 }
        case .remove(let hash):
            [
                .integer(operation.method.rawValue),
                .octetString(Data(try hash.toBytes()))
            ]
        }
    }
}

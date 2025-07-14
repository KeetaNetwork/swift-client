import Foundation
import PotentASN1

public enum SetRepOperationError: Error {
    case invalidSequenceLength
    case invalidTo
}

/*
 -- SET_REP operation
         setrep [1] SEQUENCE {
             -- Representative to delegate to
             to          OCTET STRING
         }
 */

public struct SetRepOperation: BlockOperation {
    public let operationType: BlockOperationType = .setRep
    public let to: Account.PublicKeyAndType
    
    public init(to account: Account) {
        to = account.publicKeyAndType
    }
    
    public init(from sequence: [ASN1]) throws {
        guard sequence.count == 1 else {
            throw SetRepOperationError.invalidSequenceLength
        }
        
        guard let toData = sequence[0].octetStringValue else {
            throw SetRepOperationError.invalidTo
        }
        let to = try Account(data: toData)
        
        self.init(to: to)
    }
    
    public func asn1Values() -> [ASN1] {
        [
            .octetString(Data(to))
        ]
    }
}

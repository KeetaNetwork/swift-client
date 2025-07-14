import Foundation
import BigInt
import PotentASN1

public enum TokenAdminSupplyOperationError: Error {
    case invalidSequenceLength
    case invalidAmount
    case invalidAdjustMethod
}

/*
 AdjustMethod ::= INTEGER {
         add(0),
         remove(1),
         set(2)
     }
 
 -- TOKEN_ADMIN_SUPPLY operation
         tokenadminsupply [5] SEQUENCE {
             -- Amount of change to the supply
             amount      INTEGER,
             -- Method to modify the supply
             method      AdjustMethod
         }
 */

public enum AdminSupplyAdjustMethod: Int {
    case add
    case subtract
}

public struct TokenAdminSupplyOperation: BlockOperation {
    public let operationType: BlockOperationType = .tokenAdminSupply
    public let amount: BigInt
    public let method: AdminSupplyAdjustMethod
    
    public init(amount: BigInt, method: AdminSupplyAdjustMethod) {
        self.amount = amount
        self.method = method
    }
    
    public init(from sequence: [ASN1]) throws {
        guard sequence.count == 2 else {
            throw TokenAdminSupplyOperationError.invalidSequenceLength
        }
        guard let amount = sequence[0].integerValue else {
            throw TokenAdminSupplyOperationError.invalidAmount
        }
        guard let methodRaw = sequence[1].integerValue,
              let method = AdminSupplyAdjustMethod(rawValue: Int(methodRaw)) else {
            throw TokenAdminSupplyOperationError.invalidAdjustMethod
        }
        self.init(amount: amount, method: method)
    }
    
    public func asn1Values() -> [ASN1] {
        [
            .integer(amount),
            .integer(BigInt(method.rawValue)),
        ]
    }
}


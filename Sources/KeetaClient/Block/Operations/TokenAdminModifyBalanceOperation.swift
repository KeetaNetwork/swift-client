import Foundation
import BigInt
import PotentASN1

public enum TokenAdminModifyBalanceOperationError: Error {
    case invalidSequenceLength
    case invalidToken
    case invalidAmount
    case invalidAdjustMethod
}

/*
 AdjustMethod ::= INTEGER {
         add(0),
         remove(1),
         set(2)
     }
 
 -- TOKEN_MODIFY_BALANCE operation
         tokenmodifybalance [6] SEQUENCE {
             -- Token to modify the balance of
             token       OCTET STRING,
             -- Amount to modify the balance by
             amount      INTEGER,
             -- Method to modify the balance
             method      AdjustMethod
         }
 */

public struct TokenAdminModifyBalanceOperation: BlockOperation {
    public let operationType: BlockOperationType = .tokenAdminModifyBalance
    public let token: Account.PublicKeyAndType
    public let amount: BigInt
    public let method: AdjustMethod
    
    public init(token: Account, amount: BigInt, method: AdjustMethod) {
        self.token = token.publicKeyAndType
        self.amount = amount
        self.method = method
    }
    
    public init(from sequence: [ASN1]) throws {
        guard sequence.count == 3 else {
            throw TokenAdminModifyBalanceOperationError.invalidSequenceLength
        }
        
        guard let tokenData = sequence[0].octetStringValue else {
            throw TokenAdminModifyBalanceOperationError.invalidToken
        }
        let token = try Account(data: tokenData)
        
        guard let amount = sequence[1].integerValue else {
            throw TokenAdminModifyBalanceOperationError.invalidAmount
        }
        
        guard let methodRaw = sequence[2].integerValue,
              let method = AdjustMethod(rawValue: Int(methodRaw)) else {
            throw TokenAdminModifyBalanceOperationError.invalidAdjustMethod
        }
        
        self.init(token: token, amount: amount, method: method)
    }
    
    public func asn1Values() -> [ASN1] {
        [
            .octetString(Data(token)),
            .integer(amount),
            .integer(method.value)
        ]
    }
}

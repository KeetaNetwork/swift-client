import Foundation
import BigInt
import PotentASN1

public enum SendOperationError: Error {
    case invalidSequenceLength
    case invalidTo
    case invalidAmount
    case invalidToken
}

/*
 -- SEND operation
         send [0] SEQUENCE {
             -- Destination account to send to
             to          OCTET STRING,
             -- Amount of the token to send
             amount      INTEGER,
             -- Token ID to send
             token       OCTET STRING,
             -- External reference field (optional)
             external    UTF8String OPTIONAL
         }
 */

public struct SendOperation: BlockOperation {
    public let operationType: BlockOperationType = .send
    public let amount: BigInt
    public let to: Account.PublicKeyAndType
    public let token: Account.PublicKeyAndType
    public let external: String?
    
    public init(amount: BigInt, to accountPubKey: String, tokenPubKey: String, external: String? = nil) throws {
        let account = try AccountBuilder.create(fromPublicKey: accountPubKey)
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        try self.init(amount: amount, to: account, token: token, external: external)
    }
    
    public init(amount: BigInt, to account: Account, token: Account, external: String? = nil) throws {
        guard amount > 0 else {
            throw SendOperationError.invalidAmount
        }
        
        self.amount = amount
        to = account.publicKeyAndType
        self.token = token.publicKeyAndType
        self.external = external
    }
    
    public init(from sequence: [ASN1]) throws {
        guard sequence.count == 3 || sequence.count == 4 else {
            throw SendOperationError.invalidSequenceLength
        }
        guard let toData = sequence[0].octetStringValue else {
            throw SendOperationError.invalidTo
        }
        let to = try Account(data: toData)
        
        guard let amount = sequence[1].integerValue else {
            throw SendOperationError.invalidAmount
        }
        guard let tokenData = sequence[2].octetStringValue else {
            throw SendOperationError.invalidToken
        }
        let token = try Account(data: tokenData)
        
        let external = sequence[safe: 3]?.utf8StringValue?.storage
        
        try self.init(amount: amount, to: to, token: token, external: external)
    }
    
    public func asn1Values() -> [ASN1] {
        var values: [ASN1] = [
            .octetString(Data(to)),
            .integer(amount),
            .octetString(Data(token))
        ]
        
        if let external {
            values.append(.utf8String(external))
        }
        
        return values
    }
}

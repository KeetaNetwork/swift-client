import Foundation
import BigInt
import PotentASN1

public enum ReceiveOperationError: Error {
    case invalidSequenceLength
    case invalidAmount
    case invalidToken
    case invalidFrom
    case invalidExact
    case cantForwardToFromAccount
    case invalidExactWhenForwarding
}

/*
 -- RECEIVE operation
         receive [7] SEQUENCE {
             -- Amount to receive
             amount      INTEGER,
             -- Token to receive
             token       OCTET STRING,
             -- Sender from which to receive
             from        OCTET STRING,
             -- Whether the received amount must match
             -- exactly (true) or just be greater than or
             -- equal to the amount (false)
             exact       BOOLEAN,
             -- Forward the received amount to another
             -- account (optional)
             forward     OCTET STRING OPTIONAL
         }
 */

public struct ReceiveOperation: BlockOperation {
    public let operationType: BlockOperationType = .receive
    public let amount: BigInt
    public let exact: Bool
    public let token: Account.PublicKeyAndType
    public let from: Account.PublicKeyAndType
    public let forward: Account.PublicKeyAndType?
    
    public init(
        amount: BigInt,
        tokenPubKey: String,
        fromPubKey: String,
        exact: Bool,
        forwardPubKey: String? = nil
    ) throws {
        let token = try AccountBuilder.create(fromPublicKey: tokenPubKey)
        let from = try AccountBuilder.create(fromPublicKey: fromPubKey)
        let forward = try forwardPubKey.map { try AccountBuilder.create(fromPublicKey: $0) }
        try self.init(amount: amount, token: token, from: from, exact: exact, forward: forward)
    }
    
    public init(
        amount: BigInt,
        token: Account,
        from: Account,
        exact: Bool,
        forward: Account? = nil
    ) throws {
        self.amount = amount
        self.token = token.publicKeyAndType
        self.from = from.publicKeyAndType
        self.forward = forward?.publicKeyAndType
        self.exact = exact
        
        // Cannot forward to the blocks account
        if forward == from {
            throw ReceiveOperationError.cantForwardToFromAccount
        }
        
        // Exact must be true when forwarding a receive
        if forward != nil && exact != true {
            throw ReceiveOperationError.invalidExactWhenForwarding
        }
    }
    
    public init(from sequence: [PotentASN1.ASN1]) throws {
        guard (4...5).contains(sequence.count) else {
            throw ReceiveOperationError.invalidSequenceLength
        }
        
        guard let amount = sequence[0].integerValue else {
            throw ReceiveOperationError.invalidAmount
        }
        
        guard let tokenData = sequence[1].octetStringValue else {
            throw ReceiveOperationError.invalidToken
        }
        let token = try Account(data: tokenData)
        
        guard let fromData = sequence[2].octetStringValue else {
            throw ReceiveOperationError.invalidFrom
        }
        let from = try Account(data: fromData)
        
        guard let exact = sequence[3].booleanValue else {
            throw ReceiveOperationError.invalidExact
        }
        
        let forward: Account?
        if let forwardData = sequence[safe: 4]?.octetStringValue {
            forward = try Account(data: forwardData)
        } else {
            forward = nil
        }
        
        try self.init(amount: amount, token: token, from: from, exact: exact, forward: forward)
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        var values: [ASN1] = [
            .integer(amount),
            .octetString(Data(token)),
            .octetString(Data(from)),
            .boolean(exact)
        ]
        if let forward {
            values.append(.octetString(Data(forward)))
        }
        return values
    }
}

import Foundation
import BigInt
import PotentASN1

/*
 FeeData ::= [0] EXPLICIT SEQUENCE {
     -- TRUE = QUOTE, FALSE = VOTE
     quote        BOOLEAN,
     -- Amount to modify the balance by
     amount      INTEGER,
     -- Pay To Account
     payTo       [0] IMPLICIT OCTET STRING OPTIONAL,
     -- Token Account
     token       [1] IMPLICIT OCTET STRING OPTIONAL
 }
 */

public enum FeeError: Error {
    case invalidContextSpecificTag
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidQuote
    case invalidAmount
    case invalidImplicitTag
}

public struct Fee {
    public let quote: Bool
    public let amount: BigInt
    public let payTo: Account?
    public let token: Account?
    
    public init(quote: Bool, amount: BigInt, payTo: Account, token: Account) {
        self.quote = quote
        self.amount = amount
        self.payTo = payTo
        self.token = token
    }
    
    public init(from data: Data) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        try self.init(from: asn1)
    }
    
    public init(from asn1: [ASN1]) throws {
        guard let tag = asn1.first?.taggedValue, tag.isContextSpecific, tag.contextSpecificTag == 0 else {
            throw FeeError.invalidContextSpecificTag
        }
        
        let feesAsn1 = try ASN1Serialization.asn1(fromDER: tag.data)
        
        guard let sequence = feesAsn1.first?.sequenceValue else {
            throw FeeError.invalidASN1Sequence
        }
        
        guard (2...4).contains(sequence.count) else {
            throw FeeError.invalidASN1SequenceLength
        }
        
        guard let quote = sequence[0].booleanValue else {
            throw FeeError.invalidQuote
        }
        
        guard let amount = sequence[1].integerValue else {
            throw FeeError.invalidAmount
        }
        
        var payTo: Account?
        var token: Account?
        for tagIndex in [2, 3] {
            if let tag = sequence[safe: tagIndex]?.taggedValue {
                switch tag.implicitTag {
                case 0: payTo = try Account(data: tag.data)
                case 1: token = try Account(data: tag.data)
                default: throw FeeError.invalidImplicitTag
                }
            }
        }
        
        self.quote = quote
        self.amount = amount
        self.payTo = payTo
        self.token = token
    }
}

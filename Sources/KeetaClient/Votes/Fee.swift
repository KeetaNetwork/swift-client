import Foundation
import BigInt
import PotentASN1

/*
 FeeData ::= [0] EXPLICIT CHOICE {
     singleFee    FeeEntry,
     multipleFees [0] EXPLICIT SEQUENCE OF FeeEntry
 }
 
 FeeEntry ::= SEQUENCE {
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
    case inconsistentQuote
    case emptyFeeEntries
}

public struct FeeEntry {
    public let amount: BigInt
    public let payTo: Account?
    public let token: Account?

    public init(amount: BigInt, payTo: Account? = nil, token: Account? = nil) {
        self.amount = amount
        self.payTo = payTo
        self.token = token
    }

    init(from sequence: [ASN1]) throws {
        guard (2...4).contains(sequence.count) else {
            throw FeeError.invalidASN1SequenceLength
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

        self.amount = amount
        self.payTo = payTo
        self.token = token
    }
}

public struct Fee {
    public let quote: Bool
    public let entries: [FeeEntry]

    public init(quote: Bool, entries: [FeeEntry]) {
        self.quote = quote
        self.entries = entries
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

        if let sequence = feesAsn1.first?.sequenceValue {
            // Single fee format
            guard let quote = sequence[0].booleanValue else {
                throw FeeError.invalidQuote
            }
            self.quote = quote
            self.entries = [try FeeEntry(from: sequence)]
        } else if let innerTag = feesAsn1.first?.taggedValue, innerTag.isContextSpecific, innerTag.contextSpecificTag == 0 {
            // Multi-fee format: [0] EXPLICIT SEQUENCE OF FeeEntry
            let innerAsn1 = try ASN1Serialization.asn1(fromDER: innerTag.data)
            guard let outerSequence = innerAsn1.first?.sequenceValue else {
                throw FeeError.invalidASN1Sequence
            }

            var entries = [FeeEntry]()
            var quote: Bool?

            for element in outerSequence {
                guard let entrySequence = element.sequenceValue else {
                    throw FeeError.invalidASN1Sequence
                }
                guard let entryQuote = entrySequence[0].booleanValue else {
                    throw FeeError.invalidQuote
                }
                if let existingQuote = quote {
                    guard existingQuote == entryQuote else {
                        throw FeeError.inconsistentQuote
                    }
                } else {
                    quote = entryQuote
                }
                entries.append(try FeeEntry(from: entrySequence))
            }

            guard let quote, !entries.isEmpty else {
                throw FeeError.emptyFeeEntries
            }

            self.quote = quote
            self.entries = entries
        } else {
            throw FeeError.invalidASN1Sequence
        }
    }

    /// Find a fee entry matching the given token.
    /// When `isBaseToken` is true, also matches entries with no token (which default to the base token).
    public func entry(for token: Account, isBaseToken: Bool = false) -> FeeEntry? {
        entries.first { entry in
            if isBaseToken && entry.token == nil { return true }
            return entry.token?.publicKeyString == token.publicKeyString
        }
    }
}

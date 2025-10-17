import PotentASN1

public struct BlockHash {
    public static func parse(from blocksAsn1: [ASN1]) throws -> [String] {
        guard let blocksTag = blocksAsn1.first?.taggedValue, blocksTag.isContextSpecific else {
            throw VoteError.invalidBlocksTag
        }
        guard let blocksDataSequence = (try ASN1Serialization.asn1(fromDER: blocksTag.data)).first?.sequenceValue else {
            throw VoteError.invalidBlocksDataSequence
        }
        guard blocksDataSequence.count == 2 else {
            throw VoteError.invalidBlocksSequenceLength
        }
        guard let hashAlgoOidValue = blocksDataSequence[0].objectIdentifierValue else {
            throw VoteError.invalidBlocksOID
        }
        guard let hashAlgoOID = OID(rawValue: hashAlgoOidValue.description) else {
            throw VoteError.unknownHashFunction(hashAlgoOidValue.description)
        }
        guard Hash.oid == hashAlgoOID else {
            throw VoteError.unsupportedHashFunction(hashAlgoOID)
        }
        guard let blocksSequence = blocksDataSequence[1].sequenceValue else {
            throw VoteError.invalidBlocksSequence
        }
        
        return try blocksSequence.map {
            guard let blockHash = $0.octetStringValue?.hexString else {
                throw VoteError.invalidBlockHash
            }
            return blockHash
        }
    }
}

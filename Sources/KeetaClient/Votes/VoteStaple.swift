import Foundation
import BigInt
import PotentASN1

enum VoteStapleError: Error, Equatable {
    case missingVotes
    case invalidData
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidASN1BlockSequence
    case invalidASN1BlockData
    case invalidASN1VoteData
    case invalidASN1VotesSequence
    case blocksAndVotesCountNotMatching
    case voteBlockHashNotFound(String)
    case repVotedMoreThanOnce
    case inconsistentBlocksAndVoteBlocks
    case inconsistentVotePermanence
    case inconsistentVoteBlockHashesOrder
}

public struct VoteStaple {
    public let blocks: [Block]
    public let votes: [Vote]
    public let data: Data
    
    public static func create(from votes: [Vote], blocks: [Block]) throws -> Self {
        guard !votes.isEmpty else {
            throw VoteStapleError.missingVotes
        }
        
        let blockHashOrdering = Dictionary(
            uniqueKeysWithValues: votes[0].blocks.enumerated().map { ($1, $0) }
        )
        let blocksOrdered = blocks.sorted {
            blockHashOrdering[$0.hash, default: 0] < blockHashOrdering[$1.hash, default: 0]
        }
        
        let votesOrdered = votes.sorted {
            (BigInt(hex: "0x\($0.hash)") ?? .zero) < (BigInt(hex: "0x\($1.hash)") ?? .zero)
        }
        
        let asn1Values: [ASN1] = [
            .sequence(try blocksOrdered.map { .octetString(try $0.toData()) }),
            .sequence(votesOrdered.map { .octetString($0.toData()) })
        ]
        
        let data = try asn1Values.toData()
        return try create(from: data, compressed: false)
    }
    
    public static func create(from base64: String) throws -> Self {
        guard let data = Data(base64Encoded: base64) else {
            throw VoteStapleError.invalidData
        }
        return try create(from: data, compressed: true)
    }
    
    public static func create(from data: Data, compressed: Bool) throws -> Self {
        let decompressed = compressed ? decompress(data) : data
        
        let asn1 = try ASN1Serialization.asn1(fromDER: decompressed)
        
        guard let sequence = asn1.first?.sequenceValue else {
            throw VoteStapleError.invalidASN1Sequence
        }
        guard sequence.count == 2 else {
            throw VoteStapleError.invalidASN1SequenceLength
        }
        
        let blocksSequence = sequence[0]
        let votesSequence = sequence[1]
        
        guard let blocksRaw = blocksSequence.sequenceValue else {
            throw VoteStapleError.invalidASN1BlockSequence
        }
        guard let votesRaw = votesSequence.sequenceValue else {
            throw VoteStapleError.invalidASN1VotesSequence
        }
        
        let votes: [Vote] = try votesRaw.map { voteAsn1 in
            guard let voteData = voteAsn1.octetStringValue else {
                throw VoteStapleError.invalidASN1VoteData
            }
            return try Vote(from: voteData)
        }
        
        let unorderedBlocks: [Block] = try blocksRaw.map { blockAsn1 in
            guard let blockData = blockAsn1.octetStringValue else {
                throw VoteStapleError.invalidASN1BlockData
            }
            return try Block(from: blockData)
        }
        let blockHashes = Dictionary(uniqueKeysWithValues: unorderedBlocks.map { ($0.hash, $0) })
        
        // Ensure there is at least one vote for each block
        guard Set(votes.map(\.blocks).reduce([], +)).count == unorderedBlocks.count else {
            throw VoteStapleError.blocksAndVotesCountNotMatching
        }
        
        // Order blocks by the vote ordering
        let orderedBlocks = votes[0].blocks.compactMap { blockHashes[$0.uppercased()] }
        
        guard unorderedBlocks.count == orderedBlocks.count else {
            throw VoteStapleError.inconsistentBlocksAndVoteBlocks
        }
        
        // Ensure blocks are sorted the same way as the vote
        let orderedBlockHashes = orderedBlocks.map { $0.hash.lowercased() }
        
        for vote in votes {
            if orderedBlockHashes != vote.blocks {
                throw VoteStapleError.inconsistentVoteBlockHashesOrder
            }
        }
        
        // Ensure no representative has more than 1 vote in the bundle
        // and that every vote has the same level of permanence
        var seenReps = Set<String>()
        var votesPermanence: Bool?
        
        for vote in votes {
            guard seenReps.insert(vote.issuer.publicKeyString).inserted else {
                throw VoteStapleError.repVotedMoreThanOnce
            }
            guard let votesPermanence else {
                votesPermanence = vote.permanent
                continue
            }
            if votesPermanence != vote.permanent {
                throw VoteStapleError.inconsistentVotePermanence
            }
        }
        
        return .init(blocks: orderedBlocks, votes: votes, data: decompressed)
    }
    
    public func base64String() -> String {
        data.base64EncodedString()
    }
    
    /// Totoal amount of each token
    public func totalFees(baseToken: Account) -> [String: BigInt] {
        var result: [String: BigInt] = [:]
        for vote in votes {
            if let fee = vote.fee {
                let token = (fee.token ?? baseToken).publicKeyString
                result[token, default: 0] += fee.amount
            }
        }
        return result
    }
    
    public var totalFees: BigInt {
        votes.reduce(0) { result, vote in
            result + (vote.fee?.amount ?? 0)
        }
    }
}

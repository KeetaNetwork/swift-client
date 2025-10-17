import Foundation

internal struct BlockVoteResponse: Decodable {
    let blockhash: String
    let votes: [CertificateContentResponse]?
}

internal struct VoteResponse: Decodable {
    let vote: CertificateContentResponse
}

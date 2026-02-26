import PotentASN1
import Foundation

public enum VoteQuoteError: Error {
    case invalidPermanentVote
    case invalidHashDataExtension
    case invalidFeeDataExtension
    case missingFeeExtension
    case unknownCriticalExtension(OID)
}

public struct VoteQuote {
    public let certificate: Certificate
    public let issuer: Account
    public let blocks: [String] // Hashes
    public let fee: Fee
    private let data: Data
    
    // Convenience getter
    public var id: String { certificate.id }
    public var hash: String { certificate.hash }
    public var serial: Serial { certificate.serial }
    public var validityFrom: Date { certificate.validityFrom }
    public var validityTo: Date { certificate.validityTo }
    public var permanent: Bool { certificate.permanent }
    public var signature: Signature { certificate.signature }
    
    public static func create(from base64: String) throws -> Self {
        guard let data = Data(base64Encoded: base64) else {
            throw VoteStapleError.invalidData
        }
        return try .init(from: data)
    }
    
    public init(from data: Data) throws {
        let certificate = try Certificate(from: data)
        
        if certificate.permanent {
            throw VoteQuoteError.invalidPermanentVote
        }
        
        // Parse extensions
        var blocks = [String]()
        var fee: Fee?
        
        for (oid, `extension`) in certificate.extensions {
            switch oid {
            case .hashData:
                guard let blocksData = `extension`.data.octetStringValue else {
                    throw VoteQuoteError.invalidHashDataExtension
                }
                let blocksAsn1 = try ASN1Serialization.asn1(fromDER: blocksData)
                blocks.append(contentsOf: try BlockHash.parse(from: blocksAsn1))
            case .fees:
                guard let feeData = `extension`.data.octetStringValue else {
                    throw VoteQuoteError.invalidFeeDataExtension
                }
                let feesAsn1 = try ASN1Serialization.asn1(fromDER: feeData)
                fee = try Fee(from: feesAsn1)
            default:
                if `extension`.critical {
                    throw VoteQuoteError.unknownCriticalExtension(oid)
                }
            }
        }
        
        guard let fee else {
            throw VoteQuoteError.missingFeeExtension
        }
        
        let issuer: Account = switch certificate.issuer {
            case .account(let account): account
            case .common: throw VoteError.invalidSigner
        }
        
        self.certificate = certificate
        self.issuer = issuer
        self.blocks = blocks
        self.fee = fee
        self.data = data
    }
    
    public func base64String() -> String {
        data.base64EncodedString()
    }
}

import Foundation
import BigInt
import PotentASN1

public enum VoteError: Error {
    case invalidExtensionSequence
    case invalidExtensionCriticalCheck
    case invalidExtensionOIDValue
    case invalidExtensionOID(String)
    case unknownCriticalExtension(OID)
    case invalidFeeDataExtension
    case invalidHashDataExtension
    case invalidBlocksTag
    case invalidBlocksDataSequence
    case invalidBlocksSequence
    case invalidBlocksOID
    case unsupportedHashFunction(OID)
    case unknownHashFunction(String)
    case invalidBlockHash
    case invalidBlocksSequenceLength
    case permanentVoteCanNotHaveFees
    case invalidSigner
}

/*
 -- Votes are X.509v3 Certificates with additional information stored within the extensions
 
 -- Extensions
 extensions     [3] EXPLICIT SEQUENCE {
     -- Block hashesh being voted for, as an extension
     hashDataExtension SEQUENCE {
         -- Hash Data
         extensionID OBJECT IDENTIFIER ( hashData ),
         -- Critical
         critical    BOOLEAN ( TRUE ),
         -- Data
         dataWrapper OCTET STRING (CONTAINING [0] EXPLICIT SEQUENCE {
             -- Hash Algorithm
             hashAlgorithm OBJECT IDENTIFIER,
             -- Block hashes
             hashes       SEQUENCE OF OCTET STRING
         })
     }
 }
 */

public struct Vote {
    public let certificate: Certificate
    public let issuer: Account
    public let blocks: [String] // Hashes
    public let fee: Fee?
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
        
        // Parse extensions
        var blocks = [String]()
        var fee: Fee?
        
        for (oid, `extension`) in certificate.extensions {
            switch oid {
            case .hashData:
                guard let blocksData = `extension`.data.octetStringValue else {
                    throw VoteError.invalidHashDataExtension
                }
                let blocksAsn1 = try ASN1Serialization.asn1(fromDER: blocksData)
                blocks.append(contentsOf: try BlockHash.parse(from: blocksAsn1))
            case .fees:
                guard let feeData = `extension`.data.octetStringValue else {
                    throw VoteError.invalidFeeDataExtension
                }
                let feesAsn1 = try ASN1Serialization.asn1(fromDER: feeData)
                fee = try Fee(from: feesAsn1)
            default:
                if `extension`.critical {
                    throw VoteError.unknownCriticalExtension(oid)
                }
            }
        }
        
        if fee != nil && certificate.permanent {
            throw VoteError.permanentVoteCanNotHaveFees
        }
        
        let issuer: Account = switch certificate.issuer {
            case .account(let account): account
            case .common: throw VoteError.invalidSigner
        }
        
        // Construct vote
        self.certificate = certificate
        self.issuer = issuer
        self.blocks = blocks
        self.fee = fee
        self.data = data
    }
    
    public func toData() -> Data {
        data
    }
    
    public func base64String() -> String {
        data.base64EncodedString()
    }
}

public extension [Vote] {
    var fees: [Fee] {
        compactMap { $0.fee }
    }
    
    var requiresFees: Bool {
        contains { $0.fee != nil }
    }
}

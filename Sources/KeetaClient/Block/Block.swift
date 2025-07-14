import Foundation
import BigInt
import PotentASN1

public typealias Signature = [UInt8]
public typealias NetworkID = BigInt
public typealias SubnetID = BigInt

public struct Block {
    public typealias Version = Int
    
    public let rawData: RawBlockData
    public let opening: Bool
    public let hash: String
    public let signature: Signature
    
    static let asn1Schema: Schema = .sequence([
        "version": .integer(),
        "network": .integer(),
        "subnet": .choiceOf([.integer(), .null]),
        "date": .time(kind: .generalized),
        "signer": .octetString(),
        "account": .choiceOf([.octetString(), .null]),
        "previous": .octetString(),
        "operations": .sequenceOf(.any),
        "signature": .integer()
    ])
    
    public static func accountOpeningHash(for account: Account) throws -> String {
        let publicKeyBytes = try account.keyPair.publicKey.toBytes()
        return Hash.create(from: publicKeyBytes)
    }
    
    public init(from rawBlock: RawBlockData, opening: Bool, signature: Signature? = nil) throws {
        let hash = try rawBlock.hash()
        let hashBytes = try hash.toBytes()
        
        let verifiedSignature: Signature
        if let signature = signature {
            let verified = try rawBlock.signer.verify(data: Data(hashBytes), signature: signature)
            guard verified else {
                throw BlockError.invalidSignature
            }
            verifiedSignature = signature
        } else {
            verifiedSignature = try rawBlock.signer.sign(data: Data(hashBytes))
        }
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = hash
        self.signature = verifiedSignature
    }
    
    public init(from data: Data) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        
        guard let sequence = asn1.first?.sequenceValue else {
            throw BlockError.invalidASN1Sequence
        }
        guard sequence.count == 9 else {
            throw BlockError.invalidASN1SequenceLength
        }
        
        guard let version = sequence[0].integerValue else {
            throw BlockError.invalidVersion
        }
        
        guard let network = sequence[1].integerValue else {
            throw BlockError.invalidNetwork
        }
        let subnet = sequence[2].integerValue
        guard let anyTime = sequence[3].generalizedTimeValue else {
            throw BlockError.invalidDate
        }
        
        guard let signerData = sequence[4].octetStringValue else {
            throw BlockError.invalidSigner
        }
        let signer = try Account(data: signerData)
        
        let account: Account
        if let accountData = sequence[5].octetStringValue {
            account = try Account(data: accountData)
            
            if account == signer {
                // Account should not be in block when it is same as signer
                throw BlockError.redundantAccount
            }
        } else {
            account = signer
        }
        
        guard let previousHashData = sequence[6].octetStringValue else {
            throw BlockError.invalidHash
        }
        let previousHash = previousHashData.toHexString()
        
        guard let operationsSequence = sequence[7].sequenceValue else {
            throw BlockError.invalidOperationsSequence
        }
        let operations = try operationsSequence.map { try BlockOperationBuilder.create(from: $0) }
        
        guard let signature = sequence[8].octetStringValue else {
            throw BlockError.invalidSignature
        }
        
        let opening = previousHash == account.publicKeyString
        
        let rawBlock = RawBlockData(
            version: Int(version) + 1,
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: signer,
            account: account,
            operations: operations,
            created: anyTime.zonedDate.utcDate
        )
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = try rawBlock.hash()
        self.signature = signature.bytes
    }

    public func toAsn1() throws -> [ASN1] {
        let rawASN1 = try rawData.asn1Values()
        return rawASN1 + [.octetString(.init(signature))]
    }
    
    public func toData() throws -> Data {
        try toAsn1().toData()
    }
    
    public func base64String() throws -> String {
        try toData().base64EncodedString()
    }
}

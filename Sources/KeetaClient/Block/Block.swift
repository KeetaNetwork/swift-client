import Foundation
import BigInt
import PotentASN1

public typealias Signature = [UInt8]
public typealias NetworkID = BigInt
public typealias SubnetID = BigInt

public enum BlockSignature: Hashable {
    case single(Signature)
    case multi([Signature])
    
    func toHexString() -> String {
        switch self {
        case .single(let signature): signature.toHexString()
        case .multi(let signatures): "Multi-signatures not implemented"
        }
    }
}

public struct Block {
    public typealias Signature = BlockSignature
    
    public let rawData: RawBlockData
    public let opening: Bool
    public let hash: String
    public let signature: Signature
    
    public enum Version: Int, CaseIterable {
        case v1
        case v2
        
        public var value: BigInt { BigInt(rawValue) }
        public var tag: UInt8 { UInt8(rawValue) }
        public static var all: [Self] { allCases }
        public static var latest: Self { all.last! }
        
        public static func > (lhs: Version, rhs: Version) -> Bool {
            lhs.rawValue > rhs.rawValue
        }
    }
    
    public enum Purpose: Int {
        case generic
        case fee
        
        public var value: BigInt { BigInt(rawValue) }
    }
    
    public static func accountOpeningHash(for account: Account) throws -> String {
        let publicKeyBytes = try account.keyPair.publicKey.toBytes()
        return Hash.create(from: publicKeyBytes)
    }
    
    public init(from rawBlock: RawBlockData, opening: Bool, signature: Signature? = nil) throws {
        let hash = try rawBlock.hash()
        let hashBytes = try hash.toBytes()
        
        let verifiedSignature: Signature
        if let signature = signature {
            switch signature {
            case .single(let signature):
                let verified = try rawBlock.signer.verify(data: Data(hashBytes), signature: signature)
                guard verified else {
                    throw BlockError.invalidSignature
                }
                verifiedSignature = .single(signature)
            case .multi:
                throw NSError(domain: "Multi-signatures not implemented", code: 0)
            }
        } else {
            verifiedSignature = .single(try rawBlock.signer.sign(data: Data(hashBytes)))
        }
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = hash
        self.signature = verifiedSignature
    }
    
    public init(from data: Data) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        
        let data: [ASN1]
        let version: Block.Version
        
        if let sequence = asn1.first?.sequenceValue {
            data = sequence
            
            guard let rawVersion = data[0].integerValue,
                  let versionValue = Block.Version(rawValue: Int(rawVersion)),
                  versionValue == .v1 else {
                throw BlockError.invalidVersion
            }
            version = versionValue
        } else if let tagged = asn1.first?.taggedValue {
            let asn1 = try ASN1Serialization.asn1(fromDER: tagged.data)
            guard let sequence = asn1.first?.sequenceValue else {
                throw BlockError.invalidASN1Sequence
            }
            data = sequence
            
            guard let rawVersion = tagged.contextSpecificTag,
                  let versionValue = Block.Version(rawValue: Int(rawVersion)),
                    versionValue > .v1 else {
                throw BlockError.invalidVersion
            }
            version = versionValue
        } else {
            throw BlockError.invalidASN1Schema
        }
        
        guard data.count == 8 || data.count == 9 else {
            throw BlockError.invalidASN1SequenceLength
        }
        
        let rawBlock: RawBlockData
        let signature: Signature
        let opening: Bool
        
        switch version {
        case .v1: (rawBlock, signature, opening) = try Self.blockDataV1(for: data)
        case .v2: (rawBlock, signature, opening) = try Self.blockDataV2(for: data)
        }
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = try rawBlock.hash()
        self.signature = signature
    }
    
    public func toAsn1() throws -> [ASN1] {
        let rawASN1 = try rawData.asn1Values()
        
        return switch signature {
        case .single(let signature):
            rawASN1 + [.octetString(.init(signature))]
        case .multi(let signatures):
            rawASN1 + signatures.map { .octetString(.init($0)) }
        }
    }
    
    public func toData() throws -> Data {
        switch rawData.version {
        case .v1:
            return try toAsn1().toData()
        case .v2:
            let tag = try TaggedValue.contextSpecific(tag: rawData.version.tag, try toAsn1())
            return try tag.toData()
        }
    }
    
    public func base64String() throws -> String {
        try toData().base64EncodedString()
    }
    
    // MARK: Helper
    
    private static func blockDataV1(for sequence: [ASN1]) throws -> (RawBlockData, Signature, Bool) {
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
            version: .v1,
            purpose: .generic,
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: signer,
            account: account,
            operations: operations,
            created: anyTime.zonedDate.utcDate
        )
        
        return (rawBlock, .single(signature.bytes), opening)
    }
    
    private static func blockDataV2(for sequence: [ASN1]) throws -> (RawBlockData, Signature, Bool) {
        guard let network = sequence[0].integerValue else {
            throw BlockError.invalidNetwork
        }
        let subnet = sequence[1].integerValue
        
        let offset = subnet != nil ? 0 : 1
        
        guard let anyTime = sequence[2 - offset].generalizedTimeValue else {
            throw BlockError.invalidDate
        }
        guard let purposeRaw = sequence[3 - offset].integerValue,
                let purpose = Block.Purpose(rawValue: Int(purposeRaw)) else {
            throw BlockError.invalidPurpose
        }
        
        guard let accountData = sequence[4 - offset].octetStringValue else {
            throw BlockError.invalidSigner
        }
        let account = try Account(data: accountData)
        
        let signerContainer = sequence[5 - offset]
        let signer: Account
        if signerContainer.isNull {
            signer = account
        } else if let signerData = signerContainer.octetStringValue {
            signer = try Account(data: signerData)
        } else {
            // TODO: implement 'this.signer = parseBlockSignerFieldContainer(signersContainer).parsed;'
            throw NSError(domain: "Multi-signatures not implemented", code: 0)
        }
        
        guard let previousHashData = sequence[6 - offset].octetStringValue else {
            throw BlockError.invalidHash
        }
        let previousHash = previousHashData.toHexString()
        
        guard let operationsSequence = sequence[7 - offset].sequenceValue else {
            throw BlockError.invalidOperationsSequence
        }
        let operations = try operationsSequence.map { try BlockOperationBuilder.create(from: $0) }
        
        let signatureContainer = sequence[8 - offset]
        let signature: Signature
        if let signatureValue = signatureContainer.octetStringValue {
            signature = .single(signatureValue.bytes)
        } else {
            // TODO: implement 'assertBlockSignatureField(signatureContainer);'
            throw BlockError.invalidSignature
        }
        
        let opening = previousHash == account.publicKeyString
        
        let rawBlock = RawBlockData(
            version: .v2,
            purpose: purpose,
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: signer,
            account: account,
            operations: operations,
            created: anyTime.zonedDate.utcDate
        )
        
        return (rawBlock, signature, opening)
    }
}

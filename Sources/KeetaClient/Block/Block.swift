import Foundation
import BigInt
import PotentASN1

public typealias Signature = [UInt8]
public typealias NetworkID = BigInt
public typealias SubnetID = BigInt

public enum BlockSignature: Hashable {
    case single(Signature)
    case multi([Signature])
}

public struct Block {
    public let rawData: RawBlockData
    public let opening: Bool
    public let hash: String
    public let signature: BlockSignature
    
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
        
        let verifiedSignature: BlockSignature
        if let signature = signature {
            let verified = try rawBlock.signer.account.verify(data: Data(hashBytes), signature: signature)
            guard verified else {
                throw BlockError.invalidSignature
            }
            verifiedSignature = .single(signature)
        } else {
            verifiedSignature = .single(try rawBlock.signer.account.sign(data: Data(hashBytes)))
        }
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = hash
        self.signature = verifiedSignature
    }
    
    public static func create(from base64: String) throws -> Self {
        guard let data = Data(base64Encoded: base64) else {
            throw BlockError.invalidData
        }
        return try .init(from: data)
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
        
        guard (8...10).contains(data.count) else {
            throw BlockError.invalidASN1SequenceLength
        }
        
        let rawBlock: RawBlockData
        let signature: BlockSignature
        let opening: Bool
        
        switch version {
        case .v1: (rawBlock, signature, opening) = try Self.blockDataV1(for: data)
        case .v2: (rawBlock, signature, opening) = try Self.blockDataV2(for: data)
        }
        
        self.rawData = rawBlock
        self.opening = opening
        self.hash = try rawBlock.hash()
        self.signature = signature
        
        // Verify block signature
        switch signature {
        case .single(let signature):
            let verified = try rawBlock.signer.account.verify(data: Data(try hash.toBytes()), signature: signature)
            if !verified { throw BlockError.invalidSignature }
        case .multi:
            break // currently not supported
        }
    }
    
    public func toAsn1() throws -> [ASN1] {
        let rawASN1 = try rawData.asn1Values()
        
        return switch signature {
        case .single(let signature):
            rawASN1 + [.octetString(.init(signature))]
        case .multi(let signatures):
            rawASN1 + [.sequence(signatures.map { .octetString(Data($0)) })]
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
    
    private static func blockDataV1(for sequence: [ASN1]) throws -> (RawBlockData, BlockSignature, Bool) {
        guard let network = sequence[1].integerValue else {
            throw BlockError.invalidNetwork
        }
        let subnet = sequence[2].integerValue
        
        let idempotent = try parseIdempotent(from: sequence[3])
        let offset = idempotent != nil ? 0 : 1
        
        guard let anyTime = sequence[4 - offset].generalizedTimeValue else {
            throw BlockError.invalidDate
        }
        
        guard let signerData = sequence[5 - offset].octetStringValue else {
            throw BlockError.invalidSigner
        }
        let signer = try Account(data: signerData)
        
        let account: Account
        if let accountData = sequence[6 - offset].octetStringValue {
            account = try Account(data: accountData)
            
            if account == signer {
                // Account should not be in block when it is same as signer
                throw BlockError.redundantAccount
            }
        } else {
            account = signer
        }
        
        guard let previousHashData = sequence[7 - offset].octetStringValue else {
            throw BlockError.invalidHash
        }
        let previousHash = previousHashData.toHexString()
        
        guard let operationsSequence = sequence[8 - offset].sequenceValue else {
            throw BlockError.invalidOperationsSequence
        }
        let operations = try operationsSequence.map { try BlockOperationBuilder.create(from: $0) }
        
        guard let signature = sequence[9 - offset].octetStringValue else {
            throw BlockError.invalidSignature
        }
        
        let opening = previousHash == account.publicKeyString
        
        let rawBlock = RawBlockData(
            version: .v1,
            purpose: .generic,
            idempotent: idempotent,
            previous: previousHash,
            network: network,
            subnet: subnet,
            signer: .single(signer),
            account: account,
            operations: operations,
            created: anyTime.zonedDate.utcDate
        )
        
        return (rawBlock, .single(signature.bytes), opening)
    }
    
    private static func blockDataV2(for sequence: [ASN1]) throws -> (RawBlockData, BlockSignature, Bool) {
        guard let network = sequence[0].integerValue else {
            throw BlockError.invalidNetwork
        }
        let subnet = sequence[1].integerValue
        var offset = subnet != nil ? 0 : 1
        
        let idempotent = try parseIdempotent(from: sequence[2 - offset])
        offset += idempotent != nil ? 0 : 1
        
        guard let anyTime = sequence[3 - offset].generalizedTimeValue else {
            throw BlockError.invalidDate
        }
        guard let purposeRaw = sequence[4 - offset].integerValue,
                let purpose = Block.Purpose(rawValue: Int(purposeRaw)) else {
            throw BlockError.invalidPurpose
        }
        
        guard let accountData = sequence[5 - offset].octetStringValue else {
            throw BlockError.invalidSigner
        }
        let account = try Account(data: accountData)
        
        let signerContainer = sequence[6 - offset]
        let signer: RawBlockData.Signer
        if signerContainer.isNull {
            signer = .single(account)
        } else if let signerData = signerContainer.octetStringValue {
            signer = .single(try Account(data: signerData))
        } else {
            signer = try parseMultiSig(signerContainer)
        }
        
        guard let previousHashData = sequence[7 - offset].octetStringValue else {
            throw BlockError.invalidHash
        }
        let previousHash = previousHashData.toHexString()
        
        guard let operationsSequence = sequence[8 - offset].sequenceValue else {
            throw BlockError.invalidOperationsSequence
        }
        let operations = try operationsSequence.map { try BlockOperationBuilder.create(from: $0) }
        
        let signatureContainer = sequence[9 - offset]
        let signature: BlockSignature
        if let signatureValue = signatureContainer.octetStringValue {
            signature = .single(signatureValue.bytes)
        } else if let signatureValues = signatureContainer.sequenceValue {
            let signatures = signatureValues.compactMap { $0.octetStringValue?.bytes }
            guard !signatures.isEmpty && signatures.count == signatureValues.count else {
                throw BlockError.missingMultiSigSignatures
            }
            signature = .multi(signatures)
        } else {
            throw BlockError.invalidSignature
        }
        
        let opening = previousHash == account.publicKeyString
                
        let rawBlock = RawBlockData(
            version: .v2,
            purpose: purpose,
            idempotent: idempotent,
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
    
    private static func parseMultiSig(_ container: ASN1, depth: Int = 0) throws -> RawBlockData.Signer {
        guard depth <= 3 else {
            throw BlockError.invalidMultiSigSignersDepth
        }
        
        guard let sequence = container.sequenceValue, sequence.count == 2 else {
            throw BlockError.invalidMultiSigSequence
        }
        
        guard let multiSigData = sequence[0].octetStringValue else {
            throw BlockError.invalidMultiSigAccount
        }
        
        let account = try Account(data: multiSigData)
        
        guard let signersSequence = sequence[1].sequenceValue else {
            throw BlockError.missingMultiSigSigners
        }
        
        var signers = [RawBlockData.Signer]()
        
        for item in signersSequence {
            if let accountData = item.octetStringValue {
                signers.append(.single(try Account(data: accountData)))
            } else if item.sequenceValue != nil {
                signers.append(try parseMultiSig(item, depth: depth + 1))
            } else {
                throw BlockError.invalidMultiSigSigners
            }
        }
        
        return .multi(account, signers)
    }
    
    private static func parseIdempotent(from asn1: ASN1) throws -> String? {
        guard let idempotentData = asn1.octetStringValue else { return nil }
        let idempotentString = String(data: idempotentData, encoding: .utf8) ?? idempotentData.base64EncodedString()
        return idempotentString
    }
}

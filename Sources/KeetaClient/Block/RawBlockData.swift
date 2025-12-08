import Foundation
import PotentASN1
import PotentCodables
import BigInt

public struct RawBlockData {
    public enum Signer: Hashable {
        case single(Account)
        case multi(Account, [Signer])
        
        public var account: Account {
            switch self {
            case .single(let account): account
            case .multi(let account, _): account
            }
        }
        
        func asn1Values() throws -> ASN1 {
            switch self {
            case .single(let account):
                    .octetString(Data(account.publicKeyAndType))
            case .multi(let account, let signers):
                    .sequence([
                        .octetString(Data(account.publicKeyAndType)),
                        .sequence(try signers.map { try $0.asn1Values() })
                    ])
            }
        }
    }
    
    public let version: Block.Version
    public let purpose: Block.Purpose
    public let idempotent: String?
    public let previous: String
    public let network: NetworkID
    public let subnet: SubnetID?
    public let signer: Signer
    public let account: Account
    public let operations: [BlockOperation]
    public let created: Date
}

extension RawBlockData {
    
    func toBytes() throws -> [UInt8] {
        try asn1Values().toData().bytes
    }
    
    func hash() throws -> String {
        switch version {
        case .v1: Hash.create(from: try toBytes(), length: 32)
        case .v2: try TaggedValue.contextSpecific(tag: version.tag, try asn1Values()).hash()
        }
    }
    
    func asn1Values() throws -> [ASN1] {
        let idempotentData: Data?
        if let idempotent {
            guard let data = Data(base64Encoded: idempotent) ?? idempotent.data(using: .utf8) else {
                throw BlockError.invalidIdempotentData
            }
            idempotentData = data
        } else {
            idempotentData = nil
        }
        
        let previousBytes = try previous.toBytes()
        let asn1Subnet: ASN1? = subnet.map { .integer($0) }
        let idempotent: ASN1? = idempotentData.map { .octetString($0) }
        
        let operations: [ASN1] = try operations.map { try $0.tagged() }
        let signerAccount = Data(signer.account.publicKeyAndType)
        let account = Data(account.publicKeyAndType)
        
        let result = switch version {
        case .v1:
            [
                .integer(version.value),
                .integer(network),
                asn1Subnet ?? .null,
                idempotent,
                .generalizedTime(ZonedDate(date: created, timeZone: .utc)),
                .octetString(signerAccount),
                account != signerAccount ? .octetString(account) : ASN1.null,
                .octetString(Data(previousBytes)),
                .sequence(operations)
            ].compactMap { $0 }
            
        case .v2:
            [
                .integer(network),
                asn1Subnet,
                idempotent,
                .generalizedTime(ZonedDate(date: created, timeZone: .utc)),
                .integer(purpose.value),
                .octetString(account),
                signerAccount != account ? try signer.asn1Values() : ASN1.null,
                .octetString(Data(previousBytes)),
                .sequence(operations)
            ].compactMap { $0 }
        }
        
        return result
    }
}

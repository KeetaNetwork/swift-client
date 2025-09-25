import Foundation
import PotentASN1
import PotentCodables
import BigInt

public struct RawBlockData {
    public let version: Block.Version
    public let purpose: Block.Purpose
    public let previous: String
    public let network: NetworkID
    public let subnet: SubnetID?
    public let signer: Account
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
        let previousBytes = try previous.toBytes()
        let asn1Subnet: ASN1? = subnet.map { .integer($0) }
        let operations: [ASN1] = try operations.map { try $0.tagged() }
        let signer = Data(signer.publicKeyAndType)
        let account = Data(account.publicKeyAndType)
        
        return switch version {
        case .v1:
            [
                .integer(version.value),
                .integer(network),
                asn1Subnet ?? .null,
                .generalizedTime(ZonedDate(date: created, timeZone: .utc)),
                .octetString(signer),
                account != signer ? .octetString(account) : ASN1.null,
                .octetString(Data(previousBytes)),
                .sequence(operations)
            ]
            
        case .v2:
            [
                .integer(network),
                asn1Subnet,
                .generalizedTime(ZonedDate(date: created, timeZone: .utc)),
                .integer(purpose.value),
                .octetString(account),
                signer != account ? .octetString(signer) : ASN1.null,
                .octetString(Data(previousBytes)),
                .sequence(operations)
            ].compactMap { $0 }
        }
    }
}

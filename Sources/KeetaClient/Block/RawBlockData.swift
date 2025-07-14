import Foundation
import PotentASN1
import PotentCodables
import BigInt

public struct RawBlockData {
    public let version: Block.Version
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
        Hash.create(from: try toBytes(), length: 32)
    }
    
    func asn1Values() throws -> [ASN1] {
        let previousBytes = try previous.toBytes()
        let asn1Subnet: ASN1 = subnet.map { .integer($0) } ?? .null
        let operations: [ASN1] = try operations.map { try $0.tagged() }
        
        return [
            .integer(BigInt(version - 1)),
            .integer(network),
            asn1Subnet,
            .generalizedTime(ZonedDate(date: created, timeZone: .utc)),
            .octetString(Data(signer.publicKeyAndType)),
            account != signer ? .octetString(Data(account.publicKeyAndType)) : ASN1.null,
            .octetString(Data(previousBytes)),
            .sequence(operations)
        ]
    }
}

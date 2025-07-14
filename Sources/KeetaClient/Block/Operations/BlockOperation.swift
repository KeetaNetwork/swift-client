import Foundation
import PotentASN1
import BigInt

public protocol BlockOperation {
    var operationType: BlockOperationType { get }
    
    func asn1Values() -> [ASN1]
    
    init(from sequence: [ASN1]) throws
}

public extension BlockOperation {
    func to<T: BlockOperation>(_ type: T.Type) throws -> T {
        try type.init(from: asn1Values())
    }
    
    func tagged() throws -> ASN1 {
        let data = try asn1Values().toData()
        let contextSpecificBase: UInt8 = 0xA0
        let tag = contextSpecificBase + operationType.rawValue
        return .tagged(tag, data)
    }
}

public enum BlockOperationType: UInt8, CaseIterable {
    case send = 0
    case setRep = 1
    case setInfo = 2
    case createIdentifier = 4
    case tokenAdminSupply = 5
    case tokenAdminModifyBalance = 6
    case receive = 7
}

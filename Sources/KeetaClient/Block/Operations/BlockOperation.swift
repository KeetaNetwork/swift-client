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
        try TaggedValue.contextSpecific(tag: operationType.rawValue, asn1Values()).asn1
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

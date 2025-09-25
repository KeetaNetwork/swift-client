import Foundation
import PotentASN1

extension TaggedValue {
    static let contextSpecific: UInt8 = 0xA0
    
    static func contextSpecific(tag: UInt8, _ data: [ASN1]) throws -> Self {
        let data = try data.toData()
        let tag = contextSpecific + tag
        return .init(tag: tag, data: data)
    }
    
    var isContextSpecific: Bool {
        tag == Self.contextSpecific
    }
    
    var contextSpecificTag: UInt8? {
        tag >= Self.contextSpecific ? tag - Self.contextSpecific : nil
    }
    
    var implicitTag: UInt8 {
        // Mask to extract the last 5 bits from decimal value
        tag & 0b0001_1111
    }
    
    var asn1: ASN1 {
        .tagged(tag, data)
    }
    
    func toData() throws -> Data {
        try ASN1Serialization.der(from: .tagged(tag, data))
    }

    func hash() throws -> String {
        Hash.create(from: try toData().bytes, length: 32)
    }
}

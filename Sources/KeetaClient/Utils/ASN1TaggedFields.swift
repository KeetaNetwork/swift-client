import Foundation
import PotentASN1

public enum ASN1TaggedFields {
    /// Parse an ASN.1 SEQUENCE of context-tagged fields into a dictionary of [tagNumber: UTF8 string value].
    public static func parse(from data: Data) throws -> [UInt8: String] {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        guard let sequence = asn1.first?.sequenceValue else {
            throw ASN1TaggedFieldsError.invalidASN1Structure
        }

        var fields: [UInt8: String] = [:]
        for item in sequence {
            guard let tagged = item.taggedValue else { continue }
            let innerASN1 = try ASN1Serialization.asn1(fromDER: tagged.data)
            guard let stringValue = innerASN1.first?.utf8StringValue else { continue }
            fields[tagged.implicitTag] = String(stringValue)
        }
        return fields
    }
}

public enum ASN1TaggedFieldsError: Error {
    case invalidASN1Structure
}

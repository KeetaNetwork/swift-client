import Foundation
import PotentASN1

public extension CertificateAttribute {
    static func parseKYCExtension(_ extensionData: ASN1) throws -> [OID: CertificateAttribute] {
        guard let kycOctetString = extensionData.octetStringValue else {
            throw CertificateAttributeError.invalidKYCExtensionData
        }

        let kycASN1 = try ASN1Serialization.asn1(fromDER: kycOctetString)
        guard let kycSequence = kycASN1.first?.sequenceValue else {
            throw CertificateAttributeError.invalidKYCStructure
        }

        var result = [OID: CertificateAttribute]()

        for attrEntry in kycSequence {
            guard let attrSeq = attrEntry.sequenceValue,
                  attrSeq.count >= 2,
                  let oidValue = attrSeq[0].objectIdentifierValue,
                  let oid = OID(rawValue: oidValue.description),
                  let tagged = attrSeq[1].taggedValue else {
                continue
            }

            switch tagged.implicitTag {
            case 0:
                result[oid] = .plain(String(decoding: tagged.data, as: UTF8.self))
            case 1:
                result[oid] = .sensitive(try SensitiveAttribute(data: tagged.data))
            default:
                continue
            }
        }

        return result
    }
}

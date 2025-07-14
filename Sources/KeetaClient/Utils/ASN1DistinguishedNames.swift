import PotentASN1

public enum Match<T> {
    case known(T)
    case unknown(String)
}

extension Match: Equatable where T: Hashable {}
extension Match: Hashable where T: Hashable {}

public class ASN1DistinguishedNames {
    
    public let oid: String
    public let representation: String
    
    public init(oid: String, representation: String) {
        self.oid = oid
        self.representation = representation
    }
    
    public class func find(in asn1: [ASN1]) -> [Match<OID>: String] {
        var result = [Match<OID>: String]()
        for sub in asn1 {
            
            guard let content = sub.collectionValue?[0].collectionValue,
                  let tag = content[safe: 0], tag.knownTag == .objectIdentifier,
                  let tagValue = tag.objectIdentifierValue,
                  let value = content[safe: 1]?.utf8StringValue else {
                continue
            }
            
            let oidString = tagValue.description
            let match: Match<OID> = if let oid = OID(rawValue: oidString) {
                .known(oid)
            } else {
                .unknown(oidString)
            }
            
            result[match] = value.storage
        }
        
        return result
    }
    
    class func quote(string: String) -> String {
        let specialChar = ",+=\n<>#;\\"
        return if string.contains(where: { specialChar.contains($0) }) {
            "\"" + string + "\""
        } else {
            string
        }
    }
}

extension Dictionary where Key == Match<OID> {
    subscript(key: OID) -> Value? {
            get { self[.known(key)] }
            set { self[.known(key)] = newValue }
        }
}

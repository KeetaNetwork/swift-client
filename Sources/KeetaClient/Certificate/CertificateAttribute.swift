import Foundation
import PotentASN1

public enum CertificateAttributeError: Error {
    case invalidKYCExtensionData
    case invalidKYCStructure
    case notSensitive
    case attributeNotFound(OID)
    case invalidUTF8Value
}

/*
 Represents a single KYC attribute from a certificate extension.
 Can be either sensitive (encrypted) or plain (unencrypted).

 Matches the anchor's attribute union type:
 `{ sensitive: true, value: SensitiveAttribute } | { sensitive: false, value: ArrayBuffer }`

 Within the KYC extension, each attribute is encoded as:
 
 Attribute ::= SEQUENCE {
     oid   OBJECT IDENTIFIER,
     value CHOICE {
         plainValue     [0] IMPLICIT OCTET STRING,
         sensitiveValue [1] IMPLICIT OCTET STRING
     }
 }
*/

public enum CertificateAttribute {
    case plain(String)
    case sensitive(SensitiveAttribute)

    public var isSensitive: Bool {
        if case .sensitive = self { return true }
        return false
    }

    public func value(using account: Account) throws -> String {
        switch self {
        case .plain(let value):
            return value
        case .sensitive(let attr):
            let bytes = try attr.value(account)
            guard let string = String(bytes: bytes, encoding: .utf8) else {
                throw CertificateAttributeError.invalidUTF8Value
            }
            return string
        }
    }

    public func rawValue(using account: Account) throws -> [UInt8] {
        switch self {
        case .plain(let value):
            Array(value.utf8)
        case .sensitive(let attr):
            try attr.value(account)
        }
    }

    public func proof(using account: Account) throws -> SensitiveAttributeProof {
        switch self {
        case .plain:
            throw CertificateAttributeError.notSensitive
        case .sensitive(let attr):
            return try attr.proof(account)
        }
    }

    public func validateProof(_ proof: SensitiveAttributeProof, publicKey: [UInt8]) throws -> Bool {
        switch self {
        case .plain:
            throw CertificateAttributeError.notSensitive
        case .sensitive(let attr):
            return try attr.validateProof(proof, publicKey: publicKey)
        }
    }
}

public extension [OID: CertificateAttribute] {
    
    func proofs(for oids: Set<OID>, account: Account) throws -> [OID: SensitiveAttributeProof] {
        var proofs = [OID: SensitiveAttributeProof]()
        for oid in oids {
            guard let attr = self[oid] else {
                throw CertificateAttributeError.attributeNotFound(oid)
            }
            proofs[oid] = try attr.proof(using: account)
        }
        return proofs
    }

}

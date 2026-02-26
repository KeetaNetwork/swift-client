import Foundation
import BigInt
import PotentASN1

public typealias Serial = BigInt

public enum CertificateError: Error {
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidCertificateSequence
    case invalidCertificateSequenceLength
    case invalidCertificateAlgorithmSequence
    case invalidCertificateValue
    case invalidSignatureInfoOID
    case unknownSignatureInfoOID(String)
    case invalidIssuerData
    case invalidValiditySequenceLength
    case invalidValidityData
    case invalidValidity
    case invalidVersion
    case serialMismatch
    case invalidSignatureInfoSequence
    case invalidSignatureInfoSequenceLength
    case invalidSignatureSequence
    case invalidSignatureSequenceLength
    case invalidSignatureDataBitString
    case invalidSignatureDataOID
    case unknownSignatureDataOID(String)
    case invalidSignatureData
    case signatureInformationMismatch
    case unsupportedSignatureScheme
    case signatureAlgorithmMismatch
    case issuerSignatureSchemeMismatch
    case invalidExtensions
}

/*
 -- Votes are
     Vote ::= SEQUENCE {
         -- Data (to be signed)
         data SEQUENCE {
             -- Version
             version        [0] EXPLICIT INTEGER { v3(2) },
             -- Serial number
             serial         INTEGER,
             -- Signature algorithm
             signature      SEQUENCE {
                 -- Algorithm
                 algorithm    OBJECT IDENTIFIER,
                 -- Parameters
                 parameters   ANY OPTIONAL
             },
             -- Issuer
             issuer         SEQUENCE {
                 dn     SET OF SEQUENCE {
                     -- Attribute type (commonName, 2.5.4.3)
                     type   OBJECT IDENTIFIER ( commonName ),
                     -- Attribute value
                     value  UTF8String
                 }
             },
             -- Validity
             validity       SEQUENCE {
                 -- Not before
                 notBefore     GeneralizedTime,
                 -- Not after
                 notAfter      GeneralizedTime
             },
             -- Subject
             subject        SEQUENCE {
                 dn     SET OF SEQUENCE {
                     -- Attribute type (serialNumber, 2.5.4.5)
                     type   OBJECT IDENTIFIER ( serialNumber ),
                     -- Attribute value
                     value  UTF8String
                 }
             },
             -- Subject public key info
             subjectPKInfo  SEQUENCE {
                 -- Algorithm
                 algorithm    SEQUENCE {
                     -- Algorithm
                     algorithm    OBJECT IDENTIFIER,
                     -- Parameters
                     parameters   ANY
                 },
                 -- Public key
                 publicKey     BIT STRING
             },
            -- Extensions
            extensions     [3] EXPLICIT SEQUENCE {
                -- Any extensions used by the Keeta network
            },
         },
         -- Signature algorithm
         signatureAlgorithm SEQUENCE {
             -- Algorithm
             algorithm    OBJECT IDENTIFIER,
             -- Parameters
             parameters   ANY OPTIONAL
         },
         -- Signature
         signature      BIT STRING
    }
 */

// X.509v3 Certificates
public struct Certificate: Hashable {
    
    public enum Issuer: Hashable {
        case account(Account)
        case common(String)
        
        var display: String {
            switch self {
            case .account(let account):
                account.publicKeyString
            case .common(let value):
                value
            }
        }
    }
    
    public struct Subject: Hashable {
        public let name: String
        public let account: Account
    }
    
    public let id: String
    public let hash: String
    public let version: BigInt
    public let issuer: Issuer
    public let serial: Serial
    public let subject: Subject
    public let validityFrom: Date
    public let validityTo: Date
    public let signature: Signature
    public let permanent: Bool
    public let extensions: [OID: Extension]
    public let intermediates: [Certificate]?
    private let data: Data
    
    public struct Extension: Hashable {
        public let data: ASN1
        public let critical: Bool
        
        public init(data: ASN1, critical: Bool) {
            self.data = data
            self.critical = critical
        }
    }
    
    public static let version = BigInt(2) // v3
    
    static let header = "-----BEGIN CERTIFICATE-----"
    static let footer = "-----END CERTIFICATE-----"
    
    public static func create(from pem: String, intermediates: [String]? = nil) throws -> Self {
        let intermediates = try intermediates?.map { try toData($0) }
        return try Certificate(from: toData(pem), intermediates: intermediates)
    }
    
    public static func toData(_ pem: String) throws -> Data {
        guard let data = Data(base64Encoded: normalize(pem), options: .ignoreUnknownCharacters) else {
            throw VoteStapleError.invalidData
        }
        return data
    }
    
    public static func normalize(_ pem: String) -> String {
        if pem.contains(header) {
            pem
                .replacingOccurrences(of: header, with: "")
                .replacingOccurrences(of: footer, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            pem
        }
    }
    
    static func isPermanent(validTo: Date) -> Bool {
        let permanentVoteThreshold: TimeInterval = 100/* y */ * 365/* d */ * 86400/* s */
        // If the vote is forever viable, it is a permanent vote
        return validTo > Date().addingTimeInterval(permanentVoteThreshold)
    }
    
    public init(from data: Data, intermediates: [Data]? = nil) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        
        guard let sequence = asn1.first?.sequenceValue else {
            throw CertificateError.invalidASN1Sequence
        }
        
        // Sequence contains the vote, signature info, and signature
        guard sequence.count == 3 else {
            throw CertificateError.invalidASN1SequenceLength
        }
        
        // The contents of the X.509 certificate signed area
        guard let certContent = sequence[0].sequenceValue else {
            throw CertificateError.invalidCertificateSequence
        }
        guard certContent.count == 8 else {
            throw CertificateError.invalidCertificateSequenceLength
        }
        
        guard let versionValue = certContent[0].taggedValue,
              let serial = certContent[1].integerValue,
              let signatureInfo = certContent[2].sequenceValue,
              let issuerWrapper = certContent[3].sequenceValue,
              let validityInfo = certContent[4].sequenceValue,
            let subjectWrapper = certContent[5].sequenceValue,
            let subjectPublicKey = certContent[6].sequenceValue,
            let extensionsArea = certContent[7].taggedValue else {
            throw CertificateError.invalidCertificateValue
        }
        
        guard let signatureAlgorithm = sequence[1].sequenceValue else {
            throw CertificateError.invalidCertificateAlgorithmSequence
        }
        guard signatureInfo == signatureAlgorithm else {
            throw CertificateError.signatureAlgorithmMismatch
        }
        
        // Validate version
        guard versionValue.isContextSpecific, versionValue.data.count >= 3 else {
            throw CertificateError.invalidVersion
        }
        guard let versionTag = ASN1.Tag(rawValue: versionValue.data[0]), versionTag == .integer else {
            throw CertificateError.invalidVersion
        }
        let versionLength = versionValue.data[1]
        let version = BigInt(versionValue.data[2...].suffix(Int(versionLength)).reduce(0, +))
        guard version == Self.version else {
            throw CertificateError.invalidVersion
        }
        
        let tbsCertificate = try X509Certificate.signedArea(from: data)
        
        // Signature information
        guard signatureInfo.count == 1 else {
            throw CertificateError.invalidSignatureInfoSequenceLength
        }
        guard let signatureInfoOidValue = signatureInfo[0].objectIdentifierValue else {
            throw CertificateError.invalidSignatureInfoOID
        }
        guard let signatureInfoOid = OID(rawValue: signatureInfoOidValue.description) else {
            throw CertificateError.unknownSignatureInfoOID(signatureInfoOidValue.description)
        }
        
        // Issuer information
        let issuerContent = ASN1DistinguishedNames.find(in: issuerWrapper)
        guard let issuerKey = issuerContent[.commonName] else {
            throw CertificateError.invalidIssuerData
        }
        
        let issuer: Issuer = if let account = try? AccountBuilder.create(fromPublicKey: issuerKey) {
            .account(account)
        } else {
            .common(issuerKey)
        }
        
        // Validity period
        guard validityInfo.count == 2 else {
            throw CertificateError.invalidValiditySequenceLength
        }
        
        guard let validFrom = (validityInfo[0].generalizedTimeValue?.zonedDate ?? validityInfo[0].utcTimeValue?.zonedDate)?.utcDate,
              let validTo = (validityInfo[1].generalizedTimeValue?.zonedDate ?? validityInfo[1].utcTimeValue?.zonedDate)?.utcDate else {
            throw CertificateError.invalidValidityData
        }
        
        // Votes must not have invalid validity periods
        guard validTo > validFrom else {
            throw CertificateError.invalidValidity
        }
        
        let permanent = Self.isPermanent(validTo: validTo)
        
        // Subject
        let subjectContent = ASN1DistinguishedNames.find(in: subjectWrapper)
        
        let subject = Subject(
            name: subjectContent.map { match, value in "\(match.description)=\(value)" }.joined(separator: ", "),
            account: try Account.create(from: subjectPublicKey)
        )
        
        // Validate subject serial number
        if let subjectSeral = subjectContent[.serialNumber] {
            guard serial == BigInt(hex: "0x\(subjectSeral)") else {
                throw CertificateError.serialMismatch
            }
        }
        
        // Signature data
        guard let voteSignatureInfoWrapper = sequence[1].sequenceValue else {
            throw CertificateError.invalidSignatureSequence
        }
        guard voteSignatureInfoWrapper.count == 1 else {
            throw CertificateError.invalidSignatureSequenceLength
        }
        guard let voteSignatureInfoOidValue = voteSignatureInfoWrapper[0].objectIdentifierValue else {
            throw CertificateError.invalidSignatureDataOID
        }
        guard let voteSignatureInfoOid = OID(rawValue: voteSignatureInfoOidValue.description) else {
            throw CertificateError.unknownSignatureDataOID(voteSignatureInfoOidValue.description)
        }
        // Ensure the certificate and the wrapper agree on the signature method being used
        guard voteSignatureInfoOid == signatureInfoOid else {
            throw CertificateError.signatureInformationMismatch
        }
        
        // Extensions
        let asn1Extensions = try ASN1Serialization.asn1(fromDER: extensionsArea.data)
        guard let extensionsSequence = asn1Extensions.first?.sequenceValue else {
            throw CertificateError.invalidExtensions
        }
        
        var extensions = [OID: Extension]()
        for extensionInfo in extensionsSequence {
            guard let extensionSequence = extensionInfo.sequenceValue,
                  extensionSequence.count == 2 || extensionSequence.count == 3 else {
                throw VoteError.invalidExtensionSequence
            }
            guard let oidValue = extensionSequence[0].objectIdentifierValue else {
                throw VoteError.invalidExtensionOIDValue
            }
            
            guard let oid = OID(rawValue: oidValue.description) else {
                throw VoteError.invalidExtensionOID(oidValue.description)
            }
            
            let critical: Bool
            if extensionSequence.count == 3 {
                guard let criticalCheck = extensionSequence[1].booleanValue else {
                    throw VoteError.invalidExtensionCriticalCheck
                }
                critical = criticalCheck
            } else {
                critical = false
            }
            
            guard let extensionData = extensionSequence.last else {
                throw VoteError.invalidHashDataExtension
            }
            extensions[oid] = .init(data: extensionData, critical: critical)
        }
        
        // Verify signature
        let toVerify: Data
        
        switch voteSignatureInfoOid {
        case .ecdsaWithSHA3_256:
            if case .account(let issuer) = issuer {
                guard issuer.keyAlgorithm == .ECDSA_SECP256K1 else {
                    throw CertificateError.issuerSignatureSchemeMismatch
                }
            }
            toVerify = Hash.create(from: tbsCertificate)
        case .ed25519:
            if case .account(let issuer) = issuer {
                guard issuer.keyAlgorithm == .ED25519 else {
                    throw CertificateError.issuerSignatureSchemeMismatch
                }
            }
            toVerify = tbsCertificate
        default: throw CertificateError.unsupportedSignatureScheme
        }
        
        // Get the signature
        guard let voteSignature = sequence[2].bitStringValue else {
            throw CertificateError.invalidSignatureDataBitString
        }
        let signature = voteSignature.bytes.toBytes()
        
        if case .account(let issuer) = issuer {
            guard try issuer.verify(data: toVerify, signature: signature, options: .init(raw: true, forCert: true)) else {
                throw CertificateError.invalidSignatureData
            }
        }
        
        // Construct certificate
        self.id = "ID=\(issuer.display)/Serial=\(serial)"
        hash = Hash.create(from: data.bytes)
        self.version = version
        self.serial = serial
        self.issuer = issuer
        self.signature = signature
        self.validityFrom = validFrom
        self.validityTo = validTo
        self.permanent = permanent
        self.subject = subject
        self.extensions = extensions
        self.data = data
        self.intermediates = try intermediates?.map { try Certificate(from: $0, intermediates: nil) }
    }
    
    public func toData() -> Data {
        data
    }
    
    public func base64String() -> String {
        data.base64EncodedString()
    }
}

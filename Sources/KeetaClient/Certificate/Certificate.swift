import Foundation
import BigInt
import PotentASN1

public typealias Serial = BigInt

public enum CertificateError: Error {
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidCertificateSequence
    case invalidCertificateSequenceLength
    case invalidCertificateValue
    case invalidSignatureInfoOID
    case unknownSignatureInfoOID(String)
    case invalidIssuerData
    case invalidValiditySequenceLength
    case invalidValidityData
    case invalidValidity
    case invalidSubjectData
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
public struct Certificate {
    public let id: String
    public let hash: String
    public let version: BigInt
    public let issuer: Account
    public let serial: Serial
    public let validityFrom: Date
    public let validityTo: Date
    public let signature: Signature
    public let permanent: Bool
    public let extensions: [OID: Extension]
    
    public struct Extension {
        public let data: ASN1
        public let critical: Bool
        
        public init(data: ASN1, critical: Bool) {
            self.data = data
            self.critical = critical
        }
    }
    
    private let data: Data
    
    public static let version = BigInt(2) // v3
    
    public static func create(from base64: String) throws -> Self {
        guard let data = Data(base64Encoded: base64) else {
            throw VoteStapleError.invalidData
        }
        return try .init(from: data)
    }
    
    static func isPermanent(validTo: Date) -> Bool {
        let permanentVoteThreshold: TimeInterval = 100/* y */ * 365/* d */ * 86400/* s */
        // If the vote is forever viable, it is a permanent vote
        return validTo > Date().addingTimeInterval(permanentVoteThreshold)
    }
    
    public init(from data: Data) throws {
        let asn1 = try ASN1Serialization.asn1(fromDER: data)
        
        guard let sequence = asn1.first?.sequenceValue else {
            throw CertificateError.invalidASN1Sequence
        }
        
        // Sequence contains the vote, signature info, and signature
        guard sequence.count == 3 else {
            throw CertificateError.invalidASN1SequenceLength
        }
        
        /*
         The contents of the X.509 certificate signed area
         */
        guard let voteContent = sequence[0].sequenceValue else {
            throw CertificateError.invalidCertificateSequence
        }
        guard voteContent.count == 8 else {
            throw CertificateError.invalidCertificateSequenceLength
        }
        
        guard let versionValue = voteContent[0].taggedValue,
              let serial = voteContent[1].integerValue,
              let signatureInfo = voteContent[2].sequenceValue,
              let issuerWrapper = voteContent[3].sequenceValue,
              let validityInfo = voteContent[4].sequenceValue,
            let subjectWrapper = voteContent[5].sequenceValue,
            // voteContent[6].sequenceValue // Subject Public Key: We don't use this information
            let extensionsArea = voteContent[7].taggedValue else {
            throw CertificateError.invalidCertificateValue
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
        let issuer = try AccountBuilder.create(fromPublicKey: issuerKey)
        
        // Validity period
        guard validityInfo.count == 2 else {
            throw CertificateError.invalidValiditySequenceLength
        }
        guard let validFrom = validityInfo[0].generalizedTimeValue?.zonedDate.utcDate,
              let validTo = validityInfo[1].generalizedTimeValue?.zonedDate.utcDate else {
            throw CertificateError.invalidValidityData
        }
        
        // Votes must not have invalid validity periods
        guard validTo > validFrom else {
            throw CertificateError.invalidValidity
        }
        
        let permanent = Self.isPermanent(validTo: validTo)
        
        // Subject
        let subjectContent = ASN1DistinguishedNames.find(in: subjectWrapper)
        guard let subjectSeral = subjectContent[.serialNumber] else {
            throw CertificateError.invalidSubjectData
        }
        guard serial == BigInt(hex: "0x\(subjectSeral)") else {
            throw CertificateError.serialMismatch
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
        
        let toVerify: Data
        
        switch voteSignatureInfoOid {
        case .ecdsaWithSHA3_256:
            guard issuer.keyAlgorithm == .ECDSA_SECP256K1 else {
                throw CertificateError.issuerSignatureSchemeMismatch
            }
            toVerify = Hash.create(from: tbsCertificate)
        case .ed25519:
            guard issuer.keyAlgorithm == .ED25519 else {
                throw CertificateError.issuerSignatureSchemeMismatch
            }
            toVerify = tbsCertificate
        default: throw CertificateError.unsupportedSignatureScheme
        }
        
        // Get the signature
        guard let voteSignature = sequence[2].bitStringValue else {
            throw CertificateError.invalidSignatureDataBitString
        }
        let signature = voteSignature.bytes.bytes
        
        guard try issuer.verify(data: toVerify, signature: signature, options: .init(raw: true, forCert: true)) else {
            throw CertificateError.invalidSignatureData
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
            guard let oidValue = extensionSequence[0].objectIdentifierValue,
                    let oid = OID(rawValue: oidValue.description) else {
                throw VoteError.invalidExtensionOID
            }
            
            let critical: Bool
            if extensionSequence.count == 2 {
                guard let criticalCheck = extensionSequence[1].booleanValue else {
                    throw VoteError.invalidExtensionCriticalCheck
                }
                critical = criticalCheck
            } else {
                critical = true
            }
            
            guard let extensionData = extensionSequence[safe: 2] else {
                throw VoteError.invalidHashDataExtension
            }
            extensions[oid] = .init(data: extensionData, critical: critical)
        }
        
        // Construct certificate
        self.id = "ID=\(issuer.publicKeyString)/Serial=\(serial)"
        hash = Hash.create(from: data.bytes)
        self.version = version
        self.serial = serial
        self.issuer = issuer
        self.signature = signature
        self.validityFrom = validFrom
        self.validityTo = validTo
        self.permanent = permanent
        self.extensions = extensions
        self.data = data
    }
    
    public func toData() -> Data {
        data
    }
    
    public func base64String() -> String {
        data.base64EncodedString()
    }
}

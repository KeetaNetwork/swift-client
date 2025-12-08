import Foundation
import BigInt
import PotentASN1

public enum CreateIdentifierOperationError: Error {
    case invalidSequenceLength
    case invalidIdentifier
    case invalidIdentifierKeyAlgorithm
    case invalidCreatorArgumentsTag
    case invalidCreatorArgumentsSequence
    case missingCreatorArguments
    case invalidCreatorArgumentsSignersSequence
    case missingCreatorArgumentsSigners
    case missingCreatorArgumentsSignersQuorum
    case invalidCreatorArgumentsSignersQuorum
}

/*
 -- CREATE_IDENTIFIER operation
         createidentifier [4] SEQUENCE {
             -- Identifier to create, this must match
             -- the deterministic identifier which is
             -- generated from the account, blockhash,
             -- and operation index
             identifier  OCTET STRING,

             createArguments CHOICE {
                 multiSigArguments [7] SEQUENCE {
                     signers SEQUENCE OF OCTET STRING,
                     quorum  INTEGER
                 }
             } OPTIONAL
         }
 */

public struct CreateIdentifierOperation: BlockOperation {
    public enum Arguments {
        case multisig(quorum: BigInt, signers: [Account])
        
        var key: Account.KeyAlgorithm {
            switch self {
            case .multisig: .MULTISIG
            }
        }
        
        public func asn1Values() throws -> [PotentASN1.ASN1] {
            switch self {
            case .multisig(let quorum, let signers):
                let tag = try TaggedValue.contextSpecific(tag: UInt8(key.rawValue), [
                    .sequence(signers.map { .octetString(Data($0.publicKeyAndType)) }),
                    .integer(quorum)
                ])
                return [tag.asn1]
            }
        }
    }
    
    public let operationType: BlockOperationType = .createIdentifier
    public let identifier: Account.PublicKeyAndType
    public let arguments: Arguments?
    
    public init(identifier: Account, arguments: Arguments? = nil) {
        self.identifier = identifier.publicKeyAndType
        self.arguments = arguments
    }
    
    public func asn1Values() throws -> [PotentASN1.ASN1] {
        [
            .octetString(Data(identifier))
        ] + (try arguments?.asn1Values() ?? [])
    }
    
    public init(from sequence: [PotentASN1.ASN1]) throws {
        guard sequence.count == 1 || sequence.count == 2 else {
            throw CreateIdentifierOperationError.invalidSequenceLength
        }
        guard let identifierData = sequence[0].octetStringValue else {
            throw CreateIdentifierOperationError.invalidIdentifier
        }
        let identifier = try Account(data: identifierData)
        
        switch identifier.keyAlgorithm {
        case .ECDSA_SECP256K1, .ED25519:
            throw CreateIdentifierOperationError.invalidIdentifierKeyAlgorithm
        case .NETWORK, .TOKEN, .STORAGE, .MULTISIG:
            break // valid
        }
        
        var arguments: Arguments?
        if let tag = sequence[safe: 1]?.taggedValue {
            let accountAlgorithm = Account.KeyAlgorithm(rawValue: Int(tag.implicitTag))
            guard accountAlgorithm == .MULTISIG else {
                throw CreateIdentifierOperationError.invalidCreatorArgumentsTag
            }
            let container = try ASN1Serialization.asn1(fromDER: tag.data)
            guard let sequence = container[safe: 0]?.sequenceValue, sequence.count == 2 else {
                throw CreateIdentifierOperationError.invalidCreatorArgumentsSequence
            }
            
            guard let signersSequence = sequence[0].sequenceValue else {
                throw CreateIdentifierOperationError.invalidCreatorArgumentsSignersSequence
            }
            let signersData = signersSequence.compactMap { $0.octetStringValue }
            guard !signersData.isEmpty else {
                throw CreateIdentifierOperationError.missingCreatorArgumentsSigners
            }
            let signers = try signersData.map { try Account(data: $0) }
            
            guard let quorum = sequence[1].integerValue else {
                throw CreateIdentifierOperationError.missingCreatorArgumentsSignersQuorum
            }
            guard quorum > 0 && quorum <= signers.count else {
                throw CreateIdentifierOperationError.invalidCreatorArgumentsSignersQuorum
            }
            arguments = .multisig(quorum: quorum, signers: signers)
        }
        
        let requiresArguments = identifier.keyAlgorithm == .MULTISIG
        if requiresArguments && arguments == nil {
            throw CreateIdentifierOperationError.missingCreatorArguments
        }
        
        self.init(identifier: identifier, arguments: arguments)
    }
}

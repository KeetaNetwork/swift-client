import Foundation
import BigInt
import PotentASN1

public enum CreateIdentifierOperationError: Error {
    case invalidSequenceLength
    case invalidIdentifier
    case invalidIdentifierKeyAlgorithm
}

/*
 -- CREATE_IDENTIFIER operation
         createidentifier [4] SEQUENCE {
             -- Identifier to create, this must match
             -- the deterministic identifier which is
             -- generated from the account, blockhash,
             -- and operation index
             identifier  OCTET STRING
         }
 */

public struct CreateIdentifierOperation: BlockOperation {
    public let operationType: BlockOperationType = .createIdentifier
    public let identifier: Account.PublicKeyAndType
    
    public init(identifier: Account) {
        self.identifier = identifier.publicKeyAndType
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        [
            .octetString(Data(identifier))
        ]
    }
    
    public init(from sequence: [PotentASN1.ASN1]) throws {
        guard sequence.count == 1 else {
            throw CreateIdentifierOperationError.invalidSequenceLength
        }
        guard let identifierData = sequence[0].octetStringValue else {
            throw CreateIdentifierOperationError.invalidIdentifier
        }
        let identifier = try Account(data: identifierData)
        
        switch identifier.keyAlgorithm {
        case .ECDSA_SECP256K1, .ED25519:
            throw CreateIdentifierOperationError.invalidIdentifierKeyAlgorithm
        case .NETWORK, .TOKEN:
            break // valid
        }
        
        self.init(identifier: identifier)
    }
}

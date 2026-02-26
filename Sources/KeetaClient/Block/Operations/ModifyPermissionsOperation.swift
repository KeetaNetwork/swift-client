import Foundation
import BigInt
import PotentASN1

/*
 -- MODIFY_PERMISSIONS operation
         modifypermissions [3] SEQUENCE {
             -- Principal to modify permissions for
             principal    OCTET STRING,
             -- Method to modify permissions for
             method       AdjustMethod,
             -- Permissions to modify, as a bitfield
             permissions  CHOICE {
                 -- Permissions to set
                 value SEQUENCE {
                     base        INTEGER,
                     external    INTEGER
                 },
                 -- If no permissions are required
                 none NULL
             },
             -- Target to modify permissions for
             target      OCTET STRING OPTIONAL
         }
 */

public enum ModifyPermissionsOperationError: Error {
    case invalidSequenceLength
    case invalidPrincipal
    case invalidAdjustMethod
    case invalidPermissionFlags
    case invalidPermissionSequenceLength
    case unknownPermissionFlag(BigInt)
    case invalidTarget
}

public struct ModifyPermissionsOperation: BlockOperation {
    public let operationType: BlockOperationType = .modifyPermissions
    public let principal: Account.PublicKeyAndType
    public let adjustMethod: AdjustMethod
    public let permission: Permission?
    public let target: Account.PublicKeyAndType?
    
    public init(principal: String, method: AdjustMethod, permission: Permission?, target: String? = nil) throws {
        let principal = try AccountBuilder.create(fromPublicKey: principal)
        let target = try target.map { try AccountBuilder.create(fromPublicKey: $0) }
        self.init(principal: principal, method: method, permission: permission, target: target)
    }
    
    public init(principal: Account, method: AdjustMethod, permission: Permission?, target: Account? = nil) {
        self.principal = principal.publicKeyAndType
        self.adjustMethod = method
        self.permission = permission
        self.target = target?.publicKeyAndType
    }
    
    public init(from sequence: [PotentASN1.ASN1]) throws {
        guard sequence.count == 3 || sequence.count == 4 else {
            throw ModifyPermissionsOperationError.invalidSequenceLength
        }
        guard let principalData = sequence[0].octetStringValue else {
            throw ModifyPermissionsOperationError.invalidPrincipal
        }
        let principal = try Account(data: principalData)
        
        guard let methodRaw = sequence[1].integerValue,
              let method = AdjustMethod(rawValue: Int(methodRaw)) else {
            throw ModifyPermissionsOperationError.invalidAdjustMethod
        }
        
        let permissionElement = sequence[2]
        let permission: Permission? = if permissionElement.isNull {
            nil
        } else if let permissionSequence = permissionElement.sequenceValue {
            try Permission.parse(from: permissionSequence)
        } else {
            throw ModifyPermissionsOperationError.invalidPermissionFlags
        }
        
        let target: Account?
        if let targetElement = sequence[safe: 3] {
            guard let targetData = targetElement.octetStringValue else {
                throw ModifyPermissionsOperationError.invalidTarget
            }
            target = try Account(data: targetData)
        } else {
            target = nil
        }
        
        self.init(principal: principal, method: method, permission: permission, target: target)
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        [
            .octetString(Data(principal)),
            .integer(adjustMethod.value),
            permission.map { .sequence($0.asn1Values()) } ?? .null,
            target.map {.octetString(Data($0)) }
        ].compactMap { $0 }
    }
}

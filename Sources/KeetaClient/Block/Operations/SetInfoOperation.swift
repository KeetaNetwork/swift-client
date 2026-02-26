import Foundation
import BigInt
import PotentASN1

public enum SetInfoOperationError: Error {
    case invalidSequenceLength
    case invalidName
    case invalidDescription
    case invalidMetaData
    case invalidPermissionSequenceLength
    case unknownPermissionFlag(BigInt)
}

/*
 -- SET_INFO operation
         setinfo [2] SEQUENCE {
             -- Name to specify for this account
             name              UTF8String,
             -- Description to specify for this account
             description       UTF8String,
             -- Metadata to specify for this account
             metadata          UTF8String,
             -- Default permission to specify for this account (optional)
             defaultPermission SEQUENCE {
                 -- Base permissions, which the network verifies
                 base        INTEGER,
                 -- External permissions, which the network
                 -- does not verify (for example, for use in
                 -- smart contracts)
                 external    INTEGER
             } OPTIONAL
         }
 */

public struct SetInfoOperation: BlockOperation {
    public let operationType: BlockOperationType = .setInfo
    public let name: String
    public let description: String
    public let metaData: String
    public let defaultPermission: Permission?
    
    public init(name: String, description: String = "", metaData: String = "", defaultPermission: Permission? = nil) {
        self.name = name
        self.description = description
        self.metaData = metaData
        self.defaultPermission = defaultPermission
    }
    
    public init(from sequence: [PotentASN1.ASN1]) throws {
        guard sequence.count == 3 || sequence.count == 4 else {
            throw SetInfoOperationError.invalidSequenceLength
        }
        guard let name = sequence[0].utf8StringValue?.storage else {
            throw SetInfoOperationError.invalidName
        }
        guard let description = sequence[1].utf8StringValue?.storage else {
            throw SetInfoOperationError.invalidName
        }
        guard let metaData = sequence[2].utf8StringValue?.storage else {
            throw SetInfoOperationError.invalidName
        }
        
        let defaultPermission: Permission? = if let permissionSequence = sequence[safe: 3]?.sequenceValue {
            try Permission.parse(from: permissionSequence)
        } else {
            nil
        }
        
        self.init(name: name, description: description, metaData: metaData, defaultPermission: defaultPermission)
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        var values: [PotentASN1.ASN1] = [
            .utf8String(name),
            .utf8String(description),
            .utf8String(metaData)
        ]
        
        if let defaultPermission {
            values.append(.sequence(defaultPermission.asn1Values()))
        }
        
        return values
    }
}

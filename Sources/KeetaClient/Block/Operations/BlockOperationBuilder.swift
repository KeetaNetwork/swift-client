import PotentASN1

enum BlockOperationBuilderError: Error {
    case invalidSequence
    case invalidTag
    case invalidOperationType
}

public struct BlockOperationBuilder {
    public static func create(from asn1: ASN1) throws -> BlockOperation {
        guard let tag = asn1.taggedValue else {
            throw BlockOperationBuilderError.invalidTag
        }
        let operationTypeRaw = tag.implicitTag
        
        guard let type = BlockOperationType(rawValue: operationTypeRaw) else {
            throw BlockOperationBuilderError.invalidOperationType
        }
        
        let operation = try ASN1Serialization.asn1(fromDER: tag.data)
        
        guard let sequence = operation.first?.sequenceValue, !sequence.isEmpty else {
            throw BlockOperationBuilderError.invalidSequence
        }
        
        let operationType: BlockOperation.Type = switch type {
        case .send: SendOperation.self
        case .setRep: SetRepOperation.self
        case .setInfo: SetInfoOperation.self
        case .modifyPermissions: ModifyPermissionsOperation.self
        case .createIdentifier: CreateIdentifierOperation.self
        case .tokenAdminSupply: TokenAdminSupplyOperation.self
        case .tokenAdminModifyBalance: TokenAdminModifyBalanceOperation.self
        case .receive: ReceiveOperation.self
        case .modifyCertificate: ModifyCertificateOperation.self
        }
        
        return try operationType.init(from: sequence)
    }
}

public struct KeetaErrorResponse: Decodable {
    public let error: Bool
    public let code: ErrorCode
    public let type: ErrorType
    public let message: String
}

public enum ErrorType: String, Decodable {
    case ledger = "LEDGER"
    case block = "BLOCK"
}

public enum ErrorCode: String, Decodable {
    case successorVoteExists = "LEDGER_SUCCESSOR_VOTE_EXISTS"
    case ledgerInvalidChain = "LEDGER_INVALID_CHAIN"
    case ledgerReceiveNotMet = "LEDGER_RECEIVE_NOT_MET"
    case ledgerInvalidBalance = "LEDGER_INVALID_BALANCE"
    case ledgerInvalidPermissions = "LEDGER_INVALID_PERMISSIONS"
    case ledgerPreviousAlreadyUsed = "LEDGER_PREVIOUS_ALREADY_USED"
    case ledgerNotEmpty = "LEDGER_NOT_EMPTY"
    case ledgerOther = "LEDGER_OTHER"
    case ledgerInsufficientVotingWeight = "LEDGER_INSUFFICIENT_VOTING_WEIGHT"
    case ledgerIdempotentKeyAlreadyExists = "LEDGER_IDEMPOTENT_KEY_EXISTS"
    case blockOnlyTokenOperation = "BLOCK_ONLY_TOKEN_OP"
    case blockNoTokenOperation = "BLOCK_NO_TOKEN_OP"
    case blockFieldInvalid = "BLOCK_GENERAL_FIELD_INVALID"
    case blockInvalidIdentifier = "BLOCK_IDENTIFIER_INVALID"
    case missingRequiredFeeBlock = "LEDGER_MISSING_REQUIRED_FEE_BLOCK"
}

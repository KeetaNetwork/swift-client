public enum BlockError: Error, Equatable {
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidVersion
    case invalidNetwork
    case invalidDate
    case invalidSigner
    case invalidHash
    case invalidOperationsSequence
    case redundantAccount
    case invalidSignature
}

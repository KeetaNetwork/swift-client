public enum BlockError: Error, Equatable {
    case invalidASN1Schema
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidVersion
    case invalidPurpose
    case invalidNetwork
    case invalidDate
    case invalidSigner
    case invalidHash
    case invalidOperationsSequence
    case redundantAccount
    case invalidSignature
}

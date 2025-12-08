public enum BlockError: Error, Equatable {
    case invalidData
    case invalidASN1Schema
    case invalidASN1Sequence
    case invalidASN1SequenceLength
    case invalidVersion
    case invalidPurpose
    case invalidIdempotentData
    case invalidNetwork
    case invalidDate
    case invalidSigner
    case invalidMultiSigSequence
    case invalidMultiSigAccount
    case invalidMultiSigSigners
    case missingMultiSigSigners
    case missingMultiSigSignatures
    case invalidMultiSigSignersDepth
    case invalidHash
    case invalidOperationsSequence
    case redundantAccount
    case invalidSignature
}

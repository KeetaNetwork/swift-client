//
//  MultiSignatureKeyPair.swift
//  KeetaClient
//
//  Created by David Scheutz on 11/6/25.
//

public enum MultiSignatureKeyPairError: Error {
    case signingNotSupported
    case verifyingNotSupported
    case noPrivateKey
}

public struct MultiSignatureKeyPair: KeyCreateable, Signable, Verifiable {
    static func create(from seed: String) throws -> KeyPair {
        let privateKey: String = Hash.create(from: try seed.toBytes())
        return try keypair(from: privateKey)
    }
    
    static func keypair(from privateKey: String) throws -> KeyPair {
        .init(publicKey: privateKey, privateKey: privateKey)
    }
    
    static func sign(data: [UInt8], key: [UInt8]) throws -> [UInt8] {
        throw MultiSignatureKeyPairError.signingNotSupported
    }
    
    static func verify(data: [UInt8], signature: Signature, key: [UInt8]) throws -> Bool {
        throw MultiSignatureKeyPairError.verifyingNotSupported
    }
    
    static func signatureFromDER(_ signature: Signature) throws -> Signature {
        throw MultiSignatureKeyPairError.noPrivateKey
    }
}

//
//  Data+Bytes.swift
//  KeetaClient
//
//  Created by David Scheutz on 20.11.25.
//

import Foundation

extension Data {
    public func toBytes() -> [UInt8] {
        [UInt8](self)
    }
}

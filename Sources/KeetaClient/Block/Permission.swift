import BigInt
import PotentASN1

public enum PermissionError: Error {
    case invalidSequenceLength
    case invalidBaseFlags
    case invalidExternalFlag
    case invalidBitMasks([String])
    case invalidBaseFlagsHexValue(String)
    case invalidExternalFlagHexValue(String)
    case unknownBit(BigInt)
}

public struct GrantedPermissions: Equatable {
    public let principal: Account
    public let target: Account?
    public let permission: Permission
}

public struct Permission: Equatable {
    public enum BaseFlag: Int, CaseIterable {
        case ACCESS                     = 0  // 0x0001
        case OWNER                      = 1  // 0x0002
        case ADMIN                      = 2  // 0x0004
        case UPDATE_INFO                = 3  // 0x0008
        case SEND_ON_BEHALF             = 4  // 0x0010
        case STORAGE_CAN_HOLD           = 9  // 0x0200
        case STORAGE_DEPOSIT            = 10 // 0x0400
        case STORAGE_CREATE             = 8  // 0x0100
        case TOKEN_ADMIN_CREATE         = 5  // 0x0020
        case TOKEN_ADMIN_SUPPLY         = 6  // 0x0040
        case TOKEN_ADMIN_MODIFY_BALANCE = 7  // 0x0080
        case PERMISSION_DELEGATE_ADD    = 11 // 0x0800
        case PERMISSION_DELEGATE_REMOVE = 12 // 0x1000
        case MANAGE_CERTIFICATE         = 13 // 0x2000
        case MULTISIG_SIGNER            = 14 // 0x4000
        
        init?(bitmask: BigInt) {
            guard let index = bitmask.bitIndex else { return nil }
            self.init(rawValue: index)
        }
        
        public static func parse(_ bitmask: BigInt) throws -> [BaseFlag] {
            if let flag = BaseFlag(bitmask: bitmask) {
                return [flag]
            }
            
            let bits = bitmask.bits
            
            return try bits.map {
                guard let flag = BaseFlag(bitmask: $0) else {
                    throw PermissionError.unknownBit($0)
                }
                return flag
            }
        }
        
        public var bitmask: BigInt {
            1 << rawValue
        }
    }
    
    public private(set) var baseFlags: Set<BaseFlag>
    public let external: BigInt
    
    public static func parse(from sequence: [ASN1]) throws -> Self {
        guard sequence.count == 2 else {
            throw PermissionError.invalidSequenceLength
        }
        guard let baseFlagRaw = sequence[0].integerValue else {
            throw PermissionError.invalidBaseFlags
        }
        guard let externalFlag = sequence[1].integerValue else {
            throw PermissionError.invalidExternalFlag
        }
        return Permission(baseFlags: try BaseFlag.parse(baseFlagRaw), external: externalFlag)
    }
    
    public static func parse(_ bitmasks: [String]) throws -> Self {
        guard bitmasks.count == 2 else {
            throw PermissionError.invalidBitMasks(bitmasks)
        }
        guard let baseFlagsBitMask = BigInt(hex: bitmasks[0]) else {
            throw PermissionError.invalidBaseFlagsHexValue(bitmasks[0])
        }
        guard let externalFlag = BigInt(hex: bitmasks[1]) else {
            throw PermissionError.invalidExternalFlagHexValue(bitmasks[1])
        }
        return Permission(baseFlags: try BaseFlag.parse(baseFlagsBitMask), external: externalFlag)
    }
    
    public init(baseFlags: [BaseFlag], external: BigInt = 0) {
        self.init(baseFlags: Set(baseFlags), external: external)
    }
    
    public init(baseFlags: Set<BaseFlag>, external: BigInt = 0) {
        self.baseFlags = baseFlags
        self.external = external
    }
    
    public var isEmpty: Bool {
        baseFlags.isEmpty && external == 0
    }
    
    @discardableResult
    mutating public func add(baseFlag: BaseFlag) -> Bool {
        baseFlags.insert(baseFlag).inserted
    }
    
    @discardableResult
    mutating public func remove(baseFlag: BaseFlag) -> BaseFlag? {
        baseFlags.remove(baseFlag)
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        [
            .integer(combinedBaseFlags()),
            .integer(external)
        ]
    }

    public func combinedBaseFlags() -> BigInt {
        switch baseFlags.count {
        case 0:
            return 0
        case 1:
            return baseFlags.first!.bitmask
        default:
            var combined: BigInt = 0
            
            for baseFlag in baseFlags {
                combined |= baseFlag.bitmask
            }
            return combined
        }
    }
}

extension BigInt {
    var bitIndex: Int? {
        guard self > 0 else { return nil }
        
        var index = 0
        var value = self
        
        while value > 1 {
            if value & 1 == 1 {
                return nil // more than one bit set
            }
            value >>= 1
            index += 1
        }
        
        return index
    }
    
    var bits: [BigInt] {
        var bit: BigInt = 1
        var result: [BigInt] = []

        var mask = self
        
        while bit <= mask {
            if mask & bit != 0 {
                result.append(bit)
            }
            bit <<= 1
        }
        
        return result
    }
}

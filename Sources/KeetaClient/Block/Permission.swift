import BigInt
import PotentASN1

public struct Permission {
    public enum BaseFlag: BigInt {
        case ACCESS = 0x0001
        case OWNER = 0x0002
        case ADMIN = 0x0004
        case UPDATE_INFO = 0x0008
        case SEND_ON_BEHALF = 0x0010
        case STORAGE_CAN_HOLD = 0x0200
        case STORAGE_DEPOSIT = 0x0400
        case STORAGE_CREATE = 0x0100
        case TOKEN_ADMIN_CREATE = 0x0020
        case TOKEN_ADMIN_SUPPLY = 0x0040
        case TOKEN_ADMIN_MODIFY_BALANCE = 0x0080
        case PERMISSION_DELEGATE_ADD = 0x0800
        case PERMISSION_DELEGATE_REMOVE = 0x1000
    }
    
    public let baseFlag: BaseFlag
    
    public init(baseFlag: BaseFlag) {
        self.baseFlag = baseFlag
    }
    
    public func asn1Values() -> [PotentASN1.ASN1] {
        [
            .integer(baseFlag.rawValue),
            .integer(0)
        ]
    }
}

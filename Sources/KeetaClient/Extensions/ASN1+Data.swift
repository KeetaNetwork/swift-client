import Foundation
import PotentASN1

extension Array where Element == ASN1 {
    
    func toData() throws -> Data {
        try ASN1Serialization.der(from: .sequence(self))
    }
}

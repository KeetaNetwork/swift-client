import Foundation
import PotentASN1

public struct Address {
    public let addressLines: String?
    public let addressType: String?
    public let buildingNumber: String?
    public let country: String?
    public let countrySubDivision: String?
    public let department: String?
    public let postalCode: String?
    public let streetName: String?
    public let subDepartment: String?
    public let townName: String?

    public init(from data: Data) throws {
        let fields = try ASN1TaggedFields.parse(from: data)

        addressLines = fields[0]
        addressType = fields[1]
        buildingNumber = fields[2]
        country = fields[3]
        countrySubDivision = fields[4]
        department = fields[5]
        postalCode = fields[6]
        streetName = fields[7]
        subDepartment = fields[8]
        townName = fields[9]
    }
}

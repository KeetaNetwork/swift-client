import Foundation
import PotentASN1

public struct ContactDetails {
    public let department: String?
    public let emailAddress: String?
    public let emailPurpose: String?
    public let faxNumber: String?
    public let fullName: String?
    public let jobResponsibility: String?
    public let jobTitle: String?
    public let mobileNumber: String?
    public let namePrefix: String?
    public let other: String?
    public let phoneNumber: String?
    public let preferredMethod: String?

    public init(from data: Data) throws {
        let fields = try ASN1TaggedFields.parse(from: data)

        department = fields[0]
        emailAddress = fields[1]
        emailPurpose = fields[2]
        faxNumber = fields[3]
        fullName = fields[4]
        jobResponsibility = fields[5]
        jobTitle = fields[6]
        mobileNumber = fields[7]
        namePrefix = fields[8]
        other = fields[9]
        phoneNumber = fields[10]
        preferredMethod = fields[11]
    }
}

public enum OID: String {
    case ecdsaWithSHA512 = "1.2.840.10045.4.3.4"
    case ecdsaWithSHA3_256 = "2.16.840.1.101.3.4.3.10"
    case ed25519 = "1.3.6.1.4.1.11591.15.1"
    
    // X.500 attributes
    case commonName = "2.5.4.3"
    case serialNumber = "2.5.4.5"
    case countryName = "2.5.4.6"
    case localityName = "2.5.4.7"
    case stateOrProvinceName = "2.5.4.8"
    case streetAddress = "2.5.4.9"
    case organizationName = "2.5.4.10"
    case organizationalUnitName = "2.5.4.11"
    case businessCategory = "2.5.4.15"
    case postalCode = "2.5.4.17"
    case dnQualifier = "2.5.4.46"
    
    case hashData = "2.16.840.1.101.3.3.1.3"
    case sha3_256 = "2.16.840.1.101.3.4.2.8"
    case domainComponent = "0.9.2342.19200300.100.1.25"
    case emailAddress = "1.2.840.113549.1.9.1"
    case userId = "0.9.2342.19200300.100.1.1"
    
    case fees = "1.3.6.1.4.1.62675.0.1.0"
}

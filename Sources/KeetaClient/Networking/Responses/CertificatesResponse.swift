struct CertificatesResponse: Decodable {
    let account: String
    let certificates: [CertificateResponse]
}

struct CertificateResponse: Decodable {
    let certificate: String
    let intermediates: [String]?
}

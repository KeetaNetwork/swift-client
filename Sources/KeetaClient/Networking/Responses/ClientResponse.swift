struct RepresentativesResponse: Decodable {
    let representatives: [RepresentativeResponse]
    
}

struct RepresentativeResponse: Decodable {
    let representative: String
    let weight: String
    let endpoints: Endpoints
}

struct Endpoints: Decodable {
    let api: String
    let p2p: String
}

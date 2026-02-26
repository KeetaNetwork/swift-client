struct GrantedPermissionsResponse: Decodable {
    let permissions: [GrantedPermissionResponse]
}

struct GrantedPermissionResponse: Decodable {
    let principal: String
    let entity: String
    let target: String?
    let permissions: [String] // [Baseflag, ExternalFlag]
}

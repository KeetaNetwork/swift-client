struct SendBlocksRequest {
	let blocks: [Block]
	let networkAlias: NetworkAlias

    func toJSON() throws -> JSON {
        [
            "network": networkAlias.rawValue,
            "blocks": try blocks.map { try $0.base64String() }
        ]
    }
}

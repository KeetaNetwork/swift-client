import XCTest
import KeetaClient

final class VoteStapleTests: XCTestCase {
    
    func test_parse() throws {
        // generated using TS node v0.10.6
        let binary = "eJy11HlMFHcUB/CdY1cEbBXR2JDa9UQrLr+d2ZkRKwblkCpSCZQSVHRndvY+h1lmGERYFE0koE0tHpACtSq2EbSUFiokCFgWRKpVo7ZYpWDxwJrWKodVS5u0SRuM/uMvef++l/f95P1A3rgQkAfJUM9j4BmBIRmMJkUnJsll0yZjACMAqSaAmiAJUkWow1LRmTI4/7QzOyHq8YW0m+0H1h9efEZe3H9fX7QyMTZHTIZbkXK5DFV6S34rs+2piMhImBT9w2eye8da9uRmN3uG1v+IBhyd9r0I4svjwMrRbkiIV73lWmAEs6NsET+1XCe00JrSoqi0S6pvl/SWDb+XAUMQOgNx5u358Jrs63O7Rf+TPd81tU9w0de9aZ+HMiDr7tJP3SvRiITAo1W7avo8cMipXbfjK66YEyrrC5/e/eqbmhMfaCLgKIjPxVO4ibcacrJarw3ws3K0AQFpl7/oS80ev+yeNwkDeYrZaB6UP5qFZ7SCyxEYgmFUTjRfB36K8Ru3xUIsgiK+YI06HsQpkHdRxD/awrK8doNWS+spnURo012YHbNyVh3D47iICQJJMA6nUXRSrEFvMok0TfF0ppYnONzC0AwrUXreaQJz/xc1pcIILHXaqzjASKDG1eDvlwoC1BPBK39NlvuPI3CCwVgASDBRMe7NbbFd4TCkkC/woDJfZNRow85wtOLQLVfKqfBfRmobz4X1n3gSOcWnLnJ4u6yMqfU5sAJEg8h/1kIgBIKeoni5GoT+uyrsA2aiSmaOBj8NBYbfDgrcODR18rLZBYdqf6qrby6Z4EWCzqfO+082yAoZiIKVs6RNeTn2NqmwAwwOrzqYHD4y6WJn3NCmZKkRqlJNXwArfTt63xmuVx6ATlTut9Rc9wkK7a1R2Q/tPRtzpnrhfd+eMSCQtr2LXwDCpKF1uJ4yczxJ2UTGpdE4JDNJ0EYN7cRsmQYbZ2F1osHgxjhRsGMS7xZwmmRFUwbtGgtCjT8HAmeosEW49lkQRWhW6PnXHg3UVXS9NX9w+Wb5iN7fW7mlvnB1zEN7zeK1LxUi3oyZKqtLn6akbilWnFxDfXn2alB7tF/wnDuNdy7DyRdh5SS/o937I/nLTTvj++GA6MG1XetcPccb7340v8r7sGHRG2NAwIMtfS8AIdkdJoaTMniWdFkJTqQNboNNz5ldbpq2m90OwkqaMhxOh5Cp4ZwWlyGd0DMO3KFlJWZMCM3zIDA9xeCs5hkQSHE9XGTBJL8B++Q1nSGJvujC1a9fHJ6SftXKhSZNUO1+qRCK22eOPMwt2/z7hQH0j6od/RFNvfsObs96siOn9VFcmKMYVi4xtqhobULn1n26fRHv/xzscyOxrLWH6t7vnbexu21q8FgX0cmcfgEInBFZg0kSjLzJhkvWTLdgNppcOsJksRhFgwZLtxkFBhdEMtNOsU6MJ62Cg2RtGYJG0I75NamfexEMiTP0syCOr9sWY82sKOn4ddXsm7kj+fMGKWLu9Oar1QNU3+bDN668VIiUdSVx3CokptRjcC5PCapNb6guqvZrWPL2g49LT5J1n8DKpRceFBTWJi/f1KSd8cQxVHup4PiRLO0xrqO7a6vZlt36J4r5Yjs="
        
        let staple = try VoteStaple.create(from: binary)
        
        // Verify Block
        let expectedBlock: ExpectedBlockResult = try .init(
            hash: "63253433CB01143DEA1B1460F8161341248BA6B5E2B8B9C29B0DC8031BD35A28",
            signature: "5114ADAE90B3E481022CC590EA4EA1D96A51A8B98DFFEDB7C6B3BB933440024401748033587210E9BC7F7BC4DFEC74237F6112125ED8B4E45A7D0941EFC85432",
            version: 1,
            created: "2025-06-15T01:56:56.519Z",
            network: 0x54455354,
            signerPubKey: "keeta_aabils3qpviuj7oul3umti25u45m2bmw47zwndskkneh66cwalcahifxvtvajla",
            previous: "C89BF29F6D97A14076511145DBAB00EFB0C397807DC281F85DDE0412AD18DA78",
            isOpening: false
        )
        
        XCTAssertEqual(staple.blocks.count, 1)
        let block = try XCTUnwrap(staple.blocks.first)
        try block.compare(with: expectedBlock)
        XCTAssertEqual(block.rawData.operations.count, 1)
        
        // Verify Send Operation
        let operation = try XCTUnwrap(block.rawData.operations.first as? SendOperation)

        XCTAssertEqual(operation.amount, 1)
        XCTAssertEqual(
            try Account.publicKeyString(from: operation.to),
            "keeta_aabszsbrqppriqddrkptq5awubshpq3cgsoi4rc624xm6phdt74vo5w7wipwtmi"
        )
        XCTAssertEqual(
            try Account.publicKeyString(from: operation.token),
            "keeta_anyiff4v34alvumupagmdyosydeq24lc4def5mrpmmyhx3j6vj2uucckeqn52"
        )
        
        // Verify Votes
        XCTAssertEqual(staple.votes.count, 4)
        let expectedIssuers = [
            "keeta_aabf7dz5asq2n2lrldct33x2ww65cophxp7egfiixbb7tbyat5r3kcbcez7ftpi",
            "keeta_aabi4bd3f7jrt67mxcq44ozj65bh4bp2mygmrkedxggu2rxwn2ztuw3b6exivbq",
            "keeta_aabznoicrzvte6ql5rxbgugmfrjqubbnjuo5l6ivopowy4rpkqgs5fco3oaezcq",
            "keeta_aab3cxegizwhtim3zlyuwjhiqd5ikkhxg42smhwc3wx6yn7ep2t6lwo6emvw4wa"
        ]
        let issuers = staple.votes.map(\.issuer.publicKeyString)
        XCTAssertEqual(issuers, expectedIssuers, "Issuers different than expected:\n\(issuers)")
        XCTAssertTrue(staple.votes.allSatisfy { $0.permanent })
    }
    
    func test_stapleWithArbitraryIntegersSize() throws {
        let binary = "eJy104lPFGcYBvC5FlTAGilGq9aVVkGk8O3MzgxYV1EECQrhEi0KuDM7e9/MMrOD5xBo00aaKFp7cmhQSdUUa6s2dpFWBVFRsFVjWaSiqEWjVqWiYtMmbdoGo2ni+w+8eZ5fHiAH4kCGFZgMw2DtIAJDCJaTlJ2jgMaG4gAnAaUigYpUAyImHoA8LBxCo5tVpV0vJ7DvVsXxY6p1wneM+pOKeQVnY9pmXqp6sLhYAWFKOFPDX08/JXefWVCD8x3QMkHpO1oYd9u/HeLLTzjmgqzqDJCOhUNIWatzZea8x2cKrrZsyd8244RiU++v+orU7JTVYi7yPVqNKJCcoB4Im4w65Q82dkEHTleKwYe62xtbQlzMxeaChlgWlNyYVe9JxRLwyEZHw3tsSWv00c5Zn5Xeu91e1X/KOrZVXJ1woyl6iS7467oDZ5PP3RoodP8WYjF/qonPkg5nj0/f9Yqw0zFhxwYgB0zBZLgMyPBaIMMR1SgCIwiGHl9Og6CA4cvLU2AOxdARIEOVDhYGoIswNDjJwnG8tlCrZQhW5AwmSTDyJhshWb0ewWw0uXSkyWIxigY1XmQzCiwhiJTXTnNOnKesgoPibMWCWtCCqf+pWx2D03Te2JcIgFNARajAn5cHRqtGgZF/fFYEBxIsSwGCBhQYFRAYVZ5yUoPAAYrpazFoBBoOoV8sK0+2ems+PnZ7wetX1wyURfbT5NRXmzp399E9q7ZdPr9lPkgCiX/FQmEUhp9gRLUKxP4dFRkGwjFlJ7cOWRaR8drddtDWk6qe+S0nlcR6ntRbEra6ftom4//qBp0PgXnIZKhyMPPC6sDU2bPC4hbn6Y7kRvmWRoZHPPHHDOYfOcfCK5BJUZeRMXlNmvU3D7K707ShdGK52R9S2n/pkO/RyntdozEZLgcyLP8DAulvzHgOCMnuMLFuqZjnKJeVdIuMwWOw6d1ml4dh7GaPg7RSpmKH0yF41W6nxWUoIvWsg3BoOYl1DQURp3oGBK6nWUCCp0Fs2o9UWHApqM8emnE8OnsE9kbaxB8ehBV1Wt2xOSExlS8IIgUCSchk6KspVL7Pma+ZZC3om9Ne85B9bDmRaGw53+3bUN82ffYFRJngn7g5q6AWjojN7Vb82CPt8N851sDHlX2YFYo/aq6zDDWJo5V1zyFhUjM6Qk+b3TxF20TWpVY7JDNFMkY148RtXoPNbeF0osHgwd2iYMcl3iMQDMWJpmJmaAnwzEnQ8Wot9RQJpAIrie0Y97BvX83JN6f1z12lGNAHN28v3b8uLfm+fc+MpS9yEsrhHcgEufXWYFZySGB/y1vr79yt/ai56co1/8+9fb/ErwlClIu4jp0Xt8dszKxsS79f1LF5S6uO7drxZZrz8edbz3s3+oeAUJC+hc8Boad1EqktcuF23Oq26lieIERcECiSdTiNopPmDHqTSWQYmme8Wp50ExaWYTmJ1vNO0/+aBEmQjF7NPg2i8H0NVlN3zbXksObmwN6Dp+N7vxlMDBu2L/HB21AVu3fYC4WYCPWuWNV6RaAra9cVXDo4etppX+6ecSuuwyPDHFkzbzUgSlttpIfCaLF+UpR+c/E7blrq26W4Mj6wkIUPNAYUs78Du5FlvA=="
        
        let _ = try VoteStaple.create(from: binary)
    }
}

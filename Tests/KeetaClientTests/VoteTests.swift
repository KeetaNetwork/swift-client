import XCTest
import KeetaClient

final class VoteTests: XCTestCase {
    
    func test_parseTemporaryVoteFromBinary() throws {
        // generate using the TS node v0.10.6
        let voteBinary = "MIIBhTCCASugAwIBAgIEAu5vjjALBglghkgBZQMEAwowUDFOMEwGA1UEAwxFa2VldGFfYWFiem5vaWNyenZ0ZTZxbDVyeGJndWdtZnJqcXViYm5qdW81bDZpdm9wb3d5NHJwa3FnczVmY28zb2FlemNxMCoYEzIwMjUwNjEzMjIzODM5LjI1MloYEzIwMjUwNjEzMjI0MzM5LjI1MlowEjEQMA4GA1UEBQwHMmVlNmY4ZTA2MBAGByqGSM49AgEGBSuBBAAKAyIAA5a5Ao5rMnoL7G4TUMwsUwoELU0d1fkVc91sci9UDS6Uo0cwRTBDBglghkgBZQMDAQMBAf8EM6AxMC8GCWCGSAFlAwQCCDAiBCDwfmZA80CIlMpwLj1rYyi1otmrp8mgwTN+3YS6yqLexzALBglghkgBZQMEAwoDRwAwRAIgPosTrJOK5UjmD2tgs1QrZalpuC6c/awdqTye8BWDStACIE9F4HVCbh/twxO9s0NRvpqBQO8jtfINj6syr+SM1rrZ"
        
        let vote = try Vote.create(from: voteBinary)
        
        XCTAssertEqual(vote.issuer.publicKeyString, "keeta_aabznoicrzvte6ql5rxbgugmfrjqubbnjuo5l6ivopowy4rpkqgs5fco3oaezcq")
        XCTAssertEqual(vote.serial.toHex().uppercased(), "2EE6F8E")
        XCTAssertEqual(vote.validityFrom, Block.dateFormatter.date(from: "2025-06-13T22:38:39.252Z"))
        XCTAssertEqual(vote.validityTo, Block.dateFormatter.date(from: "2025-06-13T22:43:39.252Z"))
        XCTAssertEqual(vote.blocks.count, 1)
        XCTAssertEqual(vote.blocks.first?.uppercased(), "F07E6640F3408894CA702E3D6B6328B5A2D9ABA7C9A0C1337EDD84BACAA2DEC7")
        XCTAssertFalse(vote.permanent)
        XCTAssertEqual(vote.signature.toHexString().uppercased(), "304402203E8B13AC938AE548E60F6B60B3542B65A969B82E9CFDAC1DA93C9EF015834AD002204F45E075426E1FEDC313BDB34351BE9A8140EF23B5F20D8FAB32AFE48CD6BAD9")
        XCTAssertEqual(vote.base64String(), voteBinary)
    }
    
    func test_parseFeeFromTemporaryVoteBinary() throws {
        // generate using the TS node v0.14.3
        let voteBinary = "MIIBwDCCAWWgAwIBAgIBAjALBglghkgBZQMEAwowUDFOMEwGA1UEAwxFa2VldGFfYWFiYms2dnE1bWp2aXR5dnFucnZ6NmczZjNqcjcyb3FmZXFnNGZxYmFhNHM1c2lzcmRsZmhrZnI1cDdjaGV5MCoYEzIwMjUwOTIyMTUxNjE5LjAwOVoYEzIwMjUwOTIyMTUzMTE5LjAwOVowDDEKMAgGA1UEBQwBMjA2MBAGByqGSM49AgEGBSuBBAAKAyIAAhV6sOsTVE8Vg2Nc+Nsu0x/p0CkgbhYBADkuyRKI1lOoo4GJMIGGMEMGCWCGSAFlAwMBAwEB/wQzoDEwLwYJYIZIAWUDBAIIMCIEIFQLZO4ZMtQ7RvjFqVgmyh1N/B2HhDR7prhwxY00yqEpMD8GCysGAQQBg+lTAAEAAQH/BC2gKzApAQEAAgEBgSEDwWEdNdsf5wzEkldMmcvKvOfaG8ZwZjo6clSgCSHkQeAwCwYJYIZIAWUDBAMKA0gAMEUCIQDPHifGqxAl85sJ1kopFAtjTlHRhxeVLk0aW12iKwfAZwIgM57TWrjLMJDGwHwypR+hKD+dXNjspj1bcSJAH0xZbwo="
        
        let vote = try Vote.create(from: voteBinary)
        
        let fee = try XCTUnwrap(vote.fee)
        XCTAssertEqual(fee.amount, 1)
        XCTAssertFalse(fee.quote)
        XCTAssertEqual(fee.token?.publicKeyString, "keeta_apawchjv3mp6odgesjluzgolzk6opwq3yzygmor2ojkkacjb4ra6anxxzwsti")
        XCTAssertNil(fee.payTo)
    }
    
    func test_parsePermanentVoteFromBinary() throws {
        // generate using the TS node v0.14.3
        let voteBinary = "MIIBeTCCAR6gAwIBAgIBAjALBglghkgBZQMEAwowUDFOMEwGA1UEAwxFa2VldGFfYWFiYms2dnE1bWp2aXR5dnFucnZ6NmczZjNqcjcyb3FmZXFnNGZxYmFhNHM1c2lzcmRsZmhrZnI1cDdjaGV5MCYYEzIwMjUwOTIyMTUxMjE5LjM5M1oYDzMwMjYwMTMxMDAwMDAwWjAMMQowCAYDVQQFDAEyMDYwEAYHKoZIzj0CAQYFK4EEAAoDIgACFXqw6xNUTxWDY1z42y7TH+nQKSBuFgEAOS7JEojWU6ijRzBFMEMGCWCGSAFlAwMBAwEB/wQzoDEwLwYJYIZIAWUDBAIIMCIEIPM20WcfFtD8g90RdKTYBZdCcz9DuupOKZyB7CZAhXLCMAsGCWCGSAFlAwQDCgNIADBFAiEAtDtMOoTDq+QOEQSf2O34J/9fhoa/hB1+NbvgZSiFPsMCIGyPvEZ05NglQsxZHM/VxjVA+YO/LRChbi/iq/SYzM4e"
        
        let vote = try Vote.create(from: voteBinary)
        
        XCTAssertTrue(vote.permanent)
    }
}

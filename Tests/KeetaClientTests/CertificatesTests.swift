import Foundation
import Testing
import KeetaClient
import BigInt

struct CertificatesTests {
    
    struct ExpectedCertificate {
        let hash: String
        let version: BigInt
        let issuer: Certificate.Issuer
        let serial: Serial
        let subjectAccount: Account
        let validityFrom: Date
        let validityTo: Date
        let signature: Signature
        let permanent: Bool
        
        func matches(_ certificate: Certificate) -> Bool {
            certificate.hash == hash
            && certificate.version == version
            && certificate.issuer == issuer
            && certificate.serial == serial
            && certificate.subject.account.publicKeyString == subjectAccount.publicKeyString
            && certificate.validityFrom == validityFrom
            && certificate.validityTo == validityTo
            && certificate.signature == signature
            && certificate.permanent == permanent
        }
    }
    
    @Test
    func intermediary() async throws {
        let cert = try Certificate.create(from: """
         MIIBhDCCASmgAwIBAgIBAjALBglghkgBZQMEAwowKTEnMCUGA1UEAxMeS2VldGEg
         VGVzdCBOZXR3b3JrIEtZQyBSb290IENBMB4XDTI1MDgwMTAwMDAwMFoXDTI1MDgx
         NTAwMDAwMFowKjEoMCYGA1UEAxMfSW50ZXJtZWRpYXRlIENBIGZvciBEZXZlbG9w
         bWVudDA2MBAGByqGSM49AgEGBSuBBAAKAyIAAjVgFkAV5ympmjv9ERrdfxLOyLzV
         Pg5xw1+fCyp0It1bo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIA
         xjAfBgNVHSMEGDAWgBRqnzagoWMnaOEiPYIYAFQuJfiHejAdBgNVHQ4EFgQUi4Xc
         hxNuPPyBY1MwHGqwmnHH+ZgwCwYJYIZIAWUDBAMKA0gAMEUCIQCGzdUuCCtzNMn1
         +WlU5q/LXjE1q09c2coCdW/uI6d8bAIgIa6QAqMnxc7cv3OilcBcwa0ljGGDIcIG
         skTiIbB8+cc=
        """)
        
        let expected = ExpectedCertificate(
            hash: "5563F736D1D80BFD2B1CABAEC03E7B69F93F7322E8E8E78CD68D2A94BA575A57",
            version: 2,
            issuer: .common("Keeta Test Network KYC Root CA"),
            serial: BigInt(2),
            subjectAccount: try AccountBuilder.create(fromPublicKey: "keeta_aabx3wgg7uklds2c7rabqm2b7wv45xgaivpldwy7yenrsfomheo6w7xzra5adwa"),
            validityFrom: Certificate.dateFormatter.date(from: "2025-08-01T00:00:00.000Z")!,
            validityTo: Certificate.dateFormatter.date(from: "2025-08-15T00:00:00.000Z")!,
            signature: [48, 69, 2, 33, 0, 134, 205, 213, 46, 8, 43, 115, 52, 201, 245, 249, 105, 84, 230, 175, 203, 94, 49, 53, 171, 79, 92, 217, 202, 2, 117, 111, 238, 35, 167, 124, 108, 2, 32, 33, 174, 144, 2, 163, 39, 197, 206, 220, 191, 115, 162, 149, 192, 92, 193, 173, 37, 140, 97, 131, 33, 194, 6, 178, 68, 226, 33, 176, 124, 249, 199],
            permanent: false
        )
        
        #expect(expected.matches(cert))
    }
    
    @Test
    func kyc() async throws {
        // https://explorer.test.keeta.com/account/keeta_aabg2lkwuy4gvzr44cniihdmwzinfuunqv4qgsuhbq7jpt4qms622tldjbdexwy/certificate/94868CBFD6EA00A80B6C217D81CEA25E55F24598B2B665BBB019B4F04BA843CE
        let cert = try Certificate.create(from: """
             -----BEGIN CERTIFICATE-----
             MIISMTCCEdagAwIBAgIQJ+EVDRhJeTHzqwvTlp4y/DALBglghkgBZQMEAwowHzEd
             MBsGA1UEAxMUT25lRm9vdHByaW50IFRlc3QgQ0EwHhcNMjUxMjAzMjMwMTE2WhcN
             MjYxMjAzMjMwMTE2WjBQMU4wTAYDVQQDFkVrZWV0YV9hYWJnMmxrd3V5NGd2enI0
             NGNuaWloZG13emluZnV1bnF2NHFnc3VoYnE3anB0NHFtczYyMnRsZGpiZGV4d3kw
             NjAQBgcqhkjOPQIBBgUrgQQACgMiAAJtLVamOGrmPOCahBxstlDS0o2FeQNKhww+
             l8+QZL2tTaOCEOMwghDfMA4GA1UdDwEB/wQEAwIAwDAfBgNVHSMEGDAWgBSqq6Xa
             wkY1e8ttzVjVKVnQHmq4yjAdBgNVHQ4EFgQUCumYbRgAMAjZtOADjrcAbNybiNkw
             ghCLBgorBgEEAYPpUwAABIIQezCCEHcwggFGBgorBgEEAYPpUwEAgYIBNjCCATIC
             AQAwga0GCWCGSAFlAwQBLgQMXgISB9NmZVytZzgzBIGRBLekT4tBjgFF/6uOP4gp
             4R8SgcevWCcPt21e9R9rlK8UN8v1h6MslY6CoN/Rba0HNbSDLm8KTkzAvK6UH8UC
             eWyzZ7vaiNYCsm4GFR1C6Xnm6/YjH6WdvxC1lrDAKcZIhpoadpeRKeiejVLaGeA+
             aOXx+5dx4KN2ng+3tM4WySkE7YDyENm7TSmtAn1ZI29zzDBfBDDmyfi5yZTDx8YU
             mZy7GJWkZ6E8XJQtnVVNLLnoWEScUAGL5e6YrULGPiPRFxA88f4GCWCGSAFlAwQC
             CAQg13CpZz7J/KpQgh06SZmJEw/sxHQjiOU5E4y+uimOcDUEHEwpZ0O6YQeA9t66
             ZyiOVTg7Ep7pe7ZRbCuO9iAwggFCBgsrBgEEAYPpUwEAAYGCATEwggEtAgEAMIGt
             BglghkgBZQMEAS4EDK6DRkRMQ5IltdU36wSBkQSbv4PCKs3Wv3OwH5KahD5929KQ
             ZLplknRLqmb+7Hx9bH8fDi9WtIX+lZteOZ9bSR0JX0zTkNSdvB08b4X1LUJuwhi4
             JqStKAhal0xUnRvBD+LXtmk6opnDYjzq4EEO6xCkaWGgPpQvGaz9hwncdG7SgVQd
             +8m7iZiqlugQAOU8lz0Bh5zWzDamfovCEwXj1JswXwQwSogdsfPReknGmucZWM2A
             SNSnQI4xIsxfElK4IcSFCfU3vQZBxxk381k5E8Zlt2xuBglghkgBZQMEAggEIO3m
             ADZ77Tp333et8R1LQbtUcpr3Yqoh6jlW3BSQLRcbBBdSsWgxSPRgm+4hs/Du35cq
             KPyPfSmrBzCCAUEGCysGAQQBg+lTAQACgYIBMDCCASwCAQAwga0GCWCGSAFlAwQB
             LgQMmSSvQBBiKRyFW9UfBIGRBPRkpu8qLCfMcGYC8GP7kJ6/1Pq/nQfqdIFw2Cty
             /R3FIXrXJA/8huQDxig6xgKL0SSoLvXfzNBgdjuX6EzqjQsjA0N2lzChDZzWvk//
             WLf1QnERqzYicC3IXfbpflTnJ6iSrsmgqq4uRQQyN0D0mPWLL0Sfx9tsFN1rEvkR
             T4IAb5MZgHPFs21F4tJMbgkF3DBfBDB7p17C5wEItf8Rak/otsY6SQjNKv2PscYQ
             0HMfX5pKQrSD2qfRPEi1RC7DNb/efMQGCWCGSAFlAwQCCAQgKubPUBYleWB1V1HG
             EeVMVv3FhPXVY0QX9AHBbGa9FmoEFpBmspb0uE9MnVyfpAKdqemBLtWlBBIwggFJ
             BgorBgEEAYPpUwEBgYIBOTCCATUCAQAwga0GCWCGSAFlAwQBLgQMuCew76SpKgKu
             UIdxBIGRBPiWmic2bjSHcYqGmLva2EzYGNCSAfEEyjPbJMY1BEXibSjybOGtnJL0
             IHJmS461rLeFIX8YdntNTBjaNUQD1EjEj8f3YGFtUpEY+BAdLMNVz7A58H1c4nRi
             NMCPOoBDQJEYLVpG8lWVOEMsfZg5KMealFtTp+T7ywTxF03hnlNkBTgU6U2ZNEuD
             X1xpBEouyjBfBDDFcF8tJS5/4mduRBaciDZ1D/YJMAUQnM06aSprfkWhMJWqbF8l
             5ymHSvY9EJYtcwkGCWCGSAFlAwQCCAQgE6CsBqi5HjKhYnaQus94/ylOmmzJqTTo
             X9HXApGbkKUEH68thtrv4xhMu/BcTo82HFo6g7hHu8IN5oMl5EmurnwwggFLBgor
             BgEEAYPpUwEDgYIBOzCCATcCAQAwga0GCWCGSAFlAwQBLgQMgh7oU+cdJVw0eBt8
             BIGRBBDTc6GW+4r8hXnZJ7iF4N++bSdIMjll3r7Q9et89HDekmy69v77EMP0diH6
             NpZpxqnuEOcshInxa0v58VZul1tkcm75wasJuqNw9IUY+dmBD+0KMgpkPAVdbjfa
             71b7wArr1slkWsdICCWhlUs+aHwM9jM0pGkAI88porYA9S48vU2EDOVtS8ego7ra
             KlNwHzBfBDBl+GetvnpTiffPBd7PEyZqfGqLgcgUBhJXKmJUfEzyb4783GQadZdF
             QIQ2esVt350GCWCGSAFlAwQCCAQgWXc7FMmecEraUKs1qvmrZ49ElVH1IDwVspDL
             J4rNqHYEIWR9rrIyLsors2wzFIebNAUSMz2dka1Io7zqjq5VbpmrfTCCAT4GCisG
             AQQBg+lTAQqBggEuMIIBKgIBADCBrQYJYIZIAWUDBAEuBAySUv2eDAwSpuCEmRgE
             gZEEGqzfX6gsTiPLsocjsucdScOjmvD88oEWihxce/hDhrPB1dmM2jRndQr8pD+B
             Hgveid3bTSPv5vEd9OqyPr8IJeymHMUvpdn09XtcV9kptntwwA/fqH2hwnIC2auZ
             0eQKAVaG95wZxIo8lnmIXIFZG9CbquEVyvFssgMQpRayl1WU6ZZaNN0ArYlRsKna
             hTpcMF8EMPFsjOZ6nh29GIYXSNQG0b9nyp+FpfG6MPpuruwb5K4ze6qGizrm8u4y
             H6ox4ZJnqAYJYIZIAWUDBAIIBCBuKyWAsSEcXHWRJ5CZq9tr/PuSS5uvs6VLESlQ
             YBWzBAQUkH70gLCbixjJl34peqlV+E+62JMwggGZBgorBgEEAYPpUwECgYIBiTCC
             AYUCAQAwga0GCWCGSAFlAwQBLgQMgq06dYnpn1XKVqs4BIGRBHsSETAQ4BMMC7y+
             gOhtt/f3o6CvlYHA67hrQOMO+VPks1I2/xovWVAE3rrYpvTiCobT7ymkiD/2FiYi
             uScPEoWG4NEWTFT53FQ0vgf029YprtsW3SfEeGA6s7dwp/XtQFr32C7nqB7pL/JN
             7/iW0aPy+XMoOpJVherHh/29UklIY+TJTXMpnuoAWXAuHoOvpDBfBDB7ATNQe0BN
             q1gyDdUfqf8pNFVfOCJ2ylPYhLUyx2HovL+ZX5KONz29dNGS2VEurJ8GCWCGSAFl
             AwQCCAQg7I3wBQxmsIKuu4twk3ZmhZW8H9EfmQk1VNcGwAJlxUIEb2qjQ2H/SAMn
             M09iGJRRz2+W4sILVpzYa1ybUwQO9Ha856O8UVV+K8YDoQK4rCswOeeBvW1+kJ72
             4oNNAAhab39o+VMBd2TuvqK0z+zJeE0xhUr6cQsiQVgA3DLh9JWuvLwndulNB1a1
             M6gy0EwWyTCCBDYGCysGAQQBg+lTAQsAgYIEJTCCBCECAQAwga0GCWCGSAFlAwQB
             LgQMrQ4AOD0egRXSNwQKBIGRBFPJ+ZdJkS0Di2P/nCWmSvLNxGeKALF41hQgDNVB
             5WU+c7yHbRKEPSspnlESQodZEGAu00JiVOGjCOT7Tf84O01L1S8VXjy2jbxDahsx
             LPEhN52Wcix2Jm2FhRKoCMXIC/KaHgbzmBrXAWm6wFvmZJfgdutN1OYCHLdujfzg
             JEWkrs+DdEcw551+TviNwIY3DzBfBDBgMLt/g9YsytmHUG2Ecsgr6i/WfRUcxxWX
             Hj6eY8sMMg3M9nT3m3woNmhC8h04LHMGCWCGSAFlAwQCCAQgB+KLtNJIYe92zhhg
             1d3el9rGb1N+CjREqQuqV1Fv6oQEggMJWRluUZbpQAtZ5YrchcMAwNMRfgz3oQZi
             N5mhw9yWOSSPpC660OzoNYiZMbKTtxOuG4I1VCsC2+hEAYgOQFrKe/i6PadlEURB
             sQfE1JbihOYv0HmRky0GNJYuKbWsD1ea1SbjG7RUAwEpOvKukEyuHJE971pRFThr
             y87ewQ7hos6Gnu/Df9LrEgQ8LOP0x9yl5zv/Bj1AJCZ3Nyz66KztIlvarWVvVPL3
             MhaJfHcwZa0MOgdeKSXQtU44Mmq0XtiUfSxJrxrPupM/34M3bRFMrczThdtRFTdI
             XFhzDF5tS7sLrP+kf1FrOTs7KUT4t1dMa9hQh6nwAAsL4xLrwaTkh/grbfqcYqOs
             sra7BF2WfjvWJz91vn4BNJG7NzDdgpywhbumhBIlXs5e4FylNxgAEazLPRHHUm2U
             VudGAo28qUfbAXAem/rOQYtaMKGKYDimFedUNH8w5TV5mXawQZEeDgzoa2rMYpGf
             vL40gZdzAjuSTmzKT0GOQIXycDpYOM2jDBM+A7d9/xZpzXT7uKy12YwvGOuGWHxA
             5U3kYv/p5GONCAiaUUk+9Bl6mh3QqtWdDbiDjIGDEIfKgWK3fT/ohuyoKUoDqjJh
             LIYL5qZ/8+/zWKBAO8M9s3Gp+omsODAK8E027eA+N1sQPBja8YaEqDEad/v8gz6j
             GjNqYNwSK9ZYEpmRo54XayU2jDGc7dnzGU84vMSvTUfJRy9IplRJmWYpXYM7OWxa
             zP8qjYXM49kDjkCEmDtxuinduNH5hFZnOsmOl0kWLqSNS62TCYk3XAKZ7db0FVY1
             8Gc4/M5dpPLvn3gppo9Z3yqdUS/oZS9oB6+1RYwLO94fFw5sL/K0+bF/uLcoeUPd
             h/LV3J4KFUBnU6Dka0/bKmPJ3hOlPh+MOrLltkaTe4VfoO0cypHRSsdjkd2o2t2a
             fcrgVMlsqEW3dYBllNxZ0a1IM3R/YYwgw5xjRIrgFdCQ50Tt72CaV9MBhHKMtt0R
             DP2cX5x+iPdIcxC5rPbYeQHj1mUa/6v+H8HxSvklyzchMIIBmwYKKwYBBAGD6VMB
             CIGCAYswggGHAgEAMIGtBglghkgBZQMEAS4EDCWEV3KK4uEfw5QJbASBkQTM7sIw
             f2yhqRUziBVtk7t39IhmND9FstuiKZ8eFcF7bPNPCked6cD3xeVqlm2y24DdppdK
             SusgQ3y4eBWZilrXpF3WadVXTrPWu6nXDb5Zz6w30g/KSC8Up+C+NFzygfUlqUZ6
             a0QiPJ8XgsxIBLoQIEPVW4aLVzlbq+lqY8q9Acv7Cum7WG6eYM6ZDRx97JAwXwQw
             GMbP79brcE38kuDjosx28XVFVBWRDUDp9JN9/My9KviAdyLUzWVBhod6Mor0wAI6
             BglghkgBZQMEAggEIGh+tlb6l/j6klJM43cxhUdz/s+AUUtq19a9GMJ62t54BHFQ
             FeN2m0llAIBN9Uk3kcyyQDoh1irPBrpNqramAZ7JgeQeVL/N8cx6plZFCubLAKw4
             ro11bK7volKHM+Y5GAa9mw6qQ7EIHlj5q0n3asRyR2IgIhqeXMKMk/yhuk7NBWiM
             gUpAM7mZGWBHzdkgDZAENjCCAUoGCisGAQQBg+lTAQSBggE6MIIBNgIBADCBrQYJ
             YIZIAWUDBAEuBAwsRrNjtqmKIqh8As0EgZEEFhyHX4cecJ0bsEjoyb8UNPj7n6GG
             zYDIiSfeCn0TkozFu1eo380D5fLLKTgSryFh1n3zDhaOPx+2SbZAaA7pOtfGr3iH
             oYR+kYNRSeyLWTQSDbmhisdc9Mpynp5j+ERUYVPTetLA28WubO/EfSSFdp+b0GOB
             wLc5ZNicfEJSPUPC4IYwVUBUd1Wb/VkqJZL/MF8EMF9OVmcLtcXfRx2gk7vPGYCz
             CtIjpRraay81USiG93kIh37GQCdHc/IGf4I7/BUoDgYJYIZIAWUDBAIIBCBHGgzL
             dBCh12S/pv8XS5Yz9vZgM8GSq2uiI9pNT7BjXAQgh2Zqlr5JTBiczQbL+GjUYq9p
             CkI8wR7hzmc/Xgv5/SEwCwYJYIZIAWUDBAMKA0gAMEUCIQDwqaiMD2lI/kCAmpv1
             owIZDxeiYs5YJUUC6FOMm2RqOwIgMUqgEIProSlhvH6HVUHiBXrOKVZFYh+7NFVX
             ikSEimY=
             -----END CERTIFICATE-----
            """)
        
        let expected = ExpectedCertificate(
            hash: "94868CBFD6EA00A80B6C217D81CEA25E55F24598B2B665BBB019B4F04BA843CE",
            version: 2,
            issuer: .common("OneFootprint Test CA"),
            serial: BigInt(hex: "27E1150D18497931F3AB0BD3969E32FC")!, // 53008585596866308778520305626970469116
            subjectAccount: try AccountBuilder.create(fromPublicKey: "keeta_aab25nlmhuqcojuap3tt2hhqczcthbitizgbepucoruyjo5hsjlvboodilqgcyi"),
            validityFrom: Certificate.dateFormatter.date(from: "2025-12-03T23:01:16.000Z")!,
            validityTo: Certificate.dateFormatter.date(from: "2026-12-03T23:01:16.000Z")!,
            signature: [48, 69, 2, 33, 0, 240, 169, 168, 140, 15, 105, 72, 254, 64, 128, 154, 155, 245, 163, 2, 25, 15, 23, 162, 98, 206, 88, 37, 69, 2, 232, 83, 140, 155, 100, 106, 59, 2, 32, 49, 74, 160, 16, 131, 235, 161, 41, 97, 188, 126, 135, 85, 65, 226, 5, 122, 206, 41, 86, 69, 98, 31, 187, 52, 85, 87, 138, 68, 132, 138, 102],
            permanent: false
        )
        
        #expect(expected.matches(cert))
    }
}

// KYC
/*
 -----BEGIN CERTIFICATE-----
 MIIHhDCCBymgAwIBAgIDB5BFMAsGCWCGSAFlAwQDCjAqMSgwJgYDVQQDEx9JbnRl
 cm1lZGlhdGUgQ0EgZm9yIERldmVsb3BtZW50MB4XDTI1MDgwNjEyMjMyOFoXDTI1
 MDgwNjEzMjMyOFowUDFOMEwGA1UEAxZFa2VldGFfYWFiZzJsa3d1eTRndnpyNDRj
 bmlpaGRtd3ppbmZ1dW5xdjRxZ3N1aGJxN2pwdDRxbXM2MjJ0bGRqYmRleHd5MDYw
 EAYHKoZIzj0CAQYFK4EEAAoDIgACbS1Wpjhq5jzgmoQcbLZQ0tKNhXkDSocMPpfP
 kGS9rU2jggY4MIIGNDAOBgNVHQ8BAf8EBAMCAMAwHwYDVR0jBBgwFoAUi4XchxNu
 PPyBY1MwHGqwmnHH+ZgwHQYDVR0OBBYEFArpmG0YADAI2bTgA463AGzcm4jZMIIF
 4AYKKwYBBAGD6VMAAASCBdAwggXMMIIBHgYKKwYBBAGD6VMBAIGCAQ4wggEKAgEA
 MIGtBglghkgBZQMEAS4EDEpAAIAlCbQlpRw0+ASBkQTETZxuAv9NWBbZR1QVIBPz
 36lTFtMpvC+yCc372G2A7B9H+i38aw6HomUWBly1Hy0xHnrT/UcjR7/uye+/Rszt
 MWANN1KMFqRDKX7wUHSZCCppOQG5jY4iVxDoWua2XXxWHNVQC26iwlzHsZvULRBk
 FttwqmDUyHPCzHC1wOWQCnOnLytGHBqNqRWZuCDA7FkwTwQg0gNdRawy5hxaXHmL
 ihrn2165x7pvnA+gymJMiH1EvgQGCWCGSAFlAwQCCAQgtoYAdoJRRwmF9TCb9mRy
 ct9ckYy1xvbvxnckXnf0RFMEBL9+R4cwggEoBgorBgEEAYPpUwEDgYIBGDCCARQC
 AQAwga0GCWCGSAFlAwQBLgQMivoWxVciaLMYCQK/BIGRBPOHEM521FooiwbLl0QK
 C8tVuSXPCoIF1G9+u3Es4aUpGW3Rg4sb8xMcwiG8z/6ubt5aNMj1a/qSVl7Hwst0
 Qp+FQtg3+9dRwkifHAPwylOkxu2yuWbQlhysEfculOWEr+PhIKuNzQVIu4ueuxtf
 ML/XqWS6ns5SLXvHhN+r8uAggb4mORIRD27NsGPqystjIDBPBCBMgZjOSwADbcSC
 /cOVmjCKcLWxD/gUmcFAPSbHVsB71AYJYIZIAWUDBAIIBCCZB9aacxAiPKtbPc8X
 zGz4/yFVfeqn6pBctXbE0/8JRgQO7uTRX7ovQ+Smu+zkTbUwggEpBgorBgEEAYPp
 UwEEgYIBGTCCARUCAQAwga0GCWCGSAFlAwQBLgQMUIwCC26Y5NnCN9nmBIGRBHBu
 exqc+BI02e2sh4rtVcZCs9nSiZ5Ei19HaHZSV4ocAkhhpKsAaOZFNNGpsLZTWZTz
 0LqeGvKH9UShlHC8IKr8pJBmpzSHGUr/s12kMQVA3ely38JcaetpPHDOI2N0ZAHT
 SsFs9PWC0C9DoAhsbHbAEhlo+eIgelD0CeUimZS/VEjCqji8NYRlF+fszor17jBP
 BCBzozmDexuSEdcL4aK2TZpKvr2oTdUnYFIX2FCpQQPHdAYJYIZIAWUDBAIIBCC4
 k0MKDFn4JD/rObSVNl0dJunCjTCEfefGr2N0ZvZeiAQPM6UburOiFblEgEmGd8vv
 MIIBJQYKKwYBBAGD6VMBAoGCARUwggERAgEAMIGtBglghkgBZQMEAS4EDMFtzNBS
 JqA5i4IYLASBkQTKnPXh5va7ZczaWFitwi/jo1rManzNNOur0ZdXmjhyFTz5BpzF
 wqB53U9pqSg+O7JRH55WkvPuc9sre+uk/jYZ/JoTCnQTcTokRGxsbuQ4/suHzC67
 9H6A99tN8ceGiLvLz9xWZRnbjPsW5WJTERy8kNi4tDabbvHQKd+rn8vjV0G/YsCT
 /6kwCtjptxdblS0wTwQgUrYi4vxQwTAJNPeYRdk4p7v6o4G1YqZ8nikACX8eYS0G
 CWCGSAFlAwQCCAQgKTzABo+oBBbQ0yjolWgKnk5QWipfPlfMI8msQGNb+hIEC/Mw
 zFxjE2rc0xqRMIIBJAYKKwYBBAGD6VMBAYGCARQwggEQAgEAMIGtBglghkgBZQME
 AS4EDFQkt6dLa++YDEvPQgSBkQTI43DeX4eETvoiWoJ/PzWYa5ZODU7sS0eNfsZd
 po31hPUqzx5bQGQB9vP2Vt10vImHKEUPeU/Y2vt/PEoRIeLRUIp2NbPn4hAg9hKS
 NzC0LCTz8IaImecgswHXDkCelMKxnk/EK83t0o+DPQwcIs3EocuxWwef8c4JTd6o
 1o68EYr8XIKL4r20B4TZMeRfB7EwTwQgz1/wZ+UsM3YgfzzYjL/9PvsrypBJxBXE
 uPNxULEt3scGCWCGSAFlAwQCCAQgRfJOgstOyOy+hCzytORTdWVAAaQVxXLMExgA
 xGj3G7cECoiB5Bv4v8i63pcwCwYJYIZIAWUDBAMKA0gAMEUCIQCR4qzT4XnoeMp1
 ULx+fJHM0NfdgG7qHWULgnVVPbZjHQIgTteqVDSyazE5I9dnort4aicQ1zXSvd84
 iMfoh7wTNEg=
 -----END CERTIFICATE-----
 */

// Intermediary
/*
 -----BEGIN CERTIFICATE-----
 MIIBhDCCASmgAwIBAgIBAjALBglghkgBZQMEAwowKTEnMCUGA1UEAxMeS2VldGEg
 VGVzdCBOZXR3b3JrIEtZQyBSb290IENBMB4XDTI1MDgwMTAwMDAwMFoXDTI1MDgx
 NTAwMDAwMFowKjEoMCYGA1UEAxMfSW50ZXJtZWRpYXRlIENBIGZvciBEZXZlbG9w
 bWVudDA2MBAGByqGSM49AgEGBSuBBAAKAyIAAjVgFkAV5ympmjv9ERrdfxLOyLzV
 Pg5xw1+fCyp0It1bo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIA
 xjAfBgNVHSMEGDAWgBRqnzagoWMnaOEiPYIYAFQuJfiHejAdBgNVHQ4EFgQUi4Xc
 hxNuPPyBY1MwHGqwmnHH+ZgwCwYJYIZIAWUDBAMKA0gAMEUCIQCGzdUuCCtzNMn1
 +WlU5q/LXjE1q09c2coCdW/uI6d8bAIgIa6QAqMnxc7cv3OilcBcwa0ljGGDIcIG
 skTiIbB8+cc=
 -----END CERTIFICATE-----
 */

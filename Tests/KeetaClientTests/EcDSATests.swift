import XCTest
@testable import KeetaClient

final class EcDSATests: XCTestCase {
    
    func test_signatureFromDer() throws {
        /*
         X.509 certificate signature from vote staple,
         generated with the node v.0.8.4:
         
         eJwzaGLabtDEqMnSxKgKpBWZGBmYWEJcg0NYGSSEjQyMTA0MDY0NTY1MjQ31jC0MoliUGJh3cRg53oopDXw77WV9kYL+o70vl/LlNp9b/NLqd5Xsz4lKrAwsCpHPzN8stY56+6bkbrzVA1f2XAfn9yw2OWenThflVM2tKTQoNSgG2gUy7m5KY0O5qUrSoT5x5duX6xdcZKp/minSoSH8e+1qzRpOUyZGRhZF5oKm6VPvM+y6OKWC5+DDSwdO8hYmPTgRt0k/2aD6rd2qUi9hlSTjZMM0w1QLXcukFGNdk+QkM91ES7NEXcs0M0ODlETLJAMDUyaHLGeP/lJ77tmMyyoLcj1z59okLDLxfeA+xXlGx6yg7jB956Tg70LzX/ifUTt9Y+m3zGlZjdWsN38f7X+eG2Nyam20IjCQ2oCB1QSk64BYZQEzEyMTEzPn0YcG3GycCW0ejKnMLMxcBgGGfgY+bMyhLMzCrtmpqSWJ8YmJianJJjmJZamlpsmmmSklaWnZRonGmekZBRnGeRl5psWpFdm55dmp2ZVZifnJ5ZWVSaZ5mYVlKUbpSYk5iQZqGBFiaWQRJcFvbGBkZgAUMwCDKAMBQz4DHpDNrMKslsmmqYYGZgYCbOxabR7nbJkY2Vi1G1kYuJiVGJi4u1k9/bpXyJwKzZB27Pv8dnl+ivfKaYGiLY2HthnIbRVY7G7gauAM8xQzIzMj438W4wWGBvpwjzJxGCixKBy6ZPttSvxFO22ne3cltTNzl/N+ZDxb1SRhY/ZFy0szPgQlZJjdGQxcmBR8Vc7MdJu08bA3T+Su3Mu2zWa6qQECB/5lSm2YIMmjsZqbSSFBXcVH/0j7tP/L/SzmPrwm87rcIC7AU+PMOcZvS9lL/hcBAECH6fc=
         */
        
        let signature: Signature = [
            48,  68,   2,  32,  77,  36, 204, 153,  70, 146, 177, 195,
            75,  12,  89, 186, 109, 211,  61, 131,  54,  45, 101,  80,
            16, 192, 254, 105,  26, 176, 144,  25,  12,  40, 171,  11,
            2,  32,  96,  39,  36,  76,  47, 196, 135, 150, 255, 167,
            78,  56, 157, 225, 214,  28, 235, 119,  48,  94,  80,  73,
            40, 204, 206,   1, 246, 165,   7, 116, 255, 114
        ]
        
        let expected: Signature = [
            77,  36, 204, 153,  70, 146, 177, 195,  75, 12,  89,
            186, 109, 211,  61, 131,  54,  45, 101,  80, 16, 192,
            254, 105,  26, 176, 144,  25,  12,  40, 171, 11,  96,
            39,  36,  76,  47, 196, 135, 150, 255, 167, 78,  56,
            157, 225, 214,  28, 235, 119,  48,  94,  80, 73,  40,
            204, 206,   1, 246, 165,   7, 116, 255, 114
        ]
        
        let result = try EcDSA_P256K.signatureFromDER(signature)
        
        XCTAssertEqual(result, expected)
    }
}

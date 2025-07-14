import Foundation
import Compression

func compress(_ data: Data) -> Data {
    let bufferSize = 8_000_000
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    var compressedData = Data()
    
    // Write a standard 2-byte zlib header (default compression)
    // 0x78 0x9C is the zlib header with deflate and default compression
    compressedData.append(contentsOf: [0x78, 0x9C])
    
    data.withUnsafeBytes { inputPtr in
        let input = inputPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        let written = compression_encode_buffer(
            buffer,
            bufferSize,
            input,
            data.count,
            nil,
            COMPRESSION_ZLIB
        )
        
        if written > 0 {
            compressedData.append(buffer, count: written)
        }
    }
    
    buffer.deallocate()
    
    return compressedData
}

// Custom behavior dropping the first 2 bytes (zlib header)
func decompress(_ data: Data) -> Data {
    let bufferSize = 8_000_000
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    var decompressedData = Data()

    data.subdata(in: 2 ..< data.count).withUnsafeBytes ({
        let read = compression_decode_buffer(
            buffer,
            bufferSize,
            $0.baseAddress!.bindMemory(to: UInt8.self, capacity: 1),
            data.count - 2,
            nil,
            COMPRESSION_ZLIB
        )
        decompressedData.append(Data(bytes: buffer, count:read))
    })
    
    buffer.deallocate()
    
    return decompressedData
}

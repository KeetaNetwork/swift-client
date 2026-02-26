#if canImport(UIKit)
import UIKit
public typealias KeetaImage = UIImage

extension UIImage {
    public convenience init?(contentsOf url: URL) {
        self.init(contentsOfFile: url.absoluteString)
    }
}

#elseif canImport(AppKit)
import AppKit
public typealias KeetaImage = NSImage

extension NSImage: @unchecked @retroactive Sendable {
    public func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        
        let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        return jpegData
    }
}
#endif

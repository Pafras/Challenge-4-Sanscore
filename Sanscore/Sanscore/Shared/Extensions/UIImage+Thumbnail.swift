// UIImage+Thumbnail.swift
// Shrink a camera photo to a tiny JPEG for sending over the local network.
// A full photo is multi-MB and would choke MultipeerConnectivity; a ~160px
// square thumbnail is a few KB — plenty for a lobby avatar bubble.

#if os(iOS)
import UIKit

extension UIImage {
    // Aspect-fill into a maxSide square, then JPEG-encode. Returns nil if encoding fails.
    func jpegThumbnail(maxSide: CGFloat, quality: CGFloat) -> Data? {
        let scale = max(maxSide / size.width, maxSide / size.height)
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (maxSide - scaled.width) / 2, y: (maxSide - scaled.height) / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: maxSide, height: maxSide), format: format)
        let square = renderer.image { _ in
            draw(in: CGRect(origin: origin, size: scaled))
        }
        return square.jpegData(compressionQuality: quality)
    }
}
#endif

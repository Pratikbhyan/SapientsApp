import UIKit
import SwiftUI

/// Utility for extracting simple palette colours from an image.
/// Currently returns only the average colour which we treat as the dominant colour.
enum ImageColorExtractor {
    static func dominantColor(from uiImage: UIImage) -> Color? {
        guard let cgImage = uiImage.cgImage else { return nil }
        let width = 40, height = 40 // down-sample for performance
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var rTotal = 0, gTotal = 0, bTotal = 0
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            rTotal += Int(ptr[i])
            gTotal += Int(ptr[i+1])
            bTotal += Int(ptr[i+2])
        }
        let count = width * height
        return Color(
            red: Double(rTotal) / Double(count) / 255.0,
            green: Double(gTotal) / Double(count) / 255.0,
            blue: Double(bTotal) / Double(count) / 255.0
        )
    }
} 
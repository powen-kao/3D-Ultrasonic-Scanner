/*
See LICENSE folder for this sample’s licensing information.

Abstract:
General Helper methods and properties
*/

import ARKit
import NIO

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>


class Tools {
    static func pairsToString(items: [String:Any]) -> String{
        let keys = items.keys.sorted(by: >)
        var string: String = ""
        for key in keys{
            string += "\(key): \(items[key]) \n"
        }
        return string
    }
}

extension Float {
    static let degreesToRadian = Float.pi / 180
}

extension matrix_float3x3 {
    mutating func copy(from affine: CGAffineTransform) {
        columns.0 = Float3(Float(affine.a), Float(affine.c), Float(affine.tx))
        columns.1 = Float3(Float(affine.b), Float(affine.d), Float(affine.ty))
        columns.2 = Float3(0, 0, 1)
    }
}

extension CVPixelBuffer{
    func width() -> Int {
        CVPixelBufferGetWidth(self)
    }
    func height() -> Int{
        CVPixelBufferGetHeight(self)
    }
    func pixelCount() -> Int {
        width() * height()
    }
}

extension UIScrollView{
    func blankSpace() -> CGFloat {
        let blanckSpace = self.frame.height - self.contentSize.height
            - self.safeAreaInsets.top
            - self.safeAreaInsets.bottom
        return blanckSpace > 0 ? blanckSpace : 0
    }
}

extension simd_int3 {
    func data() -> Data? {
        try? PropertyListEncoder().encode(self)
    }
}

extension Data{
    func int3() -> simd_int3? {
        try? PropertyListDecoder().decode(simd_int3.self, from: self)
    }
}

extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {

        let attrs = Probe.defaultPixelBufferAttributes as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }

        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)

            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)

            context?.translateBy(x: 0, y: self.size.height)
            context?.scaleBy(x: 1.0, y: -1.0)

            UIGraphicsPushContext(context!)
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            return pixelBuffer
        }

        return nil
    }
}

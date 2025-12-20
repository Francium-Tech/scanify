#if os(macOS)
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

class DarwinScanEffect {
    private let context: CIContext

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    func apply(to image: CGImage, preset: ScanPreset) -> CGImage? {
        var ciImage = CIImage(cgImage: image)
        let originalExtent = ciImage.extent

        // 1. Apply paper warp/bend effect first (if enabled)
        if preset.applyWarp {
            ciImage = applyPaperWarp(to: ciImage, extent: originalExtent)
        }

        // 2. Darken the whites slightly (scanned paper is never pure white)
        ciImage = darkenWhites(ciImage, amount: preset.paperDarkening)

        // 3. Apply color adjustments (contrast, brightness, saturation)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
            colorFilter.setValue(preset.contrastAdjustment, forKey: kCIInputContrastKey)
            colorFilter.setValue(preset.brightnessAdjustment, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(preset.saturationAdjustment, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                ciImage = output
            }
        }

        // 4. Apply subtle blur (simulates scan imperfection)
        if preset.blurRadius > 0 {
            let clamped = ciImage.clampedToExtent()
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(clamped, forKey: kCIInputImageKey)
                blurFilter.setValue(preset.blurRadius, forKey: kCIInputRadiusKey)
                if let output = blurFilter.outputImage {
                    ciImage = output.cropped(to: originalExtent)
                }
            }
        }

        // 5. Add noise/grain
        if preset.noiseIntensity > 0 {
            ciImage = addNoise(to: ciImage, intensity: preset.noiseIntensity, extent: originalExtent)
        }

        // 6. Add uneven lighting (scanner light isn't perfectly uniform)
        if preset.unevenLighting > 0 {
            ciImage = addUnevenLighting(to: ciImage, intensity: preset.unevenLighting, extent: originalExtent)
        }

        // 7. Add edge shadows (from scanner lid/edges)
        if preset.edgeShadow > 0 {
            ciImage = addEdgeShadows(to: ciImage, intensity: preset.edgeShadow, extent: originalExtent)
        }

        // 8. Add dust specks (if enabled)
        if preset.applyDust {
            ciImage = addDustSpecks(to: ciImage, extent: originalExtent)
        }

        // 9. Apply slight rotation
        let rotation = Double.random(in: preset.rotationRange)
        if abs(rotation) > 0.01 {
            let radians = rotation * .pi / 180.0
            let centerX = originalExtent.midX
            let centerY = originalExtent.midY

            let transform = CGAffineTransform(translationX: centerX, y: centerY)
                .rotated(by: CGFloat(radians))
                .translatedBy(x: -centerX, y: -centerY)

            ciImage = ciImage.transformed(by: transform)
            ciImage = ciImage.cropped(to: originalExtent)
        }

        guard let cgImage = context.createCGImage(ciImage, from: originalExtent) else {
            return nil
        }

        return cgImage
    }

    /// Apply paper warp/bend effect - adds shadow band to suggest curved paper
    private func applyPaperWarp(to image: CIImage, extent: CGRect) -> CIImage {
        return addHorizontalBendShadow(to: image, extent: extent)
    }

    /// Add horizontal shadow band to suggest paper is bent
    private func addHorizontalBendShadow(to image: CIImage, extent: CGRect) -> CIImage {
        let bandY = extent.midY + CGFloat(Double.random(in: -extent.height * 0.15...extent.height * 0.15))
        let bandHeight = extent.height * CGFloat(Double.random(in: 0.25...0.4))
        let shadowIntensity = CGFloat(Double.random(in: 0.25...0.40))

        guard let topGradient = CIFilter(name: "CILinearGradient") else { return image }
        topGradient.setValue(CIVector(x: extent.midX, y: bandY + bandHeight / 2), forKey: "inputPoint0")
        topGradient.setValue(CIVector(x: extent.midX, y: bandY), forKey: "inputPoint1")
        topGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
        topGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor1")

        guard let bottomGradient = CIFilter(name: "CILinearGradient") else { return image }
        bottomGradient.setValue(CIVector(x: extent.midX, y: bandY), forKey: "inputPoint0")
        bottomGradient.setValue(CIVector(x: extent.midX, y: bandY - bandHeight / 2), forKey: "inputPoint1")
        bottomGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor0")
        bottomGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let topGrad = topGradient.outputImage?.cropped(to: CGRect(x: extent.minX, y: bandY, width: extent.width, height: bandHeight / 2 + extent.height)),
              let bottomGrad = bottomGradient.outputImage?.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: bandY - extent.minY)) else {
            return image
        }

        guard let combine = CIFilter(name: "CISourceOverCompositing") else { return image }
        combine.setValue(topGrad, forKey: kCIInputImageKey)
        combine.setValue(bottomGrad, forKey: kCIInputBackgroundImageKey)

        guard let combined = combine.outputImage else { return image }

        let whiteImage = CIImage(color: CIColor.white).cropped(to: extent)
        guard let finalGradient = CIFilter(name: "CISourceOverCompositing") else { return image }
        finalGradient.setValue(combined, forKey: kCIInputImageKey)
        finalGradient.setValue(whiteImage, forKey: kCIInputBackgroundImageKey)

        guard let shadowMask = finalGradient.outputImage?.cropped(to: extent) else { return image }

        guard let multiply = CIFilter(name: "CIMultiplyCompositing") else { return image }
        multiply.setValue(shadowMask, forKey: kCIInputImageKey)
        multiply.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiply.outputImage?.cropped(to: extent) ?? image
    }

    /// Add random dust specks to simulate dirty scanner glass
    private func addDustSpecks(to image: CIImage, extent: CGRect) -> CIImage {
        let width = Int(extent.width)
        let height = Int(extent.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        cgContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let numSpecks = Int.random(in: 15...40)

        for _ in 0..<numSpecks {
            let x = CGFloat.random(in: 0...CGFloat(width))
            let y = CGFloat.random(in: 0...CGFloat(height))

            let size: CGFloat
            if Double.random(in: 0...1) < 0.85 {
                size = CGFloat.random(in: 1...4)
            } else {
                size = CGFloat.random(in: 4...8)
            }

            let darkness = CGFloat.random(in: 0.15...0.45)

            cgContext.setFillColor(CGColor(red: darkness, green: darkness, blue: darkness, alpha: 1))

            if Bool.random() {
                cgContext.fillEllipse(in: CGRect(x: x - size/2, y: y - size/2, width: size, height: size))
            } else {
                let width = size * CGFloat.random(in: 0.6...1.4)
                let height = size * CGFloat.random(in: 0.6...1.4)
                cgContext.fillEllipse(in: CGRect(x: x - width/2, y: y - height/2, width: width, height: height))
            }
        }

        let numHairs = Int.random(in: 0...3)
        for _ in 0..<numHairs {
            let startX = CGFloat.random(in: 0...CGFloat(width))
            let startY = CGFloat.random(in: 0...CGFloat(height))
            let length = CGFloat.random(in: 15...50)
            let angle = CGFloat.random(in: 0...CGFloat.pi * 2)

            let endX = startX + cos(angle) * length
            let endY = startY + sin(angle) * length

            let darkness = CGFloat.random(in: 0.2...0.4)
            cgContext.setStrokeColor(CGColor(red: darkness, green: darkness, blue: darkness, alpha: 1))
            cgContext.setLineWidth(CGFloat.random(in: 0.5...1.5))

            cgContext.move(to: CGPoint(x: startX, y: startY))
            cgContext.addLine(to: CGPoint(x: endX, y: endY))
            cgContext.strokePath()
        }

        guard let dustImage = cgContext.makeImage() else {
            return image
        }

        let dustCIImage = CIImage(cgImage: dustImage)

        guard let multiply = CIFilter(name: "CIMultiplyCompositing") else {
            return image
        }

        multiply.setValue(dustCIImage, forKey: kCIInputImageKey)
        multiply.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiply.outputImage?.cropped(to: extent) ?? image
    }

    /// Darken whites to simulate scanned paper (never pure white)
    private func darkenWhites(_ image: CIImage, amount: Double) -> CIImage {
        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            return image
        }
        gammaFilter.setValue(image, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.0 + amount * 2, forKey: "inputPower")

        return gammaFilter.outputImage ?? image
    }

    private func addNoise(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              var noiseImage = noiseFilter.outputImage else {
            return image
        }

        noiseImage = noiseImage.cropped(to: extent)

        guard let colorMatrix = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        let scale = Float(intensity)
        colorMatrix.setValue(noiseImage, forKey: kCIInputImageKey)
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputBVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputAVector")
        let offset = CGFloat(-scale / 2)
        colorMatrix.setValue(CIVector(x: offset, y: offset, z: offset, w: 0), forKey: "inputBiasVector")

        guard let grayNoise = colorMatrix.outputImage else {
            return image
        }

        guard let blendFilter = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }

        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(grayNoise, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage?.cropped(to: extent) ?? image
    }

    private func addUnevenLighting(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        let centerX = extent.midX + extent.width * CGFloat(Double.random(in: -0.1...0.1))
        let centerY = extent.midY + extent.height * CGFloat(Double.random(in: -0.1...0.1))

        guard let gradientFilter = CIFilter(name: "CIRadialGradient") else {
            return image
        }

        let radius = max(extent.width, extent.height) * 0.8
        gradientFilter.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
        gradientFilter.setValue(radius * 0.2, forKey: "inputRadius0")
        gradientFilter.setValue(radius, forKey: "inputRadius1")

        let brightVal = CGFloat(1.0)
        let darkVal = CGFloat(1.0 - intensity)
        gradientFilter.setValue(CIColor(red: brightVal, green: brightVal, blue: brightVal), forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: darkVal, green: darkVal, blue: darkVal), forKey: "inputColor1")

        guard let gradient = gradientFilter.outputImage?.cropped(to: extent) else {
            return image
        }

        guard let multiplyFilter = CIFilter(name: "CIMultiplyCompositing") else {
            return image
        }

        multiplyFilter.setValue(gradient, forKey: kCIInputImageKey)
        multiplyFilter.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiplyFilter.outputImage?.cropped(to: extent) ?? image
    }

    private func addEdgeShadows(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        guard let vignetteFilter = CIFilter(name: "CIVignette") else {
            return image
        }

        vignetteFilter.setValue(image, forKey: kCIInputImageKey)
        vignetteFilter.setValue(intensity, forKey: kCIInputIntensityKey)
        vignetteFilter.setValue(max(extent.width, extent.height) * 0.7, forKey: kCIInputRadiusKey)

        guard var result = vignetteFilter.outputImage else {
            return image
        }

        result = addTopShadow(to: result, intensity: intensity * 0.5, extent: extent)

        return result
    }

    private func addTopShadow(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        guard let gradientFilter = CIFilter(name: "CILinearGradient") else {
            return image
        }

        let shadowHeight = extent.height * 0.15
        gradientFilter.setValue(CIVector(x: extent.midX, y: extent.maxY), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: extent.midX, y: extent.maxY - shadowHeight), forKey: "inputPoint1")

        let darkVal = CGFloat(1.0 - intensity)
        gradientFilter.setValue(CIColor(red: darkVal, green: darkVal, blue: darkVal, alpha: 1), forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let gradient = gradientFilter.outputImage?.cropped(to: extent) else {
            return image
        }

        guard let multiplyFilter = CIFilter(name: "CIMultiplyCompositing") else {
            return image
        }

        multiplyFilter.setValue(gradient, forKey: kCIInputImageKey)
        multiplyFilter.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiplyFilter.outputImage?.cropped(to: extent) ?? image
    }
}
#endif

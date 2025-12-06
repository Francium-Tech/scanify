import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct ScanPreset {
    let name: String
    let rotationRange: ClosedRange<Double>
    let noiseIntensity: Double
    let contrastAdjustment: Double
    let brightnessAdjustment: Double
    let saturationAdjustment: Double
    let blurRadius: Double
    let paperDarkening: Double
    let edgeShadow: Double
    let unevenLighting: Double
    var applyWarp: Bool  // Paper bend/warp effect

    static let `default` = ScanPreset(
        name: "default",
        rotationRange: -0.4...0.4,
        noiseIntensity: 0.025,
        contrastAdjustment: 1.1,
        brightnessAdjustment: -0.02,
        saturationAdjustment: 0.9,
        blurRadius: 0.3,
        paperDarkening: 0.06,
        edgeShadow: 0.4,
        unevenLighting: 0.08,
        applyWarp: false
    )

    static let aggressive = ScanPreset(
        name: "aggressive",
        rotationRange: -1.5...1.5,
        noiseIntensity: 0.05,
        contrastAdjustment: 1.2,
        brightnessAdjustment: -0.04,
        saturationAdjustment: 0.75,
        blurRadius: 0.6,
        paperDarkening: 0.12,
        edgeShadow: 0.6,
        unevenLighting: 0.15,
        applyWarp: false
    )
}

class ScanEffect {
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

        // 8. Apply slight rotation
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

    /// Apply paper warp/bend effect - simulates a phone photo of curved paper
    private func applyPaperWarp(to image: CIImage, extent: CGRect) -> CIImage {
        var result = image

        // Create multiple subtle bump distortions to simulate paper curve
        // Randomize the warp direction and position

        let warpType = Int.random(in: 0...2)  // Different warp styles

        switch warpType {
        case 0:
            // Horizontal wave - paper bent along horizontal axis
            result = applyHorizontalWarp(to: result, extent: extent)
        case 1:
            // Vertical wave - paper bent along vertical axis
            result = applyVerticalWarp(to: result, extent: extent)
        default:
            // Corner lift - one corner lifted
            result = applyCornerWarp(to: result, extent: extent)
        }

        return result.cropped(to: extent)
    }

    /// Horizontal paper bend (like paper curling top-to-bottom)
    private func applyHorizontalWarp(to image: CIImage, extent: CGRect) -> CIImage {
        var result = image

        // Very subtle wave using single gentle bump
        let bumpRadius = extent.width * 0.8
        let bumpScale = CGFloat(Double.random(in: 0.15...0.25))  // Very subtle!

        guard let bumpFilter = CIFilter(name: "CIBumpDistortion") else {
            return result
        }

        // Single centered bump for gentle curve
        let xPos = extent.midX + CGFloat(Double.random(in: -50...50))
        let yPos = extent.midY

        bumpFilter.setValue(result.clampedToExtent(), forKey: kCIInputImageKey)
        bumpFilter.setValue(CIVector(x: xPos, y: yPos), forKey: kCIInputCenterKey)
        bumpFilter.setValue(bumpRadius, forKey: kCIInputRadiusKey)
        bumpFilter.setValue(bumpScale, forKey: kCIInputScaleKey)

        return bumpFilter.outputImage ?? result
    }

    /// Vertical paper bend (like paper curling left-to-right)
    private func applyVerticalWarp(to image: CIImage, extent: CGRect) -> CIImage {
        var result = image

        let bumpRadius = extent.height * 0.7
        let bumpScale = CGFloat(Double.random(in: 0.12...0.22))

        guard let bumpFilter = CIFilter(name: "CIBumpDistortion") else {
            return result
        }

        let xPos = extent.midX
        let yPos = extent.midY + CGFloat(Double.random(in: -50...50))

        bumpFilter.setValue(result.clampedToExtent(), forKey: kCIInputImageKey)
        bumpFilter.setValue(CIVector(x: xPos, y: yPos), forKey: kCIInputCenterKey)
        bumpFilter.setValue(bumpRadius, forKey: kCIInputRadiusKey)
        bumpFilter.setValue(bumpScale, forKey: kCIInputScaleKey)

        return bumpFilter.outputImage ?? result
    }

    /// Corner lift effect - one corner of paper is slightly lifted
    private func applyCornerWarp(to image: CIImage, extent: CGRect) -> CIImage {
        // Pick a random corner area
        let corners: [(CGFloat, CGFloat)] = [
            (extent.minX + extent.width * 0.2, extent.minY + extent.height * 0.2),
            (extent.maxX - extent.width * 0.2, extent.minY + extent.height * 0.2),
            (extent.minX + extent.width * 0.2, extent.maxY - extent.height * 0.2),
            (extent.maxX - extent.width * 0.2, extent.maxY - extent.height * 0.2),
        ]

        let corner = corners[Int.random(in: 0..<corners.count)]
        let bumpRadius = min(extent.width, extent.height) * 0.4
        let bumpScale = CGFloat(Double.random(in: 0.18...0.28))

        guard let bumpFilter = CIFilter(name: "CIBumpDistortion") else {
            return image
        }

        bumpFilter.setValue(image.clampedToExtent(), forKey: kCIInputImageKey)
        bumpFilter.setValue(CIVector(x: corner.0, y: corner.1), forKey: kCIInputCenterKey)
        bumpFilter.setValue(bumpRadius, forKey: kCIInputRadiusKey)
        bumpFilter.setValue(bumpScale, forKey: kCIInputScaleKey)

        return bumpFilter.outputImage ?? image
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

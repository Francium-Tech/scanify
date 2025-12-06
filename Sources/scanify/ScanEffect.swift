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
    var applyWarp: Bool   // Paper bend/warp effect
    var applyDust: Bool   // Dust specks effect

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
        applyWarp: false,
        applyDust: false
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
        applyWarp: false,
        applyDust: false
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
        // Always use horizontal bend - most realistic and consistent
        return addHorizontalBendShadow(to: image, extent: extent)
    }

    /// Add horizontal shadow band to suggest paper is bent
    private func addHorizontalBendShadow(to image: CIImage, extent: CGRect) -> CIImage {
        // Create a shadow band across the page
        let bandY = extent.midY + CGFloat(Double.random(in: -extent.height * 0.15...extent.height * 0.15))
        let bandHeight = extent.height * CGFloat(Double.random(in: 0.25...0.4))
        let shadowIntensity = CGFloat(Double.random(in: 0.25...0.40))  // Much more visible!

        // Top gradient (light to dark)
        guard let topGradient = CIFilter(name: "CILinearGradient") else { return image }
        topGradient.setValue(CIVector(x: extent.midX, y: bandY + bandHeight / 2), forKey: "inputPoint0")
        topGradient.setValue(CIVector(x: extent.midX, y: bandY), forKey: "inputPoint1")
        topGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
        topGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor1")

        // Bottom gradient (dark to light)
        guard let bottomGradient = CIFilter(name: "CILinearGradient") else { return image }
        bottomGradient.setValue(CIVector(x: extent.midX, y: bandY), forKey: "inputPoint0")
        bottomGradient.setValue(CIVector(x: extent.midX, y: bandY - bandHeight / 2), forKey: "inputPoint1")
        bottomGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor0")
        bottomGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let topGrad = topGradient.outputImage?.cropped(to: CGRect(x: extent.minX, y: bandY, width: extent.width, height: bandHeight / 2 + extent.height)),
              let bottomGrad = bottomGradient.outputImage?.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: bandY - extent.minY)) else {
            return image
        }

        // Combine gradients
        guard let combine = CIFilter(name: "CISourceOverCompositing") else { return image }
        combine.setValue(topGrad, forKey: kCIInputImageKey)
        combine.setValue(bottomGrad, forKey: kCIInputBackgroundImageKey)

        guard let combined = combine.outputImage else { return image }

        // Create full white background and composite the shadow band
        let whiteImage = CIImage(color: CIColor.white).cropped(to: extent)
        guard let finalGradient = CIFilter(name: "CISourceOverCompositing") else { return image }
        finalGradient.setValue(combined, forKey: kCIInputImageKey)
        finalGradient.setValue(whiteImage, forKey: kCIInputBackgroundImageKey)

        guard let shadowMask = finalGradient.outputImage?.cropped(to: extent) else { return image }

        // Multiply blend with original
        guard let multiply = CIFilter(name: "CIMultiplyCompositing") else { return image }
        multiply.setValue(shadowMask, forKey: kCIInputImageKey)
        multiply.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiply.outputImage?.cropped(to: extent) ?? image
    }

    /// Add vertical shadow band to suggest paper is bent
    private func addVerticalBendShadow(to image: CIImage, extent: CGRect) -> CIImage {
        let bandX = extent.midX + CGFloat(Double.random(in: -extent.width * 0.1...extent.width * 0.1))
        let bandWidth = extent.width * CGFloat(Double.random(in: 0.3...0.5))
        let shadowIntensity = CGFloat(Double.random(in: 0.20...0.35))  // Much more visible!

        // Left gradient
        guard let leftGradient = CIFilter(name: "CILinearGradient") else { return image }
        leftGradient.setValue(CIVector(x: bandX - bandWidth / 2, y: extent.midY), forKey: "inputPoint0")
        leftGradient.setValue(CIVector(x: bandX, y: extent.midY), forKey: "inputPoint1")
        leftGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
        leftGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor1")

        // Right gradient
        guard let rightGradient = CIFilter(name: "CILinearGradient") else { return image }
        rightGradient.setValue(CIVector(x: bandX, y: extent.midY), forKey: "inputPoint0")
        rightGradient.setValue(CIVector(x: bandX + bandWidth / 2, y: extent.midY), forKey: "inputPoint1")
        rightGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor0")
        rightGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let leftGrad = leftGradient.outputImage?.cropped(to: extent),
              let rightGrad = rightGradient.outputImage?.cropped(to: extent) else {
            return image
        }

        // Use minimum to combine (darker wins)
        guard let minFilter = CIFilter(name: "CIDarkenBlendMode") else { return image }
        minFilter.setValue(leftGrad, forKey: kCIInputImageKey)
        minFilter.setValue(rightGrad, forKey: kCIInputBackgroundImageKey)

        guard let shadowMask = minFilter.outputImage?.cropped(to: extent) else { return image }

        guard let multiply = CIFilter(name: "CIMultiplyCompositing") else { return image }
        multiply.setValue(shadowMask, forKey: kCIInputImageKey)
        multiply.setValue(image, forKey: kCIInputBackgroundImageKey)

        return multiply.outputImage?.cropped(to: extent) ?? image
    }

    /// Add corner shadow to suggest corner is lifted
    private func addCornerBendShadow(to image: CIImage, extent: CGRect) -> CIImage {
        // Pick a random corner
        let isLeft = Bool.random()
        let isTop = Bool.random()

        let cornerX = isLeft ? extent.minX : extent.maxX
        let cornerY = isTop ? extent.maxY : extent.minY

        let radius = min(extent.width, extent.height) * CGFloat(Double.random(in: 0.35...0.55))
        let shadowIntensity = CGFloat(Double.random(in: 0.25...0.40))  // Much more visible!

        guard let radialGradient = CIFilter(name: "CIRadialGradient") else { return image }

        radialGradient.setValue(CIVector(x: cornerX, y: cornerY), forKey: "inputCenter")
        radialGradient.setValue(0, forKey: "inputRadius0")
        radialGradient.setValue(radius, forKey: "inputRadius1")
        radialGradient.setValue(CIColor(red: 1 - shadowIntensity, green: 1 - shadowIntensity, blue: 1 - shadowIntensity, alpha: 1), forKey: "inputColor0")
        radialGradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor1")

        guard let shadowMask = radialGradient.outputImage?.cropped(to: extent) else { return image }

        guard let multiply = CIFilter(name: "CIMultiplyCompositing") else { return image }
        multiply.setValue(shadowMask, forKey: kCIInputImageKey)
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

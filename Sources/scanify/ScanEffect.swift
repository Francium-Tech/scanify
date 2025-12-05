import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct ScanPreset {
    let name: String
    let rotationRange: ClosedRange<Double>  // degrees
    let noiseIntensity: Double              // 0.0 - 1.0
    let contrastAdjustment: Double          // 0.9 - 1.2 typical
    let brightnessAdjustment: Double        // -0.1 to 0.1 typical
    let saturationAdjustment: Double        // 0.0 - 1.0 (0 = grayscale)
    let blurRadius: Double                  // 0.0 - 2.0 typical
    let shadowAmount: Double                // Edge shadow/vignette

    static let `default` = ScanPreset(
        name: "default",
        rotationRange: -0.3...0.3,
        noiseIntensity: 0.015,
        contrastAdjustment: 1.08,
        brightnessAdjustment: -0.01,
        saturationAdjustment: 0.92,
        blurRadius: 0.2,
        shadowAmount: 0.3
    )

    static let aggressive = ScanPreset(
        name: "aggressive",
        rotationRange: -1.5...1.5,
        noiseIntensity: 0.04,
        contrastAdjustment: 1.18,
        brightnessAdjustment: -0.03,
        saturationAdjustment: 0.8,
        blurRadius: 0.5,
        shadowAmount: 0.5
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

        // 1. Apply color adjustments (contrast, brightness, saturation)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
            colorFilter.setValue(preset.contrastAdjustment, forKey: kCIInputContrastKey)
            colorFilter.setValue(preset.brightnessAdjustment, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(preset.saturationAdjustment, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                ciImage = output
            }
        }

        // 2. Apply subtle blur (simulates scan imperfection)
        if preset.blurRadius > 0 {
            // Clamp to avoid edge issues with blur
            let clamped = ciImage.clampedToExtent()
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(clamped, forKey: kCIInputImageKey)
                blurFilter.setValue(preset.blurRadius, forKey: kCIInputRadiusKey)
                if let output = blurFilter.outputImage {
                    ciImage = output.cropped(to: originalExtent)
                }
            }
        }

        // 3. Add noise/grain using speckle noise
        if preset.noiseIntensity > 0 {
            ciImage = addNoise(to: ciImage, intensity: preset.noiseIntensity, extent: originalExtent)
        }

        // 4. Add subtle vignette (scanner edge shadow)
        if preset.shadowAmount > 0 {
            ciImage = addVignette(to: ciImage, amount: preset.shadowAmount)
        }

        // 5. Apply slight rotation (do this last to avoid extent issues)
        let rotation = Double.random(in: preset.rotationRange)
        if abs(rotation) > 0.01 {
            let radians = rotation * .pi / 180.0

            // Rotate around center
            let centerX = originalExtent.midX
            let centerY = originalExtent.midY

            let transform = CGAffineTransform(translationX: centerX, y: centerY)
                .rotated(by: CGFloat(radians))
                .translatedBy(x: -centerX, y: -centerY)

            ciImage = ciImage.transformed(by: transform)

            // Crop back to original bounds
            ciImage = ciImage.cropped(to: originalExtent)
        }

        // Render final image
        guard let cgImage = context.createCGImage(ciImage, from: originalExtent) else {
            return nil
        }

        return cgImage
    }

    private func addNoise(to image: CIImage, intensity: Double, extent: CGRect) -> CIImage {
        // Use CIRandomGenerator and blend properly
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              var noiseImage = noiseFilter.outputImage else {
            return image
        }

        // Crop noise to image size
        noiseImage = noiseImage.cropped(to: extent)

        // Transform noise to grayscale with very low intensity
        // The key is to center the noise around 0.5 (neutral gray) and scale it down
        guard let colorMatrix = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        let scale = Float(intensity)
        // Map random [0,1] to [-intensity/2, +intensity/2] centered noise
        colorMatrix.setValue(noiseImage, forKey: kCIInputImageKey)
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix.setValue(CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0), forKey: "inputBVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputAVector")
        // Offset to center the noise
        let offset = CGFloat(-scale / 2)
        colorMatrix.setValue(CIVector(x: offset, y: offset, z: offset, w: 0), forKey: "inputBiasVector")

        guard let grayNoise = colorMatrix.outputImage else {
            return image
        }

        // Use screen blend mode for more natural noise
        guard let blendFilter = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }

        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(grayNoise, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage?.cropped(to: extent) ?? image
    }

    private func addVignette(to image: CIImage, amount: Double) -> CIImage {
        guard let vignetteFilter = CIFilter(name: "CIVignette") else {
            return image
        }

        vignetteFilter.setValue(image, forKey: kCIInputImageKey)
        vignetteFilter.setValue(amount, forKey: kCIInputIntensityKey)
        vignetteFilter.setValue(image.extent.width / 2, forKey: kCIInputRadiusKey)

        return vignetteFilter.outputImage ?? image
    }
}

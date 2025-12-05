import CoreImage
import Foundation

struct ScanPreset {
    let name: String
    let rotationRange: ClosedRange<Double>  // degrees
    let noiseIntensity: Double              // 0.0 - 1.0
    let contrastAdjustment: Double          // 0.9 - 1.2 typical
    let brightnessAdjustment: Double        // -0.1 to 0.1 typical
    let saturationAdjustment: Double        // 0.0 - 1.0 (0 = grayscale)
    let blurRadius: Double                  // 0.0 - 2.0 typical

    static let `default` = ScanPreset(
        name: "default",
        rotationRange: -0.5...0.5,
        noiseIntensity: 0.02,
        contrastAdjustment: 1.05,
        brightnessAdjustment: -0.02,
        saturationAdjustment: 0.95,
        blurRadius: 0.3
    )

    static let aggressive = ScanPreset(
        name: "aggressive",
        rotationRange: -2.0...2.0,
        noiseIntensity: 0.06,
        contrastAdjustment: 1.15,
        brightnessAdjustment: -0.05,
        saturationAdjustment: 0.85,
        blurRadius: 0.8
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

        // 1. Apply slight rotation
        let rotation = Double.random(in: preset.rotationRange)
        let radians = rotation * .pi / 180.0
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(radians))
        ciImage = ciImage.transformed(by: rotationTransform)

        // 2. Apply color adjustments (contrast, brightness, saturation)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
            colorFilter.setValue(preset.contrastAdjustment, forKey: kCIInputContrastKey)
            colorFilter.setValue(preset.brightnessAdjustment, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(preset.saturationAdjustment, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                ciImage = output
            }
        }

        // 3. Apply subtle blur (simulates scan imperfection)
        if preset.blurRadius > 0 {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
                blurFilter.setValue(preset.blurRadius, forKey: kCIInputRadiusKey)
                if let output = blurFilter.outputImage {
                    ciImage = output
                }
            }
        }

        // 4. Add noise/grain
        if preset.noiseIntensity > 0 {
            ciImage = addNoise(to: ciImage, intensity: preset.noiseIntensity)
        }

        // 5. Crop back to original size (rotation expands the image)
        let croppedExtent = CGRect(
            x: ciImage.extent.midX - originalExtent.width / 2,
            y: ciImage.extent.midY - originalExtent.height / 2,
            width: originalExtent.width,
            height: originalExtent.height
        )
        ciImage = ciImage.cropped(to: croppedExtent)

        // Render final image
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return cgImage
    }

    private func addNoise(to image: CIImage, intensity: Double) -> CIImage {
        // Create random noise
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator") else {
            return image
        }

        guard let noiseImage = noiseFilter.outputImage else {
            return image
        }

        // Scale and crop noise to match input image
        let noiseScaled = noiseImage.cropped(to: image.extent)

        // Convert noise to grayscale and adjust intensity
        guard let grayFilter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        // Create subtle gray noise
        let noiseLevel = Float(intensity)
        grayFilter.setValue(noiseScaled, forKey: kCIInputImageKey)
        grayFilter.setValue(CIVector(x: CGFloat(noiseLevel), y: 0, z: 0, w: 0), forKey: "inputRVector")
        grayFilter.setValue(CIVector(x: 0, y: CGFloat(noiseLevel), z: 0, w: 0), forKey: "inputGVector")
        grayFilter.setValue(CIVector(x: 0, y: 0, z: CGFloat(noiseLevel), w: 0), forKey: "inputBVector")
        grayFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputAVector")
        grayFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBiasVector")

        guard let grayNoise = grayFilter.outputImage else {
            return image
        }

        // Blend noise with original image
        guard let blendFilter = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }

        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(grayNoise, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage ?? image
    }
}

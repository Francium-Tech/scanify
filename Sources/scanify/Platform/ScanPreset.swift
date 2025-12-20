import Foundation

/// Configuration for scan effects - shared across platforms
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
    var applyWarp: Bool
    var applyDust: Bool

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

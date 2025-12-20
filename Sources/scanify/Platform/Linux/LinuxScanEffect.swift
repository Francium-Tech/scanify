#if os(Linux)
import Foundation

class LinuxScanEffect {

    func apply(inputPath: String, outputPath: String, preset: ScanPreset) throws {
        var args: [String] = [inputPath]

        // Paper darkening
        let whiteDarken = Int((1.0 - preset.paperDarkening) * 100)
        args += ["-level", "0%,\(whiteDarken)%"]

        // Color adjustments (brightness, contrast, saturation)
        let brightness = Int(preset.brightnessAdjustment * 100)
        let contrast = Int((preset.contrastAdjustment - 1.0) * 50)
        args += ["-brightness-contrast", "\(brightness)x\(contrast)"]
        let saturation = Int(preset.saturationAdjustment * 100)
        args += ["-modulate", "100,\(saturation),100"]

        // Blur
        if preset.blurRadius > 0 {
            args += ["-blur", "0x\(preset.blurRadius)"]
        }

        // Noise/grain
        if preset.noiseIntensity > 0 {
            let noiseAttenuate = max(0.3, 1.0 - preset.noiseIntensity * 10)
            args += ["-attenuate", String(format: "%.2f", noiseAttenuate)]
            args += ["+noise", "Gaussian"]
        }

        args += [outputPath]
        try runConvert(arguments: args)

        // Effects applied BEFORE rotation (so they rotate with the page)
        if preset.edgeShadow > 0 {
            try applyTopShadow(imagePath: outputPath, intensity: preset.edgeShadow)
        }

        if preset.applyWarp {
            try applyBendEffect(imagePath: outputPath, preset: preset)
        }

        // Rotation with gray background (simulates scanner bed at corners)
        let rotation = Double.random(in: preset.rotationRange)
        if abs(rotation) > 0.01 {
            try runConvert(arguments: [
                outputPath,
                "-background", "grey85",
                "-virtual-pixel", "background",
                "-distort", "SRT", String(format: "%.2f", rotation),
                outputPath
            ])
        }

        // Dust applied AFTER rotation (dust is on scanner glass, not paper)
        if preset.applyDust {
            try applyDustEffect(imagePath: outputPath, preset: preset)
        }
    }

    private func applyBendEffect(imagePath: String, preset: ScanPreset) throws {
        let dimensions = try getImageDimensions(imagePath: imagePath)
        let width = dimensions.width
        let height = dimensions.height

        let bandY = Int(Double(height) * Double.random(in: 0.35...0.65))
        let bandHeight = Int(Double(height) * Double.random(in: 0.25...0.4))
        let shadowIntensity = Int(Double.random(in: 8...15))
        let grayValue = 100 - shadowIntensity

        let tempGradient = FileManager.default.temporaryDirectory
            .appendingPathComponent("gradient-\(UUID().uuidString).png").path
        let tempOverlay = FileManager.default.temporaryDirectory
            .appendingPathComponent("overlay-\(UUID().uuidString).png").path

        defer {
            try? FileManager.default.removeItem(atPath: tempGradient)
            try? FileManager.default.removeItem(atPath: tempOverlay)
        }

        // Create gradient band
        try runConvert(arguments: [
            "-size", "\(width)x\(bandHeight)",
            "gradient:grey\(grayValue)-white",
            "-flip",
            tempGradient
        ])

        // Composite onto white canvas
        try runConvert(arguments: [
            "-size", "\(width)x\(height)",
            "xc:white",
            tempGradient,
            "-geometry", "+0+\(bandY - bandHeight/2)",
            "-composite",
            tempOverlay
        ])

        // Multiply blend with original
        try runConvert(arguments: [
            imagePath, tempOverlay,
            "-compose", "Multiply", "-composite",
            imagePath
        ])
    }

    private func applyTopShadow(imagePath: String, intensity: Double) throws {
        let dimensions = try getImageDimensions(imagePath: imagePath)
        let width = dimensions.width
        let height = dimensions.height

        let shadowHeight = Int(Double(height) * 0.15)
        let shadowIntensity = Int(intensity * 30)

        let tempGradient = FileManager.default.temporaryDirectory
            .appendingPathComponent("topshadow-\(UUID().uuidString).png").path
        let tempOverlay = FileManager.default.temporaryDirectory
            .appendingPathComponent("topoverlay-\(UUID().uuidString).png").path

        defer {
            try? FileManager.default.removeItem(atPath: tempGradient)
            try? FileManager.default.removeItem(atPath: tempOverlay)
        }

        try runConvert(arguments: [
            "-size", "\(width)x\(shadowHeight)",
            "gradient:grey\(100 - shadowIntensity)-white",
            tempGradient
        ])

        try runConvert(arguments: [
            "-size", "\(width)x\(height)",
            "xc:white",
            tempGradient,
            "-geometry", "+0+0",
            "-composite",
            tempOverlay
        ])

        try runConvert(arguments: [
            imagePath, tempOverlay,
            "-compose", "Multiply", "-composite",
            imagePath
        ])
    }

    private func applyDustEffect(imagePath: String, preset: ScanPreset) throws {
        let dimensions = try getImageDimensions(imagePath: imagePath)
        let width = dimensions.width
        let height = dimensions.height

        var drawCommands: [String] = []

        // Dust specks (small dots)
        let numSpecks = Int.random(in: 20...50)
        for _ in 0..<numSpecks {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            let size = Double.random(in: 0...1) < 0.9 ? Int.random(in: 1...2) : Int.random(in: 2...3)
            let gray = grayHex(darkness: Int.random(in: 20...50))
            drawCommands.append("fill '\(gray)' circle \(x),\(y) \(x+size),\(y)")
        }

        // Hair/fiber lines
        let numHairs = Int.random(in: 1...4)
        for _ in 0..<numHairs {
            let startX = Int.random(in: 0..<width)
            let startY = Int.random(in: 0..<height)
            let length = Int.random(in: 30...80)
            let angle = Double.random(in: 0...(Double.pi * 2))
            let endX = startX + Int(cos(angle) * Double(length))
            let endY = startY + Int(sin(angle) * Double(length))
            let gray = grayHex(darkness: Int.random(in: 25...45))
            drawCommands.append("stroke '\(gray)' stroke-width 1 stroke-linecap round line \(startX),\(startY) \(endX),\(endY)")
        }

        if !drawCommands.isEmpty {
            try runConvert(arguments: [
                imagePath,
                "-draw", drawCommands.joined(separator: " "),
                imagePath
            ])
        }
    }

    private func grayHex(darkness: Int) -> String {
        let hex = Int(Double(darkness) / 100.0 * 255.0)
        return String(format: "#%02x%02x%02x", hex, hex, hex)
    }

    private func getImageDimensions(imagePath: String) throws -> (width: Int, height: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["identify", "-format", "%w %h", imagePath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? "0 0"
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")

        guard parts.count >= 2, let width = Int(parts[0]), let height = Int(parts[1]) else {
            return (width: 1000, height: 1400)
        }
        return (width: width, height: height)
    }

    private func runConvert(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["convert"] + arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ProcessingError.commandFailed("convert failed: \(errorMessage)")
        }
    }
}
#endif

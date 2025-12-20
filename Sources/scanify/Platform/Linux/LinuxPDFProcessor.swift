#if os(Linux)
import Foundation

class LinuxPDFProcessor: PDFProcessorProtocol {
    private let scanEffect = LinuxScanEffect()
    private let renderDPI: Int = 150

    func process(input: URL, output: URL, preset: ScanPreset) throws {
        // Create temporary directory for processing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Get page count using pdfinfo
        let pageCount = try getPageCount(pdf: input)
        guard pageCount > 0 else {
            throw ProcessingError.emptyPDF
        }

        print("Pages: \(pageCount)")

        // Convert PDF to images using pdftoppm
        let imagePrefix = tempDir.appendingPathComponent("page").path
        try runCommand("pdftoppm", arguments: [
            "-png",
            "-r", String(renderDPI),
            input.path,
            imagePrefix
        ])

        // Process each page image
        var processedImages: [String] = []

        for pageIndex in 1...pageCount {
            // pdftoppm names files as prefix-01.png, prefix-02.png, etc.
            let pageNumStr = String(format: "%0\(pageCount > 99 ? 3 : (pageCount > 9 ? 2 : 1))d", pageIndex)
            let inputImage = "\(imagePrefix)-\(pageNumStr).png"
            let outputImage = tempDir.appendingPathComponent("processed-\(pageNumStr).png").path

            // Apply scan effects using ImageMagick
            try scanEffect.apply(inputPath: inputImage, outputPath: outputImage, preset: preset)

            processedImages.append(outputImage)

            let progress = Int((Double(pageIndex) / Double(pageCount)) * 100)
            print("\rProcessing: \(progress)%", terminator: "")
            fflush(stdout)
        }

        print("\rProcessing: 100%")

        // Combine processed images into PDF using ImageMagick
        // Use -background white to avoid dark borders
        var convertArgs = ["-background", "white", "-page", "letter"]
        convertArgs.append(contentsOf: processedImages)
        convertArgs.append(output.path)
        try runCommand("convert", arguments: convertArgs)
    }

    private func getPageCount(pdf: URL) throws -> Int {
        let result = try runCommandWithOutput("pdfinfo", arguments: [pdf.path])

        // Parse "Pages: N" from pdfinfo output
        let lines = result.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("Pages:") {
                let parts = line.split(separator: ":")
                if parts.count >= 2, let count = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return count
                }
            }
        }

        // Fallback: try to count converted images
        return 1
    }

    @discardableResult
    private func runCommand(_ command: String, arguments: [String]) throws -> Void {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ProcessingError.commandFailed("\(command) failed: \(errorMessage)")
        }
    }

    private func runCommandWithOutput(_ command: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ProcessingError.commandFailed("\(command) failed: \(errorMessage)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
#endif

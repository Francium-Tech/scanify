import ArgumentParser
import Foundation

@main
struct Scanify: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scanify",
        abstract: "Transform PDFs to look like scanned documents",
        version: "0.1.0"
    )

    @Flag(name: .long, help: "Apply aggressive scan effects (more noise, rotation, artifacts)")
    var aggressive: Bool = false

    @Argument(help: "Input PDF file path")
    var input: String

    @Argument(help: "Output PDF file path (optional, defaults to input_scanned.pdf)")
    var output: String?

    func run() throws {
        let inputURL = URL(fileURLWithPath: input)

        // Validate input file exists
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ValidationError("Input file does not exist: \(input)")
        }

        // Validate it's a PDF
        guard inputURL.pathExtension.lowercased() == "pdf" else {
            throw ValidationError("Input file must be a PDF")
        }

        // Determine output path
        let outputURL: URL
        if let output = output {
            outputURL = URL(fileURLWithPath: output)
        } else {
            let inputName = inputURL.deletingPathExtension().lastPathComponent
            let outputName = "\(inputName)_scanned.pdf"
            outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(outputName)
        }

        // Process the PDF
        let processor = PDFProcessor()
        let preset: ScanPreset = aggressive ? .aggressive : .default

        print("Processing: \(inputURL.lastPathComponent)")
        print("Preset: \(preset.name)")

        do {
            try processor.process(input: inputURL, output: outputURL, preset: preset)
            print("Output saved to: \(outputURL.path)")
        } catch {
            throw ValidationError("Failed to process PDF: \(error.localizedDescription)")
        }
    }
}

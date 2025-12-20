import Foundation

/// Errors that can occur during PDF processing
enum ProcessingError: LocalizedError {
    case failedToLoadPDF
    case emptyPDF
    case failedToSavePDF
    case renderingFailed
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .failedToLoadPDF:
            return "Failed to load the input PDF file"
        case .emptyPDF:
            return "The PDF file contains no pages"
        case .failedToSavePDF:
            return "Failed to save the output PDF file"
        case .renderingFailed:
            return "Failed to render PDF page"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        }
    }
}

/// Protocol for PDF processing - implemented differently per platform
protocol PDFProcessorProtocol {
    func process(input: URL, output: URL, preset: ScanPreset) throws
}

/// Factory to get the appropriate processor for the current platform
func createPDFProcessor() -> PDFProcessorProtocol {
    #if os(macOS)
    return DarwinPDFProcessor()
    #elseif os(Linux)
    return LinuxPDFProcessor()
    #else
    fatalError("Unsupported platform")
    #endif
}

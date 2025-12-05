import PDFKit
import CoreGraphics
import Foundation

class PDFProcessor {
    private let scanEffect = ScanEffect()
    private let renderDPI: CGFloat = 150.0  // Balance between quality and speed

    func process(input: URL, output: URL, preset: ScanPreset) throws {
        guard let document = PDFDocument(url: input) else {
            throw ProcessingError.failedToLoadPDF
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ProcessingError.emptyPDF
        }

        print("Pages: \(pageCount)")

        // Create new PDF document
        let outputDocument = PDFDocument()

        for pageIndex in 0..<pageCount {
            autoreleasepool {
                guard let page = document.page(at: pageIndex) else { return }

                // Convert page to image
                guard let pageImage = renderPageToImage(page: page) else { return }

                // Apply scan effects
                guard let scannedImage = scanEffect.apply(to: pageImage, preset: preset) else { return }

                // Convert back to PDF page
                if let pdfPage = createPDFPage(from: scannedImage, originalPage: page) {
                    outputDocument.insert(pdfPage, at: outputDocument.pageCount)
                }

                // Progress indicator
                let progress = Int((Double(pageIndex + 1) / Double(pageCount)) * 100)
                print("\rProcessing: \(progress)%", terminator: "")
                fflush(stdout)
            }
        }

        print("\rProcessing: 100%")

        // Save the output PDF
        guard outputDocument.write(to: output) else {
            throw ProcessingError.failedToSavePDF
        }
    }

    private func renderPageToImage(page: PDFPage) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = renderDPI / 72.0

        let width = Int(pageRect.width * scale)
        let height = Int(pageRect.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Scale and render the PDF page
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }

    private func createPDFPage(from image: CGImage, originalPage: PDFPage) -> PDFPage? {
        let originalRect = originalPage.bounds(for: .mediaBox)

        // Create NSImage from CGImage for PDFPage
        let nsImage = NSImageFromCGImage(image, size: originalRect.size)

        // Create PDF page from image
        guard let pdfPage = PDFPage(image: nsImage) else {
            return nil
        }

        return pdfPage
    }

    private func NSImageFromCGImage(_ cgImage: CGImage, size: CGSize) -> NSImage {
        return NSImage(cgImage: cgImage, size: size)
    }
}

enum ProcessingError: LocalizedError {
    case failedToLoadPDF
    case emptyPDF
    case failedToSavePDF
    case renderingFailed

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
        }
    }
}

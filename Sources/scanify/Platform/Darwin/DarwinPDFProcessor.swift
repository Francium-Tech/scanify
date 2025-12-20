#if os(macOS)
import PDFKit
import CoreGraphics
import Foundation
import AppKit

class DarwinPDFProcessor: PDFProcessorProtocol {
    private let scanEffect = DarwinScanEffect()
    private let renderDPI: CGFloat = 150.0

    func process(input: URL, output: URL, preset: ScanPreset) throws {
        guard let document = PDFDocument(url: input) else {
            throw ProcessingError.failedToLoadPDF
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ProcessingError.emptyPDF
        }

        print("Pages: \(pageCount)")

        let outputDocument = PDFDocument()

        for pageIndex in 0..<pageCount {
            autoreleasepool {
                guard let page = document.page(at: pageIndex) else { return }

                guard let pageImage = renderPageToImage(page: page) else { return }

                guard let scannedImage = scanEffect.apply(to: pageImage, preset: preset) else { return }

                if let pdfPage = createPDFPage(from: scannedImage, originalPage: page) {
                    outputDocument.insert(pdfPage, at: outputDocument.pageCount)
                }

                let progress = Int((Double(pageIndex + 1) / Double(pageCount)) * 100)
                print("\rProcessing: \(progress)%", terminator: "")
                fflush(stdout)
            }
        }

        print("\rProcessing: 100%")

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

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)

        return context.makeImage()
    }

    private func createPDFPage(from image: CGImage, originalPage: PDFPage) -> PDFPage? {
        let originalRect = originalPage.bounds(for: .mediaBox)
        let nsImage = NSImage(cgImage: image, size: originalRect.size)
        guard let pdfPage = PDFPage(image: nsImage) else {
            return nil
        }
        return pdfPage
    }
}
#endif

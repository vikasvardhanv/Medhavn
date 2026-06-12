import SwiftUI
import VisionKit
import Vision
import UIKit

struct ScannerSheetView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var scannedText: String

        static var canScanDocument: Bool {
    #if targetEnvironment(simulator)
        return false
    #else
        return VNDocumentCameraViewController.isSupported && UIImagePickerController.isSourceTypeAvailable(.camera)
    #endif
        }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: ScannerSheetView

        init(_ parent: ScannerSheetView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            Task {
                let text = await extractText(from: scan)
                await MainActor.run {
                    if !text.isEmpty {
                        parent.scannedText = text
                    }
                    parent.dismiss()
                }
            }
        }

        private func extractText(from scan: VNDocumentCameraScan) async -> String {
            var allText: [String] = []

            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                guard let cgImage = image.cgImage else { continue }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let text = request.results?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n") ?? ""
                    allText.append(text)
                } catch {
                    continue
                }
            }

            return allText.joined(separator: "\n\n")
        }
    }
}

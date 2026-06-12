import Foundation
import PDFKit
import UIKit

enum PDFExporter {
    static func adherenceSummary(plan: MedicationPlanRecord, logs: [DoseLogRecord]) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("adherence-summary-\(plan.id.uuidString).pdf")

        let format = UIGraphicsPDFRendererFormat()
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20)
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]

                var y: CGFloat = 24
                "Medhavn Adherence Summary".draw(at: CGPoint(x: 24, y: y), withAttributes: titleAttrs)
                y += 32

                "Created: \(Date().formatted(date: .abbreviated, time: .shortened))".draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttrs)
                y += 20
                "Plan source: \(plan.source.rawValue)".draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttrs)
                y += 20
                "Needs clinician confirmation: \(plan.needsConfirmation ? "Yes" : "No")".draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttrs)
                y += 28

                "Dose Logs".draw(at: CGPoint(x: 24, y: y), withAttributes: titleAttrs)
                y += 26

                if logs.isEmpty {
                    "No doses logged.".draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttrs)
                } else {
                    for log in logs.prefix(45) {
                        let line = "• \(log.timestamp.formatted(date: .abbreviated, time: .shortened))  \(String(format: "%.1f", log.dose)) \(log.units)\(log.isPRN ? " PRN" : "")"
                        line.draw(at: CGPoint(x: 24, y: y), withAttributes: bodyAttrs)
                        y += 16
                        if y > 790 {
                            ctx.beginPage()
                            y = 24
                        }
                    }
                }

                y += 24
                let disclaimer = "Educational planning support only. Not medical advice. Confirm unclear instructions with a pharmacist/clinician."
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .left
                let disclaimerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 11),
                    .paragraphStyle: paragraph
                ]
                disclaimer.draw(in: CGRect(x: 24, y: y, width: pageBounds.width - 48, height: 80), withAttributes: disclaimerAttrs)
            }
        } catch {
            return url
        }

        return url
    }
}

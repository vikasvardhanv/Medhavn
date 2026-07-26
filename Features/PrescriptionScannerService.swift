import SwiftUI
import Vision
import MedicationLogicEngine

public struct PrescriptionScannerService {
    public static func scanPrescriptionImage(_ image: UIImage) async -> ParsedMedicationPlan? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let fullText = lines.joined(separator: "\n")
                
                // Perform parsing on raw OCR text
                let parsedPlan = parseHeuristics(fullText: fullText)
                continuation.resume(returning: parsedPlan)
            }
            
            request.recognitionLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private static func parseHeuristics(fullText: String) -> ParsedMedicationPlan {
        var drugName: String? = nil
        var dose: Double? = 1.0
        var units: String? = "mg"
        var frequency: Frequency = .onceDaily
        
        let lowercased = fullText.lowercased()
        
        // Match common drugs
        let commonMeds = ["lisinopril", "metformin", "atorvastatin", "amlodipine", "metoprolol", "albuterol", "gabapentin", "sildenafil", "levothyroxine", "losartan"]
        for med in commonMeds {
            if lowercased.contains(med) {
                drugName = med.capitalized
                break
            }
        }
        
        // Heuristics for drug fallback if not found
        if drugName == nil {
            let words = fullText.components(separatedBy: CharacterSet.alphanumerics.inverted)
            for word in words {
                if word.count > 5 && word.first?.isUppercase == true && !word.lowercased().contains("take") && !word.lowercased().contains("daily") {
                    drugName = word
                    break
                }
            }
        }
        
        // Find Dosage (e.g. 50mg, 10 mg, 500 mg)
        if let regex = try? NSRegularExpression(pattern: "(\\d+(\\.\\d+)?)\\s*(mg|mcg|g|ml|tab|pills|capsule)", options: []) {
            let nsRange = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
            if let match = regex.firstMatch(in: lowercased, options: [], range: nsRange) {
                if let doseRange = Range(match.range(at: 1), in: lowercased),
                   let doseVal = Double(lowercased[doseRange]) {
                    dose = doseVal
                }
                if let unitRange = Range(match.range(at: 3), in: lowercased) {
                    units = String(lowercased[unitRange])
                }
            }
        }
        
        // Find Frequency
        if lowercased.contains("twice") || lowercased.contains("bid") || lowercased.contains("2 times") {
            frequency = .twiceDaily
        } else if lowercased.contains("three") || lowercased.contains("tid") || lowercased.contains("3 times") {
            frequency = .threeTimesDaily
        } else if lowercased.contains("four") || lowercased.contains("qid") || lowercased.contains("4 times") {
            frequency = .fourTimesDaily
        } else if lowercased.contains("needed") || lowercased.contains("prn") {
            frequency = .asNeeded
        }
        
        return ParsedMedicationPlan(
            sourceText: fullText,
            drugName: drugName ?? "Scanned Medication",
            dose: dose,
            units: units,
            frequency: frequency,
            durationDays: 30,
            ambiguityQuestions: drugName == nil ? ["Could not confidently identify the medication name. Please verify."] : []
        )
    }
}

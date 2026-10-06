import CoffeeKit
import Foundation
import FoundationModels
import SwiftUI
import UIKit
import Vision

@Generable
struct GeneratedBean {
    @Guide(description: "Coffee name, usually origin plus farm, region or blend name, e.g. 'Ethiopia Guji' or 'House Blend'.")
    var name: String?
    @Guide(description: "Roaster company name.")
    var roaster: String?
    @Guide(description: "Country and region of origin.")
    var origin: String?
    @Guide(description: "Processing method: Washed, Natural, Honey, Anaerobic or Other.")
    var process: String?
    @Guide(description: "Coffee variety or varietal, e.g. Heirloom, Bourbon, Gesha.")
    var varietal: String?
    @Guide(description: "Roast level: Light, Medium or Dark.")
    var roastLevel: String?
    @Guide(description: "Roast date in yyyy-MM-dd format, only if printed on the label.")
    var roastDate: String?
    @Guide(description: "Tasting notes printed on the bag, comma separated.")
    var notes: String?
}

/// Reads a photo of a coffee bag: Vision finds the text, the on-device model sorts it into fields.
enum BeanLabelReader {
    struct Found {
        var name: String?
        var roaster: String?
        var origin: String?
        var process: String?
        var varietal: String?
        var roastLevel: String?
        var roastDate: Date?
        var notes: String?
    }

    static func read(_ image: UIImage) async -> Found? {
        let lines = await recognizeText(image)
        guard !lines.isEmpty else { return nil }
        let text = lines.joined(separator: "\n")

        if BrewExtractor.isModelAvailable {
            do {
                let session = LanguageModelSession(instructions: "You read the text printed on a bag of coffee beans and pull out the details. Only use what the text says.")
                let g = try await session.respond(to: "Label text:\n\(text)", generating: GeneratedBean.self).content
                return Found(name: g.name, roaster: g.roaster, origin: g.origin,
                             process: g.process.map(normalize(process:)), varietal: g.varietal,
                             roastLevel: g.roastLevel.map { $0.capitalized }, roastDate: g.roastDate.flatMap { DateCodec.read($0) },
                             notes: g.notes)
            } catch {
                // Fall through to the simple version.
            }
        }
        // Without the model: the biggest line is usually the name; keep all text as notes.
        let lower = text.lowercased()
        let process = ["washed", "natural", "honey", "anaerobic"].first { lower.contains($0) }?.capitalized
        return Found(name: lines.first, process: process, notes: lines.dropFirst().joined(separator: ", "))
    }

    private static func normalize(process: String) -> String {
        let p = process.lowercased()
        for known in BeanRecord.processes where p.contains(known.lowercased()) { return known }
        return process.capitalized
    }

    /// Recognized lines, largest text first (titles before small print).
    private static func recognizeText(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                try? handler.perform([request])
                let observations = request.results ?? []
                let lines = observations
                    .sorted { $0.boundingBox.height > $1.boundingBox.height }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .filter { $0.count > 1 }
                continuation.resume(returning: lines)
            }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// The system camera, or the photo library on devices without one (the simulator).
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPick(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPick(nil)
        }
    }
}

import Foundation
import ImageIO
import UniformTypeIdentifiers
import SwiftUI

enum ExercisePhoto {
    static func image(from data: Data, maxPixels: Int = 1200) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Bound storage size, apply orientation, and omit the original photo's location/EXIF metadata.
    static func prepare(_ data: Data) throws -> Data {
        guard data.count <= 50_000_000, let image = image(from: data) else { throw ExerciseEditorError.invalidPhoto }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ExerciseEditorError.invalidPhoto
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ExerciseEditorError.invalidPhoto }
        return output as Data
    }
}

struct ExercisePhotoView: View {
    let data: Data
    let exerciseName: String
    var maximumHeight: CGFloat = 240
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(image, scale: 1, label: Text("Illustration for \(exerciseName)"))
                    .resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: maximumHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Label("Photo unavailable", systemImage: "photo").foregroundStyle(.secondary)
            }
        }.task(id: data) { image = ExercisePhoto.image(from: data) }
    }
}

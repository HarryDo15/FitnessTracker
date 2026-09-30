import SwiftUI

struct ProfileAvatarView: View {
    let data: Data?
    let symbolName: String
    var size: CGFloat = 96
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(image, scale: 1, label: Text("Profile photo"))
                    .resizable().scaledToFill()
            } else {
                Image(systemName: symbolName).resizable().scaledToFit()
                    .padding(size * 0.1).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary, in: Circle())
        .clipShape(Circle())
        .task(id: data) { image = data.flatMap { ExercisePhoto.image(from: $0, maxPixels: 512) } }
    }
}

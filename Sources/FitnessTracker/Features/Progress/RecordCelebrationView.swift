import SwiftUI

struct RecordCelebrationView: View {
    let message: String
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Personal record!", systemImage: "trophy.fill").font(.title3.bold()).foregroundStyle(.orange)
            Text(message).fixedSize(horizontal: false, vertical: true)
            Button("Nice!", action: dismiss).frame(minHeight: 44)
        }.frame(maxWidth: .infinity, alignment: .leading).padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
    }
}


import SwiftUI

struct NotesView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var noteContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Rich text editor with white background and rounded corners
            RichTextEditor(content: $noteContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

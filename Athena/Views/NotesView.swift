
import SwiftUI

struct NotesView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var noteContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Rich text editor (background and rounded corners handled at AppKit level)
            RichTextEditor(content: $noteContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

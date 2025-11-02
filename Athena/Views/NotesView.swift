
import SwiftUI

struct NotesView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Rich text editor (background and rounded corners handled at AppKit level)
            RichTextEditor(content: $appViewModel.noteContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

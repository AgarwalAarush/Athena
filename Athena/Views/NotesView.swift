
import SwiftUI

struct NotesView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        VStack {
            HStack {
                Button(action: { appViewModel.showChat() }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Go back to chat")
                Spacer()
            }
            .padding()
            
            Spacer()
            Text("Notes View (Placeholder)")
            Spacer()
        }
    }
}

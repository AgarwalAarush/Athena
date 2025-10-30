//
//  ContentView.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager
    @State private var selectedView: MainView = .chat

    enum MainView {
        case chat
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TitleBarView(selectedView: $selectedView)

            Divider()

            // Main Content Area
            Group {
                switch selectedView {
                case .chat:
                    ChatView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: windowManager.windowSize.width, height: windowManager.windowSize.height)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
    }
}

struct TitleBarView: View {
    @Binding var selectedView: ContentView.MainView

    var body: some View {
        HStack {
            Text("Athena")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { selectedView = .chat }) {
                    Image(systemName: "message")
                        .foregroundColor(selectedView == .chat ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Chat")

                Button(action: { selectedView = .settings }) {
                    Image(systemName: "gear")
                        .foregroundColor(selectedView == .settings ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
    }
}



#Preview {
    ContentView()
        .environmentObject(WindowManager())
}

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
                .opacity(0.5)

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
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
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
        .background(Color.clear)
    }
}



// Visual effect blur for transparent window background
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}

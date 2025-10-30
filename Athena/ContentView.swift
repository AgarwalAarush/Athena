//
//  ContentView.swift
//  Athena
//
//  Created by Aarush Agarwal on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        ZStack {
            // Define the rounded shell shape once
            let shell = RoundedRectangle(cornerRadius: 12, style: .continuous)

            // 1) Background shell with shadow (NOT clipped)
            shell
                .fill(Color.white.opacity(0.85))
                .overlay(
                    shell.stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

            // 2) Content clipped to the shell shape
            VStack(spacing: 0) {
                // Title Bar
                TitleBarView()

                Divider()
                    .opacity(0.5)

                // Main Content Area
                ChatView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(shell)
            .compositingGroup()
        }
        .frame(width: windowManager.windowSize.width, height: windowManager.windowSize.height)
    }
}

struct TitleBarView: View {
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "message")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Chat")

                Button(action: { windowManager.openSettingsWindow() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
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

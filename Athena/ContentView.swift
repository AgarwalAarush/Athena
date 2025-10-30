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
    @State private var showingSidebar = true
    
    enum MainView {
        case chat
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            TitleBarView(selectedView: $selectedView, showingSidebar: $showingSidebar)
            
            Divider()
            
            // Main Content Area
            Group {
                switch selectedView {
                case .chat:
                    if showingSidebar {
                        ConversationListView()
                    } else {
                        ChatView()
                    }
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: windowManager.windowSize.width, height: windowManager.windowSize.height)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TitleBarView: View {
    @Binding var selectedView: ContentView.MainView
    @Binding var showingSidebar: Bool
    
    var body: some View {
        HStack {
            // Sidebar Toggle (only show in chat view)
            if selectedView == .chat {
                Button(action: { showingSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                        .foregroundColor(showingSidebar ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar")
            }
            
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}



#Preview {
    ContentView()
        .environmentObject(WindowManager())
}

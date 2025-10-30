# Athena AI Assistant

A floating utility window macOS AI assistant with multi-provider support (OpenAI, Anthropic/Claude), built with SwiftUI and AppKit.

## Features

### Current (Phase 1 - MVP) ✅
- ✅ Floating utility window (470x640, always-on-top, no dock icon)
- ✅ SQLite database with GRDB for conversation persistence
- ✅ Multi-provider AI chat (OpenAI gpt-5-nano-2025-08-07, Anthropic claude-haiku-4-5-20251001)
- ✅ Clean SwiftUI chat interface with streaming responses
- ✅ Secure API key storage with Keychain
- ✅ Conversation management with sidebar, search, and organization
- ✅ Settings panel with provider configuration
- ✅ Model parameter configuration (temperature, max tokens)
- ✅ Python FastAPI backend service

### Phase 2 - Near-term
- 🚧 Ollama local model support
- 🚧 Markdown rendering in messages
- 🚧 Code syntax highlighting
- 🚧 Conversation export
- 🚧 Global keyboard shortcut

### Phase 3 - Future
- Voice AI integration (speech-to-text, text-to-speech)
- Computer use/automation features
- Apple Calendar and Google Calendar integration
- Tool calling framework

## Architecture

- **Frontend**: SwiftUI (70%) + AppKit (30%)
- **Backend**: Python FastAPI service for AI provider orchestration
- **Database**: SQLite with GRDB.swift
- **Configuration**: Centralized manager with Keychain security

## Setup Instructions

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- Python 3.10+ (for backend service)

### 1. Add GRDB Dependency

**In Xcode:**
1. Open `Athena.xcodeproj`
2. Select the project in the navigator
3. Select the `Athena` target
4. Go to "Package Dependencies" tab
5. Click the "+" button
6. Add: `https://github.com/groue/GRDB.swift.git`
7. Version: 6.0.0 or later
8. Click "Add Package"

### 2. Install Python Backend Dependencies

```bash
cd Backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure API Keys

On first launch, go to Settings and add your API keys:
- OpenAI API Key (for GPT models)
- Anthropic API Key (for Claude models)

Keys are stored securely in macOS Keychain.

### 4. Run the Application

**Development Mode:**
1. Start Python backend: `cd Backend && python main.py`
2. Run Athena from Xcode (⌘R)

**Production Mode:**
- Python service will be embedded in the .app bundle

## Project Structure

```
Athena/
├── Core/
│   ├── AthenaApp.swift          # App entry point
│   ├── AppDelegate.swift        # AppKit integration
│   └── WindowManager.swift      # Floating window management
├── Database/
│   ├── DatabaseManager.swift    # SQLite operations
│   └── Models/
│       ├── Conversation.swift
│       └── Message.swift
├── Configuration/               # Coming soon
├── Services/                    # Coming soon
├── ViewModels/                  # Coming soon
└── Views/                       # Coming soon

Backend/                         # Python AI Service
├── main.py                      # FastAPI server
├── providers/                   # AI provider implementations
└── requirements.txt
```

## Development Status

**Phase 1 MVP - COMPLETE** ✅

Completed features:
- [x] Project foundation and structure
- [x] Floating utility window with AppKit
- [x] Database layer with GRDB and migrations
- [x] Configuration management with Keychain
- [x] Python FastAPI service with OpenAI & Anthropic providers
- [x] Swift service layer with network client
- [x] Chat interface with streaming support
- [x] Conversation management with sidebar
- [x] Provider management UI in Settings
- [x] Model parameter configuration

Next priorities:
- [ ] Add Ollama provider support
- [ ] Implement markdown rendering
- [ ] Add global keyboard shortcuts
- [ ] Polish error messages and loading states

## Contributing

This is a personal project, but suggestions and feedback are welcome!

## License

TBD


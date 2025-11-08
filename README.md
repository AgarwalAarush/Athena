# Athena AI Assistant

## Core Capabilities

### Voice Processing & Wake Word Detection
- Custom Voice Activity Detection (VAD): Intelligent silence detection with configurable timeouts, preventing false triggers while maintaining responsiveness.
- Continuous Wake Word Recognition: Always-listening "Athena" detection using on-device speech recognition for privacy and low latency.
- Real-Time Speech-to-Text: Streaming transcription with partial results, supporting dictation-optimized speech recognition.
- Multi-Stage Speech Pipeline: Sophisticated audio processing pipeline with error recovery and state management.

### AI Integration & Tool Calling
- Multi-Provider Support: Seamless integration with Anthropic Claude and OpenAI GPT models.
- Advanced Tool Calling: Provider-specific adapters enabling AI agents to interact with your system through structured tool calls.
- Streaming Responses: Real-time response streaming with proper state management and error handling.
- Secure Authentication: Enterprise-grade API key management using macOS Keychain.

### System Automation Framework
- Comprehensive File Operations: Create, read, edit, delete, and list files with full permission handling.
- System Control Integration: Direct control over brightness, volume, and other system settings via AppleScript.
- Application Management: Open, close, activate, and monitor running applications programmatically.
- Accessibility Integration: Screen and window information access for intelligent automation.

### Window Management & Configuration
- Window Configuration Profiles: Save and restore complete window layouts with named configurations.
- Direct Window Control: Move, resize, tile, and focus windows with natural language commands.
- Multi-Monitor Support: Intelligently tracks which screen each window belongs to.
- Auto-Launch Apps: Automatically launches missing applications when restoring configurations.
- Smart Permission Handling: Automatic accessibility permission requests following iOS/macOS patterns.
- Voice-Controlled Window Tiling: "Move Chrome to the left", "Put Safari on the right half", etc.

### Calendar & Productivity
- Full Google Calendar Integration: Complete CRUD operations on calendar events with attendee management.
- Rich Calendar Visualization: Timeline-based day view with overlapping event handling and current time indicators.
- Event Search & Management: Advanced event querying with date range filtering and attendee tracking.

### Rich Text & Note Taking
- Custom NSTextView Integration: Full Cocoa text system with rich formatting capabilities.
- Checkbox List Support: Markdown-style task management with automatic formatting.
- Persistent Note Storage: SQLite-backed note management with conversation threading.

## Technical Stack

- **UI Framework**: SwiftUI with AppKit integration for native macOS features.
- **AI Backend**: Python with Flask, providing a REST API and WebSocket communication.
- **Speech Recognition**: OpenAI Whisper and Apple's Speech framework for real-time transcription and wake word detection.
- **AI Model Orchestration**: LangChain integration with Ollama for flexible AI model usage.
- **System Automation**: AppleScript for deep integration with macOS.
- **Data Persistence**: CoreData and SQLite with GRDB for local data storage.
- **Real-time Audio Visualization**: Waveform and spectrum analyzer for voice activity feedback.
- **Secure Storage**: macOS Keychain for securely storing sensitive data like API keys.
- **Networking**: Combine publishers for HTTP client and WebSocket for real-time communication.

## Planned Features

### Computer Use & Automation
- Visual Screen Understanding: AI agents that can see and understand your screen.
- Mouse & Keyboard Control: Programmatic interaction with any application.
- Workflow Automation: Complex multi-step task execution across applications.
- Smart Application Switching: Context-aware app management and window handling.

### Advanced AI Integration
- Local Model Support: Ollama integration for offline AI capabilities.
- Multi-Modal Processing: Image and document understanding.
- Custom Model Fine-Tuning: Specialized models for individual user workflows.

### Enhanced Productivity Features
- Meeting Intelligence: Real-time meeting transcription and summarization.
- Smart Scheduling: AI-powered calendar management and conflict resolution.
- Document Processing: Intelligent document analysis and information extraction.

### Expanded System Integration
- Spotify Control: Music playback and playlist management.
- Email Integration: Intelligent email processing and response generation.
- Browser Automation: Web interaction and information retrieval.
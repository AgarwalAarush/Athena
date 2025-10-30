# Jarvis UI Components & Features Documentation

## Overview
Jarvis is a sophisticated macOS AI assistant built with SwiftUI, featuring both text-based chat and hands-free voice interaction modes. The application combines a modern, animated interface with real-time AI processing capabilities.

## Core UI Architecture

### Main Application Structure
- **SwiftUI App**: Modern macOS application using SwiftUI lifecycle
- **NavigationView**: Split-view layout with collapsible sidebar
- **State Management**: Custom `JarvisStateManager` for global app state
- **CoreData Integration**: Persistent conversation and message storage

## UI Components Breakdown

### 1. ContentView (Main Container)
**Location**: `Views/ContentView.swift`
**Purpose**: Main application container managing navigation between modes

**Features**:
- Split-view navigation with collapsible sidebar
- Mode switching toolbar (Chat ↔ Voice)
- Settings access via toolbar and menu commands
- First-launch onboarding flow
- Keyboard shortcuts (⌘+, for settings, ⌘⇧V/C for mode switching)

**Technical Details**:
- Uses `NavigationView` with master-detail layout
- Environment objects for state management
- Sheet presentations for settings and onboarding
- NSSplitViewController integration for sidebar toggling

### 2. Sidebar Components

#### SidebarView (Main Sidebar)
**Location**: `Views/Components/SidebarView.swift`
**Purpose**: Navigation sidebar with conversation list

**Sub-components**:
- **Navigation Section**: Tab-based navigation (Chat, Voice, Search)
- **ChatListView**: Recent conversations with search functionality
- **CreateChatView**: New conversation creation modal

**Features**:
- Modern search bar with real-time filtering
- Conversation thumbnails with last message preview
- Floating "New Chat" button
- Context menus for conversation management (rename, export, delete)
- Hover effects and selection states

#### ChatRowView (Conversation Item)
**Features**:
- Message count badges
- Last message preview (truncated to 200 chars)
- Relative timestamps
- Selection highlighting with color transitions
- Smooth hover animations

### 3. Chat Interface Components

#### ChatView (Main Chat Interface)
**Location**: `Views/Chat/ChatView.swift`
**Purpose**: Text-based conversation interface

**Sub-components**:
- **ChatHeader**: Connection status, error indicators, conversation info
- **MessagesArea**: Scrollable message list with auto-scroll
- **MessageInputView**: Text input with send functionality

#### MessageBubbleView (Individual Messages)
**Location**: `Views/Chat/MessageBubbleView.swift`
**Features**:
- User vs Assistant message styling
- Markdown rendering support
- Code syntax highlighting
- Timestamps and message metadata
- Smooth animations for new messages

#### MessageInputView (Text Input)
**Location**: `Views/Chat/MessageInputView.swift`
**Features**:
- Modern rounded text field with line expansion (1-5 lines)
- Character counter
- Send button with state-based styling
- Loading indicators during processing
- Keyboard shortcuts (⌘+Return to send)
- Auto-focus management

### 4. Voice Interface Components

#### VoiceModeView (Voice Interaction)
**Location**: `Views/Voice/VoiceModeView.swift`
**Purpose**: Hands-free voice interaction interface

**Features**:
- Animated AI sphere visualization
- Real-time audio level monitoring
- Voice activity waveform display
- Microphone controls with state feedback
- Status text updates
- Permission handling for microphone access

#### AISphereView (Animated AI Sphere)
**Features**:
- Multi-layered radial gradient design
- Pulsing outer rings with varying delays
- Breathing inner sphere animation
- Real-time scaling based on audio activity
- Professional gradient colors (accent-based)

#### VoiceActivityView (Audio Visualization)
**Features**:
- 20-bar spectrum analyzer
- Real-time amplitude-based scaling
- Staggered animation delays for wave effect
- Adaptive scaling based on audio levels

#### MicrophoneView (Recording Controls)
**Features**:
- State-based icon switching (mic/stop)
- Scale animations during recording
- Color transitions (green → red)
- Haptic feedback simulation
- Permission-based availability

### 5. Settings Interface

#### SettingsView (Main Settings)
**Location**: `Views/Settings/SettingsView.swift`
**Purpose**: Comprehensive application configuration

**Sub-views**:
- **APISettingsView**: Backend API configuration
- **VoiceSettingsView**: Audio and TTS settings
- **GeneralSettingsView**: App preferences

#### API Settings Features
- Base URL configuration
- API key management (secure field)
- Timeout and retry settings
- Connection testing functionality
- SSL/TLS status indicators

#### Voice Settings Features
- TTS voice selection
- Microphone sensitivity slider
- Recording timeout configuration
- Sample rate selection (8kHz, 16kHz, 44.1kHz)
- Echo cancellation toggle

#### General Settings Features
- Theme selection
- Language preferences
- Notification toggles
- Auto-save interval configuration
- Chat history limits

### 6. Utility Components

#### LoadingIndicator (Loading States)
- Animated dot progression
- Multiple animation phases
- Used throughout app for async operations

#### ConnectionStatusView (Network Status)
- Color-coded status indicators (green/yellow/red)
- Real-time status text updates
- Connection state management

#### ModernTextField & ModernSearchField
- Custom styled text inputs
- Icon integration
- Clear button functionality
- Placeholder text support

## UI Patterns & Design System

### Color Scheme
- **Primary**: System accent color
- **Secondary**: Gray scale for inactive states
- **Success**: Green for connected states
- **Error**: Red for error states
- **Warning**: Orange for warnings

### Typography
- **Headers**: System font, .headline/.title2 weights
- **Body**: System font, .body/.caption weights
- **Code**: Monospaced font for code blocks

### Animations
- **Hover Effects**: 0.2s ease-in-out transitions
- **State Changes**: 0.3s spring animations
- **Loading**: Continuous animations with varying delays
- **Mode Switching**: Cross-dissolve transitions

### Layout Patterns
- **Spacing**: 12pt base grid system
- **Padding**: 16pt for containers, 12pt for elements
- **Corner Radius**: 8pt for cards, 4pt for small elements
- **Shadows**: Subtle shadows for depth

## User Experience Features

### Accessibility
- Keyboard navigation support
- Screen reader compatibility
- High contrast mode support
- Reduced motion preferences

### Performance
- Lazy loading for conversation lists
- Efficient CoreData queries
- Background thread processing
- Memory-efficient audio buffering

### Error Handling
- User-friendly error messages
- Retry mechanisms
- Graceful degradation
- Error state recovery

## Technical Implementation Notes

### State Management
- ObservableObject pattern for reactive UI
- Environment objects for dependency injection
- Published properties for automatic UI updates
- State persistence via UserDefaults

### Data Flow
- ViewModels handle business logic
- Services manage external communication
- CoreData for local persistence
- Real-time updates via WebSocket

### Platform Integration
- macOS-specific UI patterns
- AppKit bridging for advanced features
- System permission management
- Menu bar integration

This documentation covers the current UI implementation. The next sections will analyze architectural choices and recommend improvements for scaling.

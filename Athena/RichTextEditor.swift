//
//  RichTextEditor.swift
//  Rich text editor with checkbox list support for macOS
//

import SwiftUI
import AppKit

/// SwiftUI wrapper around NSTextView with rich text editing and checkbox support.
///
/// Bridges AppKit NSTextView to SwiftUI using the full Cocoa text system stack.
/// Supports markdown-style checkbox triggers ("- [ ] ") and maintains bidirectional
/// binding synchronization while preventing feedback loops.
@MainActor
struct RichTextEditor: NSViewRepresentable {

    @Binding var content: String

    init(content: Binding<String>) {
        self._content = content
    }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        // Create text system stack from scratch for full control over formatting
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Configure text container for flexible width
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        // Create and configure text view
        let textView = NSTextView(frame: .zero, textContainer: textContainer)

        // Enable rich text editing with modern macOS conventions
        textView.isEditable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true

        // Disable smart quotes/dashes for technical writing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.smartInsertDeleteEnabled = false

        // Enable spell checking
        textView.isContinuousSpellCheckingEnabled = true

        // Set comfortable padding around text
        textView.textContainerInset = NSSize(width: 10, height: 10)

        // Use system font with good readability
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        // Set default paragraph style with reasonable spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 8
        textView.defaultParagraphStyle = paragraphStyle

        // Wire up coordinator as delegate
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Accessibility support
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel("Rich Text Editor")
        textView.setAccessibilityRole(.textArea)

        // Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Initialize content
        if !content.isEmpty {
            textStorage.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: content
            )
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let textStorage = textView.textStorage else { return }

        let currentText = textStorage.string

        // Only update if content actually changed to avoid feedback loops
        guard currentText != content else { return }

        // Use programmatic change guard to prevent delegate from updating binding
        context.coordinator.isProgrammaticChange = true
        defer { context.coordinator.isProgrammaticChange = false }

        // Preserve selection across content update
        let selectedRange = textView.selectedRange()

        // Update text storage
        textStorage.replaceCharacters(
            in: NSRange(location: 0, length: textStorage.length),
            with: content
        )

        // Restore selection if still valid
        let newLength = textStorage.length
        if selectedRange.location <= newLength {
            let newRange = NSRange(
                location: min(selectedRange.location, newLength),
                length: 0
            )
            textView.setSelectedRange(newRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content)
    }

    // MARK: - Coordinator

    /// Coordinator handling NSTextView delegate callbacks and checkbox logic.
    ///
    /// Implements NSTextViewDelegate to handle text changes and checkbox behavior.
    /// Uses isProgrammaticChange guard to prevent binding feedback loops.
    /// Requires macOS 15+ for NSTextList.MarkerFormat.checkBox support.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {

        @Binding var content: String
        weak var textView: NSTextView?

        /// Guard flag preventing infinite loops when syncing content and textStorage.
        var isProgrammaticChange = false

        /// Markdown trigger for checkbox list items.
        private let checkboxTrigger = "- [ ] "

        init(content: Binding<String>) {
            self._content = content
        }

        // MARK: - Delegate Methods

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage,
                  !isProgrammaticChange else { return }

            // Update binding with current text
            content = textStorage.string

            // Check for checkbox trigger at paragraph start
            detectAndTransformCheckboxTrigger(in: textView)
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let replacementString = replacementString else { return true }

            // Handle Enter key in checkbox paragraphs
            if replacementString == "\n" {
                return handleEnterKeyInCheckboxParagraph(textView: textView, at: affectedCharRange)
            }

            return true
        }

        // MARK: - Checkbox Trigger Detection

        /// Detects "- [ ] " typed at paragraph start and transforms into checkbox list.
        ///
        /// Only triggers at paragraph start. Deletes trigger text after applying checkbox style.
        /// Groups operations into single undo action and preserves caret position.
        private func detectAndTransformCheckboxTrigger(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let selection = textView.selectedRange()
            guard selection.location > 0 && selection.location <= textStorage.length else { return }

            // Get current paragraph range
            let paragraphRange = currentParagraphRange(in: textView)
            guard paragraphRange.length > 0 else { return }

            // Extract paragraph text
            let paragraphText = (textStorage.string as NSString).substring(with: paragraphRange)

            // Check if paragraph starts with trigger at the very start
            guard paragraphText.hasPrefix(checkboxTrigger) else { return }

            // Ensure cursor is after the trigger
            let triggerRange = NSRange(location: paragraphRange.location, length: checkboxTrigger.count)
            guard selection.location == triggerRange.location + triggerRange.length else { return }

            // Apply transformation within undo group
            isProgrammaticChange = true
            defer { isProgrammaticChange = false }

            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }

            textStorage.beginEditing()

            // Delete trigger text
            textStorage.deleteCharacters(in: triggerRange)

            // Adjust paragraph range after deletion
            let adjustedParagraphRange = NSRange(
                location: paragraphRange.location,
                length: paragraphRange.length - checkboxTrigger.count
            )

            // Apply checkbox list style to paragraph
            applyCheckboxList(toParagraphRange: adjustedParagraphRange, in: textView)

            textStorage.endEditing()

            // Update selection (move back by trigger length)
            let newLocation = selection.location - checkboxTrigger.count
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))

            // Sync binding
            content = textStorage.string
        }

        // MARK: - Enter Key Handling

        /// Handles Enter key in checkbox paragraphs to propagate checkbox style.
        ///
        /// Returns false to prevent default behavior and manually inserts newline.
        /// Applies checkbox style to new paragraph and groups operations into undo action.
        private func handleEnterKeyInCheckboxParagraph(
            textView: NSTextView,
            at affectedCharRange: NSRange
        ) -> Bool {
            guard let textStorage = textView.textStorage else { return true }

            // Check if current paragraph has checkbox style
            guard paragraphHasCheckboxStyle(at: affectedCharRange.location) else {
                return true
            }

            // Manually insert newline with checkbox style
            isProgrammaticChange = true
            defer { isProgrammaticChange = false }

            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }

            textStorage.beginEditing()

            // Insert newline
            textStorage.replaceCharacters(in: affectedCharRange, with: "\n")

            // Apply checkbox style to new paragraph
            let newParagraphStart = affectedCharRange.location + 1
            if newParagraphStart <= textStorage.length {
                let newParagraphRange = (textStorage.string as NSString)
                    .paragraphRange(for: NSRange(location: newParagraphStart, length: 0))

                // Apply checkbox style to new paragraph
                applyCheckboxList(toParagraphRange: newParagraphRange, in: textView)
            }

            textStorage.endEditing()

            // Move cursor to start of new line
            textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))

            // Sync binding
            content = textStorage.string

            return false
        }

        // MARK: - Helper Methods

        /// Returns the paragraph range containing the current selection.
        private func currentParagraphRange(in textView: NSTextView) -> NSRange {
            guard let textStorage = textView.textStorage else { return NSRange() }

            let selection = textView.selectedRange()
            guard selection.location <= textStorage.length else { return NSRange() }

            return (textStorage.string as NSString).paragraphRange(for: selection)
        }

        /// Applies checkbox list formatting to the specified paragraph range.
        ///
        /// Creates NSTextList with checkBox marker format and applies via paragraph style.
        /// Uses mutable copy to avoid mutating shared default style objects.
        private func applyCheckboxList(toParagraphRange range: NSRange, in textView: NSTextView) {
            guard let textStorage = textView.textStorage,
                  range.location + range.length <= textStorage.length else { return }

            // Create checkbox text list
            let checkboxList = NSTextList(markerFormat: .checkBox, options: 0)

            // Get current paragraph style or create new one
            var paragraphStyle: NSMutableParagraphStyle
            if range.length > 0,
               let existingStyle = textStorage.attribute(
                .paragraphStyle,
                at: range.location,
                effectiveRange: nil
               ) as? NSParagraphStyle {
                paragraphStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
            } else {
                paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 2
                paragraphStyle.paragraphSpacing = 8
            }

            // Add checkbox list to paragraph style
            paragraphStyle.textLists = [checkboxList]

            // Apply to range
            textStorage.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: range
            )
        }

        /// Checks if the paragraph at the given location has checkbox style applied.
        private func paragraphHasCheckboxStyle(at location: Int) -> Bool {
            guard let textView = textView,
                  let textStorage = textView.textStorage,
                  textStorage.length > 0 else { return false }

            // Check at valid character position (adjust if at end of document)
            let checkLocation = min(location, textStorage.length - 1)

            // Get paragraph style at location
            guard let paragraphStyle = textStorage.attribute(
                .paragraphStyle,
                at: checkLocation,
                effectiveRange: nil
            ) as? NSParagraphStyle else { return false }

            // Check if any text list has checkbox marker format
            return paragraphStyle.textLists.contains { list in
                list.markerFormat == .checkBox
            }
        }
    }
}

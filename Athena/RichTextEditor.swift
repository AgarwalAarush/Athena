//
//  RichTextEditor.swift
//  Rich text editor with checkbox list support for macOS
//

import SwiftUI
import AppKit

/// SwiftUI wrapper around NSTextView with rich text editing and checkbox support.
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
        // Create text system stack
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Flexible width
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        // Text view
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true

        // Disable "smart" substitutions for technical writing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.isContinuousSpellCheckingEnabled = true

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)

        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        // ✅ Explicit text color
        textView.textColor = .black

        // Default paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 8
        textView.defaultParagraphStyle = paragraphStyle

        // Delegate wiring
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Accessibility
        textView.setAccessibilityElement(true)
        textView.setAccessibilityLabel("Rich Text Editor")
        textView.setAccessibilityRole(.textArea)

        // Scroll view wrapper
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // ✅ Rounded, translucent white background
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor

        // Initialize content
        if !content.isEmpty {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: content)
        }

        // First responder when attached
        DispatchQueue.main.async { [weak textView] in
            textView?.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let textStorage = textView.textStorage else { return }

        let currentText = textStorage.string
        guard currentText != content else { return }

        context.coordinator.isProgrammaticChange = true
        defer { context.coordinator.isProgrammaticChange = false }

        let selectedRange = textView.selectedRange()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: content)

        let newLength = textStorage.length
        if selectedRange.location <= newLength {
            let newRange = NSRange(location: min(selectedRange.location, newLength), length: 0)
            textView.setSelectedRange(newRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content)
    }

    // MARK: - Coordinator

    /// NSTextViewDelegate + checkbox logic.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {

        @Binding var content: String
        weak var textView: NSTextView?
        var isProgrammaticChange = false

        private let checkboxTrigger = "- [ ] "

        init(content: Binding<String>) {
            self._content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage,
                  !isProgrammaticChange else { return }

            content = textStorage.string
            detectAndTransformCheckboxTrigger(in: textView)
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let replacementString = replacementString else { return true }
            if replacementString == "\n" {
                return handleEnterKeyInCheckboxParagraph(textView: textView, at: affectedCharRange)
            }
            return true
        }

        // MARK: - Trigger detection

        private func detectAndTransformCheckboxTrigger(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let selection = textView.selectedRange()
            guard selection.location > 0 && selection.location <= textStorage.length else { return }

            let paragraphRange = currentParagraphRange(in: textView)
            guard paragraphRange.length >= 0 else { return }

            let paragraphText = (textStorage.string as NSString).substring(with: paragraphRange)
            let leadingWhitespaceCount = paragraphText.prefix { $0 == " " || $0 == "\t" }.count
            let triggerStart = paragraphRange.location + leadingWhitespaceCount

            guard paragraphText.dropFirst(leadingWhitespaceCount).hasPrefix(checkboxTrigger) else { return }
            let triggerRange = NSRange(location: triggerStart, length: checkboxTrigger.count)

            // Cursor must be just after the trigger
            guard selection.location == NSMaxRange(triggerRange) else { return }

            isProgrammaticChange = true
            defer { isProgrammaticChange = false }

            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }

            textStorage.beginEditing()

            // Delete the typed trigger
            textStorage.deleteCharacters(in: triggerRange)

            // Get the paragraph range after deletion
            let caretLocation = triggerRange.location
            
            // Find the paragraph that contains the caret
            var effectiveRange: NSRange
            if textStorage.length > 0 {
                let currentString = textStorage.string as NSString
                let checkLocation = min(max(caretLocation, 0), textStorage.length - 1)
                effectiveRange = currentString.paragraphRange(for: NSRange(location: checkLocation, length: 0))
                
                // Check if paragraph is effectively empty (only whitespace/newline after trigger deletion)
                let paragraphContent = currentString.substring(with: effectiveRange)
                let trimmed = paragraphContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // If paragraph has no real content, ensure it has at least a space for the marker to attach to
                if trimmed.isEmpty {
                    // Insert a space at the caret location
                    textStorage.replaceCharacters(in: NSRange(location: caretLocation, length: 0), with: " ")
                    // Recalculate paragraph range after insertion
                    let updatedString = textStorage.string as NSString
                    effectiveRange = updatedString.paragraphRange(for: NSRange(location: caretLocation, length: 0))
                }
            } else {
                // Empty document - insert space + newline to create a paragraph with content
                textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: " \n")
                effectiveRange = NSRange(location: 0, length: 2)
            }

            // Apply checkbox style to this paragraph
            applyCheckboxList(toParagraphRange: effectiveRange, in: textView)

            textStorage.endEditing()

            // Place caret where the trigger started
            let finalCaretLocation = min(caretLocation, textStorage.length)
            textView.setSelectedRange(NSRange(location: finalCaretLocation, length: 0))

            content = textStorage.string
        }

        // MARK: - Enter handler

        private func handleEnterKeyInCheckboxParagraph(
            textView: NSTextView,
            at affectedCharRange: NSRange
        ) -> Bool {
            guard let textStorage = textView.textStorage else { return true }

            guard paragraphHasCheckboxStyle(at: affectedCharRange.location) else {
                return true
            }

            isProgrammaticChange = true
            defer { isProgrammaticChange = false }

            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }

            textStorage.beginEditing()

            // Insert newline
            textStorage.replaceCharacters(in: affectedCharRange, with: "\n")

            let newParagraphStart = affectedCharRange.location + 1
            if newParagraphStart <= textStorage.length {
                let newParagraphRange = (textStorage.string as NSString)
                    .paragraphRange(for: NSRange(location: newParagraphStart, length: 0))

                applyCheckboxList(toParagraphRange: newParagraphRange, in: textView)
            }

            textStorage.endEditing()

            textView.setSelectedRange(NSRange(location: newParagraphStart, length: 0))
            content = textStorage.string
            return false
        }

        // MARK: - Helpers

        private func currentParagraphRange(in textView: NSTextView) -> NSRange {
            guard let textStorage = textView.textStorage else { return NSRange() }
            let selection = textView.selectedRange()
            guard selection.location <= textStorage.length else { return NSRange() }
            return (textStorage.string as NSString).paragraphRange(for: selection)
        }

        /// Apply checkbox paragraph style with robust empty-paragraph handling.
        private func applyCheckboxList(toParagraphRange range: NSRange, in textView: NSTextView) {
            guard let textStorage = textView.textStorage,
                  NSMaxRange(range) <= textStorage.length else { return }

            let checkboxList = makeCheckboxList()
            let paragraphRange = (textStorage.string as NSString).paragraphRange(for: range)
            
            // Build the paragraph style
            let paragraphStyle: NSMutableParagraphStyle
            if textStorage.length > 0 && paragraphRange.location < textStorage.length {
                let attributeLocation = max(min(paragraphRange.location, textStorage.length - 1), 0)
                if let existing = textStorage.attribute(.paragraphStyle,
                                                        at: attributeLocation,
                                                        effectiveRange: nil) as? NSParagraphStyle {
                    paragraphStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineSpacing = 2
                    paragraphStyle.paragraphSpacing = 8
                }
            } else {
                paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 2
                paragraphStyle.paragraphSpacing = 8
            }

            paragraphStyle.textLists = [checkboxList]

            // ✅ Separate indents to avoid marker/text overlap
            let markerIndent: CGFloat = 8
            let textIndent: CGFloat = 28

            paragraphStyle.firstLineHeadIndent = markerIndent
            paragraphStyle.headIndent = textIndent

            // Ensure a tab stop at the text indent
            var stops = paragraphStyle.tabStops ?? []
            stops.removeAll { abs($0.location - textIndent) < 0.5 }
            stops.append(NSTextTab(textAlignment: .left, location: textIndent, options: [:]))
            stops.sort { $0.location < $1.location }
            paragraphStyle.tabStops = stops

            // Always apply to storage for markers to render properly
            if paragraphRange.length > 0 {
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            }
            
            // Also set typing attributes so new text inherits the style
            var attrs = textView.typingAttributes
            attrs[.paragraphStyle] = paragraphStyle
            attrs[.foregroundColor] = NSColor.black
            textView.typingAttributes = attrs
        }

        /// Determine if current paragraph (or typing attributes) have checkbox style.
        private func paragraphHasCheckboxStyle(at location: Int) -> Bool {
            guard let textView = textView else { return false }
            guard let textStorage = textView.textStorage else {
                if let ps = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                    return ps.textLists.contains(where: { isCheckboxList($0) })
                }
                return false
            }

            if textStorage.length == 0 || location >= textStorage.length {
                if let ps = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                    return ps.textLists.contains(where: { isCheckboxList($0) })
                }
                return false
            }

            let checkLocation = min(max(location, 0), textStorage.length - 1)
            if let ps = textStorage.attribute(.paragraphStyle, at: checkLocation, effectiveRange: nil) as? NSParagraphStyle {
                return ps.textLists.contains(where: { isCheckboxList($0) })
            }
            return false
        }

        private func makeCheckboxList() -> NSTextList {
            if #available(macOS 15.0, *) {
                return NSTextList(markerFormat: .check, options: 0)
            } else {
                return LegacyCheckboxTextList()
            }
        }

        private func isCheckboxList(_ list: NSTextList) -> Bool {
            if #available(macOS 15.0, *) {
                return list.markerFormat == .check
            } else {
                return list is LegacyCheckboxTextList
            }
        }

        /// Legacy fallback list rendering "[ ]\t" (tab aligns to headIndent).
        private final class LegacyCheckboxTextList: NSTextList {
            convenience init() {
                self.init(markerFormat: .square, options: 0)
            }
            override func marker(forItemNumber itemNumber: Int) -> String { "[ ]\t" }
        }
    }
}

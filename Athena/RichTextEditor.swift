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

        // ✅ Rounded, translucent white background - use NSScrollView's native backgroundColor
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.white.withAlphaComponent(0.6)
        
        // For rounded corners, use layer
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.masksToBounds = true
        
        // Ensure the text view remains transparent
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        // Force the enclosing scroll view clip view to be transparent
        scrollView.contentView.drawsBackground = false

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
        
        // MARK: - Range Safety Helper
        
        /// Validates and returns a safe range within textStorage bounds, or nil if invalid
        private func safeRange(location: Int, length: Int, in textStorage: NSTextStorage) -> NSRange? {
            let maxLocation = textStorage.length
            guard location >= 0 && location <= maxLocation else { return nil }
            
            let safeLength = min(length, maxLocation - location)
            guard safeLength >= 0 else { return nil }
            
            return NSRange(location: location, length: safeLength)
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

            // Get the paragraph range after deletion - SAFE APPROACH
            let caretLocation = triggerRange.location
            
            // Ensure we have content to work with
            if textStorage.length == 0 {
                textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: " ")
            }
            
            // Get paragraph range safely
            let safeLocation = min(caretLocation, textStorage.length)
            let effectiveRange = (textStorage.string as NSString).paragraphRange(
                for: NSRange(location: safeLocation, length: 0)
            )

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
                // Use safe range helper to validate before accessing
                guard let searchRange = safeRange(location: newParagraphStart, length: 0, in: textStorage) else {
                    textStorage.endEditing()
                    return false
                }
                let newParagraphRange = (textStorage.string as NSString).paragraphRange(for: searchRange)

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
            
            // Build the paragraph style - SAFER APPROACH
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 2
            paragraphStyle.paragraphSpacing = 8
            
            // Only try to preserve existing style if we have valid content
            if textStorage.length > 0 && paragraphRange.location < textStorage.length {
                let safeLocation = min(paragraphRange.location, textStorage.length - 1)
                if let existing = textStorage.attribute(.paragraphStyle,
                                                       at: safeLocation,
                                                       effectiveRange: nil) as? NSParagraphStyle,
                   existing.textLists.isEmpty { // Only copy if not already a list
                    paragraphStyle.lineSpacing = existing.lineSpacing
                    paragraphStyle.paragraphSpacing = existing.paragraphSpacing
                }
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

            // Always apply to storage for markers to render properly - WITH VALIDATION
            // Validate range before applying
            let validRange = NSRange(
                location: min(paragraphRange.location, textStorage.length),
                length: min(paragraphRange.length, textStorage.length - paragraphRange.location)
            )
            
            if validRange.length > 0 && NSMaxRange(validRange) <= textStorage.length {
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: validRange)
            }
            
            // Defer typing attributes update to avoid range conflicts
            DispatchQueue.main.async { [weak textView] in
                guard let textView = textView else { return }
                var attrs = textView.typingAttributes
                attrs[.paragraphStyle] = paragraphStyle
                attrs[.foregroundColor] = NSColor.black
                textView.typingAttributes = attrs
            }
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

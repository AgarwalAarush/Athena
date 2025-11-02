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

    func makeNSView(context: Context) -> NSView {
        // Container that provides the rounded translucent background
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        
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
        textView.textColor = .black
        
        // Make text view transparent
        textView.drawsBackground = false
        textView.backgroundColor = .clear

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

        // Scroll view wrapper - fully transparent
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        // Put scroll view inside the container and pin
        container.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Initialize content
        if !content.isEmpty {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: content)
        }

        // First responder when attached
        DispatchQueue.main.async { [weak textView] in
            textView?.window?.makeFirstResponder(textView)
        }

        return container
    }

    func updateNSView(_ containerView: NSView, context: Context) {
        // Find the scroll view inside the container
        guard let scrollView = containerView.subviews.first as? NSScrollView,
              let textView = scrollView.documentView as? NSTextView,
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
            let paragraphRange = currentParagraphRange(in: textView)
            
            // Check trigger "- [ ] " after leading whitespace
            let paragraphText = (textStorage.string as NSString).substring(with: paragraphRange)
            let wsCount = paragraphText.prefix { $0 == " " || $0 == "\t" }.count
            let triggerStart = paragraphRange.location + wsCount
            let triggerRange = NSRange(location: triggerStart, length: checkboxTrigger.count)
            
            guard paragraphText.dropFirst(wsCount).hasPrefix(checkboxTrigger),
                  selection.location == NSMaxRange(triggerRange) else { return }
            
            isProgrammaticChange = true
            defer { isProgrammaticChange = false }
            
            textView.undoManager?.beginUndoGrouping()
            defer { textView.undoManager?.endUndoGrouping() }
            
            textStorage.beginEditing()
            textStorage.deleteCharacters(in: triggerRange)
            
            // Recompute paragraph (since content changed)
            var para = (textStorage.string as NSString).paragraphRange(for: NSRange(location: triggerStart, length: 0))
            
            // Ensure a TAB at the actual paragraph START
            let paraString = (textStorage.string as NSString).substring(with: para)
            if !paraString.hasPrefix("\t") {
                textStorage.replaceCharacters(in: NSRange(location: para.location, length: 0), with: "\t")
                para = (textStorage.string as NSString).paragraphRange(for: NSRange(location: para.location, length: 0))
            }
            
            // Apply list style
            applyCheckboxList(toParagraphRange: para, in: textView)
            
            textStorage.endEditing()
            
            // Place caret after the tab (start of text column)
            let caret = min(para.location + 1, textStorage.length)
            textView.setSelectedRange(NSRange(location: caret, length: 0))
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
                let newParagraphRange = (textStorage.string as NSString).paragraphRange(
                    for: NSRange(location: newParagraphStart, length: 0)
                )

                applyCheckboxList(toParagraphRange: newParagraphRange, in: textView)
                
                // Place caret after the tab that applyCheckboxList inserted
                let caret = min(newParagraphRange.location + 1, textStorage.length)
                textStorage.endEditing()
                textView.setSelectedRange(NSRange(location: caret, length: 0))
            } else {
                textStorage.endEditing()
                textView.setSelectedRange(NSRange(location: newParagraphStart, length: 0))
            }

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

        /// Apply checkbox paragraph style with hanging indent and proper tab handling.
        private func applyCheckboxList(toParagraphRange range: NSRange, in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            
            // Recompute the full paragraph
            var para = (textStorage.string as NSString).paragraphRange(for: range)
            
            // Ensure a leading tab AT PARAGRAPH START (not caret)
            let paraString = (textStorage.string as NSString).substring(with: para)
            if !paraString.hasPrefix("\t") {
                textStorage.replaceCharacters(in: NSRange(location: para.location, length: 0), with: "\t")
                // update range after insertion
                para = (textStorage.string as NSString).paragraphRange(for: NSRange(location: para.location, length: 0))
            }
            
            // Build paragraph style: hanging indent; marker drawn before the tab at headIndent
            let head: CGFloat = 28 // text column start
            let ps = NSMutableParagraphStyle()
            ps.lineSpacing = 2
            ps.paragraphSpacing = 8
            ps.firstLineHeadIndent = head
            ps.headIndent = head
            
            // Ensure a tab stop exactly at head indent
            var tabs = ps.tabStops ?? []
            tabs.removeAll { abs($0.location - head) < 0.5 }
            tabs.append(NSTextTab(textAlignment: .left, location: head, options: [:]))
            tabs.sort { $0.location < $1.location }
            ps.tabStops = tabs
            
            // Attach a checkbox list (macOS 15+), else fallback
            let list: NSTextList
            if #available(macOS 15.0, *) {
                list = NSTextList(markerFormat: .check, options: 0)
            } else {
                list = LegacyCheckboxTextList()
            }
            ps.textLists = [list]
            
            // Apply style to the whole paragraph
            textStorage.addAttribute(.paragraphStyle, value: ps, range: para)
            
            // Keep typing attributes in sync
            DispatchQueue.main.async { [weak textView] in
                guard let tv = textView else { return }
                var attrs = tv.typingAttributes
                attrs[.paragraphStyle] = ps
                attrs[.foregroundColor] = NSColor.black
                tv.typingAttributes = attrs
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

        /// Legacy fallback list rendering with Unicode checkbox character.
        private final class LegacyCheckboxTextList: NSTextList {
            convenience init() {
                // Use disc format as base, we'll override the marker anyway
                self.init(markerFormat: .disc, options: 0)
                self.startingItemNumber = 1
            }
            
            override func marker(forItemNumber itemNumber: Int) -> String { 
                "☐" // Use the actual checkbox Unicode character
            }
        }
    }
}

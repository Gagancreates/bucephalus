import SwiftUI
import UIKit

/// Free-form notes for a meeting. Markdown turns into formatting as you type; the symbols are hidden.
struct NotesView: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownEditor(text: $text, minHeight: 220)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Write anything you want to remember about this meeting…")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
                .card()
            Text(verbatim: "# heading   - bullet   1. list   **bold**   *italic*")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

/// A text view that formats its Markdown on every keystroke and continues lists on return.
private struct MarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.tintColor = UIColor(Theme.accent)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        textView.inputAccessoryView = DoneBar(target: context.coordinator, action: #selector(Coordinator.done))
        context.coordinator.textView = textView

        textView.text = text
        MarkdownStyler.apply(to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.text = $text
        if textView.text != text {
            textView.text = text
            MarkdownStyler.apply(to: textView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, minHeight))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        weak var textView: UITextView?

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func done() {
            textView?.resignFirstResponder()
        }

        func textViewDidChange(_ textView: UITextView) {
            MarkdownStyler.apply(to: textView)
            text.wrappedValue = textView.text
            textView.invalidateIntrinsicContentSize()
        }

        // Return on a list item starts the next one (numbers count up); on an empty item it ends the list.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            let string = textView.text as NSString
            // Backspacing into a heading's hidden "# " removes the whole marker, turning the line back into text.
            if replacement.isEmpty, range.length == 1,
               let hidden = MarkdownStyler.headingMarker(in: string, containing: range.location) {
                replace(hidden, with: "", in: textView)
                return false
            }
            guard replacement == "\n", range.length == 0 else { return true }
            let lineStart = string.lineRange(for: NSRange(location: range.location, length: 0)).location
            let beforeCursor = string.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            guard let marker = MarkdownStyler.listMarker(in: beforeCursor) else { return true }

            if beforeCursor == marker.current {
                replace(NSRange(location: lineStart, length: range.location - lineStart), with: "", in: textView)
            } else {
                replace(range, with: "\n" + marker.next, in: textView)
            }
            return false
        }

        private func replace(_ range: NSRange, with string: String, in textView: UITextView) {
            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end) else { return }
            textView.replace(textRange, withText: string)
            textViewDidChange(textView)
        }
    }
}

/// A floating glass "Done" button that rides above the keyboard, clear of the screen's corners.
private final class DoneBar: UIView {
    init(target: Any, action: Selector) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        autoresizingMask = .flexibleHeight
        backgroundColor = .clear

        var configuration = UIButton.Configuration.glass()
        configuration.title = "Done"
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 18, bottom: 9, trailing: 18)
        let button = UIButton(configuration: configuration)
        button.addTarget(target, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Lets the bar grow to include the bottom safe area when there is no on-screen keyboard.
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }
}

private enum MarkdownStyler {
    private static let heading = try! NSRegularExpression(pattern: #"^(#{1,3}) "#)
    private static let bullet = try! NSRegularExpression(pattern: #"^(\s*)([-*•]) "#)
    private static let number = try! NSRegularExpression(pattern: #"^(\s*)(\d+)[.)] "#)
    private static let bold = try! NSRegularExpression(pattern: #"\*\*(?=\S)(.+?)(?<=\S)\*\*"#)
    private static let italic = try! NSRegularExpression(pattern: #"(?<![\*\w])\*(?=[^\s\*])(.+?)(?<=[^\s\*])\*(?!\*)"#)

    /// The range of the hidden "# " marker on the line holding `location`, if `location` falls inside it.
    static func headingMarker(in string: NSString, containing location: Int) -> NSRange? {
        let line = string.lineRange(for: NSRange(location: location, length: 0))
        guard let match = heading.firstMatch(in: string as String, range: line),
              NSLocationInRange(location, match.range) else { return nil }
        return match.range
    }

    /// The list marker a line starts with, and the marker the next line should get.
    static func listMarker(in line: String) -> (current: String, next: String)? {
        let string = line as NSString
        let range = NSRange(location: 0, length: string.length)
        if let match = bullet.firstMatch(in: line, range: range) {
            let marker = string.substring(with: match.range)
                .replacingOccurrences(of: "-", with: "•").replacingOccurrences(of: "*", with: "•")
            return (marker, marker)
        }
        if let match = number.firstMatch(in: line, range: range),
           let value = Int(string.substring(with: match.range(at: 2))) {
            let marker = string.substring(with: match.range)
            let indent = string.substring(with: match.range(at: 1))
            let separator = marker.contains(")") ? ")" : "."
            return (marker, "\(indent)\(value + 1)\(separator) ")
        }
        return nil
    }

    static func apply(to textView: UITextView) {
        // Leave text alone mid-composition (e.g. while an input method is building a character).
        guard textView.markedTextRange == nil else { return }
        let storage = textView.textStorage
        let string = storage.string as NSString
        let full = NSRange(location: 0, length: string.length)

        let body = UIFont.preferredFont(forTextStyle: .callout)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let base: [NSAttributedString.Key: Any] = [
            .font: body, .foregroundColor: UIColor.label, .paragraphStyle: paragraph,
        ]
        let accent = UIColor(Theme.accent)
        // Syntax characters stay in the text but take up no space and draw nothing.
        let hidden: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 0.1), .foregroundColor: UIColor.clear,
        ]

        storage.beginEditing()
        storage.setAttributes(base, range: full)
        string.enumerateSubstrings(in: full, options: [.byLines, .substringNotRequired]) { _, line, _, _ in
            if let match = heading.firstMatch(in: storage.string, range: line) {
                storage.addAttribute(.font, value: headingFont(level: match.range(at: 1).length), range: line)
                storage.addAttributes(hidden, range: match.range)
            } else if let match = bullet.firstMatch(in: storage.string, range: line)
                        ?? number.firstMatch(in: storage.string, range: line) {
                // A typed "-" or "*" becomes a real bullet. Same length, so the cursor doesn't move.
                if match.range(at: 2).length == 1, storage.string[match.range(at: 2)] != "•",
                   Int(storage.string[match.range(at: 2)]) == nil {
                    storage.replaceCharacters(in: match.range(at: 2), with: "•")
                }
                let marker = NSRange(location: match.range(at: 2).location,
                                     length: NSMaxRange(match.range) - 1 - match.range(at: 2).location)
                storage.addAttributes([
                    .foregroundColor: accent,
                    .font: UIFont.systemFont(ofSize: body.pointSize, weight: .bold),
                ], range: marker)
                // Wrapped lines of a list item line up with its text, not its marker.
                let indented = paragraph.mutableCopy() as! NSMutableParagraphStyle
                indented.headIndent = storage.attributedSubstring(from: match.range).size().width
                indented.firstLineHeadIndent = 0
                storage.addAttribute(.paragraphStyle, value: indented, range: line)
            }
            for match in bold.matches(in: storage.string, range: line) {
                addTrait(.traitBold, to: storage, range: match.range)
                storage.addAttributes(hidden, range: NSRange(location: match.range.location, length: 2))
                storage.addAttributes(hidden, range: NSRange(location: NSMaxRange(match.range) - 2, length: 2))
            }
            for match in italic.matches(in: storage.string, range: line) {
                addTrait(.traitItalic, to: storage, range: match.range)
                storage.addAttributes(hidden, range: NSRange(location: match.range.location, length: 1))
                storage.addAttributes(hidden, range: NSRange(location: NSMaxRange(match.range) - 1, length: 1))
            }
        }
        storage.endEditing()
        // Keeps a heading's size from carrying over to the line typed after it.
        textView.typingAttributes = base
    }

    private static func headingFont(level: Int) -> UIFont {
        switch level {
        case 1: .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize, weight: .semibold)
        case 2: .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .headline).pointSize, weight: .semibold)
        default: .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        }
    }

    private static func addTrait(_ trait: UIFontDescriptor.SymbolicTraits, to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? UIFont,
                  let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(trait))
            else { return }
            storage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: subrange)
        }
    }
}

private extension String {
    subscript(range: NSRange) -> String { (self as NSString).substring(with: range) }
}

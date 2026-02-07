import SwiftUI
import SafariLikeCoreKit
#if canImport(SafariLikeUXKit)
import SafariLikeUXKit
typealias CaretBlinkPolicy = MicroInteractionConfig.CaretBlinkPolicy
#else
enum CaretBlinkPolicy: Equatable {
    case system
    case hidden
}
#endif
#if canImport(UIKit)
import UIKit
typealias KeyboardType = UIKeyboardType
typealias ReturnKeyType = UIReturnKeyType
#else
enum KeyboardType: Equatable { case URL }
enum ReturnKeyType: Equatable { case go }
#endif
/// Text field with deterministic selection/cursor behavior when UIKit is available.
///
/// Falls back to a plain SwiftUI `TextField` on platforms without UIKit.
struct SelectableTextField: View {
    enum FocusBehavior: Equatable {
        /// Select all text upon focus.
        case selectAll
        /// Place cursor at end upon focus.
        case cursorAtEnd
    }
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    var caretBlinkPolicy: CaretBlinkPolicy = .system
    var focusBehavior: FocusBehavior = .selectAll
    var selectionAnimationDuration: Double = 0.12
    var keyboardType: KeyboardType = .URL
    var submitLabel: ReturnKeyType = .go
    var onSubmit: (() -> Void)?
    var onFocusChanged: ((Bool) -> Void)?
    var onTextChanged: ((String) -> Void)?
    var body: some View {
        #if canImport(UIKit)
        _UIKitSelectableTextField(
            placeholder: placeholder,
            text: $text,
            isFocused: $isFocused,
            caretBlinkPolicy: caretBlinkPolicy,
            focusBehavior: focusBehavior,
            selectionAnimationDuration: selectionAnimationDuration,
            keyboardType: keyboardType,
            submitLabel: submitLabel,
            onSubmit: onSubmit,
            onFocusChanged: onFocusChanged,
            onTextChanged: onTextChanged
        )
        #else
        TextField(placeholder, text: $text)
            .onSubmit { onSubmit?() }
            .onChange(of: text) { _, newValue in onTextChanged?(newValue) }
        #endif
    }
}
#if canImport(UIKit)
private struct _UIKitSelectableTextField: UIViewRepresentable {
    typealias FocusBehavior = SelectableTextField.FocusBehavior
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    var caretBlinkPolicy: CaretBlinkPolicy
    var focusBehavior: FocusBehavior
    var selectionAnimationDuration: Double
    var keyboardType: UIKeyboardType
    var submitLabel: UIReturnKeyType
    var onSubmit: (() -> Void)?
    var onFocusChanged: ((Bool) -> Void)?
    var onTextChanged: ((String) -> Void)?
    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.font = UIFont.preferredFont(forTextStyle: .body)
        tf.adjustsFontForContentSizeCategory = true
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.clearButtonMode = .never
        tf.placeholder = placeholder
        tf.keyboardType = keyboardType
        tf.returnKeyType = submitLabel
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        context.coordinator.applyCaretPolicy(tf, caretBlinkPolicy: caretBlinkPolicy)
        return tf
    }
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.applyCaretPolicy(uiView, caretBlinkPolicy: caretBlinkPolicy)
        if isFocused {
            if uiView.window != nil, uiView.isFirstResponder == false {
                uiView.becomeFirstResponder()
                context.coordinator.applyFocusBehavior(uiView, behavior: focusBehavior, animatedDuration: selectionAnimationDuration)
            }
        } else {
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: _UIKitSelectableTextField
        private var lastCaretPolicy: CaretBlinkPolicy?
        @MainActor
        private func deferStateMutation(_ block: @escaping @MainActor () -> Void) {
            Task { @MainActor in
                await Task.yield()
                block()
            }
        }
        init(parent: _UIKitSelectableTextField) {
            self.parent = parent
        }
        func applyCaretPolicy(_ textField: UITextField, caretBlinkPolicy: CaretBlinkPolicy) {
            guard lastCaretPolicy != caretBlinkPolicy else { return }
            lastCaretPolicy = caretBlinkPolicy
            switch caretBlinkPolicy {
            case .system:
                textField.tintColor = nil
            case .hidden:
                textField.tintColor = .clear
            @unknown default:
                textField.tintColor = nil
            }
        }
        func applyFocusBehavior(_ textField: UITextField, behavior: FocusBehavior, animatedDuration: Double) {
            guard let textRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument) else { return }
            switch behavior {
            case .selectAll:
                Task { @MainActor in
                    await Task.yield()
                    textField.selectedTextRange = textRange
                }
            case .cursorAtEnd:
                Task { @MainActor in
                    await Task.yield()
                    textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
                }
            }
        }
        @objc func textDidChange(_ sender: UITextField) {
            let newText = sender.text ?? ""
            deferStateMutation { [parent] in
                if parent.text != newText {
                    parent.text = newText
                    parent.onTextChanged?(newText)
                }
            }
        }
        func textFieldDidBeginEditing(_ textField: UITextField) {
            deferStateMutation { [parent] in
                if parent.isFocused == false {
                    parent.isFocused = true
                }
                parent.onFocusChanged?(true)
            }
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            deferStateMutation { [parent] in
                if parent.isFocused == true {
                    parent.isFocused = false
                }
                parent.onFocusChanged?(false)
            }
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            deferStateMutation { [parent] in
                parent.onSubmit?()
            }
            return true
        }
    }
}
#endif

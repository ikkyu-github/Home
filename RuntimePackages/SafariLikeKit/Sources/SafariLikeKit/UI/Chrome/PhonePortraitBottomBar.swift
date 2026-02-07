import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
/// Shared Safari-like phone portrait bottom bar.
///
/// Visual layout is intentionally kept identical to `StartPageFloatingURLBar`.
internal struct PhonePortraitBottomBar: View {
	@Binding var text: String
	@Binding var isEditing: Bool
	var onToggleSidebar: () -> Void
	var onToggleRelated: () -> Void
	var onPresentTabOverview: () -> Void
	var onNewTab: () -> Void
	var onBack: () -> Void
	var onForward: () -> Void
	var onReload: () -> Void
	var onSubmitURL: (String) -> Void
	var onAddBookmark: () -> Void
	var onShare: () -> Void
	@Namespace private var animationNamespace
	@FocusState private var isFocused: Bool
	@Environment(\.uxPolicy) private var uxPolicy
	var body: some View {
		ZStack(alignment: .center) {
			if isEditing {
				expandedBar
					.transition(.opacity)
			} else {
				compactBar
					.transition(.opacity)
			}
		}
		.onChange(of: isEditing) { newValue in
			guard isFocused != newValue else { return }
			isFocused = newValue
		}
		.animation(.easeInOut(duration: 0.25), value: isEditing)
	}
}

extension PhonePortraitBottomBar {
	/// Layout metrics used by other layers (e.g. overlays) to reserve space for the
	/// bottom chrome. Keep in sync with the paddings used in `compactBar`/`expandedBar`.
	enum LayoutMetrics {
		/// Approximate rendered height of the compact bar (excluding safe-area padding).
		/// 17pt icon + (8pt * 2) button padding + (6pt * 2) row padding = 45pt.
		static let compactHeight: CGFloat = 45
		/// Conservative height for the expanded editing bar (excluding safe-area padding).
		/// Slightly over-reserving is preferred to prevent tap interception.
		static let expandedHeight: CGFloat = 56
	}
}
extension PhonePortraitBottomBar {
	private var compactBar: some View {
		HStack(spacing: 10) {
			Button(action: onToggleSidebar) {
				Image(systemName: "sidebar.left")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Sidebar")
			.buttonStyle(.plain)
			.allowsHitTesting(true)
			.contentShape(Rectangle())
			.zIndex(10)
			.foregroundStyle(.primary.opacity(0.9))
			Button(action: onBack) {
				Image(systemName: "chevron.left")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Back")
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.9))
			Button(action: onForward) {
				Image(systemName: "chevron.right")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Forward")
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.9))
			compactURLField
				.matchedGeometryEffect(id: "urlField", in: animationNamespace)
			Button(action: onToggleRelated) {
				Image(systemName: "square.stack.3d.up")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Related")
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.9))
			Button(action: onReload) {
				Image(systemName: "arrow.clockwise")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Reload")
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.9))
			Menu {
				Button(uxPolicy.strings.newTabTitle, action: onNewTab)
					.accessibilityIdentifier("SafariLike.Menu.NewTab")
				if uxPolicy.tabOverview.isEnabled {
					Button(uxPolicy.strings.tabOverviewTitle, action: onPresentTabOverview)
						.accessibilityIdentifier("SafariLike.Menu.TabOverview")
				}
				Divider()
				Button("Add Bookmark", action: onAddBookmark)
					.accessibilityIdentifier("SafariLike.Menu.AddBookmark")
				Button("Share", action: onShare)
					.accessibilityIdentifier("SafariLike.Menu.Share")
			} label: {
				Image(systemName: "ellipsis")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.accessibilityIdentifier("SafariLike.BottomBar.Menu")
			.foregroundStyle(.primary.opacity(0.9))
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(.ultraThinMaterial, in: Capsule(style: .continuous))
		.padding(.horizontal, 16)
	}
	private var expandedBar: some View {
		HStack(spacing: 12) {
			expandedURLField
				.matchedGeometryEffect(id: "urlField", in: animationNamespace)
				.frame(maxWidth: .infinity)
			Button(action: onToggleRelated) {
				Image(systemName: "square.stack.3d.up")
					.imageScale(.medium)
					.font(.system(size: 17, weight: .semibold))
					.padding(8)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.9))
			Button("Cancel") {
				isEditing = false
			}
			.buttonStyle(.plain)
			.foregroundStyle(.primary.opacity(0.95))
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.background(
			.ultraThinMaterial,
			in: RoundedRectangle(cornerRadius: 18, style: .continuous)
		)
		.padding(.horizontal, 16)
	}
	private var compactURLField: some View {
		urlField
			.contentShape(Rectangle())
			.simultaneousGesture(
				TapGesture().onEnded {
					isEditing = true
				}
			)
	}
	private var expandedURLField: some View {
		urlField
	}
	private var urlField: some View {
		TextField(
			uxPolicy.strings.addressPlaceholder,
			text: $text,
			onEditingChanged: { didBeginEditing in
				if didBeginEditing {
					isEditing = true
				}
			}
		)
		.accessibilityIdentifier("SafariLike.BottomBar.AddressField")
		.accessibilityLabel(uxPolicy.strings.addressPlaceholder)
		.textInputAutocapitalization(.never)
		.autocorrectionDisabled(true)
		.keyboardType(.URL)
		.submitLabel(.go)
		.focused($isFocused)
		.onSubmit {
			onSubmitURL(text)
			isEditing = false
		}
		.foregroundStyle(.primary)
		.tint(.primary)
		.lineLimit(1)
	}
}

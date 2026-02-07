import Foundation
import SafariLikeContracts
import SafariLikeUXKit

/// Adapter surface so Views/ViewModels can consume Address Bar state via a single, UI-safe contract.
///
/// This is scaffolding only: it does not change behavior; it maps existing UXKit state + events into
/// `SafariLikeContracts.AddressBarViewState` / `SafariLikeContracts.AddressBarEvent`.
@MainActor
protocol AddressBarStateProviding: ObservableObject {
    var addressBarViewState: AddressBarViewState { get }
    func send(_ event: AddressBarEvent)
}

@MainActor
extension SplitBrowserAddressBarDomain: AddressBarStateProviding {
    var addressBarViewState: AddressBarViewState {
        AddressBarViewState(
            mode: addressBarState.contractMode,
            textFieldText: addressBarState.textFieldText,
            isTextInputFocused: addressBarState.isTextInputFocused,
            security: addressBarState.contractSecurity,
            loadingProgress: addressBarState.progress,
            isSecurityInfoPresented: addressBarState.isSecurityInfoPresented,
            shouldShowClearButton: addressBarState.shouldShowClearButton
        )
    }
}

private extension AddressBarUIState {
    var contractMode: AddressBarViewState.Mode {
        switch self {
        case .idle: return .idle
        case .focused: return .focused
        case .editing: return .editing
        case .loading: return .loading
        case .securityInfoDisplayed: return .securityInfo
        @unknown default:
            return .idle // fallback: safe default
        }
    }

    var contractSecurity: AddressBarViewState.SecurityIndicator {
        switch self {
        case .idle(_, let s), .loading(_, _, let s), .securityInfoDisplayed(_, let s):
            return s.asContract
        case .focused, .editing:
            // While editing, the UI shows a search glyph (not a security indicator).
            return .unknown
        @unknown default:
            return .unknown // fallback: safe default
        }
    }
}

private extension AddressBarUIState.Security {
    var asContract: AddressBarViewState.SecurityIndicator {
        switch self {
        case .secure: return .secure
        case .insecure: return .insecure
        case .unknown: return .unknown
        @unknown default:
            return .unknown // fallback: safe default
        }
    }
}

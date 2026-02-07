import Foundation
import SafariLikeContracts
import WebKit

public enum NavigationErrorMapper {
    public static func makeFailureRecord(
        url: URL?,
        isMainFrame: Bool,
        phase: NavigationFailurePhase,
        error: Error
    ) -> NavigationFailureRecord {
        let nsError = error as NSError

        let category = classify(error: nsError)
        let scheme = url?.scheme
        let host = url?.host

        let message = Self.redactedMessage(for: nsError)

        return NavigationFailureRecord(
            phase: phase,
            isMainFrame: isMainFrame,
            urlScheme: scheme,
            urlHost: host,
            category: category,
            errorDomain: nsError.domain,
            errorCode: nsError.code,
            message: message
        )
    }

    private static func classify(error: NSError) -> NavigationFailureCategory {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorCancelled:
                return .cancelled
            case NSURLErrorNotConnectedToInternet:
                return .offline
            case NSURLErrorTimedOut:
                return .timedOut
            case NSURLErrorCannotFindHost:
                return .dns
            case NSURLErrorDNSLookupFailed:
                return .dns
            case NSURLErrorCannotConnectToHost:
                return .cannotConnect
            case NSURLErrorSecureConnectionFailed:
                return .tls
            case NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid,
                 NSURLErrorClientCertificateRejected,
                 NSURLErrorClientCertificateRequired:
                return .tls
            case NSURLErrorHTTPTooManyRedirects,
                 NSURLErrorBadServerResponse:
                return .http
            default:
                return .unknown
            }
        }

        if error.domain == WKError.errorDomain {
            if #available(iOS 14.0, *) {
                if error.code == WKError.Code.webContentProcessTerminated.rawValue {
                    return .webContentProcessTerminated
                }
            }
        }

        return .unknown
    }

    private static func redactedMessage(for error: NSError) -> String? {
        // Keep this intentionally short and avoid embedding URLs.
        // `localizedDescription` typically includes only generic strings but can include hostnames.
        // Hostnames are already captured separately.
        let desc = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return desc.isEmpty ? nil : desc
    }
}

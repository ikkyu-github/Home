import CoreGraphics

#if canImport(UIKit)
import UIKit

public enum DeviceLayout {

    public static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// A recommended max content width for large displays.
    /// - iPad: 720
    /// - iPhone: nil (no max width)
    public static var contentMaxWidth: CGFloat? {
        isPad ? 720 : nil
    }

    /// A recommended horizontal padding for large displays.
    /// - iPad: 24
    /// - iPhone: 0
    public static var horizontalPadding: CGFloat {
        isPad ? 24 : 0
    }
}
#else
public enum DeviceLayout {
    public static var isPad: Bool { false }
    public static var contentMaxWidth: CGFloat? { nil }
    public static var horizontalPadding: CGFloat { 0 }
}
#endif

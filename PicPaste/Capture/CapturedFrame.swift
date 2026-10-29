import CoreGraphics
import Foundation

/// Immutable geometry for one captured display. The desktop frame is in
/// AppKit global logical points; image size is in display-local source pixels.
struct DisplayGeometry: Equatable {
    let displayID: CGDirectDisplayID
    let desktopFramePoints: CGRect
    let imageWidthPixels: Int
    let imageHeightPixels: Int
}

struct CapturedFrame {
    let geometry: DisplayGeometry
    let image: CGImage
}

enum CaptureFailure: Error, Equatable, LocalizedError {
    case permissionDenied
    case noDisplayUnderPointer
    case displayDisconnected
    case cannotExcludeOwnWindows
    case timedOut
    case cancelled
    case system(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有屏幕录制权限。请在系统设置 → 隐私与安全性 → 屏幕与系统音频录制中允许 PicPaste，必要时重启应用。"
        case .noDisplayUnderPointer:
            return "无法定位鼠标所在显示器，请移动鼠标后重试。"
        case .displayDisconnected:
            return "目标显示器已断开或屏幕布局已变化，请重新截图。"
        case .cannotExcludeOwnWindows:
            return "无法安全排除 PicPaste 的窗口，已取消本次截图以避免污染图像。"
        case .timedOut:
            return "屏幕捕获超时，请重试。"
        case .cancelled:
            return "截图已取消。"
        case .system(let message):
            return "屏幕捕获失败：\(message)"
        }
    }
}

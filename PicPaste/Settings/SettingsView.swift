import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PicPaste").font(.title.bold())
            Text("macOS 27 · Apple Silicon · 原生截图工具")
            Text("默认截图快捷键：\(AppSettings.captureHotkeyDescription)")
            Text("已接入单帧屏幕捕获；原生截图选区将在 P0-05 实现。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 380, minHeight: 180)
    }
}

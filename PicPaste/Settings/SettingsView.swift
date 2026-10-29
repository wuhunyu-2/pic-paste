import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PicPaste").font(.title.bold())
            Text("macOS 27 · Apple Silicon · 原生截图工具")
            Text("当前为 P0-01 工程启动基线，截图功能尚未实现。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 380, minHeight: 180)
    }
}

import AppKit
import SwiftUI
import Translation
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class TranslationWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    var onClose: (() -> Void)?
    init(text: String) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(); window.title = "截图翻译 · macOS 本机翻译"; window.isReleasedWhenClosed = false; window.delegate = self
        window.minSize = NSSize(width: 600, height: 450); window.center()
        if #available(macOS 15.0, *) { window.contentViewController = NSHostingController(rootView: TranslationContent(input: text)) }
        else {
            let field = NSTextField(wrappingLabelWithString: "截图文字已经识别。翻译功能需要 macOS 15 或更新版本。\n\n" + text)
            field.frame = NSRect(x: 24, y: 24, width: 730, height: 560); window.contentView?.addSubview(field)
        }
    }
    func show() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    func windowWillClose(_ notification: Notification) { onClose?() }
}

@available(macOS 15.0, *)
private struct TranslationContent: View {
    @State var input: String
    @State private var source = "auto"
    @State private var target = "zh-Hans"
    @State private var output = ""
    @State private var status = "选择目标语言后点击翻译。首次使用可能需要下载系统语言包。"
    @State private var configuration: TranslationSession.Configuration?
    @State private var working = false
    @State private var snapshot = ""
    @State private var generation = UUID()
    private let languages = [("zh-Hans", "简体中文"), ("zh-Hant", "繁体中文"), ("en", "英语"), ("ja", "日语"), ("ko", "韩语"), ("fr", "法语"), ("de", "德语"), ("es", "西班牙语"), ("it", "意大利语"), ("pt", "葡萄牙语"), ("ru", "俄语")]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("原文", selection: $source) {
                    Text("自动识别").tag("auto")
                    ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                }.frame(maxWidth: 245).disabled(working)
                Image(systemName: "arrow.right")
                Picker("译为", selection: $target) { ForEach(languages, id: \.0) { Text($0.1).tag($0.0) } }.frame(maxWidth: 245).disabled(working)
                Spacer()
                Button(working ? "取消" : "开始翻译") { working ? cancel() : begin() }.keyboardShortcut(.return, modifiers: .command)
            }
            Text("原文 · 可修改或粘贴其他文字").font(.headline)
            TextEditor(text: $input).font(.system(size: 15)).border(Color.secondary.opacity(0.3)).disabled(working).accessibilityLabel("翻译原文")
            HStack { Text("译文").font(.headline); Spacer(); Button("复制译文") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string) }.disabled(output.isEmpty) }
            TextEditor(text: .constant(output)).font(.system(size: 15)).border(Color.secondary.opacity(0.3)).accessibilityLabel("翻译结果")
            HStack { if working { ProgressView().controlSize(.small) }; Text(status).font(.caption).foregroundStyle(.secondary) }
            Text("使用 Apple Translation 本机语言模型。截图不会上传到第三方翻译网站。").font(.caption2).foregroundStyle(.secondary)
        }.padding(20)
        .translationTask(configuration) { @MainActor session in
            let run = generation, text = snapshot
            do {
                // Auto-detection needs real source text; preparing a nil-source session cannot identify a language.
                if session.sourceLanguage != nil { try await session.prepareTranslation() }
                try Task.checkCancellation()
                let chunks = TranslationChunks.split(text)
                var translated: [String] = []
                for (index, chunk) in chunks.enumerated() {
                    try Task.checkCancellation()
                    let response = try await session.translate(chunk)
                    guard run == generation else { return }
                    translated.append(response.targetText); status = "正在翻译 \(index + 1)/\(chunks.count)…"
                }
                guard run == generation else { return }
                output = translated.joined(separator: "\n"); status = "翻译完成，可选择或复制译文。"; working = false
            } catch {
                guard run == generation else { return }
                if ProcessInfo.processInfo.arguments.contains("--translation-demo") { NSLog("Translation diagnostic: %@", String(reflecting: error)) }
                status = error is CancellationError ? "已取消，可重新翻译。" : "翻译未完成：\(error.localizedDescription)。可尝试指定原文语言，并检查系统语言包下载。"
                working = false
            }
        }
        .onDisappear { cancel() }
    }
    private func begin() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = "请先输入需要翻译的文字。"; return }
        if source != "auto" && source == target { output = text; status = "原文与目标语言相同。"; return }
        snapshot = text; output = ""; generation = UUID(); working = true; status = "正在准备本机翻译，首次使用请按系统提示下载语言包…"
        let config = TranslationSession.Configuration(source: source == "auto" ? nil : Locale.Language(identifier: source), target: Locale.Language(identifier: target))
        if configuration?.source == config.source && configuration?.target == config.target { configuration?.invalidate() } else { configuration = config }
    }
    private func cancel() { generation = UUID(); configuration = nil; working = false; status = "已取消，可重新翻译。" }
}

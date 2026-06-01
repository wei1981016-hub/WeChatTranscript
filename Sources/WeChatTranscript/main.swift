import AppKit
import AVFoundation
import Foundation
import ScreenCaptureKit
import Speech

final class WeChatTranscriptApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let recorder = SystemAudioRecorder()
    private let outputDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents")
        .appendingPathComponent("WeChatTranscript")

    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var statusItemText: NSMenuItem!
    private var window: NSWindow!
    private var windowStatusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("applicationDidFinishLaunching")
        NSApplication.shared.setActivationPolicy(.regular)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        configureMenu()
        configureWindow()
        showControlWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showControlWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return true
    }

    private func configureMenu() {
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.and.mic", accessibilityDescription: "微信视频文稿")
        statusItem.button?.toolTip = "微信视频文稿整理"

        let menu = NSMenu()
        statusItemText = NSMenuItem(title: "空闲", action: nil, keyEquivalent: "")
        startItem = NSMenuItem(title: "开始录制", action: #selector(startRecording), keyEquivalent: "r")
        stopItem = NSMenuItem(title: "停止并转写", action: #selector(stopRecording), keyEquivalent: "s")
        let showWindowItem = NSMenuItem(title: "显示控制窗口", action: #selector(showControlWindow), keyEquivalent: "w")
        let openFolderItem = NSMenuItem(title: "打开输出文件夹", action: #selector(openOutputFolder), keyEquivalent: "o")
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")

        startItem.target = self
        stopItem.target = self
        showWindowItem.target = self
        openFolderItem.target = self
        quitItem.target = self
        stopItem.isEnabled = false

        menu.addItem(statusItemText)
        menu.addItem(.separator())
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        menu.addItem(showWindowItem)
        menu.addItem(openFolderItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configureWindow() {
        log("configureWindow")
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 190))

        let titleLabel = NSTextField(labelWithString: "微信视频文稿")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.frame = NSRect(x: 24, y: 140, width: 260, height: 28)

        windowStatusLabel = NSTextField(labelWithString: "空闲")
        windowStatusLabel.font = .systemFont(ofSize: 13)
        windowStatusLabel.textColor = .secondaryLabelColor
        windowStatusLabel.frame = NSRect(x: 24, y: 112, width: 360, height: 22)

        startButton = NSButton(title: "开始录制", target: self, action: #selector(startRecording))
        startButton.bezelStyle = .rounded
        startButton.frame = NSRect(x: 24, y: 58, width: 112, height: 34)

        stopButton = NSButton(title: "停止并转写", target: self, action: #selector(stopRecording))
        stopButton.bezelStyle = .rounded
        stopButton.frame = NSRect(x: 148, y: 58, width: 120, height: 34)
        stopButton.isEnabled = false

        let folderButton = NSButton(title: "打开输出文件夹", target: self, action: #selector(openOutputFolder))
        folderButton.bezelStyle = .rounded
        folderButton.frame = NSRect(x: 280, y: 58, width: 116, height: 34)

        let hintLabel = NSTextField(labelWithString: "播放电脑微信视频时保持本窗口或菜单栏 App 运行即可。")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.frame = NSRect(x: 24, y: 22, width: 360, height: 18)

        contentView.addSubview(titleLabel)
        contentView.addSubview(windowStatusLabel)
        contentView.addSubview(startButton)
        contentView.addSubview(stopButton)
        contentView.addSubview(folderButton)
        contentView.addSubview(hintLabel)

        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "微信视频文稿"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        placeWindowOnMainScreen()
    }

    @objc private func showControlWindow() {
        log("showControlWindow")
        if window == nil {
            configureWindow()
        }
        placeWindowOnMainScreen()
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        log("window visible=\(window.isVisible) frame=\(window.frame)")
    }

    private func placeWindowOnMainScreen() {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }
        let frame = screen.visibleFrame
        let windowSize = NSSize(width: 420, height: 190)
        let origin = NSPoint(
            x: frame.midX - windowSize.width / 2,
            y: frame.maxY - windowSize.height - 80
        )
        window.setFrame(NSRect(origin: origin, size: windowSize), display: true)
    }

    @objc private func startRecording() {
        setBusy("准备录制...")
        Task {
            do {
                let outputURL = makeOutputURL(extension: "m4a")
                try await recorder.start(outputURL: outputURL)
                await MainActor.run {
                    self.statusItem.button?.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "正在录制")
                    self.statusItemText.title = "正在录制系统音频"
                    self.windowStatusLabel.stringValue = "正在录制系统音频"
                    self.startItem.isEnabled = false
                    self.stopItem.isEnabled = true
                    self.startButton.isEnabled = false
                    self.stopButton.isEnabled = true
                }
            } catch {
                await showError("无法开始录制", error)
                await MainActor.run { self.setIdle() }
            }
        }
    }

    @objc private func stopRecording() {
        setBusy("正在转写...")
        Task {
            do {
                let audioURL = try await recorder.stop()
                let transcript = try await SpeechTranscriber(localeIdentifier: "zh-CN").transcribe(audioURL: audioURL)
                let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
                let mdURL = audioURL.deletingPathExtension().appendingPathExtension("md")
                try transcript.write(to: txtURL, atomically: true, encoding: .utf8)
                try DraftOrganizer.makeMarkdown(transcript: transcript, sourceAudioURL: audioURL)
                    .write(to: mdURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    self.statusItem.button?.image = NSImage(systemSymbolName: "waveform.and.mic", accessibilityDescription: "微信视频文稿")
                    self.statusItemText.title = "已生成：\(mdURL.lastPathComponent)"
                    self.windowStatusLabel.stringValue = "已生成：\(mdURL.lastPathComponent)"
                    self.startItem.isEnabled = true
                    self.stopItem.isEnabled = false
                    self.startButton.isEnabled = true
                    self.stopButton.isEnabled = false
                    NSWorkspace.shared.activateFileViewerSelecting([mdURL])
                }
            } catch {
                await showError("无法完成转写", error)
                await MainActor.run { self.setIdle() }
            }
        }
    }

    @objc private func openOutputFolder() {
        NSWorkspace.shared.open(outputDirectory)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func setBusy(_ title: String) {
        statusItem.button?.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "处理中")
        statusItemText.title = title
        windowStatusLabel?.stringValue = title
        startItem.isEnabled = false
        stopItem.isEnabled = false
        startButton?.isEnabled = false
        stopButton?.isEnabled = false
    }

    private func setIdle() {
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.and.mic", accessibilityDescription: "微信视频文稿")
        statusItemText.title = "空闲"
        windowStatusLabel?.stringValue = "空闲"
        startItem.isEnabled = true
        stopItem.isEnabled = false
        startButton?.isEnabled = true
        stopButton?.isEnabled = false
    }

    private func makeOutputURL(extension pathExtension: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "wechat-video-\(formatter.string(from: Date())).\(pathExtension)"
        return outputDirectory.appendingPathComponent(filename)
    }

    @MainActor
    private func showError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/WeChatTranscript.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = WeChatTranscriptApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

final class SystemAudioRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var didStartSession = false
    private let sampleQueue = DispatchQueue(label: "local.codex.WeChatTranscript.samples")

    func start(outputURL: URL) async throws {
        if stream != nil {
            throw RecorderError.alreadyRecording
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw RecorderError.noDisplay
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(audioInput) else {
            throw RecorderError.cannotAddAudioInput
        }
        writer.add(audioInput)

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.width = 2
        configuration.height = 2
        configuration.queueDepth = 3

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)

        self.outputURL = outputURL
        self.writer = writer
        self.audioInput = audioInput
        self.stream = stream
        self.didStartSession = false

        try await stream.startCapture()
    }

    func stop() async throws -> URL {
        guard let stream, let writer, let audioInput, let outputURL else {
            throw RecorderError.notRecording
        }

        try await stream.stopCapture()
        audioInput.markAsFinished()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        self.stream = nil
        self.writer = nil
        self.audioInput = nil
        self.outputURL = nil
        self.didStartSession = false

        return outputURL
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid, let writer, let audioInput else {
            return
        }

        if !didStartSession {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            didStartSession = true
        }

        if writer.status == .writing, audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "录制已停止"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

final class SpeechTranscriber {
    private let localeIdentifier: String

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func transcribe(audioURL: URL) async throws -> String {
        let authStatus = await requestAuthorization()
        guard authStatus == .authorized else {
            throw TranscriptionError.speechPermissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            _ = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal, !didResume {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error, !didResume {
                    didResume = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

enum DraftOrganizer {
    static func makeMarkdown(transcript: String, sourceAudioURL: URL) -> String {
        let cleaned = normalize(transcript)
        let paragraphs = splitIntoParagraphs(cleaned)
        let title = makeTitle(from: cleaned)
        let bullets = makeBullets(from: cleaned)

        return """
        # \(title)

        来源音频：\(sourceAudioURL.lastPathComponent)

        ## 要点摘要

        \(bullets)

        ## 阅读稿

        \(paragraphs.joined(separator: "\n\n"))

        ## 原始转写

        \(transcript)
        """
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "嗯", with: "")
            .replacingOccurrences(of: "呃", with: "")
            .replacingOccurrences(of: "啊", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitIntoParagraphs(_ text: String) -> [String] {
        let sentences = text
            .replacingOccurrences(of: "。", with: "。\n")
            .replacingOccurrences(of: "？", with: "？\n")
            .replacingOccurrences(of: "！", with: "！\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var paragraphs: [String] = []
        var current: [String] = []
        for sentence in sentences {
            current.append(sentence)
            if current.joined().count >= 180 {
                paragraphs.append(current.joined())
                current.removeAll()
            }
        }
        if !current.isEmpty {
            paragraphs.append(current.joined())
        }
        return paragraphs.isEmpty ? [text] : paragraphs
    }

    private static func makeTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "微信视频文稿"
        }
        let prefix = String(trimmed.prefix(28))
        return prefix + (trimmed.count > 28 ? "..." : "")
    }

    private static func makeBullets(from text: String) -> String {
        let sentences = text
            .replacingOccurrences(of: "。", with: "。\n")
            .replacingOccurrences(of: "？", with: "？\n")
            .replacingOccurrences(of: "！", with: "！\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }
            .prefix(5)

        if sentences.isEmpty {
            return "- 暂无可提取摘要，建议检查音频是否包含清晰人声。"
        }
        return sentences.map { "- \($0)" }.joined(separator: "\n")
    }
}

enum RecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case noDisplay
    case cannotAddAudioInput

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "当前已经在录制。"
        case .notRecording:
            return "当前没有正在进行的录制。"
        case .noDisplay:
            return "没有找到可捕获的显示器。"
        case .cannotAddAudioInput:
            return "无法创建音频写入通道。"
        }
    }
}

enum TranscriptionError: LocalizedError {
    case speechPermissionDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "没有语音识别权限，请在系统设置中允许本应用使用语音识别。"
        case .recognizerUnavailable:
            return "中文语音识别服务暂不可用。"
        }
    }
}

import AppKit
import Carbon
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

enum Demo {
    static func image(size: CGSize) -> CGImage {
        let context = ScreenshotRenderer.makeContext(width: Int(size.width * 2), height: Int(size.height * 2))!
        context.scaleBy(x: 2, y: 2)
        context.setFillColor(NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.93, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let card = CGRect(x: size.width * 0.23, y: size.height * 0.33, width: size.width * 0.52, height: size.height * 0.38)
        NSColor.white.setFill(); NSBezierPath(roundedRect: card, xRadius: 24, yRadius: 24).fill()
        ("让想法，一目了然。" as NSString).draw(at: CGPoint(x: card.minX + 36, y: card.maxY - 90), withAttributes: [.font: NSFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.17, alpha: 1)])
        ("选区、标注、复制，一气呵成。" as NSString).draw(at: CGPoint(x: card.minX + 36, y: card.maxY - 132), withAttributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: NSColor.gray])
        for i in 0..<9 {
            NSColor(calibratedRed: CGFloat(i) / 12 + 0.1, green: 0.5, blue: CGFloat(i) / 18 + 0.35, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: card.minX + 36 + CGFloat(i) * 44, y: card.minY + 44, width: 32, height: CGFloat(35 + (i * 13) % 70)), xRadius: 5, yRadius: 5).fill()
        }
        ("轻截 · 演示画面" as NSString).draw(at: CGPoint(x: 40, y: size.height - 60), withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .medium), .foregroundColor: NSColor.darkGray])
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }
    static func show(controller: CaptureController) {
        guard let screen = NSScreen.main else { return }
        controller.welcome?.close(); controller.present([(screen, image(size: screen.frame.size))])
    }
}

enum IntegrationChecks {
    static var preferencesDomain: String { "local.qingcapture.integration.\(ProcessInfo.processInfo.processIdentifier)" }
    static func preferences() -> UserDefaults {
        let defaults = UserDefaults(suiteName: preferencesDomain)!
        ShortcutStore.save(ScreenshotShortcut(keyCode: 25, modifiers: NSEvent.ModifierFlags([.control, .option, .shift]).rawValue), to: defaults)
        return defaults
    }
    static func run(controller: CaptureController, output: String) {
        var checks: [String: Bool] = [:]
        checks["welcomeVisible"] = controller.welcome?.isVisible == true
        checks["menuBarReady"] = controller.statusItem.menu?.items.contains(where: { $0.title.contains("设置快捷键") }) == true
        checks["globalHotKeyRegistered"] = controller.hotKeyRegistered
        let manager = controller.hotKeys
        let original = manager.current
        let settings = SettingsWindow(manager: manager)
        settings.show(); settings.recorder.beginRecording()
        checks["recordingSuspendsShortcut"] = manager.suspended && !manager.isRegistered
        let candidate = ScreenshotShortcut(keyCode: 37, modifiers: NSEvent.ModifierFlags([.control, .option, .shift]).rawValue)
        let recorded = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: candidate.flags, timestamp: 0, windowNumber: settings.window.windowNumber, context: nil, characters: "L", charactersIgnoringModifiers: "L", isARepeat: false, keyCode: 37)!
        settings.recorder.keyDown(with: recorded); settings.saveShortcut()
        checks["shortcutRecorderSaves"] = manager.current == candidate && ShortcutStore.load(from: manager.defaults) == candidate && manager.isRegistered
        let blocked = ScreenshotShortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags([.control, .option, .shift]).rawValue)
        var blocker: EventHotKeyRef?
        let status = RegisterEventHotKey(blocked.keyCode, blocked.carbonModifiers, EventHotKeyID(signature: 0x424C4F43, id: 1), GetEventDispatcherTarget(), OptionBits(kEventHotKeyExclusive), &blocker)
        checks["conflictKeepsPreviousBinding"] = status == noErr && manager.update(blocked) != nil && manager.current == candidate && manager.isRegistered && ShortcutStore.load(from: manager.defaults) == candidate
        if let blocker { UnregisterEventHotKey(blocker) }
        let originalHandler = manager.onTrigger
        var triggered = 0
        manager.onTrigger = { triggered += 1 }
        let shortcutEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: candidate.flags, timestamp: 0, windowNumber: settings.window.windowNumber, context: nil, characters: "L", charactersIgnoringModifiers: "L", isARepeat: false, keyCode: 37)!
        NSApp.sendEvent(shortcutEvent)
        checks["configuredShortcutDispatches"] = triggered == 1
        manager.onTrigger = originalHandler
        _ = manager.update(original)
        settings.recorder.beginRecording()
        settings.window.makeFirstResponder(nil)
        checks["leavingRecorderResumesShortcut"] = !manager.suspended && manager.isRegistered
        settings.recorder.stop()
        settings.window.close()
        guard let screen = NSScreen.main else { return }
        let image = Demo.image(size: screen.frame.size)
        controller.welcome?.orderOut(nil); controller.present([(screen, image)])
        guard let canvas = controller.canvases.first else { return }
        let size = screen.frame.size
        let selection = CGRect(x: size.width * 0.2, y: size.height * 0.22, width: size.width * 0.6, height: size.height * 0.55)
        canvas.selection = selection; controller.selected(canvas)
        controller.windows.forEach { $0.orderOut(nil) }
        controller.ocrWindow = OCRResultWindow(text: "test")
        controller.ocrWindow?.show()
        let priorWindows = controller.windows.count
        controller.startCapture()
        checks["ocrReentryKeepsSingleCaptureSession"] = !controller.busy && controller.windows.count == priorWindows
        controller.ocrWindow?.window.close(); controller.ocrWindow = nil
        canvas.window?.makeKeyAndOrderFront(nil)
        checks["toolbarVisible"] = controller.toolbar?.isVisible == true
        checks["toolbarInsideScreen"] = controller.toolbar.map { screen.frame.contains($0.frame) } ?? false
        checks["twelveToolsAvailable"] = controller.toolbar?.toolButtons.count == 12
        canvas.history.append(Annotation(tool: .rectangle, start: CGPoint(x: selection.minX + 12, y: selection.minY + 20), end: CGPoint(x: selection.maxX - 20, y: selection.maxY - 20)))
        func key(_ code: UInt16, _ character: String, modifiers: NSEvent.ModifierFlags = .command) {
            guard let window = canvas.window else { return }
            window.makeKey(); window.makeFirstResponder(canvas)
            let actualCharacter = modifiers.contains(.shift) ? character.uppercased() : character
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: actualCharacter, charactersIgnoringModifiers: actualCharacter, isARepeat: false, keyCode: code)!
            NSApp.sendEvent(event)
        }
        key(6, "z"); checks["commandZUndo"] = canvas.history.items.isEmpty
        key(6, "z", modifiers: [.command, .shift]); checks["commandShiftZRedo"] = canvas.history.items.count == 1
        canvas.beginText(at: CGPoint(x: selection.minX + 30, y: selection.minY + 30))
        canvas.textField?.stringValue = "中文标注测试"
        let result = controller.output(canvas)
        checks["textCommittedBeforeExport"] = canvas.textField == nil && canvas.history.items.count == 2
        let expected = CaptureGeometry.pixelRect(selection: selection, canvasSize: size, imageSize: CGSize(width: image.width, height: image.height))!
        checks["exportRetinaDimensions"] = result?.width == Int(expected.width) && result?.height == Int(expected.height)
        let dir = URL(fileURLWithPath: output).deletingLastPathComponent()
        if let result, let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) { try? data.write(to: dir.appendingPathComponent("smoke-export.png")) }
        controller.savePanelDriver = { panel in panel.cancel(nil) }
        key(1, "s")
        checks["commandSSaveCancelRestoresEditing"] = canvas.window?.isVisible == true && controller.toolbar?.isVisible == true && canvas.history.items.count == 2
        controller.savePanelDriver = nil
        let pasteboard = NSPasteboard.general
        let backup: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { source in
            let item = NSPasteboardItem(); for type in source.types { if let data = source.data(forType: type) { item.setData(data, forType: type) } }; return item
        }
        key(8, "c")
        checks["commandCCopiesThroughAppKit"] = controller.windows.isEmpty
        checks["clipboardPNG"] = pasteboard.data(forType: .png) == result.flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
        checks["allCaptureWindowsClosed"] = controller.windows.isEmpty && controller.canvases.isEmpty && controller.toolbar == nil
        pasteboard.clearContents(); if !backup.isEmpty { pasteboard.writeObjects(backup) }
        controller.present([(screen, image)])
        if let pinnedCanvas = controller.canvases.first {
            pinnedCanvas.selection = selection; controller.selected(pinnedCanvas)
            controller.pin(pinnedCanvas)
            checks["pinCreatesFloatingScreenshot"] = controller.pinnedWindows.count == 1 && controller.pinnedWindows.first?.window.isVisible == true && controller.canvases.isEmpty
            controller.pinnedWindows.first?.window.close()
            checks["pinClosesCleanly"] = controller.pinnedWindows.isEmpty
        }
        let longContext = ScreenshotRenderer.makeContext(width: 480, height: 2600)!
        longContext.setFillColor(NSColor.white.cgColor); longContext.fill(CGRect(x: 0, y: 0, width: 480, height: 2600))
        controller.presentLongImage(longContext.makeImage()!)
        if let longCanvas = controller.canvases.first {
            let longOutput = controller.output(longCanvas)
            checks["longImageScrollableEditor"] = longCanvas.enclosingScrollView != nil && longOutput?.width == 480 && longOutput?.height == 2600
            checks["longImageToolbarInsideWindow"] = controller.toolbar.map { longCanvas.window!.frame.contains($0.frame) } ?? false
            longCanvas.window?.performClose(nil)
            checks["longImageCloseCleansSession"] = controller.canvases.isEmpty && controller.toolbar == nil
        }
        let translate = TranslationWindow(text: "Hello QingCapture")
        translate.show(); checks["translationWindowVisible"] = translate.window.isVisible
        translate.window.close()
        let scrollSession = ScrollCaptureSession(screen: screen, region: CGRect(x: 100, y: 100, width: 300, height: 200))
        var scrollCancelled = false; scrollSession.onCancel = { scrollCancelled = true }
        scrollSession.cancel()
        checks["scrollCancellationCleansControls"] = scrollCancelled && scrollSession.stopped && !scrollSession.panel.isVisible && !scrollSession.border.isVisible
        manager.defaults.removePersistentDomain(forName: preferencesDomain)
        let report: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "screenCapturePermission": CGPreflightScreenCaptureAccess(), "screens": NSScreen.screens.count, "architecture": "arm64"]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: output)) }
    }
}

import AppKit
#if canImport(QingCaptureCore)
import QingCaptureCore
#endif

final class CaptureToolbar: NSPanel {
    weak var canvas: CaptureCanvas?
    weak var controller: CaptureController?
    var toolButtons: [NSButton] = []
    var undoButton: NSButton!
    var redoButton: NSButton!
    var ocrButton: NSButton!
    var recognizing = false
    let widthPopup = NSPopUpButton(), fontPopup = NSPopUpButton(), fillPopup = NSPopUpButton(), arrowPopup = NSPopUpButton(), mosaicPopup = NSPopUpButton()
    var colorButtons: [NSButton] = []
    let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .white, .black]
    let widths: [CGFloat] = [2, 3, 5, 8, 12], sizes: [CGFloat] = [16, 20, 24, 32, 40, 56], strengths: [CGFloat] = [6, 12, 24, 40]
    override var canBecomeKey: Bool { false }
    static let definitions: [(Tool, String, String)] = [(.selection,"cursorarrow","选区"),(.rectangle,"rectangle","矩形"),(.ellipse,"circle","椭圆"),(.arrow,"arrow.up.right","箭头"),(.line,"line.diagonal","直线"),(.pen,"pencil.tip","画笔"),(.highlighter,"highlighter","荧光笔"),(.text,"textformat","文字"),(.mosaic,"square.grid.3x3.fill","马赛克"),(.blur,"drop.halffull","模糊"),(.number,"1.circle","序号"),(.eraser,"eraser","橡皮擦")]

    init(canvas: CaptureCanvas, controller: CaptureController) {
        self.canvas = canvas; self.controller = controller
        let available = canvas.window?.frame.width ?? 1280
        let width = min(820, available - 24), columns = max(4, min(12, Int((width - 24) / 53)))
        let toolRows = Int(ceil(Double(Self.definitions.count) / Double(columns)))
        let height: CGFloat = CGFloat(toolRows * 47 + 108)
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "轻截 · 标注工具栏"; isFloatingPanel = true; hidesOnDeactivate = false; isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear; isOpaque = false; hasShadow = true
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .hudWindow; effect.state = .active; effect.blendingMode = .behindWindow
        effect.wantsLayer = true; effect.layer?.cornerRadius = 14; effect.layer?.masksToBounds = true
        effect.appearance = NSAppearance(named: .darkAqua); contentView = effect
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 7; root.alignment = .leading
        root.translatesAutoresizingMaskIntoConstraints = false; effect.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12), root.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12), root.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10)])
        func addRow(_ row: NSStackView, height: CGFloat) {
            root.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true; row.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        for start in stride(from: 0, to: Self.definitions.count, by: columns) {
            let row = NSStackView(); row.orientation = .horizontal; row.distribution = .fillEqually; row.spacing = 3
            for entry in Self.definitions[start..<min(start + columns, Self.definitions.count)] {
                let button = makeButton(entry.1, title: entry.2, action: #selector(chooseTool(_:)), vertical: true)
                button.tag = Tool.allCases.firstIndex(of: entry.0)!; toolButtons.append(button); row.addArrangedSubview(button)
            }
            addRow(row, height: 43)
        }
        let style = NSStackView(); style.orientation = .horizontal; style.spacing = 5; style.alignment = .centerY
        for (index, color) in colors.enumerated() {
            let button = NSButton(image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "颜色 \(index + 1)")!, target: self, action: #selector(chooseColor(_:)))
            button.isBordered = false; button.contentTintColor = color; button.tag = index; button.wantsLayer = true; button.layer?.cornerRadius = 11
            button.widthAnchor.constraint(equalToConstant: 22).isActive = true; colorButtons.append(button); style.addArrangedSubview(button)
        }
        let custom = NSButton(title: "+", target: self, action: #selector(customColor)); custom.toolTip = "自定义颜色"; custom.setAccessibilityLabel("自定义颜色"); custom.bezelStyle = .recessed; custom.widthAnchor.constraint(equalToConstant: 24).isActive = true; style.addArrangedSubview(custom)
        func popup(_ popup: NSPopUpButton, title: String, values: [String], action: Selector) {
            let label = NSTextField(labelWithString: title); label.font = .systemFont(ofSize: 10); label.textColor = .secondaryLabelColor
            let group = NSStackView(views: [label, popup]); group.orientation = .vertical; group.spacing = 0
            popup.addItems(withTitles: values); popup.target = self; popup.action = action; popup.font = .systemFont(ofSize: 11); popup.setAccessibilityLabel(title)
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            style.addArrangedSubview(group)
        }
        popup(widthPopup, title: "线宽", values: widths.map { String(Int($0)) }, action: #selector(changeWidth))
        popup(fontPopup, title: "字号", values: sizes.map { String(Int($0)) }, action: #selector(changeFont))
        popup(fillPopup, title: "形状", values: ["空心", "实心"], action: #selector(changeFill))
        popup(arrowPopup, title: "箭头", values: ["单向", "双向"], action: #selector(changeArrow))
        popup(mosaicPopup, title: "马赛克", values: ["细", "中", "强", "很强"], action: #selector(changeMosaic))
        // Scroll the style controls on narrow external screens instead of clipping actions.
        let scroller = NSScrollView(); scroller.drawsBackground = false; scroller.hasHorizontalScroller = true; scroller.autohidesScrollers = true
        let stylesWidth = max(width - 24, 700.0)
        style.frame = NSRect(x: 0, y: 0, width: stylesWidth, height: 39); scroller.documentView = style
        root.addArrangedSubview(scroller); scroller.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true; scroller.heightAnchor.constraint(equalToConstant: 43).isActive = true
        let actions = NSStackView(); actions.orientation = .horizontal; actions.distribution = .fillEqually; actions.spacing = 4
        undoButton = makeButton("arrow.uturn.backward", title: "撤销", action: #selector(undoAction)); actions.addArrangedSubview(undoButton)
        redoButton = makeButton("arrow.uturn.forward", title: "重做", action: #selector(redoAction)); actions.addArrangedSubview(redoButton)
        actions.addArrangedSubview(makeButton("trash", title: "清空", action: #selector(clearAction)))
        actions.addArrangedSubview(makeButton("arrow.up.left.and.arrow.down.right", title: "全屏", action: #selector(fullScreenAction)))
        ocrButton = makeButton("text.viewfinder", title: "识别文字", action: #selector(ocrAction)); actions.addArrangedSubview(ocrButton)
        actions.addArrangedSubview(makeButton("character.bubble", title: "翻译", action: #selector(translateAction)))
        let longShot = makeButton("scroll", title: "长截图", action: #selector(scrollAction)); longShot.toolTip = "滚动长截图 S"; longShot.isEnabled = canvas.enclosingScrollView == nil; actions.addArrangedSubview(longShot)
        actions.addArrangedSubview(makeButton("pin", title: "贴图", action: #selector(pinAction)))
        actions.addArrangedSubview(makeButton("square.and.arrow.down", title: "保存", action: #selector(saveAction)))
        actions.addArrangedSubview(makeButton("xmark", title: "取消", action: #selector(cancelAction)))
        let copy = makeButton("checkmark", title: "完成复制", action: #selector(copyAction)); copy.contentTintColor = .systemGreen; actions.addArrangedSubview(copy)
        addRow(actions, height: 34)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    func makeButton(_ symbol: String, title: String, action: Selector, vertical: Bool = false) -> NSButton {
        let button = NSButton(title: title, image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage(), target: self, action: action)
        button.setAccessibilityLabel(title); button.toolTip = title; button.bezelStyle = .recessed; button.isBordered = false
        button.imagePosition = vertical ? .imageAbove : .imageLeading; button.font = .systemFont(ofSize: vertical ? 10 : 11)
        button.contentTintColor = .white; button.wantsLayer = true; button.layer?.cornerRadius = 7
        return button
    }
    func refresh() {
        guard let canvas else { return }
        for button in toolButtons {
            let selected = Tool.allCases[button.tag] == canvas.tool
            button.layer?.backgroundColor = selected ? NSColor.systemGreen.withAlphaComponent(0.23).cgColor : NSColor.clear.cgColor
            button.contentTintColor = selected ? .systemGreen : .white
        }
        for (index, button) in colorButtons.enumerated() {
            button.layer?.borderWidth = canvas.ink.isEqual(colors[index]) ? 1.5 : 0; button.layer?.borderColor = NSColor.white.cgColor
        }
        undoButton.isEnabled = canvas.history.canUndo || canvas.textField != nil; redoButton.isEnabled = canvas.history.canRedo
        widthPopup.selectItem(at: widths.firstIndex(of: canvas.lineWidth) ?? 1)
        fontPopup.selectItem(at: sizes.firstIndex(of: canvas.fontSize) ?? 2)
        fillPopup.selectItem(at: canvas.filled ? 1 : 0); arrowPopup.selectItem(at: canvas.doubleArrow ? 1 : 0)
        mosaicPopup.selectItem(at: strengths.firstIndex(of: canvas.mosaicSize) ?? 1)
        fontPopup.isEnabled = canvas.tool == .text; fillPopup.isEnabled = canvas.tool == .rectangle || canvas.tool == .ellipse
        arrowPopup.isEnabled = canvas.tool == .arrow; mosaicPopup.isEnabled = canvas.tool == .mosaic
        ocrButton.isEnabled = !recognizing; ocrButton.title = recognizing ? "识别中…" : "识别文字"
    }
    @objc func chooseTool(_ sender: NSButton) { canvas?.setTool(Tool.allCases[sender.tag]) }
    @objc func chooseColor(_ sender: NSButton) { canvas?.commitText(); canvas?.ink = colors[sender.tag]; refresh() }
    @objc func customColor() {
        guard let canvas else { return }; canvas.commitText()
        let panel = NSColorPanel.shared; panel.color = canvas.ink; panel.showsAlpha = false; panel.isContinuous = true
        panel.setTarget(self); panel.setAction(#selector(colorChanged(_:))); panel.level = NSWindow.Level(rawValue: level.rawValue + 1); panel.orderFront(nil)
    }
    @objc func colorChanged(_ panel: NSColorPanel) { canvas?.ink = panel.color; refresh() }
    @objc func changeWidth() { canvas?.commitText(); canvas?.lineWidth = widths[widthPopup.indexOfSelectedItem]; refresh() }
    @objc func changeFont() { canvas?.commitText(); canvas?.fontSize = sizes[fontPopup.indexOfSelectedItem]; refresh() }
    @objc func changeFill() { canvas?.commitText(); canvas?.filled = fillPopup.indexOfSelectedItem == 1; refresh() }
    @objc func changeArrow() { canvas?.commitText(); canvas?.doubleArrow = arrowPopup.indexOfSelectedItem == 1; refresh() }
    @objc func changeMosaic() { canvas?.mosaicSize = strengths[mosaicPopup.indexOfSelectedItem]; refresh() }
    @objc func undoAction() { canvas?.undoAnnotation() }
    @objc func redoAction() { canvas?.redoAnnotation() }
    @objc func clearAction() { canvas?.clearAnnotations() }
    @objc func fullScreenAction() { canvas?.selectAllScreen() }
    @objc func ocrAction() { if let canvas { controller?.recognize(canvas) } }
    @objc func translateAction() { if let canvas { controller?.recognize(canvas, translate: true) } }
    @objc func scrollAction() { if let canvas { controller?.startScrolling(canvas) } }
    @objc func pinAction() { if let canvas { controller?.pin(canvas) } }
    @objc func saveAction() { if let canvas { controller?.save(canvas) } }
    @objc func copyAction() { if let canvas { controller?.copy(canvas) } }
    @objc func cancelAction() { controller?.cancel() }
}

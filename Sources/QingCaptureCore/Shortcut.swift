import AppKit
import Carbon

public struct ScreenshotShortcut: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt
    public init(keyCode: UInt32, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers & NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue
    }
    public static let standard = ScreenshotShortcut(keyCode: 0, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue)
    public var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }
    public var isValid: Bool {
        guard !flags.intersection([.control, .option, .command]).isEmpty,
              Self.keyNames[keyCode] != nil, ![UInt32(36), 48, 51, 53, 76, 117].contains(keyCode) else { return false }
        // Avoid common editing/quit commands and the system screenshot shortcuts.
        if flags == .command, [UInt32(0), 6, 7, 8, 9, 12, 13].contains(keyCode) { return false }
        if flags == [.command, .shift], [UInt32(20), 21, 23].contains(keyCode) { return false }
        return true
    }
    public var display: String {
        (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + (Self.keyNames[keyCode] ?? "?")
    }
    public var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
    public func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode && event.modifierFlags.intersection([.control, .option, .shift, .command]).rawValue == modifiers
    }
    public static let keyNames: [UInt32: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"Space",50:"`",51:"⌫",53:"Esc",76:"⌅",96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",109:"F10",111:"F12",117:"⌦",118:"F4",120:"F2",122:"F1",123:"←",124:"→",125:"↓",126:"↑"]
}
public enum ShortcutStore {
    public static func load(from defaults: UserDefaults) -> ScreenshotShortcut {
        guard let data = defaults.data(forKey: "screenshotShortcut"), let shortcut = try? JSONDecoder().decode(ScreenshotShortcut.self, from: data), shortcut.isValid else { return .standard }
        return shortcut
    }
    public static func save(_ shortcut: ScreenshotShortcut, to defaults: UserDefaults) {
        guard shortcut.isValid, let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: "screenshotShortcut")
    }
}

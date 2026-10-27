// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct CompactAudioDeviceChoice {
    let id: String
    let title: String
    var image: NSImage? = nil
    var isSeparator = false
}

/// macOS' SwiftUI Menu can flatten a composed label into only its image. A
/// native button preserves the complete boxed face and opens a normal NSMenu.
struct CompactAudioDevicePicker: NSViewRepresentable {
    @ObservedObject private var icons = AudioDeviceIconStore.shared
    @Binding var selection: String
    let title: String
    let name: String
    let iconURL: URL?
    let fallback: String
    let choices: [CompactAudioDeviceChoice]
    let enabled: Bool

    func makeNSView(context: Context) -> CompactAudioDeviceButton {
        let button = CompactAudioDeviceButton(frame: .zero, pullsDown: false)
        button.isBordered = false
        button.title = ""
        button.target = button
        button.action = #selector(AudioDevicePopUpButton.selectDevice(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: CompactAudioDeviceButton, context: Context) {
        button.deviceImage = choices.first { $0.id == selection }?.image
            ?? iconURL.flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        button.configure(choices: choices, selection: selection)
        button.onSelect = { selection = $0 }
        button.isEnabled = enabled
        button.toolTip = "\(title): \(name)"
        button.setAccessibilityLabel(title)
        button.setAccessibilityValue(name)
        button.needsDisplay = true
    }
}

final class CompactAudioDeviceButton: AudioDevicePopUpButton {
    var deviceImage: NSImage?

    override var intrinsicContentSize: NSSize { NSSize(width: 46, height: 24) }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isHighlighted ? NSColor.selectedControlColor : NSColor.controlColor).setFill()
        box.fill()
        NSColor.labelColor.withAlphaComponent(0.16).setStroke()
        box.lineWidth = 1
        box.stroke()
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let opacity: CGFloat = isEnabled ? 1 : 0.4
        if let deviceImage {
            // Preserve the device asset's aspect ratio within a fixed column.
            let size = deviceImage.size
            let scale = min(18 / max(1, size.width), 18 / max(1, size.height))
            let fitted = NSSize(width: size.width * scale, height: size.height * scale)
            let rect = NSRect(x: 7 + (18 - fitted.width) / 2,
                              y: (bounds.height - fitted.height) / 2,
                              width: fitted.width, height: fitted.height)
            if deviceImage.isTemplate {
                NSColor.labelColor.withAlphaComponent(opacity).setFill()
                let tinted = NSImage(size: deviceImage.size, flipped: false) { bounds in
                    deviceImage.draw(in: bounds)
                    NSColor.labelColor.setFill()
                    bounds.fill(using: .sourceIn)
                    return true
                }
                // NSButton draws in a flipped coordinate system; keep assets upright.
                tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity,
                            respectFlipped: true, hints: nil)
            } else {
                deviceImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity,
                                 respectFlipped: true, hints: nil)
            }
        }
        // Mirror the same geometry, so both chevrons have identical dimensions.
        NSColor.labelColor.withAlphaComponent(opacity * 0.85).setStroke()
        let arrows = NSBezierPath()
        arrows.lineWidth = 1.25
        arrows.lineCapStyle = .round
        arrows.lineJoinStyle = .round
        for direction: CGFloat in [-1, 1] {
            let centerY = bounds.midY + direction * 4
            arrows.move(to: NSPoint(x: 32, y: centerY - direction * 1.5))
            arrows.line(to: NSPoint(x: 34.5, y: centerY + direction * 1.5))
            arrows.line(to: NSPoint(x: 37, y: centerY - direction * 1.5))
        }
        arrows.stroke()
    }

    // The inherited NSPopUpButton tracks the same image-bearing menu as the
    // full selector. Only the closed face above is custom drawn.
}

/// SwiftUI's menu Picker drops images nested inside composed device labels.
/// Use the same native pop-up control, supplying its menu images explicitly.
struct AudioDeviceMenuPicker: NSViewRepresentable {
    @Binding var selection: String
    let title: String
    let choices: [CompactAudioDeviceChoice]

    func makeNSView(context: Context) -> AudioDevicePopUpButton {
        let button = AudioDevicePopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .small
        button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        button.bezelStyle = .rounded
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail
        button.target = button
        button.action = #selector(AudioDevicePopUpButton.selectDevice(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: AudioDevicePopUpButton, context: Context) {
        button.configure(choices: choices, selection: selection)
        button.onSelect = { selection = $0 }
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.setAccessibilityValue(button.title)
    }
}

class AudioDevicePopUpButton: NSPopUpButton {
    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        cell = AudioDevicePopUpCell(textCell: "", pullsDown: flag)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    var onSelect: ((String) -> Void)?

    func configure(choices: [CompactAudioDeviceChoice], selection: String) {
        alignment = .left
        menu = AudioDeviceMenu.make(choices: choices, selectedID: selection, target: nil, action: nil)
        if let index = choices.firstIndex(where: { !$0.isSeparator && $0.id == selection }) {
            selectItem(at: index)
        }
    }

    @objc func selectDevice(_ sender: NSPopUpButton) {
        guard let uid = selectedItem?.representedObject as? String else { return }
        onSelect?(uid)
    }
}

enum AudioDeviceMenu {
    static func make(choices: [CompactAudioDeviceChoice], selectedID: String,
                     target: AnyObject?, action: Selector?) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for choice in choices {
            if choice.isSeparator { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: choice.title, action: action, keyEquivalent: "")
            item.image = choice.image.map { source in
                let image = source.copy() as! NSImage
                let scale = 16 / max(1, max(source.size.width, source.size.height))
                image.size = NSSize(width: source.size.width * scale, height: source.size.height * scale)
                return image
            }
            item.target = target
            item.representedObject = choice.id
            item.state = choice.id == selectedID ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
}

/// NSPopUpButtonCell centers the image/title group even with left text
/// alignment. Keep fixed leading columns while retaining native chrome/menu.
final class AudioDevicePopUpCell: NSPopUpButtonCell {
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        drawImage(withFrame: cellFrame, in: controlView)
        drawTitle(withFrame: cellFrame, in: controlView)
    }

    override func drawImage(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard let image = selectedItem?.image else { return }
        let rendered: NSImage
        if image.isTemplate {
            rendered = NSImage(size: image.size, flipped: false) { bounds in
                image.draw(in: bounds)
                NSColor.controlTextColor.setFill()
                bounds.fill(using: .sourceIn)
                return true
            }
        } else {
            rendered = image
        }
        rendered.draw(in: imageRect(forBounds: controlView.bounds), from: .zero,
                      operation: .sourceOver, fraction: isEnabled ? 1 : 0.4,
                      respectFlipped: true, hints: nil)
    }

    override func drawTitle(withFrame cellFrame: NSRect, in controlView: NSView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        let text = NSAttributedString(string: selectedItem?.title ?? stringValue, attributes: [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: isEnabled ? NSColor.controlTextColor : NSColor.disabledControlTextColor,
            .paragraphStyle: paragraph
        ])
        var rect = titleRect(forBounds: controlView.bounds)
        rect.origin.y = controlView.bounds.midY - text.size().height / 2
        rect.size.height = text.size().height
        text.draw(in: rect)
    }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        NSRect(x: rect.minX + 6, y: rect.midY - 8, width: 16, height: 16)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let original = super.titleRect(forBounds: rect)
        let leading = rect.minX + 26
        return NSRect(x: leading, y: original.minY,
                      width: max(0, rect.maxX - leading - 20), height: original.height)
    }
}

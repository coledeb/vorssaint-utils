// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct CompactAudioDeviceChoice {
    let id: String
    let title: String
}

/// macOS' SwiftUI Menu can flatten a composed label into only its image. A
/// native button preserves the complete boxed face and opens a normal NSMenu.
struct CompactAudioDevicePicker: NSViewRepresentable {
    @Binding var selection: String
    let title: String
    let name: String
    let iconURL: URL?
    let fallback: String
    let choices: [CompactAudioDeviceChoice]
    let enabled: Bool

    func makeNSView(context: Context) -> CompactAudioDeviceButton {
        let button = CompactAudioDeviceButton(frame: .zero)
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.title = ""
        button.target = button
        button.action = #selector(CompactAudioDeviceButton.showDeviceMenu)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: CompactAudioDeviceButton, context: Context) {
        button.deviceImage = iconURL.flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)
        button.choices = choices
        button.selectedID = selection
        button.onSelect = { selection = $0 }
        button.isEnabled = enabled
        button.toolTip = "\(title): \(name)"
        button.setAccessibilityLabel(title)
        button.setAccessibilityValue(name)
        button.needsDisplay = true
    }
}

final class CompactAudioDeviceButton: NSButton {
    var deviceImage: NSImage?
    var choices: [CompactAudioDeviceChoice] = []
    var selectedID = ""
    var onSelect: ((String) -> Void)?

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

    @objc func showDeviceMenu() {
        guard isEnabled else { return }
        let menu = NSMenu()
        for choice in choices {
            let item = NSMenuItem(title: choice.title, action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.id
            item.state = choice.id == selectedID ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: bounds.minX, y: bounds.minY - 3), in: self)
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelect?(id)
    }
}

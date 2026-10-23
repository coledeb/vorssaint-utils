// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// A disabled or unavailable feature must never replace the app's entry point.
enum VolumeMenuBarPlacement {
    case disabled, separate, main

    init(featureAvailable: Bool, enabled: Bool, replaceMain: Bool) {
        self = featureAvailable && enabled ? (replaceMain ? .main : .separate) : .disabled
    }
}

/// Output volume settings, rather than the amplitude of the audio playing.
enum VolumeMenuBarState: Equatable, Hashable {
    case muted
    case level(Int)
    case unavailable

    init(volume: Double?, muted: Bool?) {
        if muted == true {
            self = .muted
        } else if let volume, volume.isFinite {
            self = .level(Int((min(max(volume, 0), 1) * 100).rounded()))
        } else {
            self = .unavailable
        }
    }

    var waveCount: Int {
        guard case let .level(percent) = self, percent > 0 else { return 0 }
        switch percent {
        case 1...33: return 1
        case 34...66: return 2
        default: return 3
        }
    }
}

enum VolumeMenuBarGlyph {
    static let size = NSSize(width: 24, height: 20)
    /// Keep the mic badge anchored to the same right edge when waves turn
    /// into the narrower mute mark (or the volume becomes unavailable).
    static let micBadgeSpacingReference = image(for: .level(67))

    static func image(for state: VolumeMenuBarState) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            let color: NSColor = (state == .muted || state == .level(100)) ? .systemRed : .white
            color.withAlphaComponent(state == .unavailable ? 0.35 : 1).setFill()
            // Every state shares the speaker's position; mute replaces the
            // waves with a cross in the space to its right.
            let speaker = NSBezierPath()
            speaker.move(to: NSPoint(x: 2, y: 7))
            speaker.line(to: NSPoint(x: 5, y: 7))
            speaker.line(to: NSPoint(x: 10, y: 3))
            speaker.line(to: NSPoint(x: 10, y: 17))
            speaker.line(to: NSPoint(x: 5, y: 13))
            speaker.line(to: NSPoint(x: 2, y: 13))
            speaker.close()
            speaker.fill()

            if state == .muted {
                let cross = NSBezierPath()
                cross.move(to: NSPoint(x: 14, y: 13.5))
                cross.line(to: NSPoint(x: 19.5, y: 6.5))
                cross.move(to: NSPoint(x: 14, y: 6.5))
                cross.line(to: NSPoint(x: 19.5, y: 13.5))
                cross.lineCapStyle = .round
                cross.lineWidth = 1.6
                color.setStroke()
                cross.stroke()
            } else {
                for wave in 1...3 {
                    color.withAlphaComponent(wave <= state.waveCount ? 1 : 0.22).setStroke()
                    let path = NSBezierPath()
                    path.appendArc(withCenter: NSPoint(x: 9, y: 10),
                                   radius: CGFloat(2 + wave * 3),
                                   startAngle: -50, endAngle: 50)
                    path.lineWidth = 1.6
                    path.lineCapStyle = .round
                    path.stroke()
                }
            }
            return true
        }
        // Preserve the requested white/red colors, including on light menu bars.
        image.isTemplate = false
        return image
    }
}

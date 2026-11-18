// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Waits for AppKit and SwiftUI to finish reacting to a change, instead of
/// always sleeping for a fixed time. The main run loop turns in short slices
/// until `snapshot` (what the caller is about to assert on) has stayed the
/// same for `quiet` seconds, after at least `minimum` seconds. It never waits
/// longer than `limit`, the fixed wait it replaces.
///
/// `VORSSAINT_SETTLE_VERIFY=1` proves an early return is safe: the run loop
/// keeps turning until `limit`, and any later change to the snapshot is
/// reported on stderr with the caller's location.
enum Settle {
    static let verifying = ProcessInfo.processInfo.environment["VORSSAINT_SETTLE_VERIFY"] == "1"

    static func quietly<State: Equatable>(limit: TimeInterval, quiet: TimeInterval = 0.05,
                                          minimum: TimeInterval = 0, slice: TimeInterval = 0.005,
                                          file: StaticString = #fileID, line: UInt = #line,
                                          _ snapshot: () -> State) {
        let start = Date()
        let deadline = start.addingTimeInterval(limit)
        var last = snapshot()
        var quietSince = Date()
        while Date() < deadline {
            RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(slice)))
            let now = Date()
            let current = snapshot()
            if current != last {
                last = current
                quietSince = now
            } else if now.timeIntervalSince(quietSince) >= quiet && now.timeIntervalSince(start) >= minimum {
                break
            }
        }
        guard verifying, Date() < deadline else { return }
        while Date() < deadline {
            RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(slice)))
        }
        if snapshot() != last {
            fputs("settle-verify: state changed after the early return at \(file):\(line)\n", stderr)
        }
    }

    /// Every descendant's frame in window coordinates, plus each clip view's
    /// scroll position: the geometry layout assertions read.
    static func geometry(of view: NSView) -> [CGRect] {
        view.layoutSubtreeIfNeeded()
        var rects: [CGRect] = []
        func visit(_ view: NSView) {
            rects.append(view.convert(view.bounds, to: nil))
            if let clip = view as? NSClipView { rects.append(clip.bounds) }
            view.subviews.forEach(visit)
        }
        visit(view)
        return rects
    }
}

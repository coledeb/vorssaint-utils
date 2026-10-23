// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The Sound settings alert level, relative to output volume. This is not the
/// master volume of the device selected for sound effects (often the same device
/// used for music). Standard Additions exposes the separate alert setting.
/// Only visible mixer views subscribe; subprocess work never blocks the UI.
final class SystemAlertVolume: ObservableObject {
    static let shared = SystemAlertVolume()

    @Published private(set) var volume: Double?
    @Published private(set) var unavailable = false
    private var subscribers = 0
    private var timer: Timer?
    private var pendingWrite: DispatchWorkItem?
    private var desiredPercent: Int?
    private var busy = false
    private var revision = 0

    /// Warm the value at feature startup, like the output/input observers, so
    /// the first visible panel doesn't have to wait for its initial read.
    /// This does not start polling or write any system setting.
    func prepare() {
        refresh()
    }

    func attach() {
        subscribers += 1
        guard subscribers == 1 else { return }
        refresh()
        // Alert preferences have no HAL volume listener. Reconcile external
        // changes while a mixer is visible, including changes in Sound settings.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func detach() {
        subscribers = max(0, subscribers - 1)
        guard subscribers == 0 else { return }
        timer?.invalidate()
        timer = nil
        // A user's final adjustment must still finish if the panel closes.
    }

    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        let percent = Int((min(1, max(0, value)) * 100).rounded())
        revision += 1
        volume = Double(percent) / 100
        desiredPercent = percent
        pendingWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.performNext() }
        pendingWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func refresh() {
        guard !busy, desiredPercent == nil else { return }
        performNext()
    }

    private func performNext() {
        guard !busy else { return }
        pendingWrite?.cancel()
        pendingWrite = nil
        busy = true
        let requested = desiredPercent
        desiredPercent = nil
        let startedRevision = revision
        var arguments: [String] = []
        if let requested {
            arguments += ["-e", "set volume alert volume \(requested)"]
        }
        arguments += ["-e", "alert volume of (get volume settings)"]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Shell.run("/usr/bin/osascript", arguments, timeout: 3, maxOutputBytes: 4096)
            let percent = Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
            let value = result.status == 0 ? percent.flatMap { (0...100).contains($0) ? $0 / 100 : nil } : nil
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                if self.revision == startedRevision {
                    self.volume = value
                    self.unavailable = value == nil
                }
                if self.desiredPercent != nil { self.performNext() }
            }
        }
    }
}

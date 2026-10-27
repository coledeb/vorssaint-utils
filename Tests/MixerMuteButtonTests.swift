// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation

private typealias NativeVolumeKeyEvents = PreciseVolumeKeyEvents

/// Exercise production action bodies against sinks that never write live audio.
enum MixerMuteButtonTests {
    class AlertFixture {
        var unavailable = false
        var volume: Double? = 0.37
        var mutedDisplayVolume: Double?
        var muteState = MixerVolumeMuteState()
        var writes: [Double] = []
        func setVolume(_ value: Double) { mutedDisplayVolume = nil; writes.append(value); volume = value }
    }
    class InputFixture {
        var listenerInstalled = true
        var inputVolume: Double? = 0.62
        var effectiveInputDeviceUID: String? = "first-mic"
        var muteState = MixerVolumeMuteState()
        var writes: [Double] = []
        func setInputVolume(_ value: Double) { writes.append(value); inputVolume = value }
    }
    final class FeatureMute {
        var toggles = 0
        func toggle() { toggles += 1 }
    }
    class ControlsFixture {
        var featureAvailable = false
        let micMute = FeatureMute()
        let inputManager = Input()
    }

    enum AppVolumeMixer {
        enum Result { case applied, fallback, superseded, unconfirmed }
        final class Mixer {
            var result = Result.applied
            var requests = 0
            func requestOutputMuteToggle(completion: (Result) -> Void) {
                requests += 1
                completion(result)
            }
        }
        static let shared = Mixer()
    }
    enum PreciseVolumeKeyEvents {
        struct Event { func post(tap: CGEventTapLocation) { posts += 1 } }
        static var posts = 0
        static func muteToggle() -> [Event] { [Event(), Event()] }
    }
    enum NotchService {
        final class HUD {
            var shows = 0
            func showCurrentVolume() { shows += 1 }
        }
        static let shared = HUD()
    }

    static func run(_ suite: TestSuite) {
        AppVolumeMixer.shared.requests = 0
        PreciseVolumeKeyEvents.posts = 0
        NotchService.shared.shows = 0
        let output = Output()
        AppVolumeMixer.shared.result = .applied
        output.toggleOutputMute()
        suite.expect(AppVolumeMixer.shared.requests == 1 && NotchService.shared.shows == 1 && PreciseVolumeKeyEvents.posts == 0,
                     "output button uses queued hardware mute without a second native key when applied")
        AppVolumeMixer.shared.result = .fallback
        output.toggleOutputMute()
        suite.expect(PreciseVolumeKeyEvents.posts == 2 && NotchService.shared.shows == 1,
                     "unsupported hardware mute forwards exactly one native key pair")
        AppVolumeMixer.shared.result = .superseded
        output.toggleOutputMute()
        AppVolumeMixer.shared.result = .unconfirmed
        output.toggleOutputMute()
        suite.expect(PreciseVolumeKeyEvents.posts == 2 && NotchService.shared.shows == 1,
                     "superseded or unconfirmed output writes do not trigger another mute")
        let alerts = Alerts()
        alerts.toggleMute()
        suite.expect(alerts.volume == 0 && alerts.displayVolume == 0.37,
                     "muted alerts really stay at zero while their slider displays the remembered position")
        alerts.toggleMute()
        suite.expect(alerts.displayVolume == 0.37 && alerts.mutedDisplayVolume == nil,
                     "unmuting clears presentation state and restores the real alert level")
        suite.expect(alerts.writes == [0, 0.37], "system-sounds button zeroes only alert volume and restores its prior level")
        alerts.unavailable = true
        alerts.toggleMute()
        suite.expect(alerts.writes.count == 2, "unavailable alert control cannot invent a volume reading")
        alerts.unavailable = false
        alerts.volume = nil
        alerts.toggleMute()
        suite.expect(alerts.writes.count == 2 && alerts.displayVolume == nil, "unread alert control performs no writes or synthetic display")
        let controls = Controls()
        controls.toggleMicrophoneMute()
        controls.toggleMicrophoneMute()
        suite.expect(controls.inputManager.writes == [0, 0.62] && controls.micMute.toggles == 0,
                     "without the mic feature the button only zeroes/restores the selected microphone volume")
        controls.featureAvailable = true
        controls.toggleMicrophoneMute()
        suite.expect(controls.inputManager.writes.count == 2 && controls.micMute.toggles == 1,
                     "with the mic feature the button delegates exclusively to its existing toggle")
        controls.inputManager.effectiveInputDeviceUID = "other-mic"
        controls.inputManager.inputVolume = 0.23
        controls.inputManager.toggleVolumeMute()
        controls.inputManager.toggleVolumeMute()
        suite.expect(controls.inputManager.writes.suffix(2) == [0, 0.23], "microphone restore levels are scoped to device UID")
        controls.inputManager.effectiveInputDeviceUID = "first-mic"
        controls.inputManager.inputVolume = 0
        controls.inputManager.toggleVolumeMute()
        suite.expect(controls.inputManager.writes.last == 0.62, "returning to the original microphone retains its own restore level")
        controls.inputManager.listenerInstalled = false
        let count = controls.inputManager.writes.count
        controls.inputManager.toggleVolumeMute()
        suite.expect(controls.inputManager.writes.count == count, "unavailable microphone cannot be changed")
        var state = MixerVolumeMuteState()
        suite.expect(state.target(volume: .nan, deviceUID: "mic") == nil
                     && state.target(volume: nil, deviceUID: "mic") == nil
                     && state.target(volume: 0.5, deviceUID: nil) == nil,
                     "invalid readings or device identities cannot generate mute writes")
        suite.expect(state.target(volume: 0, deviceUID: "already-silent") == 0.5,
                     "a device first seen silent has a usable unmute level")
        let events = NativeVolumeKeyEvents.muteToggle()
        suite.expect(events.count == 2 && events.allSatisfy(NativeVolumeKeyEvents.isPosted),
                     "output fallback creates one marked native mute press/release pair without posting it in tests")
        let decoded = events.compactMap { NSEvent(cgEvent: $0) }
        suite.expect(decoded.count == 2 && decoded.allSatisfy { ($0.data1 >> 16) & 0xffff == 7 }
                     && decoded.map { ($0.data1 >> 8) & 0xff } == [0x0a, 0x0b],
                     "native fallback uses the keyboard mute key, not a volume-zero command")
        suite.expect(events.allSatisfy { !$0.flags.contains(.maskAlternate) && !$0.flags.contains(.maskShift) },
                     "native mute fallback does not accidentally carry fine-volume modifiers")
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// Persistence, invalid preferences, reset isolation, and shared-feature gating.
enum AudioDeviceIconTests {
    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.audio-device-icons.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else { fatalError("test defaults unavailable") }
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = AudioDeviceIconStore(defaults: defaults)
        suite.expect(store.symbols.isEmpty, "new devices use automatic icons")
        suite.expect(store.setSymbol("headphones", for: "stable-device"), "macOS symbol is accepted")
        suite.expect(store.setSymbol("mic.fill", for: "other-device"), "other device has its own icon")
        let reopened = AudioDeviceIconStore(defaults: defaults)
        suite.expect(reopened.symbols["stable-device"] == "headphones", "device icon survives reconnect/relaunch with same UID")
        suite.expect(!store.setSymbol("not.a.real.symbol.123456", for: "stable-device"), "invalid names are rejected")
        suite.expect(store.symbols["stable-device"] == "headphones", "invalid edit does not erase saved icon")
        suite.expect(store.setSymbol(nil, for: "stable-device"), "reset accepts automatic mode")
        suite.expect(store.symbols["stable-device"] == nil && store.symbols["other-device"] == "mic.fill",
                     "reset affects only this device")
        // A backup restore is a separate defaults writer. The next edit must retain it.
        defaults.set(["restored-device": "display"], forKey: DefaultsKey.audioDeviceIcons)
        store.setSymbol("earbuds", for: "stable-device")
        suite.expect(store.symbols["restored-device"] == "display", "editing preserves restored preferences")
        suite.expect(!store.setSymbol("mic.fill", for: ""), "empty device identities cannot be saved")
        defaults.set(["broken": "missing.symbol.123456"], forKey: DefaultsKey.audioDeviceIcons)
        let broken = AudioDeviceIconStore(defaults: defaults)
        let resolved = broken.image(uid: "broken", fallback: "headphones")
        suite.expect(resolved.isValid && resolved.isTemplate, "unknown saved symbol falls back to a usable automatic icon")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("audio-device-icon-\(UUID().uuidString).tiff")
        if let data = NSImage(systemSymbolName: "display", accessibilityDescription: nil)?.tiffRepresentation {
            try? data.write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            let supplied = broken.image(uid: "device", iconURL: file, fallback: "headphones")
            suite.expect(!supplied.isTemplate, "automatic mode prefers the driver-provided image")
            broken.setSymbol("mic.fill", for: "device")
            suite.expect(broken.image(uid: "device", iconURL: file, fallback: "headphones").isTemplate,
                         "saved symbol overrides the driver image")
            broken.setSymbol(nil, for: "device")
            suite.expect(!broken.image(uid: "device", iconURL: file, fallback: "headphones").isTemplate,
                         "reset restores the driver image")
            let airPlay = broken.image(uid: "airplay-device", iconURL: file, fallback: "airplay.audio")
            suite.expect(airPlay.isTemplate, "automatic AirPlay route uses AirPlay instead of a generic driver image")
            broken.setSymbol("headphones", for: "airplay-device")
            suite.expect(broken.image(uid: "airplay-device", iconURL: file, fallback: "airplay.audio")
                         === broken.image(uid: "other-headphones", fallback: "headphones"),
                         "a saved custom icon still overrides automatic AirPlay")
            broken.setSymbol(nil, for: "airplay-device")
            suite.expect(broken.image(uid: "airplay-device", iconURL: file, fallback: "airplay.audio") === airPlay,
                         "AirPlay reset restores its automatic route icon")
        }
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.audioDeviceIcons), "icons participate in settings backup")
        suite.expect(!SettingsSectionAnchor.showsAudioDevices { _ in false }, "icons settings hidden without a relevant feature")
        for feature: AppFeature in [.mixer, .soundOutputSwitcher, .audioPriority] {
            suite.expect(SettingsSectionAnchor.showsAudioDevices { $0 == feature }, "each device feature exposes shared icon settings")
        }
        suite.expect(!SettingsSectionAnchor.showsAudioDevices { $0 == .musicBlock }, "unrelated sound feature does not expose device settings")
        let item = SettingsSearchItem(id: .setting(.audioDevices),
                                     destination: FeatureSettingsDestination(.general, sectionAnchor: .audioDevices),
                                     title: "Audio devices", icon: "speaker.wave.2", keywords: ["Device icons"])
        let general = SettingsSearchItem(id: .page(.general), destination: FeatureSettingsDestination(.general), title: "General", icon: "gear")
        suite.expect(SettingsSearchSupport.groupedMatchingItems(query: "Device icons", items: [general, item], isAvailable: { _ in false }).isEmpty,
                     "hidden device settings do not leak into search")
        suite.expect(!SettingsSearchSupport.groupedMatchingItems(query: "Device icons", items: [general, item], isAvailable: { $0 == .mixer }).isEmpty,
                     "available device settings can be searched")
        suite.expect(SettingsSearchSupport.route(for: item, isAvailable: { _ in false }).destination.sectionAnchor == nil,
                     "stale device settings destination falls back to General")
        suite.expect(AudioDeviceIconStore.fallback(name: "Living Room (AirPlay)", input: false) == "airplay.audio",
                     "named AirPlay routes use the AirPlay fallback")
        let curated = AudioDeviceSymbolCatalog.curated
        suite.expect((20...30).contains(curated.count) && curated.contains("headphones") && curated.contains("mic.fill") && curated.contains("airplay.audio"),
                     "default gallery stays limited to audio-device symbols")
        suite.expect(Set(curated).count == curated.count, "curated gallery has no duplicate cells")
        let missingCatalog = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suite.expect(AudioDeviceSymbolCatalog.names(catalogURL: missingCatalog).isEmpty,
                     "missing OS catalog hides expanded selection without a bundled fallback")
        let malformedCatalog = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? Data("not a plist".utf8).write(to: malformedCatalog)
        suite.expect(AudioDeviceSymbolCatalog.names(catalogURL: malformedCatalog).isEmpty,
                     "invalid OS catalog leaves curated picker available")
        try? FileManager.default.removeItem(at: malformedCatalog)
        nativeMenus(suite)
        iconSizing(suite)
        for language in AppLanguage.allCases {
            suite.expect(!AudioDeviceIconStrings.localized(language).reset.isEmpty, "every language has reset text")
        }
    }

    private static func nativeMenus(_ suite: TestSuite) {
        let symbol = NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)!
        let originalSize = symbol.size
        let choices = [
            CompactAudioDeviceChoice(id: "built-in", title: "MacBook Pro Speakers (current)", image: symbol),
            CompactAudioDeviceChoice(id: "", title: "", isSeparator: true),
            CompactAudioDeviceChoice(id: "virtual", title: "RemotePCSound", image: symbol)
        ]
        let menu = AudioDeviceMenu.make(choices: choices, selectedID: "virtual", target: nil, action: nil)
        suite.expect(menu.items.count == 3 && menu.items[1].isSeparatorItem, "device menu preserves separators and order")
        suite.expect(menu.items[0].title == choices[0].title && menu.items[2].title == choices[2].title,
                     "native icons do not replace or truncate menu device names")
        suite.expect(menu.items[0].image != nil && menu.items[2].image != nil, "native menu gets an explicit image for every device")
        suite.expect(menu.items[2].state == .on && menu.items[0].state == .off, "selection checkmark remains separate from device icon")
        suite.expect(menu.items[2].representedObject as? String == "virtual", "native selection retains stable device identity")
        suite.expect(symbol.size == originalSize && menu.items[0].image !== symbol,
                     "menu sizing does not mutate a shared macOS symbol")
        let button = AudioDevicePopUpButton(frame: NSRect(x: 0, y: 0, width: 164, height: 18), pullsDown: false)
        button.configure(choices: choices, selection: "virtual")
        var selected: String?
        button.onSelect = { selected = $0 }
        button.selectDevice(button)
        suite.expect(selected == "virtual", "native full selector routes device changes by UID")
        suite.expect(button.selectedItem?.image != nil && button.title == "RemotePCSound",
                     "closed full selector retains both the chosen icon and device title")
        suite.expect(button.alignment == .left, "short and long device titles are pinned to the leading edge")
        button.imagePosition = .imageLeading
        let shortChoice = CompactAudioDeviceChoice(id: "short", title: "Default", image: symbol)
        button.configure(choices: [shortChoice], selection: "short")
        let shortImageRect = button.cell!.imageRect(forBounds: button.bounds)
        let shortTextRect = button.cell!.titleRect(forBounds: button.bounds)
        button.configure(choices: choices, selection: "built-in")
        let longImageRect = button.cell!.imageRect(forBounds: button.bounds)
        let longTextRect = button.cell!.titleRect(forBounds: button.bounds)
        suite.expect(shortImageRect.minX == longImageRect.minX && shortTextRect.minX == longTextRect.minX,
                     "native image and text columns stay fixed when the selected title length changes")
        let compact = CompactAudioDeviceButton(frame: .zero, pullsDown: false)
        compact.configure(choices: choices, selection: "built-in")
        suite.expect(compact.menu?.items[0].image != nil && compact.menu?.items[2].image != nil,
                     "cozy uses the same image-bearing popup menu as default")
        suite.expect(compact.selectedItem?.representedObject as? String == "built-in",
                     "cozy native popup retains current device selection")
        var compactSelection: String?
        compact.onSelect = { compactSelection = $0 }
        compact.selectItem(at: 2)
        compact.selectDevice(compact)
        suite.expect(compactSelection == "virtual", "cozy native selection routes through the same callback as default")
        suite.expect(compact.intrinsicContentSize == NSSize(width: 46, height: 24), "cozy selector retains its original dimensions")
    }

    private static func iconSizing(_ suite: TestSuite) {
        for symbol in ["mic.fill", "laptopcomputer", "headphones"] {
            let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
            let normalized = AudioDeviceIconRendering.normalized(source)
            let bitmap = AudioDeviceIconRendering.raster(normalized)!
            let bounds = AudioDeviceIconRendering.visibleBounds(bitmap)!
            suite.expect(normalized.size == NSSize(width: 16, height: 16), "device glyphs share a fixed canvas")
            suite.expect(max(bounds.width, bounds.height) >= 62,
                         "\(symbol) visible artwork fills the same icon extent without intrinsic padding")
            suite.expect(normalized.isTemplate, "normalized symbol retains native tinting")
        }
        let padded = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { _ in
            NSColor.systemBlue.setFill()
            NSBezierPath(ovalIn: NSRect(x: 22, y: 22, width: 20, height: 20)).fill()
            return true
        }
        let normalized = AudioDeviceIconRendering.normalized(padded)
        let bitmap = AudioDeviceIconRendering.raster(normalized)!
        let bounds = AudioDeviceIconRendering.visibleBounds(bitmap)!
        suite.expect(max(bounds.width, bounds.height) >= 62 && !normalized.isTemplate,
                     "padded driver icons match symbol sizing while retaining color")
    }

}

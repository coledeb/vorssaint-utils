// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

extension MixerOutputDevice {
    var iconFallback: String {
        if isAirPlay || MixerRoutingSupport.isAirPlaySentinel(uid) { return "airplay.audio" }
        return AudioDeviceIconStore.fallback(name: name, input: false, headphones: isHeadphones, virtual: priorityTier == .virtual)
    }
}

extension MixerInputDevice {
    var iconFallback: String {
        AudioDeviceIconStore.fallback(name: name, input: true, virtual: priorityTier == .virtual)
    }
}

/// Fixed icon slot leaves the existing picker, slider and row geometry intact.
struct AudioDeviceIcon: View {
    @ObservedObject private var icons = AudioDeviceIconStore.shared
    let uid: String
    var iconURL: URL? = nil
    var fallback = "speaker.wave.2.fill"

    var body: some View {
        Image(nsImage: icons.image(uid: uid, iconURL: iconURL, fallback: fallback))
            .resizable().scaledToFit().frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

struct AudioDeviceLabel: View {
    let title: String
    let uid: String
    var iconURL: URL? = nil
    var fallback = "speaker.wave.2.fill"

    var body: some View {
        Label {
            Text(title)
        } icon: {
            AudioDeviceIcon(uid: uid, iconURL: iconURL, fallback: fallback)
        }
    }
}

struct AudioDeviceIconSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var input = AudioInputDeviceManager.shared
    @ObservedObject private var icons = AudioDeviceIconStore.shared
    @State private var editing: Device?

    private struct Device: Identifiable {
        let id: String
        let name: String
        let iconURL: URL?
        let fallback: String
    }

    private var text: AudioDeviceIconStrings { .localized(l10n.language) }

    var body: some View {
        SettingsCard(title: text.devices) {
            Text(text.caption).font(.callout).foregroundStyle(.secondary)
            deviceList(title: l10n.s.mixerSystemOutputTitle, devices: mixer.outputDevices.map {
                Device(id: $0.uid, name: $0.name, iconURL: $0.iconURL, fallback: $0.iconFallback)
            }, empty: l10n.s.mixerSystemOutputNoDevices)
            Divider()
            deviceList(title: text.input, devices: input.inputDevices.map {
                Device(id: $0.uid, name: $0.name, iconURL: $0.iconURL, fallback: $0.iconFallback)
            }, empty: l10n.s.mixerInputNoDevices)
        }
        .sheet(item: $editing) { device in
            AudioDeviceSymbolPicker(uid: device.id, name: device.name, iconURL: device.iconURL, fallback: device.fallback)
        }
    }

    private func deviceList(title: String, devices: [Device], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if devices.isEmpty { Text(empty).font(.callout).foregroundStyle(.secondary) }
            ForEach(devices) { device in
                HStack(spacing: 10) {
                    AudioDeviceIcon(uid: device.id, iconURL: device.iconURL, fallback: device.fallback)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name).lineLimit(1).truncationMode(.middle)
                        Text(icons.symbols[device.id] ?? text.automatic)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(text.change) { editing = device }
                        .accessibilityLabel("\(text.change) — \(device.name)")
                }
                .padding(10)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AudioDeviceSymbolPicker: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var icons = AudioDeviceIconStore.shared
    @Environment(\.dismiss) private var dismiss
    let uid: String
    let name: String
    let iconURL: URL?
    let fallback: String
    @State private var query = ""
    @State private var symbols: [String] = []
    @State private var loading = false
    @State private var expanded = false
    @State private var catalogNames: [String] = []
    private static var cachedSymbols: [String]?
    private var text: AudioDeviceIconStrings { .localized(l10n.language) }
    private var matches: [String] {
        let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "." })
        return terms.isEmpty ? symbols : symbols.filter { name in terms.allSatisfy { name.localizedCaseInsensitiveContains($0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AudioDeviceIcon(uid: uid, iconURL: iconURL, fallback: fallback)
                VStack(alignment: .leading, spacing: 3) {
                    Text(text.icons).font(.headline)
                    Text(name).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button(text.done) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                Button(text.reset) { icons.setSymbol(nil, for: uid) }
                if icons.symbols[uid] == nil {
                    Label(text.automatic, systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !catalogNames.isEmpty {
                Toggle(text.showAllSymbols, isOn: $expanded).toggleStyle(.checkbox)
            }
            TextField(text.search, text: $query).textFieldStyle(.roundedBorder)
                .accessibilityLabel(text.search)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if loading { ProgressView().controlSize(.small) }
                    if !loading && matches.isEmpty { Text(text.noMatches).foregroundStyle(.secondary) }
                    symbolGrid(matches)
                }
                .padding(3)
            }
            Text(text.shared).font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 540, height: 510)
        .onAppear { catalogNames = AudioDeviceSymbolCatalog.names() }
        .task(id: expanded) {
            symbols = AudioDeviceSymbolCatalog.curated.filter {
                NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil
            }
            guard expanded else { loading = false; return }
            if let cached = Self.cachedSymbols { symbols = cached; loading = false; return }
            loading = true
            var available: [String] = []
            for (index, name) in catalogNames.enumerated() {
                guard !Task.isCancelled else { return }
                if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil { available.append(name) }
                if index.isMultiple(of: 128) { await Task.yield() }
            }
            guard !Task.isCancelled else { return }
            Self.cachedSymbols = available
            symbols = available
            loading = false
        }
    }

    private func symbolGrid(_ names: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 9), spacing: 6) {
            ForEach(names, id: \.self) { symbol in
                Button {
                    icons.setSymbol(symbol, for: uid)
                    dismiss()
                } label: {
                    Image(systemName: symbol).font(.system(size: 20))
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(icons.symbols[uid] == symbol ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain).help(symbol).accessibilityLabel(symbol)
                .accessibilityAddTraits(icons.symbols[uid] == symbol ? .isSelected : [])
            }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Per-app volume sliders, the mixer macOS never shipped. Shows every app
/// holding an audio connection (a green dot marks the ones playing right now).
/// 100% is untouched passthrough; below it attenuates and above it (up to 200%)
/// boosts, with the slider and percentage turning amber in the boost range.
struct MixerSection: View {
    @ObservedObject private var deviceIcons = AudioDeviceIconStore.shared
    @Environment(\.notchPresentation) private var inNotch
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var alertVolume = SystemAlertVolume.shared
    @AppStorage(DefaultsKey.mixerCozyVolumeControls) private var cozyVolumeControls = false
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var inputManager = AudioInputDeviceManager.shared
    @ObservedObject private var audioPriority = AudioPriorityService.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var windowsGlass = false
    @AppStorage(DefaultsKey.notchLiquidGlassEnabled) private var islandGlass = false
    @AppStorage(DefaultsKey.mixerAppArrangement)
    private var arrangementValue = ""
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @AppStorage(DefaultsKey.mixerKeepPinnedAppsVisible) private var keepPinnedAppsVisible = false
    @State private var optionsExpanded = false
    @State private var normalSliderTint = Color(nsColor: .controlAccentColor)
    @State private var accentRevision = 0
    @State private var lastResolvedAccent: NSColor?
    @State private var editingVolumeID: String?
    @State private var draggingAppID: String?
    @State private var dropTarget: MixerAppDropTarget?
    var collapsible = true
    var settingsMode = false

    private var glassEnabled: Bool {
        LiquidGlassSupport.isEnabled(inNotch: inNotch, windows: windowsGlass, island: islandGlass)
    }

    var body: some View {
        Group {
            if settingsMode {
                SettingsCard(title: l10n.s.mixerSection) {
                    mixerControls
                }
            } else {
                PanelSection(.mixer, title: l10n.s.mixerSection, collapsible: collapsible) {
                    mixerControls.panelCard(interactive: false)
                }
            }
        }
        .onReceive(NSApplication.shared.publisher(for: \.effectiveAppearance, options: [.new])) { _ in
            refreshSliderTint()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NSSystemColorsDidChangeNotification"))) { _ in
            refreshSliderTint()
        }
        .onAppear {
            mixer.refreshApps()
            alertVolume.attach()
        }
        .onDisappear { alertVolume.detach() }
    }

    private var mixerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            audioDevicesSection

            if AppVolumeMixer.isSupported, (!visibleApps.isEmpty || mixer.needsPermission) {
                Divider()
            }

            if !AppVolumeMixer.isSupported {
                emptyLabel(l10n.s.mixerUnavailable)
            } else if mixer.needsPermission {
                permissionHint
            } else if visibleApps.isEmpty {
                emptyLabel(l10n.s.mixerEmpty)
            } else {
                mixerRows
            }

            Divider()
            optionsDisclosure
        }
    }

    private var audioDevicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if cozyVolumeControls {
                cozyOutputRow
                cozyAlertsRow
                cozyMicrophoneRow
            } else {
                universalOutputPicker
                systemSoundOutputPicker
                microphonePicker
            }
            if let outputSwitchError = mixer.outputSwitchError {
                inputMessage(String(format: l10n.s.mixerSystemOutputErrorFormat, outputSwitchError),
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var optionsDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                optionsExpanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                        .rotationEffect(.degrees(optionsExpanded ? 90 : 0))
                    Text(l10n.s.keepAwakeOptions)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if optionsExpanded {
                MixerOptionsControls(includeSharedAudioFeatures: !settingsMode)
                    .padding(.leading, 19)
            }
        }
    }

    private var outputIsMuted: Bool {
        mixer.systemOutputMuted == true || mixer.systemOutputVolume.map { $0 <= 0.001 } == true
    }

    private var microphoneIsMuted: Bool {
        (AppFeature.micMute.isAvailable && micMute.isMuted)
            || inputManager.inputVolume.map { $0 <= 0.001 } == true
    }

    private var outputMuteButton: some View {
        muteButton(symbol: "speaker.wave.2.fill", mutedSymbol: "speaker.slash.fill",
                   muted: outputIsMuted, enabled: mixer.currentOutputDeviceUID != nil,
                   title: l10n.s.mixerSystemOutputTitle) {
            PreciseVolumeRollerService.shared.toggleOutputMute()
        }
    }

    private var alertsMuteButton: some View {
        muteButton(symbol: "bell.fill", mutedSymbol: "bell.slash.fill",
                   muted: alertVolume.volume.map { $0 <= 0.001 } == true,
                   enabled: alertVolume.volume != nil && !alertVolume.unavailable,
                   title: l10n.s.mixerSoundEffectsOutputTitle) { alertVolume.toggleMute() }
    }

    private var microphoneMuteButton: some View {
        muteButton(symbol: "mic.fill", mutedSymbol: "mic.slash.fill",
                   muted: microphoneIsMuted,
                   enabled: AppFeature.micMute.isAvailable ? !inputManager.inputDevices.isEmpty : inputManager.inputVolume != nil,
                   title: l10n.s.mixerInputTitle, action: toggleMicrophoneMute)
    }

    private func toggleMicrophoneMute() {
        if AppFeature.micMute.isAvailable { micMute.toggle() }
        else { inputManager.toggleVolumeMute() }
    }

    private func muteButton(symbol: String, mutedSymbol: String, muted: Bool,
                            enabled: Bool, title: String, action: @escaping () -> Void) -> some View {
        let label = "\(muted ? l10n.s.actionUnmute : l10n.s.actionMute): \(title)"
        return Button(action: action) {
            Image(systemName: muted ? mutedSymbol : symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(muted ? Color.red : Color.secondary)
                .frame(width: 16, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func volumeControl(_ volume: Double?, binding: Binding<Double>,
                               title: String, editorID: String, muted: Bool = false) -> some View {
        HStack(spacing: 8) {
            if volume != nil {
                MixerVolumeSlider(value: binding,
                                  normalTint: normalSliderTint,
                                  boostTint: normalSliderTint,
                                  isBoosting: false,
                                  accentRevision: accentRevision,
                                  glassEnabled: glassEnabled,
                                  maximum: 1,
                                  accessibilityLabel: title)
            } else {
                // Reserve the slider column without constructing a thumb at 0.
                // When the read finishes, create it directly at the real level.
                Color.clear.frame(height: 18).accessibilityHidden(true)
            }
            EditableVolumePercent(currentPercent: MixerRoutingSupport.displayPercent(forVolume: volume ?? 0),
                                  maximumPercent: 100, width: 36,
                                  alignment: cozyVolumeControls ? .leading : .trailing, editorID: editorID,
                                  editingID: $editingVolumeID, accessibilityLabel: title) {
                Text(volume.map { "\(MixerRoutingSupport.displayPercent(forVolume: $0))%" } ?? "—")
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } onCommit: { binding.wrappedValue = $0 }
        }
        .frame(maxWidth: .infinity)
        .disabled(volume == nil || muted)
    }

    private var alertVolumeControl: some View {
        volumeControl(alertVolume.displayVolume,
                      binding: Binding(get: { alertVolume.displayVolume ?? 0 }, set: { alertVolume.setVolume($0) }),
                      title: l10n.s.mixerSoundEffectsOutputTitle, editorID: "system-alerts",
                      muted: alertVolume.volume.map { $0 <= 0.001 } == true)
            .help(alertVolume.unavailable ? l10n.s.mixerAlertVolumeUnavailable : l10n.s.mixerSoundEffectsOutputTitle)
    }

    private var cozyOutputRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                outputMuteButton
                volumeControl(mixer.systemOutputVolume, binding: systemOutputVolumeBinding,
                              title: l10n.s.mixerSystemOutputTitle, editorID: "system-output", muted: outputIsMuted)
                compactDevicePicker(title: l10n.s.mixerSystemOutputTooltip,
                                    selection: universalOutputSelectionBinding,
                                    name: universalOutputDevices.first { $0.uid == mixer.currentOutputDeviceUID }?.name,
                                    iconURL: universalOutputDevices.first { $0.uid == mixer.currentOutputDeviceUID }?.iconURL,
                                    fallback: universalOutputDevices.first { $0.uid == mixer.currentOutputDeviceUID }?.isHeadphones == true ? "headphones" : "speaker.wave.2.fill",
                                    disabled: universalOutputDevices.isEmpty,
                                    choices: compactOutputChoices(universalOutputDevices,
                                                                  selectedUID: mixer.currentOutputDeviceUID,
                                                                  title: outputDeviceTitle))
            }
            if universalOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
            }
        }
    }

    private var cozyAlertsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                alertsMuteButton
                alertVolumeControl
                compactDevicePicker(title: l10n.s.mixerSoundEffectsOutputTooltip,
                                    selection: systemSoundOutputSelectionBinding,
                                    name: systemSoundOutputDevices.first { $0.uid == mixer.currentSystemSoundOutputDeviceUID }?.name,
                                    iconURL: systemSoundOutputDevices.first { $0.uid == mixer.currentSystemSoundOutputDeviceUID }?.iconURL,
                                    fallback: systemSoundOutputDevices.first { $0.uid == mixer.currentSystemSoundOutputDeviceUID }?.isHeadphones == true ? "headphones" : "speaker.wave.2.fill",
                                    disabled: systemSoundOutputDevices.isEmpty,
                                    choices: compactOutputChoices(systemSoundOutputDevices,
                                                                  selectedUID: mixer.currentSystemSoundOutputDeviceUID,
                                                                  title: systemSoundOutputDeviceTitle))
            }
            if systemSoundOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
            }
        }
    }

    private var displayedInputDevice: MixerInputDevice? {
        let selection = inputSelectionBinding.wrappedValue
        let uid = selection == MixerRoutingSupport.systemDefaultSelectionID
            ? inputManager.currentInputDeviceUID : selection
        return inputManager.inputDevices.first { $0.uid == uid }
    }

    private var cozyMicrophoneRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                microphoneMuteButton
                volumeControl(inputManager.inputVolume, binding: inputVolumeBinding,
                              title: l10n.s.mixerInputTitle, editorID: "microphone-input")
                    .disabled(micMute.isMuted)
                compactDevicePicker(title: l10n.s.mixerInputTooltip,
                                    selection: inputSelectionBinding,
                                    name: displayedInputDevice?.name,
                                    iconURL: displayedInputDevice?.iconURL,
                                    fallback: "mic.fill", disabled: inputManager.inputDevices.isEmpty,
                                    choices: compactInputChoices)
            }
            microphoneStatus
        }
    }

    private func compactDevicePicker(title: String, selection: Binding<String>,
                                     name: String?, iconURL: URL?, fallback: String,
                                     disabled: Bool,
                                     choices: [CompactAudioDeviceChoice]) -> some View {
        CompactAudioDevicePicker(selection: selection, title: title,
                                 name: name ?? l10n.s.mixerOutputUnavailable,
                                 iconURL: iconURL, fallback: fallback,
                                 choices: choices, enabled: !disabled)
            .frame(width: 46, height: 24)
    }

    private func compactOutputChoices(_ devices: [MixerOutputDevice], selectedUID: String?,
                                      title: (MixerOutputDevice) -> String) -> [CompactAudioDeviceChoice] {
        var choices = devices.map { CompactAudioDeviceChoice(id: $0.uid, title: title($0),
            image: deviceIcons.image(uid: $0.uid, iconURL: $0.iconURL, fallback: $0.iconFallback)) }
        if selectedUID == nil {
            choices.insert(CompactAudioDeviceChoice(id: MixerRoutingSupport.systemDefaultSelectionID,
                                                    title: l10n.s.mixerOutputUnavailable), at: 0)
        } else if let selectedUID, !devices.contains(where: { $0.uid == selectedUID }) {
            choices.append(CompactAudioDeviceChoice(id: selectedUID, title: l10n.s.mixerOutputUnavailable))
        }
        return choices
    }

    private var compactInputChoices: [CompactAudioDeviceChoice] {
        var choices = [CompactAudioDeviceChoice(id: MixerRoutingSupport.systemDefaultSelectionID,
                                               title: l10n.s.mixerOutputDefault,
                                               image: displayedInputDevice.map { deviceIcons.image(uid: $0.uid, iconURL: $0.iconURL, fallback: $0.iconFallback) })]
        choices += inputManager.inputDevices.map { CompactAudioDeviceChoice(id: $0.uid, title: inputDeviceTitle($0),
            image: deviceIcons.image(uid: $0.uid, iconURL: $0.iconURL, fallback: $0.iconFallback)) }
        if !audioPriority.inputPriorityEnabled, let selected = inputManager.preferredInputDeviceUID,
           inputManager.preferredUnavailable {
            choices.append(CompactAudioDeviceChoice(id: selected, title: l10n.s.mixerInputUnavailable))
        }
        return choices
    }

    private var universalOutputPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    outputMuteButton
                    Text(l10n.s.mixerSystemOutputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                AudioDeviceMenuPicker(selection: universalOutputSelectionBinding,
                                      title: l10n.s.mixerSystemOutputTooltip,
                                      choices: compactOutputChoices(universalOutputDevices,
                                          selectedUID: mixer.currentOutputDeviceUID, title: outputDeviceTitle))
                .frame(width: 164)
                .disabled(universalOutputDevices.isEmpty)
                .help(l10n.s.mixerSystemOutputTooltip)
            }

            if let volume = mixer.systemOutputVolume {
                HStack(spacing: 8) {
                    MixerVolumeSlider(value: systemOutputVolumeBinding,
                                      normalTint: normalSliderTint,
                                      boostTint: normalSliderTint,
                                      isBoosting: false,
                                      accentRevision: accentRevision,
                                      glassEnabled: glassEnabled,
                                      maximum: 1,
                                      accessibilityLabel: l10n.s.mixerSystemOutputTitle)

                    EditableVolumePercent(currentPercent: MixerRoutingSupport.displayPercent(forVolume: volume),
                                          maximumPercent: 100,
                                          width: 36,
                                          editorID: "system-output",
                                          editingID: $editingVolumeID,
                                          accessibilityLabel: l10n.s.mixerSystemOutputTitle) {
                        Text("\(MixerRoutingSupport.displayPercent(forVolume: volume))%")
                            .font(.system(size: 10.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } onCommit: {
                        setSystemOutputVolume($0)
                    }
                }
                .padding(.leading, 24)
                .disabled(outputIsMuted)
            }

            if universalOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
            }
        }
    }

    private var systemSoundOutputPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    alertsMuteButton
                    Text(l10n.s.mixerSoundEffectsOutputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                AudioDeviceMenuPicker(selection: systemSoundOutputSelectionBinding,
                                      title: l10n.s.mixerSoundEffectsOutputTooltip,
                                      choices: compactOutputChoices(systemSoundOutputDevices,
                                          selectedUID: mixer.currentSystemSoundOutputDeviceUID, title: systemSoundOutputDeviceTitle))
                .frame(width: 164)
                .disabled(systemSoundOutputDevices.isEmpty)
                .help(l10n.s.mixerSoundEffectsOutputTooltip)
            }

            alertVolumeControl
                .padding(.leading, 24)

            if systemSoundOutputDevices.isEmpty {
                inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "bell.slash")
            }
        }
    }

    private var universalOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultOutput)
    }

    private var systemSoundOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultSystemOutput)
    }

    private var universalOutputSelectionBinding: Binding<String> {
        Binding(
            get: { mixer.currentOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setUniversalOutputDeviceUID(selection)
            }
        )
    }

    private func setSystemOutputVolume(_ value: Double) {
        if inNotch {
            // The slider shows the level; the island's header need not repeat it.
            NotchService.shared.noteOwnLevelAdjustment(.volume)
        }
        // Both panels share the key queue, so a drag supersedes an older key.
        mixer.requestOutputAdjustment(volume: value)
    }

    private var systemOutputVolumeBinding: Binding<Double> {
        Binding(
            get: { mixer.systemOutputVolume ?? 0 },
            set: { setSystemOutputVolume($0) }
        )
    }

    private var systemSoundOutputSelectionBinding: Binding<String> {
        Binding(
            get: {
                mixer.currentSystemSoundOutputDeviceUID
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                mixer.setSystemSoundOutputDeviceUID(selection)
            }
        )
    }

    private var microphonePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    microphoneMuteButton
                    Text(l10n.s.mixerInputTitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                AudioDeviceMenuPicker(selection: inputSelectionBinding,
                                      title: l10n.s.mixerInputTooltip, choices: compactInputChoices)
                .frame(width: 164)
                .disabled(inputManager.inputDevices.isEmpty)
                .help(l10n.s.mixerInputTooltip)
            }

            if let volume = inputManager.inputVolume {
                HStack(spacing: 8) {
                    MixerVolumeSlider(value: inputVolumeBinding,
                                      normalTint: normalSliderTint,
                                      boostTint: normalSliderTint,
                                      isBoosting: false,
                                      accentRevision: accentRevision,
                                      glassEnabled: glassEnabled,
                                      maximum: 1,
                                      accessibilityLabel: l10n.s.mixerInputTitle)

                    EditableVolumePercent(currentPercent: MixerRoutingSupport.displayPercent(forVolume: volume),
                                          maximumPercent: 100,
                                          width: 36,
                                          editorID: "microphone-input",
                                          editingID: $editingVolumeID,
                                          accessibilityLabel: l10n.s.mixerInputTitle) {
                        Text("\(MixerRoutingSupport.displayPercent(forVolume: volume))%")
                            .font(.system(size: 10.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } onCommit: {
                        inputManager.setInputVolume($0)
                    }
                }
                .padding(.leading, 24)
                .disabled(micMute.isMuted)
            }

            microphoneStatus
        }
    }

    @ViewBuilder private var microphoneStatus: some View {
        if inputManager.inputDevices.isEmpty {
            inputMessage(l10n.s.mixerInputNoDevices, systemImage: "mic.slash")
        } else if !audioPriority.inputPriorityEnabled, inputManager.preferredUnavailable {
            inputMessage(l10n.s.mixerInputFallback, systemImage: "mic.badge.xmark")
        } else if let lastError = inputManager.lastError {
            inputMessage(String(format: l10n.s.mixerInputErrorFormat, lastError),
                         systemImage: "exclamationmark.triangle")
        }
    }

    private var inputSelectionBinding: Binding<String> {
        Binding(
            get: {
                return MixerRoutingSupport.selectedInputDeviceUID(
                    preferredUID: inputManager.preferredInputDeviceUID,
                    currentUID: inputManager.currentInputDeviceUID,
                    priorityIsActive: audioPriority.inputPriorityEnabled)
                    ?? MixerRoutingSupport.systemDefaultSelectionID
            },
            set: { selection in
                if audioPriority.inputPriorityEnabled {
                    guard selection != MixerRoutingSupport.systemDefaultSelectionID else { return }
                    inputManager.setCurrentInputDeviceUID(selection)
                } else {
                    inputManager.setPreferredInputDeviceUID(
                        selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection)
                }
            }
        )
    }

    private var inputVolumeBinding: Binding<Double> {
        Binding(
            get: { inputManager.inputVolume ?? 0 },
            set: { inputManager.setInputVolume($0) }
        )
    }

    private var arrangement: MixerAppArrangement { MixerAppArrangement(rawValue: arrangementValue) }

    private var visibleApps: [MixerApp] {
        arrangement.ordered(mixer.apps, identity: { $0.persistenceID }).filter { app in
            MixerRoutingSupport.shouldShowApp(isPlaying: app.isPlaying,
                                              volume: app.volume,
                                              selectedOutputDeviceUID: app.selectedOutputDeviceUID,
                                              hideInactiveApps: hideInactiveApps,
                                              keepPinnedAppsVisible: keepPinnedAppsVisible,
                                              isPinned: arrangement.isPinned(app.persistenceID))
        }
    }

    private func inputDeviceTitle(_ device: MixerInputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }

    private func systemSoundOutputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.uid == mixer.currentSystemSoundOutputDeviceUID
            ? "\(device.name) (\(l10n.s.mixerOutputCurrent))"
            : device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var mixerRows: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), glassEnabled {
            GlassEffectContainer(spacing: 8) {
                rowList
            }
        } else {
            rowList
        }
#else
        rowList
#endif
    }

    @ViewBuilder
    private var rowList: some View {
        ForEach(visibleApps) { app in
            MixerRow(app: app,
                     normalTint: normalSliderTint,
                     accentRevision: accentRevision,
                     glassEnabled: glassEnabled,
                     editingVolumeID: $editingVolumeID,
                     isPinned: arrangement.isPinned(app.persistenceID),
                     togglePin: { updateArrangement { $0.togglePin(app.persistenceID ?? "") } },
                     moveUp: moveAction(for: app, offset: -1),
                     moveDown: moveAction(for: app, offset: 1))
                .modifier(MixerAppReorderModifier(
                    id: app.persistenceID,
                    icon: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 32),
                    draggingID: $draggingAppID,
                    target: $dropTarget,
                    dragChanged: { active in
                        if inNotch { NotchService.shared.fileDragChanged(active, internalDrag: true) }
                    },
                    canMove: { source, target in
                        let ids = visibleApps.compactMap(\.persistenceID)
                        return ids.contains(source) && ids.contains(target)
                            && arrangement.isPinned(source) == arrangement.isPinned(target)
                    },
                    move: { source, target, after in
                        updateArrangement {
                            $0.move(source, to: target, after: after,
                                    visibleIDs: visibleApps.compactMap(\.persistenceID))
                        }
                    }))
        }
    }

    private func updateArrangement(_ change: (inout MixerAppArrangement) -> Void) {
        var updated = arrangement
        change(&updated)
        arrangementValue = updated.rawValue
    }

    private func moveAction(for app: MixerApp, offset: Int) -> (() -> Void)? {
        let ids = visibleApps.compactMap(\.persistenceID)
        guard let id = app.persistenceID,
              arrangement.neighbor(of: id, offset: offset, visibleIDs: ids) != nil else { return nil }
        return {
            updateArrangement {
                $0.move(id, offset: offset, visibleIDs: visibleApps.compactMap(\.persistenceID))
            }
        }
    }

    /// Appearance KVO and the system-colors notification can fire in bursts
    /// without the accent actually changing, and every revision bump re-renders
    /// (and, before macOS 26, recreates) every slider row — so compare the
    /// accent resolved against the current appearance and only then re-tint.
    /// When the accent cannot be resolved this fails open (always re-tints),
    /// never closed: eating a real accent change would leave stale sliders.
    private func refreshSliderTint() {
        var resolved: NSColor?
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.controlAccentColor.usingColorSpace(.sRGB)
        }
        if let resolved, let last = lastResolvedAccent, resolved == last { return }
        lastResolvedAccent = resolved
        normalSliderTint = Color(nsColor: .controlAccentColor)
        accentRevision += 1
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }

    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.s.mixerPermissionBody)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(l10n.s.permissionOpenSettings) {
                Permissions.shared.openAudioCaptureSettings()
            }
            .controlSize(.small)
        }
    }
}

/// The options under the routing, shared with the island's mixer page so
/// both surfaces offer the same switches: idle rows, the headphone guard, the
/// precise roller, the output switcher and the hidden apps.
struct MixerOptionsControls: View {
    @AppStorage(DefaultsKey.mixerCozyVolumeControls) private var cozyVolumeControls = false
    @AppStorage(DefaultsKey.mixerMenuBarIndicator)
    private var menuBarIndicator = false
    @AppStorage(DefaultsKey.mixerMenuBarReplaceMainIcon)
    private var replaceMainIcon = false

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var preciseVolumeRoller = PreciseVolumeRollerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.mixerHideInactiveApps)
    private var hideInactiveApps = false
    @AppStorage(DefaultsKey.mixerKeepPinnedAppsVisible) private var keepPinnedAppsVisible = false
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect)
    private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    private var headphonesDisconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent
    @AppStorage(DefaultsKey.preciseVolumeRollerEnabled)
    private var preciseVolumeRollerEnabled = false
    @State private var showListChooser = false
    var includeSharedAudioFeatures = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(l10n.s.mixerVolumeControls, selection: $cozyVolumeControls) {
                Text(l10n.s.micMuteMenuBarSpacingDefault).tag(false)
                Text(l10n.s.micMuteMenuBarSpacingCozy).tag(true)
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .font(.system(size: 11.5, weight: .medium))
            if AppVolumeMixer.isSupported {
                inactiveAppsVisibilityToggle
                Toggle(FeatureStrings.mixer(l10n.language).keepPinnedAppsVisible,
                       isOn: $keepPinnedAppsVisible)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .medium))
            }
            Toggle(l10n.s.mixerMenuBarIndicator, isOn: $menuBarIndicator)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))
            if menuBarIndicator {
                Toggle(l10n.s.mixerMenuBarReplaceMainIcon, isOn: $replaceMainIcon)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .medium))
                    .padding(.leading, 19)
            }
            headphoneDisconnectProtectionToggle
            preciseVolumeRollerToggle
            if includeSharedAudioFeatures, AppFeature.soundOutputSwitcher.isAvailable {
                SoundOutputSwitcherControls()
            }
            if includeSharedAudioFeatures, AppFeature.audioPriority.isAvailable {
                AudioPriorityDisclosure()
            }
            if AppVolumeMixer.isSupported, !listChoices.isEmpty {
                listVisibilityFooter
            }
        }
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headphoneDisconnectProtectionToggle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(l10n.s.mixerLowerOnHeadphonesDisconnect,
                   isOn: $lowerOnHeadphonesDisconnect)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))

            Text(l10n.s.mixerLowerOnHeadphonesDisconnectCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if lowerOnHeadphonesDisconnect {
                HStack(spacing: 8) {
                    Stepper(value: headphonesDisconnectVolumeBinding,
                            in: Defaults.minimumMixerHeadphonesDisconnectVolumePercent...100,
                            step: 5) {
                        Text(l10n.s.mixerHeadphonesDisconnectVolume)
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .controlSize(.small)
                    Spacer(minLength: 6)
                    Text("\(headphonesDisconnectDisplayPercent)%")
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var headphonesDisconnectVolumeBinding: Binding<Int> {
        Binding(
            get: { Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent) },
            set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent($0) }
        )
    }

    private var headphonesDisconnectDisplayPercent: Int {
        Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent)
    }

    private var preciseVolumeRollerToggle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(l10n.s.preciseVolumeRollerEnable, isOn: $preciseVolumeRollerEnabled)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))
                .onChange(of: preciseVolumeRollerEnabled) { _, enabled in
                    if enabled { permissions.requestAccessibility() }
                    PreciseVolumeRollerService.shared.syncWithPreferences()
                }

            Text(l10n.s.preciseVolumeRollerCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if preciseVolumeRollerEnabled, !permissions.accessibility {
                Button {
                    Permissions.shared.openAccessibilitySettings()
                } label: {
                    Label(l10n.s.permissionOpenSettings, systemImage: "hand.raised")
                }
                .buttonStyle(.link)
                .font(.system(size: 10.5, weight: .medium))
            } else if preciseVolumeRoller.tapFailed {
                inputMessage(l10n.s.preciseVolumeRollerTapFailed,
                             systemImage: "exclamationmark.triangle")
            }
        }
    }

    /// One entry per app the list knows about: visible rows checked, hidden
    /// apps unchecked, everything in one alphabetical run so the menu reads
    /// like the list itself.
    private struct MixerListChoice: Identifiable {
        let id: String
        let name: String
        let isListed: Bool
        /// A row with nothing stable to remember it by cannot be hidden; it
        /// still shows here so the menu mirrors the list.
        let canToggle: Bool
    }

    private var listChoices: [MixerListChoice] {
        // The hidden list updates the moment a box is unchecked, while the
        // visible rows only change when the next HAL refresh lands. Keyed by
        // persistence id with the hidden entry winning, a just-hidden app
        // shows up once (unchecked) instead of twice during that gap.
        var seen = Set<String>()
        var choices = mixer.hiddenApps.map { hidden -> MixerListChoice in
            seen.insert(hidden.id)
            return MixerListChoice(id: hidden.id, name: hidden.name, isListed: false, canToggle: true)
        }
        for app in mixer.apps {
            let id = app.persistenceID ?? app.id
            guard seen.insert(id).inserted else { continue }
            choices.append(MixerListChoice(id: id, name: app.name,
                                           isListed: true, canToggle: app.persistenceID != nil))
        }
        choices.sort {
            MixerRoutingSupport.displayOrderedBefore(name: $0.name, id: $0.id,
                                                     otherName: $1.name, otherID: $1.id)
        }
        return choices
    }

    /// Which apps the list shows (issue #300): the row reads how many are
    /// hidden and opens a check per app, right in the panel so several can be
    /// checked or unchecked in one go. Hidden apps stay here even while they
    /// are not running, so they can always be brought back.
    private var listVisibilityFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showListChooser.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(l10n.s.mixerVisibleApps)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text(mixer.hiddenApps.isEmpty
                         ? l10n.s.mixerAllShown
                         : "\(l10n.s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showListChooser ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.s.mixerVisibleApps)
            .accessibilityValue(mixer.hiddenApps.isEmpty
                                ? l10n.s.mixerAllShown
                                : "\(l10n.s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")

            if showListChooser {
                ForEach(listChoices) { choice in
                    Toggle(isOn: listedBinding(for: choice)) {
                        Text(choice.name)
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .disabled(!choice.canToggle)
                }
            }
        }
    }

    private func listedBinding(for choice: MixerListChoice) -> Binding<Bool> {
        Binding(
            get: { choice.isListed },
            set: { listed in
                if listed {
                    mixer.showInList(id: choice.id)
                } else if let app = mixer.apps.first(where: { ($0.persistenceID ?? $0.id) == choice.id }) {
                    mixer.hideFromList(app)
                }
            }
        )
    }

    private var inactiveAppsVisibilityToggle: some View {
        let label = FeatureStrings.mixer(l10n.language).hideInactiveApps
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Toggle(label, isOn: $hideInactiveApps)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel(label)
        }
    }
}

/// The same output-switcher preferences in the menu panel and Settings.
struct SoundOutputSwitcherControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var outputSwitcher = SoundOutputSwitcher.shared
    @AppStorage(DefaultsKey.soundOutputSwitcherEnabled)
    private var enabled = false
    @State private var selectedUIDs: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(l10n.s.soundOutputSwitcherEnable, isOn: $enabled)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .medium))
                .onChange(of: enabled) { _, isEnabled in
                    if isEnabled, selectedUIDs.isEmpty,
                       let current = mixer.currentOutputDeviceUID,
                       universalOutputDevices.contains(where: { $0.uid == current }) {
                        setSelectedUIDs([current])
                    }
                    outputSwitcher.syncWithPreferences()
                }

            Text(l10n.s.soundOutputSwitcherCaption)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if enabled {
                ShortcutPreferenceRow(role: .soundOutputSwitcher,
                                      isEnabled: enabled,
                                      additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                    outputSwitcher.syncWithPreferences()
                }
                if outputSwitcher.registrationFailed {
                    inputMessage(l10n.s.shortcutUnavailable, systemImage: "keyboard.badge.ellipsis")
                }
                if outputSwitcher.lastSwitchFailed {
                    inputMessage(l10n.s.soundOutputSwitcherNoAvailableSelection,
                                 systemImage: "speaker.badge.exclamationmark")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.s.soundOutputSwitcherDevices)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    if universalOutputDevices.isEmpty {
                        inputMessage(l10n.s.mixerSystemOutputNoDevices, systemImage: "speaker.slash")
                    } else {
                        ForEach(universalOutputDevices) { device in
                            Toggle(isOn: selectionBinding(for: device.uid)) {
                                AudioDeviceLabel(title: outputDeviceTitle(device), uid: device.uid, iconURL: device.iconURL, fallback: device.iconFallback)
                                    .font(.system(size: 10.5))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .onAppear { selectedUIDs = outputSwitcher.selectedDeviceUIDs() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            selectedUIDs = outputSwitcher.selectedDeviceUIDs()
        }
    }

    private var universalOutputDevices: [MixerOutputDevice] {
        mixer.outputDevices.filter(\.canBeDefaultOutput)
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }

    private func inputMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func selectionBinding(for uid: String) -> Binding<Bool> {
        Binding(
            get: { selectedUIDs.contains(uid) },
            set: { selected in
                var next = selectedUIDs
                if selected {
                    if !next.contains(uid) { next.append(uid) }
                } else {
                    next.removeAll { $0 == uid }
                }
                let visibleOrder = universalOutputDevices.map(\.uid)
                let visible = visibleOrder.filter { next.contains($0) }
                let unavailable = next.filter { !visibleOrder.contains($0) }
                setSelectedUIDs(visible + unavailable)
            }
        )
    }

    private func setSelectedUIDs(_ uids: [String]) {
        let sanitized = Defaults.sanitizedSoundOutputSwitcherDeviceUIDs(uids)
        selectedUIDs = sanitized
        outputSwitcher.setSelectedDeviceUIDs(sanitized)
    }
}

private struct MixerRow: View {
    @ObservedObject private var deviceIcons = AudioDeviceIconStore.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let app: MixerApp
    let normalTint: Color
    let accentRevision: Int
    let glassEnabled: Bool
    @Binding var editingVolumeID: String?
    let isPinned: Bool
    let togglePin: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    private var arrangementStrings: MixerFeatureStrings { FeatureStrings.mixer(l10n.language) }
    private var sharingStrings: MixerScreenSharingStrings { .localized(l10n.language) }

    /// Warm accent to flag the boost range, darkened in Light Mode for contrast.
    private var boostColor: Color { PanelMetricColor.orange(for: colorScheme) }
    /// Keep boost styling tied to the displayed level; reset still follows
    /// actual gain so it can restore unity even while muted.
    private var isMuted: Bool { app.volume <= 0.001 }
    private var displayedVolume: Double { mixer.displayedVolume(for: app) }
    private var percentColor: Color { isMuted ? Color.secondary.opacity(0.5) : (isBoosting ? boostColor : .secondary) }
    private var isBoosting: Bool { (displayedVolume * 100).rounded() > 100 }
    private var isAtUnity: Bool { (app.volume * 100).rounded() == 100 }

    /// SoundSource-sized icon spanning the row's two lines (issue #166); the
    /// bitmap must be requested at this size or the upscale looks blurry.
    private static let iconPointSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid,
                                                       pointSize: Self.iconPointSize))
                    .resizable()
                    .frame(width: Self.iconPointSize, height: Self.iconPointSize)
                if app.isPlaying {
                    Circle()
                        .fill(PanelMetricColor.green(for: colorScheme))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.2))
                        .offset(x: -1, y: -1)
                }
            }
            .help(arrangementStrings.arrange)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(arrangementStrings.arrange)

                    Spacer(minLength: 4)

                    if app.persistenceID != nil {
                        Button(action: togglePin) {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(isPinned ? arrangementStrings.unpin : arrangementStrings.pin)
                        .accessibilityLabel("\(isPinned ? arrangementStrings.unpin : arrangementStrings.pin): \(app.name)")
                    }
                    if !app.isBypassed {
                        outputPicker
                    }
                }

                if app.isBypassed {
                    Text(app.supportsVolumeOverride ? sharingStrings.protectedCaption : l10n.s.mixerBypassedCaption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(app.supportsVolumeOverride ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        MixerVolumeSlider(value: volumeBinding,
                                          normalTint: normalTint,
                                          boostTint: boostColor,
                                          isBoosting: isBoosting,
                                          accentRevision: accentRevision,
                                          glassEnabled: glassEnabled,
                                          maximum: AppVolumeMixer.maxVolume,
                                          accessibilityLabel: app.name)
                            .disabled(isMuted)

                        EditableVolumePercent(currentPercent: MixerRoutingSupport.displayPercent(forVolume: displayedVolume),
                                              maximumPercent: Int(AppVolumeMixer.maxVolume * 100),
                                              width: 42,
                                              editorID: "app:\(app.id)",
                                              editingID: $editingVolumeID,
                                              accessibilityLabel: app.name) {
                            HStack(spacing: 2) {
                                if isBoosting {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(percentColor)
                                }
                                Text("\(MixerRoutingSupport.displayPercent(forVolume: displayedVolume))%")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(percentColor)
                            }
                        } onCommit: {
                            mixer.setVolume($0, for: app)
                        }
                        .disabled(isMuted)

                        Button {
                            mixer.setVolume(1, for: app)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(!isMuted && isBoosting ? boostColor : Color.secondary)
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        .help(l10n.s.mixerResetTooltip)
                        .opacity(isAtUnity ? 0 : 1)
                        .disabled(isAtUnity)

                        Button {
                            mixer.toggleMute(app)
                        } label: {
                            Image(systemName: app.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(app.volume <= 0.001
                                                 ? PanelMetricColor.red(for: colorScheme)
                                                 : Color.secondary)
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)
                    }

                    if app.supportsVolumeOverride {
                        Label(sharingStrings.sharingWarning, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if app.outputDeviceUnavailable {
                        Label(l10n.s.mixerOutputFallback, systemImage: "speaker.badge.exclamationmark")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityAction(named: Text(arrangementStrings.moveUp)) { moveUp?() }
        .accessibilityAction(named: Text(arrangementStrings.moveDown)) { moveDown?() }
        .contextMenu {
            if app.persistenceID != nil {
                arrangementActions
                Divider()
                Button(l10n.s.mixerHideFromList) {
                    mixer.hideFromList(app)
                }
            }
        }
    }

    @ViewBuilder
    private var arrangementActions: some View {
        Button(action: togglePin) {
            Label(isPinned ? arrangementStrings.unpin : arrangementStrings.pin,
                  systemImage: isPinned ? "pin.slash" : "pin")
        }
        if app.supportsVolumeOverride {
            Divider()
            Toggle(sharingStrings.allowVolumeControl, isOn: Binding(
                get: { !app.isBypassed },
                set: { mixer.setCallAppVolumeControl($0, for: app) }))
                .help(sharingStrings.sharingWarning)
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { displayedVolume },
            set: { mixer.setVolume($0, for: app) }
        )
    }

    private var outputPicker: some View {
        AudioDeviceMenuPicker(selection: outputSelectionBinding,
                              title: l10n.s.mixerOutputTooltip, choices: outputChoices)
            .frame(width: 112)
            .help(l10n.s.mixerOutputTooltip)
    }

    private var outputChoices: [CompactAudioDeviceChoice] {
        let icons = deviceIcons
        let current = mixer.outputDevices.first { $0.uid == mixer.currentOutputDeviceUID }
        var choices = [CompactAudioDeviceChoice(id: MixerRoutingSupport.systemDefaultSelectionID,
                                                title: l10n.s.mixerOutputDefault,
                                                image: current.map { icons.image(uid: $0.uid, iconURL: $0.iconURL, fallback: $0.iconFallback) })]
        choices += mixer.outputDevices.map {
            CompactAudioDeviceChoice(id: $0.uid, title: outputDeviceTitle($0),
                                     image: icons.image(uid: $0.uid, iconURL: $0.iconURL, fallback: $0.iconFallback))
        }
        if let selected = app.selectedOutputDeviceUID,
           MixerRoutingSupport.needsUnavailableOutputRow(selectedUID: selected,
                                                         isUnavailable: app.outputDeviceUnavailable,
                                                         listedUIDs: mixer.outputDevices.map(\.uid)) {
            choices.append(CompactAudioDeviceChoice(id: selected, title: l10n.s.mixerOutputUnavailable,
                                                    image: icons.image(uid: selected, fallback: "speaker.wave.2.fill")))
        }
        if mixer.outputDevices.contains(where: { MixerRoutingSupport.isAirPlaySentinel($0.uid) }) {
            choices.append(CompactAudioDeviceChoice(id: "", title: "", isSeparator: true))
            choices.append(CompactAudioDeviceChoice(id: MixerRoutingSupport.airPlaySpeakerChoiceID,
                                                    title: l10n.s.mixerAirPlayChooseSpeaker,
                                                    image: NSImage(systemSymbolName: "airplay.audio", accessibilityDescription: nil)))
        }
        return choices
    }

    private var outputSelectionBinding: Binding<String> {
        Binding(
            get: { app.selectedOutputDeviceUID ?? MixerRoutingSupport.systemDefaultSelectionID },
            set: { selection in
                mixer.setOutputDeviceUID(selection == MixerRoutingSupport.systemDefaultSelectionID ? nil : selection,
                                         for: app)
            }
        )
    }

    private func outputDeviceTitle(_ device: MixerOutputDevice) -> String {
        device.isDefault ? "\(device.name) (\(l10n.s.mixerOutputCurrent))" : device.name
    }
}

/// The percentage keeps its compact read-only appearance until clicked, then
/// becomes a selected text field so the next keystroke replaces the old value.
struct EditableVolumePercent<Label: View>: View {
    let currentPercent: Int
    let maximumPercent: Int
    let width: CGFloat
    var height: CGFloat = 18
    var alignment: Alignment = .trailing
    let editorID: String
    @Binding var editingID: String?
    let accessibilityLabel: String
    @ViewBuilder let label: () -> Label
    let onCommit: (Double) -> Void

    @State private var draft = ""
    @Environment(\.isEnabled) private var isEnabled

    private var isEditing: Bool { isEnabled && editingID == editorID }

    var body: some View {
        ZStack {
            HStack(spacing: 1) {
                AutofocusingVolumeTextField(text: $draft,
                                            isActive: isEditing,
                                            accessibilityLabel: accessibilityLabel,
                                            onSubmit: commit,
                                            onCancel: cancel)
                Text("%")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 3)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
            )
            .opacity(isEditing ? 1 : 0)
            .allowsHitTesting(isEditing)
            .accessibilityHidden(!isEditing)

            Button(action: beginEditing) {
                label()
                    .frame(width: width, alignment: alignment)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isEditing ? 0 : 1)
            .allowsHitTesting(!isEditing)
            .accessibilityLabel("\(accessibilityLabel) \(currentPercent)%")
            .accessibilityHidden(isEditing)
        }
        .frame(width: width, alignment: alignment)
        .onChange(of: isEnabled) { _, enabled in
            if !enabled, editingID == editorID { editingID = nil }
        }
    }

    private func beginEditing() {
        guard isEnabled else { return }
        draft = String(currentPercent)
        editingID = editorID
    }

    @discardableResult
    private func commit() -> Bool {
        guard isEnabled else {
            editingID = nil
            return true
        }
        guard let volume = MixerRoutingSupport.volumeFraction(
            fromPercentageText: draft,
            maximumPercent: maximumPercent
        ) else {
            NSSound.beep()
            return false
        }
        onCommit(volume)
        editingID = nil
        return true
    }

    private func cancel() {
        if isEditing { editingID = nil }
    }
}

/// A native field is used because an NSPopover can attach its SwiftUI backing
/// view after a FocusState request has already fired. The field retries when it
/// joins the window, then owns Return, Escape and loss-of-focus behavior.
private struct AutofocusingVolumeTextField: NSViewRepresentable {
    @Binding var text: String
    let isActive: Bool
    let accessibilityLabel: String
    let onSubmit: () -> Bool
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text,
                    isActive: isActive,
                    onSubmit: onSubmit,
                    onCancel: onCancel)
    }

    func makeNSView(context: Context) -> MixerPercentNativeTextField {
        let field = MixerPercentNativeTextField()
        field.delegate = context.coordinator
        context.coordinator.field = field
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .right
        field.font = .systemFont(ofSize: 10.5, weight: .medium)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.isEnabled = isActive
        field.isHidden = !isActive
        field.setAccessibilityLabel(accessibilityLabel)
        field.didAttachToWindow = { [weak field, weak coordinator = context.coordinator] in
            guard let field else { return }
            coordinator?.focusIfNeeded(field)
        }
        return field
    }

    func updateNSView(_ field: MixerPercentNativeTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onCancel = onCancel
        field.setAccessibilityLabel(accessibilityLabel)
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.setActive(isActive, field: field)
    }

    static func dismantleNSView(_ field: MixerPercentNativeTextField,
                                coordinator: Coordinator) {
        coordinator.stopMonitoringEscape()
        field.didAttachToWindow = nil
        field.delegate = nil
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        private var isActive: Bool
        var onSubmit: () -> Bool
        var onCancel: () -> Void
        weak var field: MixerPercentNativeTextField?
        private var didFocus = false
        private var isFinishing = false
        private var escapeMonitor: Any?

        init(text: Binding<String>,
             isActive: Bool,
             onSubmit: @escaping () -> Bool,
             onCancel: @escaping () -> Void) {
            self.text = text
            self.isActive = isActive
            self.onSubmit = onSubmit
            self.onCancel = onCancel
            super.init()
            if isActive { startMonitoringEscape() }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard isActive, didFocus, !isFinishing,
                  let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
            isFinishing = true
            if !onSubmit() { onCancel() }
        }

        func control(_ control: NSControl,
                     textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = (control as? NSTextField)?.stringValue ?? text.wrappedValue
                if onSubmit() { isFinishing = true }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                finish(onCancel)
                return true
            }
            return false
        }

        func focusIfNeeded(_ field: MixerPercentNativeTextField) {
            guard isActive, !didFocus else { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field, self.isActive, !self.didFocus else { return }
                if field.focusAndSelectAll() { self.didFocus = true }
            }
        }

        func setActive(_ active: Bool, field: MixerPercentNativeTextField) {
            if active != isActive {
                isActive = active
                didFocus = false
                isFinishing = false
                if active {
                    field.isHidden = false
                    field.isEnabled = true
                    startMonitoringEscape()
                } else {
                    stopMonitoringEscape()
                    field.isEnabled = false
                    field.isHidden = true
                }
            }
            if active { focusIfNeeded(field) }
        }

        private func startMonitoringEscape() {
            guard escapeMonitor == nil else { return }
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // The monitor sees the whole app; Escape in another window,
                // such as Settings, stays there.
                guard let self, self.isActive, event.keyCode == 53,
                      let window = self.field?.window, event.window === window else { return event }
                // While an input method is composing, Esc belongs to it and
                // drops the candidate; the next one cancels the level.
                if (window.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
                self.finish(self.onCancel)
                return nil
            }
        }

        func stopMonitoringEscape() {
            guard let escapeMonitor else { return }
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        private func finish(_ action: () -> Void) {
            guard !isFinishing else { return }
            isFinishing = true
            action()
        }
    }
}

private struct MixerVolumeSlider: View {
    @Binding var value: Double
    let normalTint: Color
    let boostTint: Color
    let isBoosting: Bool
    let accentRevision: Int
    let glassEnabled: Bool
    let maximum: Double
    let accessibilityLabel: String

    @Environment(\.isEnabled) private var isEnabled
    private var activeTint: Color { isEnabled ? (isBoosting ? boostTint : normalTint) : .secondary }
    private var percentage: Int { MixerRoutingSupport.displayPercent(forVolume: value) }

    var body: some View {
        Group {
#if compiler(>=6.2)
            if #available(macOS 26.0, *), glassEnabled {
                LiquidGlassMixerSlider(value: $value,
                                       tint: activeTint,
                                       isBoosting: isBoosting,
                                       maximum: maximum,
                                       accessibilityLabel: accessibilityLabel)
            } else {
                nativeSlider
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue("\(percentage)%")
            }
#else
            nativeSlider
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue("\(percentage)%")
#endif
        }
    }

    private var nativeSlider: some View {
        Slider(value: $value, in: 0...maximum)
            .controlSize(.small)
            // Pass an explicit accent (not nil) for the normal state: on the
            // macOS slider, tint(nil) does not reliably clear a previously
            // applied colour, so the bar would stay amber after leaving boost.
            .tint(activeTint)
            .id(accentRevision)
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private struct LiquidGlassMixerSlider: View {
    @Binding var value: Double
    let tint: Color
    let isBoosting: Bool
    let maximum: Double
    let accessibilityLabel: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.isEnabled) private var isEnabled
    private let knobWidth: CGFloat = 24
    private let knobHeight: CGFloat = 15
    private let trackHeight: CGFloat = 5

    private var progress: CGFloat {
        let clamped = min(max(value, 0), maximum)
        return CGFloat(clamped / maximum)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, knobWidth)
            let amount = progress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(trackOpacity))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(tint)
                    .frame(width: max(trackHeight, width * amount), height: trackHeight)
                    .shadow(color: tint.opacity(0.18), radius: 3)

                knob
                    .frame(width: knobWidth, height: knobHeight)
                    .offset(x: (width - knobWidth) * amount)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.16), value: amount)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(at: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: knobHeight)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(MixerRoutingSupport.displayPercent(forVolume: value))%")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment:
                value = min(maximum, value + 0.05)
            case .decrement:
                value = max(0, value - 0.05)
            @unknown default:
                break
            }
        }
    }

    private var trackOpacity: Double {
        colorScheme == .light ? 0.11 : 0.16
    }

    private var knob: some View {
        ZStack {
            knobFill
            Capsule()
                .strokeBorder(tint.opacity(isBoosting ? 0.55 : 0.36), lineWidth: isBoosting ? 1.1 : 0.8)
            Capsule()
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(colorScheme == .light ? 0.48 : 0.28),
                        Color.white.opacity(0.06)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .blendMode(.screen)
                .padding(1)
        }
        .shadow(color: tint.opacity(isBoosting ? 0.24 : 0.16), radius: 3, x: 0, y: 0)
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.18), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var knobFill: some View {
        if reduceTransparency {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Capsule().fill(tint.opacity(colorScheme == .light ? 0.10 : 0.16)))
        } else {
            Color.clear
                .glassEffect(.regular.tint(tint.opacity(isBoosting ? 0.18 : 0.10)).interactive(), in: Capsule())
        }
    }

    private func updateValue(at x: CGFloat, width: CGFloat) {
        guard isEnabled else { return }
        let travel = max(width - knobWidth, 1)
        let normalized = min(max((x - knobWidth / 2) / travel, 0), 1)
        value = Double(normalized) * maximum
    }
}
#endif

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme/logo-dark.svg">
    <img src="docs/assets/readme/logo.svg" width="220" alt="Vorssaint logo">
  </picture>
</p>

<h1 align="center">Vorssaint</h1>

<p align="center">
  One menu bar icon doing the job of a dozen paid Mac apps.<br>
  Install only what you use.
</p>

<p align="center">
  <a href="https://vorssaint.com">Upstream website</a> ·
  <a href="#install">Install</a> ·
  <a href="#everything-it-does">Features</a> ·
  <a href="#private-by-default">Privacy</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/vorssaint/vorssaint-utils/issues">Upstream issues</a> ·
  <a href="https://discord.gg/M6BwWH4BJp">Discord</a>
</p>

<p align="center">
  <a href="https://github.com/vorssaint/vorssaint-utils/releases"><img src="https://img.shields.io/github/v/release/vorssaint/vorssaint-utils?label=upstream%20release&color=4c8dff" alt="Latest upstream release"></a>
  <a href="https://github.com/vorssaint/vorssaint-utils/releases"><img src="https://img.shields.io/github/downloads/vorssaint/vorssaint-utils/total?label=upstream%20downloads&color=4c8dff" alt="Upstream downloads"></a>
  <a href="https://github.com/coledeb/vorssaint-utils/actions/workflows/ci.yml"><img src="https://github.com/coledeb/vorssaint-utils/actions/workflows/ci.yml/badge.svg?branch=main&event=push" alt="CI status"></a>
  <a href="#what-you-need"><img src="https://img.shields.io/badge/macOS-14%2B%20Apple%20Silicon-black" alt="macOS 14 and newer, Apple Silicon"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License GPL 3.0 or later"></a>
</p>

<p align="center">
  <a href="https://buymeacoffee.com/vorssaint">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="217" height="60" alt="Buy Me a Coffee">
  </a>
</p>

<p align="center">
  To contact the upstream maintainer privately, email
  <a href="mailto:hello@vorssaint.com"><strong>hello@vorssaint.com</strong></a>.
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/53716?utm_source=repository-badge&amp;utm_medium=badge&amp;utm_campaign=badge-repository-53716" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/repositories/53716" alt="vorssaint/vorssaint-utils | Trendshift" width="250" height="55"></a>
  <a href="https://trendshift.io/repositories/53716?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-53716" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/53716/weekly?language=Swift" alt="vorssaint/vorssaint-utils | Trendshift weekly ranking" width="250" height="55"></a>
  <a href="https://trendshift.io/repositories/53716?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-53716" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/53716/monthly?language=Swift" alt="vorssaint/vorssaint-utils | Trendshift monthly ranking" width="250" height="55"></a>
</p>

<p align="center">
  <img src="docs/assets/readme/panel-mixer.png" width="196" alt="Volume mixer with per app sliders, one app boosted past 100 percent">
  <img src="docs/assets/readme/panel-system.png" width="196" alt="System tab with temperatures, usage graphs and memory pressure">
  <img src="docs/assets/readme/panel-controls.png" width="196" alt="Window controls with the app switcher and Dock features">
  <img src="docs/assets/readme/panel-utilities.png" width="196" alt="Utilities with cleaner, Homebrew, media tools and clipboard">
</p>

Per app volume, a real system monitor, a better app switcher, window snapping, Dock previews, clipboard history, text snippets, a file shelf, an uninstaller. The utilities Mac users usually buy one by one, together behind a single menu bar icon, with no account, no telemetry and no subscription.

> [!NOTE]
> **About this fork (Audio changes)**
>
> This fork of [Vorssaint](https://github.com/vorssaint/vorssaint-utils) adds audio controls and mixer refinements for my personal setup, alongside a few panel and build improvements.
>
> - **Live output volume in the menu bar (optional).** Show a speaker icon beside the Vorssaint icon or use it in place of the main icon. Its waves follow the current output volume; the speaker turns red at 100%, and muting shows a red speaker with an X instead of waves. Changes follow the system's volume and mute state without polling.
> - **Default or Cozy volume controls.** Choose the original labeled layout or a compact row for each output, system-sounds and microphone control, with aligned sliders, editable percentages and boxed device selectors. Device menus keep full names and use device icons where available.
> - **Separate system-sounds volume.** Adjust macOS alert and sound-effect volume independently of output and microphone volume. The level loads before the mixer opens and follows external changes while the mixer is visible.
> - **Keep pinned apps visible (optional).** Pinned apps can stay in both the panel and Dynamic Island mixers when inactive, including running apps that aren't currently producing audio. Quitting removes their rows; reopening restores them. Explicitly hidden apps stay hidden, and saved volume and output choices are preserved.
> - **Direct mixer pin button.** Pin or unpin an app directly from its row; the right-click menu remains available, including upstream’s optional volume-control override for supported Discord and Teams apps. These apps bypass mixer processing by default to protect screen-shared audio.
> - **Default or Cozy muted-microphone icon spacing.** Choose the original spacing or a tighter gap beside the menu bar icon. The microphone badge stays in place as the speaker's volume or mute state changes.
>
> **Other improvements**
>
> - **Settings and Quit beside the logo.** The menu bar panel keeps these actions in its header for quicker access and less space at the bottom.
> - **Panel fits its content.** Balanced spacing and content-based sizing reduce empty space while keeping long sections scrollable.
> - **Single-tab selector visibility.** Choose whether to hide the tab selector when only one section is visible.
> - **Local builds without a signing certificate.** [Tools/build-local.py](Tools/build-local.py) wraps the upstream build with ad-hoc signing and a local compiler cache. The app and executable are named Vorssaint, including when installed at `/Applications/Vorssaint.app`.
> - **Separate fork identity.** Bundle ID `com.coledeb.vorssaint.utils` keeps this fork’s settings, stored data, permissions and fan helper separate from upstream. Installing can replace the official app at the same path without deleting or importing its settings or data. macOS permissions need to be granted for the fork.
> - **Upstream update proposals.** A daily [sync workflow](.github/UPSTREAM_SYNC.md) updates the fork's upstream branch and opens or refreshes a pull request for review. Updates are merged manually. This fork does not self-update from upstream releases; pull the fork’s latest source and rebuild to update it.
>
> For full details of each change, see the [commits list](https://github.com/coledeb/vorssaint-utils/commits/main).

## Install only what you use

Choose individual features or start with a preset. Uninstalled features stop loading and disappear from the interface; reinstalling restores their settings. Setup asks only for the permissions your choices need.

<p align="center">
  <img src="docs/assets/readme/features-hub.png" width="720" alt="The Features hub in Settings, installing and uninstalling whole features">
</p>

Reorder or hide panel sections, choose a compact layout, and export settings to another Mac. The app supports more than a dozen languages.

## Everything it does

### Sound

- **Volume mixer.** Set volume per app, boost quiet audio past 100%, and pin or reorder favorites. No audio driver required.
- **Per app output.** Play music through speakers while a call uses your headset.
- **Output switcher.** Switch audio outputs with a shortcut and lower the volume when headphones disconnect.
- **Microphone tools.** Choose a preferred input, adjust its level on supported devices, and mute all microphones with one shortcut.
- **Music app blocker.** Prevent unwanted Music launches after detected playback-button presses. Requires Accessibility.

### Know what your Mac is doing

- **System monitor.** CPU, GPU, memory, temperatures, battery health and power use, with history graphs and a view of energy-hungry apps.
- **Fan Control (beta).** Set manual fan speeds or temperature curves and monitor live RPM.
- **Menu bar readouts.** Put your chosen readings, usage bars, battery time or fan speed directly in the menu bar.
- **Network.** See live traffic, session totals and your local IP address, or run a speed test.
- **Alerts.** Get notified about sustained CPU load, high temperatures, memory pressure, low disk space or low battery.

### Windows and the Dock

- **App switcher.** Switch between apps and windows with live previews, search and display filters. A simpler mode works without screen capture.
- **Window layout.** Snap windows into layouts, move them between displays and restore earlier positions using shortcuts, screen edges or modifier-drag gestures.
- **Dock Preview.** Hover over Dock icons to preview windows across desktops. Switch, close, move or snap them from the preview.
- **Dock clicks.** Click an active app's Dock icon to minimize, hide or cycle through its windows.
- **Maximize windows.** Use the green button to fill the screen without creating another Space.
- **Fixed Space order.** Keep Spaces in the order you set instead of rearranging them by recent use. Turning it off restores your previous setting.
- **Quit on close.** Quit selected apps when their last window closes.
- **Quit and close protection.** Prevent accidental ⌘Q or ⌘W with a hold, double press or extra modifier, per app.

<p align="center">
  <img src="docs/assets/readme/quit-protection-hold.png" width="300" alt="The hold-to-confirm prompt showing progress below the Command-Q quit shortcut hint">
</p>

<p align="center">
  <img src="docs/assets/readme/window-switcher.gif" width="540" alt="The window switcher showing live thumbnails of open windows">
</p>

### Keyboard and mouse

- **Text snippets.** Expand short triggers into text with clipboard, date and time variables, or insert snippets from a searchable menu.
- **Smooth scrolling.** Give your mouse wheel a fluid glide with adjustable speed and response.
- **Pointer acceleration.** Disable mouse acceleration and restore your previous setting when turned off.
- **Linear scrolling.** Make every mouse wheel notch scroll the same number of lines, however fast the wheel spins.
- **Focus follows mouse.** Bring the window under the pointer forward after an adjustable pause.
- **Scroll direction.** Invert vertical and horizontal mouse scrolling independently of the trackpad.
- **Scroll sideways while holding a key.** Turn vertical wheel movement into horizontal scrolling while holding a chosen key.
- **Side buttons.** Use mouse Back and Forward buttons in Finder, browsers and compatible apps.
- **Mouse button shortcuts.** Assign keys to extra buttons and side wheels, or use button-drag gestures for Spaces and Mission Control.
- **Middle click.** Turn a three-finger trackpad press into a middle click.
- **Apps to leave alone.** Exclude chosen apps from mouse enhancements.
- **Extra click filter.** Ignore accidental rapid clicks from worn mouse buttons without delaying normal clicks.
- **Key debounce.** Filter repeated letters caused by a worn keyboard.
- **Super key.** Use Caps Lock or a right-side modifier as a shortcut combination, with a separate tap action and app exclusions.
- **Keyboard shortcuts.** Manage feature shortcuts in one place, including optional takeover of supported macOS shortcuts while a feature is active.

### Clipboard, files and links

- **Clipboard history.** Search local text, image and file history, pin favorites, preview entries and paste with shortcuts.
- **Auto clear clipboard.** Clear the system clipboard after a delay, sleep or lock, while keeping saved history.
- **Paste as plain text.** Paste without formatting while preserving the original clipboard content.
- **Shelf.** Park files, text and links near your cursor while dragging, then drop or share them later.
- **Finder shortcuts.** Move files with ⌘X and ⌘V, rename with F2, or paste copied images as PNG files.
- **Clean URL.** Remove tracking parameters from links, manually or automatically.
- **Disk image installer.** Install an app from a mounted disk image and eject it, with optional download cleanup.

### Everyday tools

- **Dynamic Island.** Keep music, notifications, calendars, timers, downloads and everyday controls around the camera cutout, or a simulated one on other Macs. Customize sections and shortcuts, with optional lyrics, a live equalizer, camera preview and file tools.
- **AI agents.** Follow Claude, Codex, OpenCode and GitHub Copilot in the Dynamic Island: plan limits and when they reset where available, tokens, API value, models, projects and live work, with a notice when a long task finishes. Codex's banked resets can be used from there too, and each extra Codex account (`CODEX_HOME`) can have a limits card of its own. Copilot uses local CLI/app session logs; its token totals update when shutdown metrics arrive, and aggregate API-value estimates use base rates.
- **Command Bar.** Search apps, windows, files, clipboard history, snippets and app menu commands from one field. Calculate, convert units, find emoji or run saved scripts.
- **Quick panel.** Open a floating palette of favorite tools with ⌃⌘V.
- **Quick toggles.** Switch appearance, hide desktop icons, eject disks, empty the Trash, lock the screen and more.
- **Radial menu.** Open a customizable wheel of apps, files, shortcuts and tools around the pointer, with profiles and submenus.
- **Scratchpad.** Keep autosaved notes in tabs, with Markdown preview and export, in a floating window or Dynamic Island.
- **Cleaning Mode.** Lock keyboard input while cleaning, with a black screen or a small visible indicator.

### Capture and create

- **Screen capture.** Switch between screenshots, recording, text recognition and color picking in one selector with a pixel magnifier.
- **Screenshot.** Capture an area, window, screen or scrolling page. Annotate, crop, redact, add backgrounds and watermarks, pin captures, send them through the Share menu or share an expiring link.
- **Screen recording.** Record with separate system-audio and microphone tracks. Trim, cut, add automatic zooms, blur private details and export video or GIFs, or share an expiring link.
- **Camera preview.** Check your camera in a floating mirror or Dynamic Island before a call.
- **Copy text from screen.** Recognize text offline from any screen area, or read a QR code.
- **Color picker.** Copy a screen color as HEX, RGB, HSL or SwiftUI code.
- **Media tools.** Compress and edit videos, batch-convert images, add watermarks, make GIFs and extract text, all locally.

### App management

- **App updates.** Check store apps, package-managed apps and supported developer feeds in one list. Install managed updates together or open an app's own updater.
- **Cleaner.** Remove caches, logs and app leftovers, manually or on a schedule.
- **Messaging downloads.** Review, organize or move messaging downloads to the Trash using retention rules.
- **Uninstaller.** Remove apps and review their related caches, preferences and helpers before moving them to the Trash.
- **Homebrew manager.** Search, install and remove formulae and casks without opening a terminal.
- **Port manager.** Find processes listening on network ports and stop them with Kill Process when installed.

### Energy and display

- **Keep awake.** Keep your Mac working on a timer, with the lid closed, or while selected apps, power or external displays are present.
- **Displays.** Control individual displays and brightness, with hardware control where supported, half or quarter steps for the brightness keys, optional extra dimming below a monitor's minimum, and software dimming as a fallback.
- **Extra brightness.** Use a MacBook Pro XDR display's HDR headroom to go beyond its normal maximum brightness.
- **Bluetooth on sleep.** Disconnect Bluetooth during sleep and restore it on wake only if Vorssaint turned it off.

## Install

This fork is currently distributed as source; it has no published app releases.
Follow [Build it yourself](#build-it-yourself) below to build the customized app.

The app and executable are both named **Vorssaint**. Installation uses
`/Applications/Vorssaint.app`, so it can replace the official app in the same
location. Its bundle ID, `com.coledeb.vorssaint.utils`, keeps its preferences,
stored data, permissions and fan helper separate from upstream’s
`com.vorssaint.utils` identity. Replacing the app does not remove or import
upstream’s settings or data. Grant the fork its own macOS permissions when asked.

Portable settings from the previous local `com.vorssaint.utils.dev` build are
copied once, without overwriting existing fork settings. Stored history, folder
grants and system recovery state remain with the old build.

### Official upstream app

The Homebrew cask and [upstream releases](https://github.com/vorssaint/vorssaint-utils/releases)
install the official app, without this fork’s customizations:

```sh
brew install --cask vorssaint
```

Official upstream releases are Developer ID signed and notarized. Local builds
made with this fork’s helper use ad-hoc signing; they are not notarized, and
permissions may need to be granted again after a rebuild.

## Uninstall

Use **Settings → Advanced** in the fork to uninstall it completely, or run this
from the fork’s source checkout:

```sh
./Tools/uninstall.sh
```

The script removes the fork’s app, settings, stored data and permissions. It
checks the installed app’s bundle ID and refuses to remove the official app.
Upstream’s separate settings and stored data are left in place.

For an official Homebrew installation, use `brew uninstall --cask vorssaint`.
The cask targets the same app path, so avoid using it to manage the fork.

## Private by default

Vorssaint is local-first, with no account, analytics or tracking. The network is touched only by things you can see: update checks, the speed test, Homebrew actions, optional online lyric lookup, temporary screenshot or recording links and feedback you explicitly send. The full story is in the [privacy notes](docs/PRIVACY.md).

Permissions get the same treatment. Every one is optional, the app explains each in plain words, shows which features actually use it, and even tells you when a permission you granted is no longer needed by anything, with a shortcut to revoke it.

<p align="center">
  <img src="docs/assets/readme/permissions.png" width="720" alt="The Permissions page showing what each permission does, which features use it, and an unused permission warning">
</p>

See the [permissions guide](docs/PERMISSIONS.md) for which features need access and what remains available without it.

## What you need

- A Mac with Apple Silicon
- macOS 14 Sonoma or newer

### Build it yourself

```sh
git clone https://github.com/coledeb/vorssaint-utils.git
cd vorssaint-utils
python3 Tools/build-local.py --dev
open build/stage.noindex/Vorssaint.app
```

To install at `/Applications/Vorssaint.app` instead:

```sh
python3 Tools/build-local.py --dev --install
open /Applications/Vorssaint.app
```

The install command replaces an existing official app, this fork, or its old
local development build at that path. It stops the matching app by bundle ID
before replacement and leaves upstream’s settings and data intact.

To update this fork, pull its latest source and repeat the build:

```sh
git pull --ff-only
python3 Tools/build-local.py --dev
```

Quit the running copy before opening the rebuilt app. If you use the installed
copy, repeat the install command instead.

Xcode Command Line Tools and Python 3 are required. The
[contributing guide](CONTRIBUTING.md) covers the layout and conventions.
Official upstream builds come from the upstream maintainer; this is a personal
fork. See [LICENSE](LICENSE) and [TRADEMARKS.md](TRADEMARKS.md) for the upstream
licensing and branding notices.

## When something misbehaves

See [troubleshooting](docs/TROUBLESHOOTING.md) for launch problems, permissions and missing previews. The [support guide](SUPPORT.md) explains the current fork and upstream reporting options.

## Documentation

- [Privacy](docs/PRIVACY.md), what does and does not leave your Mac
- [Permissions](docs/PERMISSIONS.md), every macOS permission in plain words
- [Troubleshooting](docs/TROUBLESHOOTING.md), the common fixes
- [Contributing](CONTRIBUTING.md), build, layout and conventions
- [Support](SUPPORT.md), fork and upstream support availability
- [Security](SECURITY.md), how to report a vulnerability

## Community

The upstream Vorssaint project went from first commit to the front of GitHub trending in three days, top of the Swift charts, and issues and pull requests have shaped every release since. Bug reports, feature ideas and translations are all welcome, starting from the [contributing guide](CONTRIBUTING.md).

Vorssaint is free and will stay that way. If it earned its place in your menu bar, a star helps other people find it, and a [coffee](https://buymeacoffee.com/vorssaint) supports the upstream maintainer, with or without the Keep awake feature.

## Acknowledgements

- App icon designed by [@divisionseven](https://github.com/divisionseven)

## License

[GPL 3.0 or later](LICENSE), copyright 2026 Vorssaint. The license covers the source code; the Vorssaint name, logo and look are covered separately in [TRADEMARKS.md](TRADEMARKS.md).

<p align="center">
  <sub>Made by <a href="https://x.com/vorssaint">@vorssaint</a></sub>
</p>

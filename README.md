# DS4Mac

DS4Mac is a native macOS menu bar app for running a local `ds4-server` sidecar.
It provides a graphical workflow for selecting a GGUF model, configuring the
runtime, starting or stopping the service, and viewing service logs without
manually using Terminal flags.

The project is currently in early v0.1 development. The base SwiftUI interface
and local service launcher are running, including sidecar embedding, parameter
configuration, readiness checks, log capture, and app-fronting behavior for the
menu bar and Settings windows.

## What It Does

- Runs as a macOS menu bar app.
- Starts, stops, and restarts a bundled `ds4-server` process.
- Lets users choose a local GGUF model file from Settings.
- Exposes configurable ds4 runtime options such as `--ctx`, `--tokens`,
  `--backend`, `--threads`, `--kv-disk-dir`, and `--kv-disk-space-mb`.
- Captures stdout and stderr from the service into an in-app log view.
- Copies the local OpenAI-compatible API base address for agent clients.

## Project Layout

- `DS4Mac/`: SwiftUI app source.
- `DS4MacTests/`: Unit tests for configuration and command generation.
- `DS4MacUITests/`: App launch UI tests.
- `Vendor/ds4/`: Pinned ds4 source checkout used to build the sidecar.
- `scripts/`: Helper scripts for building and embedding `ds4-server`.

## Build And Run

Clone the project with its ds4 submodule:

```sh
git submodule update --init --recursive
```

Open `DS4Mac.xcodeproj` in Xcode and run the `DS4Mac` scheme.

The Xcode build embeds the sidecar automatically by running:

```sh
scripts/build-sidecar.sh "$TARGET_BUILD_DIR/$WRAPPER_NAME"
```

For manual sidecar refreshes:

```sh
scripts/update-ds4.sh
```

After launching the app, open Settings, choose a GGUF model, then start the
service from the menu bar.

## Current Progress

Implemented for the first commit:

- Native menu bar app shell.
- SwiftUI Settings window with Service, Runtime, KV Cache, and Logs tabs.
- Persistent JSON-backed settings in `UserDefaults`.
- Automatic sidecar build and app bundle embedding from `Vendor/ds4`.
- `ds4-server` launch command generation using ds4-style flag names.
- Safe service startup with model/engine validation.
- Readiness polling through `/v1/models`.
- stdout/stderr capture into recent in-memory logs and `ds4-server.log`.
- `DS4_LOCK_FILE` environment setup so the sidecar does not depend on
  `/tmp/ds4.lock` from inside app launch contexts.
- App activation helpers for status menu and Settings windows.
- Unit coverage for command generation, legacy default migration, and log
  clearing.

Validated locally:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project DS4Mac.xcodeproj \
  -scheme DS4Mac \
  -configuration Debug \
  build

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project DS4Mac.xcodeproj \
  -scheme DS4Mac \
  -configuration Debug \
  test
```

## Roadmap

### v0.1

- Polish first-run setup and empty-state guidance.
- Improve validation messages in Settings before launch.
- Add a compact diagnostics export.
- Prepare basic app icon and release metadata.

### v0.2

- First-run model installer wizard.
- Download resume and checksum validation.
- Recommended model selection based on available memory and disk space.
- Better diagnostics and exportable support bundle.

### v0.3

- Automated ds4 update workflow.
- Signed and notarized app distribution.
- DMG packaging.
- More complete status and health reporting.

## Non-Goals For Now

- No built-in chat UI.
- No multi-model router.
- No cloud account or hosted service integration.
- No automatic background update system yet.

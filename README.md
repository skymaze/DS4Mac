# DS4Mac

DS4Mac is a native macOS menu bar app for running a local `ds4-server` sidecar.
It provides a graphical workflow for selecting a GGUF model, configuring the
runtime, starting or stopping the service, and viewing service logs without
manually using Terminal flags.

The project is in early development. The SwiftUI interface and local service
launcher are functional: sidecar embedding, parameter configuration, readiness
checks, log capture, app-fronting for the menu bar and Settings windows, model
download and management, and localization.

## What It Does

- Runs as a macOS menu bar app.
- Starts, stops, and restarts a bundled `ds4-server` process.
- **Models tab** — download recommended models from the catalog, view local
  `.gguf` files in `Models/main/` and `Models/mtp/` directories.
- **Service tab** — displays the selected model path with a shortcut to the
  Models tab for switching.
- Exposes configurable ds4 runtime options including `--ctx`, `--tokens`,
  `--backend`, `--threads`, `--host`, `--port`, `--cors`, and the full set of
  KV cache and speculative decoding flags.
- Captures stdout and stderr from the service into an in-app log view.
- Copies the local OpenAI-compatible API base address for agent clients.

### Engine Selection

- Builds two `ds4-server` variants at build time:
  - **Baseline** (`-mcpu=apple-m1`) — compatible with all Apple Silicon Macs.
  - **Optimized** (`-mcpu=native`) — leverages M4+ features like SME.
- Detects hardware at runtime and selects the best engine automatically.
- Users can override: Automatic, Metal baseline, Metal M4+ optimized, or a
  custom executable path.

### KV Cache Management

- Reports current on-disk KV cache size with a usage bar in Settings.
- Provides Refresh and Clear Cache actions (service must be stopped first).

### Localization

- English and Simplified Chinese (`Localizable.xcstrings`).

## Project Layout

- `DS4Mac/`: SwiftUI app source.
- `DS4MacTests/`: Unit tests.
- `DS4MacUITests/`: App launch UI tests.
- `Vendor/ds4/`: Pinned ds4 source checkout used to build the sidecar.
- `scripts/`: Helper scripts for building and embedding `ds4-server`.

## Build And Run

```sh
git clone --recurse-submodules https://github.com/aixn/DS4Mac.git
# or
git submodule update --init --recursive
```

Open `DS4Mac.xcodeproj` in Xcode and run the `DS4Mac` scheme. The "Embed ds4
Sidecar" build phase runs `scripts/build-sidecar.sh` automatically.

For manual sidecar refreshes:

```sh
scripts/update-ds4.sh [ref]
```

After launching the app, open Settings to download or select a model, then
start the service from the menu bar.

## Next Steps

- First-run setup experience and empty-state guidance.
- App icon, signed and notarized distribution, DMG packaging.
- Diagnostics export and support bundle.

## Non-Goals

- No built-in chat UI.
- No multi-model router.
- No cloud account or hosted service integration.

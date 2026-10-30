# Changelog

Notable changes to Vapor, called DXMetal before 2.0.0. Version numbers follow [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-10-30

DXMetal is now **Vapor**. Open the Vapor app and click **Move to Vapor**: it moves your install across, keeping Steam, your games, sign-ins and settings.

### Changed

- Renamed DXMetal to Vapor. The app is now called Vapor, and the install it manages is `~/Games/Vapor Steam.app`.
- New installs use the DXMT translator by default. D3DMetal is still one click away, and DirectX 12 games need it.

### Added

- Updates that keep your games. When a release brings newer versions of the wrapper, Wine or the translators, Vapor shows **Update**: it builds a fresh wrapper and moves your Windows drive into it, so Steam, games, sign-ins and settings stay. `setup.sh` does the same from Terminal.
- Vapor updates itself. It checks GitHub once a day, and **More → Check for Updates…** checks straight away. Updates are checked against the release's `SHA256SUMS` before they're installed.
- **Show Steam**, which brings back Steam's window while it's running.
- **Clear Caches…**, which deletes the shader caches, and **Uninstall Vapor Steam…**, which removes everything. Both ask Yes or No first. `clear-caches.sh` does the former from Terminal, and `uninstall.sh` now removes the caches too.
- **Copy Diagnostics**, for bug reports, without names, file paths or accounts. `diagnostics.sh` prints the same.
- Setup checks there's enough free space before downloading.
- A daily GitHub Action proposes newer wrapper and Wine releases in a pull request, and every version tag is built and published by GitHub.
- `SECURITY.md`, explaining how to report a vulnerability.

## [1.0.0] - 2026-10-29

The first tagged release, as DXMetal.

### Added

- `setup.sh` builds `~/Games/DXMetal.app` (the Sikarugir wrapper with Wine 11, D3DMetal and DXMT) from downloads checked against pinned SHA-256 checksums, then installs Windows Steam. It finishes in one run and is safe to run again.
- `run-steam.sh` starts Steam with up to four switches: scaled or Retina resolution, D3DMetal or DXMT, the Metal performance overlay, and MetalFX upscaling. Switches you leave off keep their current value.
- MetalFX spatial upscaling, for DXMT at scaled resolution.
- Double-clicking `DXMetal.app` applies every setting, including MetalFX.
- DXMetal Settings, a Mac app that installs DXMetal, changes the settings (locked while Steam runs) and starts or quits Steam. It's attached to this release as a disk image.
- `status.sh`, `close-wine.sh` and `uninstall.sh`.

### Security

- Setup makes `DXMetal.app`, which holds your sign-ins, readable only by your Mac account.
- The scripts use macOS's own tools, whatever else is in your PATH.
- DXMetal Settings is signed with the hardened runtime, and contains no accounts or personal details.

[2.0.0]: https://github.com/rhas1/Vapor/releases/tag/v2.0.0
[1.0.0]: https://github.com/rhas1/Vapor/releases/tag/v1.0.0

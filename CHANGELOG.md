# Changelog

Notable changes to DXMetal. Version numbers follow [Semantic Versioning](https://semver.org).

## [1.0.0] - 2026-10-29

The first tagged release.

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

[1.0.0]: https://github.com/rhas1/DXMetal/releases/tag/v1.0.0

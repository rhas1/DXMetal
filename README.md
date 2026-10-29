# DXMetal

Play Windows-only Steam games on an Apple Silicon Mac, including online with friends on Windows PCs.

These scripts build one self-contained app, `~/Games/DXMetal.app`, that holds:

- **Wine 11**, which lets Windows programs run on macOS
- **D3DMetal** (by Apple) and **DXMT** (open source), two translators that turn a game's DirectX graphics into Metal. You can choose which one to use.
- **Windows Steam**, and the games you install through it

Nothing else is installed on the Mac apart from Rosetta 2. You don't need Homebrew, Xcode or an Apple developer account.

## Requirements

- A Mac with Apple Silicon (M1 or newer). Intel Macs won't work.
- macOS 14.6 or newer
- About 4 GB of free space for Wine and Steam, plus room for your games. Try to keep 20 GB or more free beyond that.
- Your Mac password, only needed if Rosetta 2 has to be installed
- 16 GB of memory is recommended. 8 GB works, but close other apps while playing.

## Setup (once per Mac)

Prefer not to use Terminal? Open the [DXMetal Settings app](#dxmetal-settings-app), click **Install**, then **Start Steam**, and continue from step 4.

1. Copy this folder to the Mac (AirDrop, USB stick or `git clone`).
2. Open **Terminal**, go into the folder and run the setup:
   ```
   cd ~/Downloads/dxmetal      # wherever the folder is
   zsh scripts/setup.sh
   ```
   This takes a few minutes. It:
   - checks that the Mac has Apple Silicon and macOS 14.6 or newer
   - installs Rosetta 2 if it's missing. This accepts Apple's Rosetta license on your behalf, and it may ask for your password.
   - downloads the Sikarugir wrapper and Wine 11 (about 250 MB), checks that both files are exactly the expected versions, and builds `~/Games/DXMetal.app`
   - installs Windows Steam into it, using Valve's own installer
   - applies the default settings (scaled resolution, D3DMetal, FPS overlay off, MetalFX upscaling off), marks the app as a game for macOS Game Mode, and excludes it from Time Machine backups
3. Start Steam and sign in with your Steam account:
   ```
   zsh scripts/run-steam.sh
   ```
4. Install your games through Steam as usual.
5. Click **Play**. A game's first launch may install Windows components it needs, such as Visual C++ or DirectX runtimes, which takes a minute. Some games also ask you to sign in to their publisher's account.

> **Tip:** if `./scripts/something.sh` says "permission denied", run it as `zsh scripts/something.sh` instead. Copying the folder can remove the permission that lets the scripts run directly.

## Everyday use

Run these from the `dxmetal` folder. You can also `cd scripts` first and leave out the `scripts/` part.

| To... | Run |
|---|---|
| Start Steam with your current settings | `./scripts/run-steam.sh`, or double-click `~/Games/DXMetal.app` |
| Start Steam with different settings | `./scripts/run-steam.sh RETINA DXMT HUD METALFX`, e.g. `./scripts/run-steam.sh 0 1 0 1` (see below) |
| Do any of these without Terminal | Open the [DXMetal Settings app](#dxmetal-settings-app) |
| See the settings, and which translator a running game uses | `./scripts/status.sh` |
| Quit Steam and Wine | Steam menu → **Exit**, or `./scripts/close-wine.sh` |

`run-steam.sh` starts Steam in the background, so you can close the Terminal window afterwards. Closing Steam's window only hides it to the menu bar. To bring it back, run `./scripts/run-steam.sh` again.

## Launch arguments

`run-steam.sh` takes up to four arguments, each `0` or `1`. Any you leave off keep their current setting, so `./scripts/run-steam.sh` on its own changes nothing.

```
./scripts/run-steam.sh RETINA DXMT HUD METALFX
```

| Argument | `0` | `1` |
|---|---|---|
| `RETINA` (1st) | **Scaled:** games see your screen at its scaled ("looks like") size. Faster. | **Retina:** games can use the full Retina resolution, about 4× the pixels. Sharper, but much heavier. |
| `DXMT` (2nd) | **D3DMetal**, Apple's translator, for DirectX 11 and 12 games | **DXMT**, an open-source translator for DirectX 10 and 11 games that's sometimes faster |
| `HUD` (3rd) | No overlay | **Metal performance overlay** in games, showing FPS and frame timing |
| `METALFX` (4th) | No upscaling | **MetalFX upscaling:** Apple's MetalFX upscales each frame to twice its resolution, so games at scaled resolution look close to Retina-sharp at about the same speed. DXMT at scaled resolution only. Experimental. |

Some examples:

| Command | Result |
|---|---|
| `./scripts/run-steam.sh 0 0 0 0` | Scaled resolution, D3DMetal, no overlay, no upscaling (the defaults) |
| `./scripts/run-steam.sh 0 1 0 1` | Scaled resolution, DXMT, with MetalFX upscaling |
| `./scripts/run-steam.sh 0 1 1` | Scaled resolution, DXMT, with the FPS overlay. MetalFX stays as it was. |
| `./scripts/run-steam.sh 1 0` | Retina resolution, D3DMetal. The rest stays as it was. |
| `./scripts/run-steam.sh` | Keep the current settings |

The settings are remembered, so you only need arguments when you want to change something. They apply to every game you launch from Steam.

- **Settings can only change while Steam is closed.** If Steam is running with different settings, the script stops and tells you. To switch in one step: `./scripts/close-wine.sh && ./scripts/run-steam.sh 0 1 0 1`
- After changing the resolution mode, pick the resolution again in each game's display settings.
- **About MetalFX upscaling:**
  - It only switches on with DXMT at scaled resolution. If it's on while you use D3DMetal or Retina, it stays inactive, and `status.sh` says so.
  - It also upscales Steam's own window, because Steam's interface runs on DXMT.
  - With the overlay on, DXMT adds a "MetalFX: Spatial" line to it while upscaling is active.
  - It's experimental: DXMT describes itself as not yet ready for general users.
- Each translator builds its own cache of a game's converted shaders (the small programs that draw effects). After switching, expect stutter the first time through each area. To compare the two fairly, play the same section twice on each with the overlay on, and compare the FPS on the second pass.

## DXMetal Settings app

A small Mac app that does the same as the scripts, with switches instead of arguments. It shows whether Steam is running and which game is running, and has:

- **Install**, while DXMetal isn't installed yet. It runs `setup.sh`, installing Rosetta 2 first if it's missing, which asks for your password.
- A switch for each of the four settings, saved as soon as you change them. Steam only reads them when it starts, so they're locked while it runs.
- **Start Steam**, or **Quit Steam** while it's running. If a game is running, it asks first, because unsaved progress would be lost.

Settings are saved in `DXMetal.app` itself, so double-clicking `~/Games/DXMetal.app` uses them too.

**Building it** needs Apple's free Command Line Tools (`xcode-select --install`), not the full Xcode:

```
zsh app/build.sh
```

This creates `app/build/DXMetal Settings.app`; move it to your Applications folder. The scripts are bundled inside it, so build it again after changing them.

**Giving it to another Mac:** send `app/build/DXMetal Settings.zip`, and double-click it there to unzip the app. The app runs on any Apple Silicon Mac with macOS 14 or newer, without the Command Line Tools, and holds no accounts or personal details: just the program, its icon and the scripts. It isn't signed with a paid Apple developer account, so if it arrives by AirDrop or download, macOS blocks it the first time. Try to open it, then go to System Settings → Privacy & Security and click **Open Anyway**.

## Compatibility

Each game is different, so check [Tested games](#tested-games) or just try it. In general:

- **DirectX 11 games** work with either translator. Try D3DMetal first, and DXMT if you want to compare speed or D3DMetal has problems.
- **DirectX 12 games** need D3DMetal (second argument `0`), because DXMT only handles DirectX 10 and 11.
- **32-bit DirectX 10 or 11 games** need DXMT (second argument `1`), because D3DMetal only supports 64-bit games.
- **Older DirectX 9 games** are handled by the wrapper's own DirectX 9 translator (D9VK, via Vulkan), which is switched on by default. They haven't been tested with these scripts.
- **Games whose anti-cheat doesn't support Wine** usually won't run. This is common in competitive online games.

`./scripts/status.sh` shows which translator a running game is actually using.

## Tested games

| Game | Translator | Result | Notes |
|---|---|---|---|
| It Takes Two | D3DMetal and DXMT | Works | Tested with the free Friend's Pass on a MacBook Air M3 (16 GB) running macOS 27. The EA account sign-in works in the Steam overlay. A harmless Steam networking warning (`steamerrorreporter`) appears once at launch. |

Tested another game? Add a row with the translator you used, and anything worth knowing.

## Tips for smooth games

- **Play in fullscreen.** The app is marked as a game, so macOS may switch on Game Mode (🎮 in the menu bar), which gives the game priority and reduces Bluetooth controller lag.
- **Cap the frame rate** at your screen's refresh rate: 60 on most MacBooks. Anything higher only produces extra heat.
- **VSync off** makes the controls feel more responsive. Turn it on if you see tearing, a horizontal split line across the picture when the camera turns fast.
- **Keep resolution scale at 100%.** Games already run below Retina resolution by default, so only lower it as a last resort.
- **For a sharper picture without the cost of Retina,** try MetalFX upscaling with DXMT: `./scripts/run-steam.sh 0 1 0 1`. If a game has its own FSR or DLSS option, you can also try that.
- **Start with High quality.** If the FPS dips, lower shadows and effects first.
- **On a MacBook Air:** it has no fan, so if the FPS starts swinging after 20–30 minutes, cap the frame rate at 30. A steady 30 feels better than a jumpy 40–55. Keep the Mac plugged in, with Low Power Mode off.

## Playing online

Online play works as it does on Windows: friends, invites and matchmaking go through Steam and the game as usual, and players on Windows PCs see the Mac as just another player. 5 GHz Wi-Fi or Ethernet helps. Turn off any VPN.

## Files

```
dxmetal/
├── README.md
├── LICENSE
├── .gitignore
├── scripts/
│   ├── setup.sh
│   ├── run-steam.sh
│   ├── status.sh
│   ├── close-wine.sh
│   ├── uninstall.sh
│   └── config.sh
└── app/
    ├── DXMetalSettings.swift
    ├── build.sh
    └── AppIcon.icns
```

| File | What it does |
|---|---|
| `scripts/setup.sh` | Installs everything (see [Setup](#setup-once-per-mac)). It's safe to run again: it skips finished steps, picks up where a failed run stopped, and keeps your settings. Steam must be closed. |
| `scripts/run-steam.sh` | Starts Steam, optionally changing the resolution mode, translator, overlay and MetalFX upscaling first (see [Launch arguments](#launch-arguments)). |
| `scripts/status.sh` | Shows the current settings, whether Steam/Wine is running, and which translator a running game is actually using. |
| `scripts/close-wine.sh` | Quits everything running in Wine, including other Wine apps such as CrossOver. It asks before closing a running game, because unsaved progress is lost. It then asks Steam to exit properly, so Steam saves its state, and force-quits anything still running after 60 seconds. |
| `scripts/uninstall.sh` | Deletes `~/Games/DXMetal.app`, **including Steam, all installed games and saved sign-ins**, after asking you to confirm. Steam must be closed. Run `setup.sh` afterwards to install again. |
| `scripts/config.sh` | Shared settings and helpers used by the other scripts: where the app lives, the pinned download links and their checksums, and how settings are read and changed. You don't run it directly. |
| `app/DXMetalSettings.swift` | The source code of the [DXMetal Settings app](#dxmetal-settings-app): one window that runs the scripts above. |
| `app/build.sh` | Builds the app into `app/build/`, plus a zip of it for sending to another Mac. |
| `app/AppIcon.icns` | The app's icon. |
| `.gitignore` | Keeps built apps and downloaded files out of git. |
| `LICENSE` | The MIT license for these scripts. |
| `README.md` | This file. |

## Troubleshooting

| Problem | Fix |
|---|---|
| A game won't start, or shows a black screen | Try the other translator: `./scripts/close-wine.sh && ./scripts/run-steam.sh 0 1` for DXMT, or `0 0` for D3DMetal. Also check [Compatibility](#compatibility). |
| "Steam is running with ..." when changing settings | Run `./scripts/close-wine.sh`, then `./scripts/run-steam.sh` with the new arguments. |
| `setup.sh` or `uninstall.sh` says "Quit Steam" | Run `./scripts/close-wine.sh` first. |
| Setup fails partway | Run `zsh scripts/setup.sh` again: it picks up where it stopped. If it keeps failing, run `./scripts/uninstall.sh` and then `zsh scripts/setup.sh`, and save the Terminal output to troubleshoot with. |
| "Checksum mismatch" during setup | A download isn't the expected file. Setup stops without using it. Try again later, or check for a newer version of these scripts. |
| Stutter the first time through an area | Normal: the translator is converting the game's shaders for the first time. It's smooth on the next visit. |
| Stutter comes back after it was smooth | macOS deletes caches when disk space runs low. Keep 20 GB or more free. |
| Glitches or crashes with DXMT | Switch back to D3DMetal: `./scripts/close-wine.sh && ./scripts/run-steam.sh 0 0 0 0` |
| The picture, or Steam's window, looks wrong with MetalFX upscaling | Turn upscaling off: `./scripts/close-wine.sh && ./scripts/run-steam.sh 0 1 0 0` |
| macOS says DXMetal Settings "can't be opened" or can't be checked for malware | Expected for a copy that arrived by AirDrop or download. Go to System Settings → Privacy & Security and click **Open Anyway** (once). |
| Every controller press happens twice | In Steam, right-click the game → **Properties** → **Controller** → **Disable Steam Input**. |
| `steamerrorreporter` appears briefly after launching a game | Harmless. It's a known warning from Steam's networking code under Wine, and the game keeps running. |

## Updating Wine

Steam and your games update themselves. Wine and the wrapper stay at the versions pinned in `scripts/config.sh` until you change them. If a future Steam update stops working, a newer Wine engine usually fixes it:

1. Find a newer release on [Sikarugir-App/Engines](https://github.com/Sikarugir-App/Engines/releases) (Wine) or [Sikarugir-App/Template](https://github.com/Sikarugir-App/Template/releases) (wrapper).
2. In `scripts/config.sh`, update `ENGINE_URL` or `TEMPLATE_URL` **and** the matching `ENGINE_SHA256` or `TEMPLATE_SHA256`. GitHub lists each file's SHA-256 on the release page, or you can run `shasum -a 256` on the downloaded file.
3. Rebuild: `./scripts/close-wine.sh`, then `./scripts/uninstall.sh`, then `zsh scripts/setup.sh`. This removes installed games, so they download again, and you sign in to Steam and any game accounts again.

## Privacy

- **Never share or upload your `DXMetal.app`.** It contains your Steam and game sign-ins, cookies and saves. To set up another Mac, copy this folder (or the DXMetal Settings app) to it and install there, rather than copying `DXMetal.app`.
- These scripts contain no accounts, keys or personal details. They only download from GitHub (the wrapper and Wine, checked against pinned checksums) and Valve (the Steam installer).

## How it works

```
┌──────────────────────────────────────────────┐
│ Windows game (unchanged)                     │
├──────────────────────────────────────────────┤
│ Wine 11              Windows → macOS         │  files, windows, input, sound, network
│ D3DMetal or DXMT     DirectX → Metal         │  graphics
├──────────────────────────────────────────────┤
│ Rosetta 2            Intel → Apple Silicon   │  CPU instructions
├──────────────────────────────────────────────┤
│ macOS · Metal · Apple Silicon                │
└──────────────────────────────────────────────┘
```

Neither Steam nor your games are modified. Rosetta 2 translates their Intel code for Apple Silicon. Wine provides the Windows system functions they call, using macOS underneath. D3DMetal or DXMT turns their DirectX graphics into Metal. To other players, the Mac is just another Windows PC.

### Where things live

- `~/Games/DXMetal.app` holds everything:
  - `Contents/SharedSupport/prefix` is the Windows side: Wine's registry, and the C: drive with Steam and your games. `Contents/drive_c` is a shortcut to that C: drive.
  - `Contents/Info.plist` stores the wrapper's settings. To apply MetalFX, DXMetal keeps one line in its "CLI Custom Commands" setting; anything else you add there is kept.
- The shader caches are in the Mac's cache folder: run `open $(getconf DARWIN_USER_CACHE_DIR)` and look in `d3dm/` (D3DMetal) and `dxmt/` (DXMT), with one folder per game.
- **Keeping the app on an external drive:** before running setup, edit the `APP=` line near the top of `scripts/config.sh`, replacing `$HOME/Games/DXMetal.app` with something like `/Volumes/GameSSD/DXMetal.app`. The drive must be formatted as APFS.

## Credits

- [Sikarugir](https://github.com/Sikarugir-App): the wrapper template (1.0.24) and Wine 11 engine, which include D3DMetal and DXMT
- [DXMT](https://github.com/3Shain/dxmt) by 3Shain
- D3DMetal, from Apple's [Game Porting Toolkit](https://developer.apple.com/games/)
- [Wine](https://www.winehq.org), built from CrossOver's sources

## License

The scripts in this repository are released under the [MIT License](LICENSE). The wrapper, Wine, D3DMetal and DXMT that setup downloads are separate projects under their own licenses, and they aren't included in this repository.

Steam, Apple, and the games and publishers mentioned here are trademarks of their respective owners. This project isn't affiliated with any of them.

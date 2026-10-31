# Vapor

Play Windows-only Steam games on an Apple Silicon Mac, including online with friends on Windows PCs.

Vapor comes in two parts:

- **Vapor**, a Mac app that installs, updates and removes everything, changes the settings, and starts or quits Steam.
- **Vapor Steam**, the install it manages, kept in a hidden folder so that only the Vapor app shows up in Spotlight (see [Where things live](#where-things-live)). It holds:
  - **Wine 11**, which lets Windows programs run on macOS
  - **DXMT** (open source) and **D3DMetal** (by Apple), two translators that turn a game's DirectX graphics into Metal. You choose which one to use.
  - **Windows Steam**, and the games you install through it

Nothing else is installed on the Mac apart from Rosetta 2. You don't need Homebrew, Xcode or an Apple developer account. Everything the app does is also available as scripts, for Terminal users.

> **Used Vapor 2.0, or DXMetal (Vapor's name before 2.0)?** Open Vapor and click **Move**. It moves your install out of `~/Games`, where Spotlight finds it, keeping Steam, your games, sign-ins and settings.

## Requirements

- A Mac with Apple Silicon (M1 or newer). Intel Macs won't work.
- macOS 14.6 or newer
- About 5 GB of free space for Wine and Steam, plus room for your games. Try to keep 20 GB or more free beyond that.
- Your Mac password, only needed if Rosetta 2 has to be installed
- 16 GB of memory is recommended. 8 GB works, but close other apps while playing.

## Install

### With the Vapor app

1. Download `Vapor-<version>.dmg` from the [latest release](https://github.com/rhas1/Vapor/releases/latest), open it, and drag **Vapor** onto **Applications**.
2. Open Vapor. The first time, macOS blocks it because it isn't notarized by Apple: go to **System Settings → Privacy & Security**, click **Open Anyway** next to "Vapor" was blocked, and confirm. You only do this once per Mac. (To check the download first, run `shasum -a 256` on it and compare the result with the SHA-256 in the release notes.)
3. Click **Install**. It takes a few minutes:
   - It installs Rosetta 2 if it's missing. This accepts Apple's Rosetta license on your behalf and asks for your password.
   - It downloads the Sikarugir wrapper and Wine 11 (about 250 MB), checks both against pinned checksums, and builds Vapor Steam.
   - It installs Windows Steam, using Valve's own installer, and makes the install private to your Mac account.
4. Click **Start Steam**, sign in with your Steam account, and install your games as usual.
5. Click **Play** in Steam. A game's first launch may install Windows components it needs, such as Visual C++ or DirectX runtimes, which takes a minute. Some games also ask you to sign in to their publisher's account.

### With Terminal

Copy this folder to the Mac (AirDrop, USB stick or `git clone`), then:

```
cd ~/Downloads/Vapor      # wherever the folder is
zsh scripts/setup.sh
zsh scripts/run-steam.sh
```

`setup.sh` does the same as the app's **Install** button. See [Command line](#command-line) for the other scripts.

## Using Vapor

Vapor's window shows whether Steam is running, which game is running, and six settings:

| Setting | Choices |
|---|---|
| Resolution | **Scaled** (default): games see your screen at its "looks like" size. Faster. **Retina**: games can use the full Retina resolution, about 4× the pixels. Sharper, but much heavier. |
| Translator | **DXMT** (default): open source, for DirectX 10 and 11 games, and sometimes the faster one. **D3DMetal**: Apple's translator, for DirectX 11 and 12 games. |
| FPS overlay | Apple's Metal performance overlay in games, showing the frame rate and frame timing |
| MetalFX upscaling | Apple's MetalFX upscales each frame to twice its resolution, so games at scaled resolution look close to Retina-sharp at about the same speed. Works with DXMT at scaled resolution. Experimental. |
| Frame rate limit | **Off** (default), **60** or **30** frames per second, for games without their own limit. 30 keeps a MacBook Air cooler and steadier. Works with both translators. |
| Steam overlay | Steam's in-game overlay (Shift+Tab). **Off** by default, because opening it can freeze a game (see [Troubleshooting](#troubleshooting)). Vapor sets it in Steam's own settings each time it starts Steam. |

- Changes are saved as soon as you make them. Steam only reads the settings when it starts, so they're **locked while Steam is running**: quit Steam to change them.
- After changing the resolution, pick the resolution again in each game's display settings.
- **Start Steam**, **Show Steam** and **Quit Steam** do what they say. Closing Steam's window only hides it to the menu bar; **Show Steam** brings it back. If a game is running, Quit asks first, because unsaved progress would be lost.
- Double-clicking Vapor Steam (see [Where things live](#where-things-live)) also starts Steam with your saved settings.

The **More** menu has:

| Item | What it does |
|---|---|
| Check for Updates… | Looks for a new version of Vapor. When there is one, this reads **Update to Vapor…** instead. See [Updates](#updates). |
| Clear Caches… | Deletes the translators' shader caches, after asking Yes or No. Games rebuild them as you play, so expect some stutter the first time through each area. Useful if a game shows graphics glitches after an update. |
| Copy Diagnostics | Copies versions, settings and status for a bug report. It contains no names, file paths or accounts. |
| Uninstall Vapor Steam… | Deletes Vapor Steam, **including Steam, all installed games, your sign-ins and any saves stored only on this Mac**, plus the shader caches, after asking Yes or No. Then it offers to move Vapor itself to the Trash. Saves in Steam Cloud stay online. |
| Vapor on GitHub | Opens this page. |

**About MetalFX upscaling:**
- It only switches on with DXMT at scaled resolution. If it's on while you use D3DMetal or Retina, it stays inactive, and Vapor says so.
- It also upscales Steam's own window, because Steam's interface runs on DXMT.
- With the FPS overlay on, DXMT adds a "MetalFX: Spatial" line to it while upscaling is active.
- It's experimental: DXMT describes itself as not yet ready for general users.

Each translator builds its own cache of a game's converted shaders (the small programs that draw effects). After switching translators, expect stutter the first time through each area. To compare the two fairly, play the same section twice on each with the overlay on, and compare the FPS on the second pass.

## Updates

| What | How it updates |
|---|---|
| **Vapor** | Each time Vapor opens, it checks GitHub, as soon as the Mac is online. When there's a new version, it shows **Update Vapor**, with a red dot on its Dock icon and on **More**. You can also choose **More → Check for Updates…**. It downloads the new version, checks it against the release's `SHA256SUMS`, replaces itself and restarts. |
| **Wine, the wrapper and the translators** | New Vapor releases bring newer versions. When your install is older, Vapor shows **Update**, with a red dot on its Dock icon: it builds a fresh wrapper and moves your Windows drive into it, so **Steam, your games, sign-ins and settings stay**. Only about 250 MB downloads. It takes a few minutes, mostly while macOS checks the new wrapper, as it does the first time any new app runs. From Terminal, `zsh scripts/setup.sh` does the same. |
| **Steam and your games** | They update themselves, as on Windows. |

The translators come inside the Sikarugir wrapper, so an update brings new versions of D3DMetal, DXMT and DXVK together.

## Command line

Run these from the folder. You can also `cd scripts` first and leave out the `scripts/` part. If one says "permission denied", run it as `zsh scripts/<name>.sh` instead: copying the folder can remove the permission that lets the scripts run directly.

| To... | Run |
|---|---|
| Install, update, or move an install from where an earlier version put it | `zsh scripts/setup.sh` |
| Start Steam with your current settings (or show its window) | `./scripts/run-steam.sh` |
| Start Steam with different settings | `./scripts/run-steam.sh RETINA DXMT HUD METALFX FPS OVERLAY`, e.g. `./scripts/run-steam.sh 0 1 0 1 30` (see below) |
| See the settings, whether an update is ready, and which translator a running game uses | `./scripts/status.sh` |
| Quit Steam and Wine | Steam menu → **Exit**, or `./scripts/close-wine.sh` |
| Clear the shader caches | `./scripts/clear-caches.sh` |
| Print diagnostics for a bug report | `./scripts/diagnostics.sh` |
| Remove everything | `./scripts/uninstall.sh` |

### Launch arguments

`run-steam.sh` takes up to six arguments: `FPS` is `0`, `30` or `60`, and the others are each `0` or `1`. Any you leave off keep their current setting, so `./scripts/run-steam.sh` on its own changes nothing.

```
./scripts/run-steam.sh RETINA DXMT HUD METALFX FPS OVERLAY
```

| Argument | `0` | `1` |
|---|---|---|
| `RETINA` (1st) | Scaled resolution | Retina resolution |
| `DXMT` (2nd) | D3DMetal | DXMT |
| `HUD` (3rd) | No FPS overlay | FPS overlay |
| `METALFX` (4th) | No upscaling | MetalFX upscaling |
| `FPS` (5th) | No frame rate limit | `30` or `60`: limit games to that many frames per second |
| `OVERLAY` (6th) | Steam's in-game overlay off | Steam's in-game overlay on |

| Command | Result |
|---|---|
| `./scripts/run-steam.sh 0 1 0 0 0 0` | Scaled resolution, DXMT, no FPS overlay, no upscaling, no frame rate limit, Steam's overlay off (the defaults) |
| `./scripts/run-steam.sh 0 1 0 1` | Scaled resolution, DXMT, with MetalFX upscaling. The rest stays as it was. |
| `./scripts/run-steam.sh 0 0 1` | Scaled resolution, D3DMetal, with the FPS overlay. The rest stays as it was. |
| `./scripts/run-steam.sh 0 1 0 0 30` | DXMT at scaled resolution, limited to 30 frames per second |
| `./scripts/run-steam.sh 1` | Retina resolution. The rest stays as it was. |

Settings can only change while Steam is closed. To switch in one step: `./scripts/close-wine.sh && ./scripts/run-steam.sh 0 1 0 1`

## Compatibility

Each game is different, so check [Tested games](#tested-games) or just try it. In general:

- **DirectX 11 games** work with either translator. DXMT is the default; try D3DMetal if a game has problems.
- **DirectX 12 games** need D3DMetal, because DXMT only handles DirectX 10 and 11.
- **32-bit DirectX 10 or 11 games** need DXMT, because D3DMetal only supports 64-bit games.
- **Older DirectX 9 games** are handled by the wrapper's own DirectX 9 translator (D9VK, via Vulkan), which is switched on by default. They haven't been tested with Vapor.
- **Games whose anti-cheat doesn't support Wine** usually won't run. This is common in competitive online games.

`./scripts/status.sh` shows which translator a running game is actually using.

## Tested games

| Game | Translator | Result | Notes |
|---|---|---|---|
| It Takes Two | D3DMetal and DXMT | Works | Tested with the free Friend's Pass on a MacBook Air M3 (16 GB) running macOS 27. **Don't use the game's Invite friend button:** it opens the Steam overlay, which freezes the game, a known bug with Wine (see [Troubleshooting](#troubleshooting)). Vapor keeps the overlay off. Create the online session in the game, then invite your friend through Steam's Friends list. A harmless Steam networking warning (`steamerrorreporter`) appears once at launch. |

Tested another game? Add a row with the translator you used, and anything worth knowing.

## Tips for smooth games

- **Close other apps** while playing, especially on 8 GB Macs. macOS Game Mode, which normally does this for you, doesn't turn on for Windows games run through Wine.
- **Cap the frame rate** at your screen's refresh rate: 60 on most MacBooks. Anything higher only produces extra heat. Use the game's own limit, or Vapor's **Frame rate limit** if it has none.
- **VSync off** makes the controls feel more responsive. Turn it on if you see tearing, a horizontal split line across the picture when the camera turns fast.
- **Keep resolution scale at 100%.** Games already run below Retina resolution by default, so only lower it as a last resort.
- **For a sharper picture without the cost of Retina,** turn on MetalFX upscaling with DXMT. If a game has its own FSR or DLSS option, you can also try that.
- **Start with High quality.** If the FPS dips, lower shadows and effects first.
- **On a MacBook Air:** it has no fan, so if the FPS starts swinging after 20–30 minutes, set **Frame rate limit** to 30. A steady 30 feels better than a jumpy 40–55. Keep the Mac plugged in, with Low Power Mode off.

## Playing online

Online play works as it does on Windows: friends, invites and matchmaking go through Steam and the game as usual, and players on Windows PCs see the Mac as just another player. Invite friends through Steam's Friends list rather than a game's own invite button, which opens the Steam overlay and can freeze the game (see [Troubleshooting](#troubleshooting)). Vapor keeps the overlay off unless you turn it on. 5 GHz Wi-Fi or Ethernet helps. Turn off any VPN.

## Troubleshooting

| Problem | Fix |
|---|---|
| macOS says Vapor "can't be opened" or can't be checked for malware | Expected the first time. Go to System Settings → Privacy & Security and click **Open Anyway** (once). |
| A game won't start, or shows a black screen | Try the other translator, and check [Compatibility](#compatibility). |
| Glitches or crashes with DXMT | Switch to D3DMetal. If glitches started after an update, also try **More → Clear Caches…**. |
| The picture, or Steam's window, looks wrong with MetalFX upscaling | Turn MetalFX upscaling off. |
| Setup or an update fails partway | Try again: setup picks up where it stopped. If it keeps failing, choose **More → Copy Diagnostics** and include them, with the setup output, in a bug report. |
| "Not enough free space" | Free up space and try again. Installing needs 5 GB free, and an update 3 GB. |
| "Checksum mismatch" | A download isn't the expected file. Setup stops without using it. Try again later, or update Vapor. |
| "An earlier update didn't finish" | See [An update stopped partway](#an-update-stopped-partway). |
| Stutter the first time through an area | Normal: the translator is converting the game's shaders for the first time. It's smooth on the next visit. |
| Stutter comes back after it was smooth | macOS deletes caches when disk space runs low. Keep 20 GB or more free. |
| A game freezes when the Steam overlay opens, from Shift+Tab or a game's **Invite friend** button: the picture stops but the sound keeps playing | A known bug with Windows Steam's overlay under Wine, which CrossOver has too: Steam stops responding, and the game waits for it. It doesn't recover, so click **Quit Steam** in Vapor, which notices that Steam isn't responding and force-quits it within seconds. Vapor keeps the overlay off for this reason: if you turned on **Steam overlay** in Vapor, turn it off. To play with a friend, create the online session in the game, then invite them through Steam instead of pressing the game's invite button: in Steam's window, open **Friends & Chat**, right-click your friend and choose **Invite to Game**. |
| Every controller press happens twice | In Steam, right-click the game → **Properties** → **Controller** → **Disable Steam Input**. |
| `steamerrorreporter` appears briefly after launching a game | Harmless. It's a known warning from Steam's networking code under Wine, and the game keeps running. |
| Spotlight shows **Vapor Steam** next to Vapor | Your install is where an earlier version put it. Open Vapor and click **Move**. |
| A `Steam.desktop` file appears on the desktop | Wine made it when Steam's installer created a Windows shortcut. Delete it. Installs made, updated or moved by Vapor 2.1 or later don't make these. |

### An update stopped partway

An update moves your Windows drive (Steam, games and sign-ins) into a fresh wrapper in a hidden `.vapor-update` folder next to Vapor Steam, then swaps it into place. If anything fails, setup moves everything back. If the Mac lost power at exactly the wrong moment, setup refuses to continue and shows where the Windows drive is. To put it back:

1. In Finder, choose **Go → Go to Folder…** and open `~/Library/Application Support/Vapor.noindex/.vapor-update` (or `~/Games/.vapor-update`, for an update started by Vapor 2.0 or DXMetal). It contains `new.app` and maybe `old.app`.
2. If Vapor Steam is missing from the folder above `.vapor-update`, move `old.app` back there and rename it **Vapor Steam** (or **DXMetal**, if that was its name).
3. Right-click the app with the Windows drive → **Show Package Contents** → **Contents → SharedSupport**, and move the `prefix` folder into the same place in your Vapor Steam (or DXMetal) app.
4. Delete the `.vapor-update` folder, then open Vapor and run the update again.

## Privacy and security

- **Never share or upload `Vapor Steam.app`.** It contains your Steam and game sign-ins, cookies and saves. To set up another Mac, install Vapor there instead. Setup makes it readable only by your Mac account.
- **Vapor collects nothing.** It contains no accounts, keys or tracking. It only contacts GitHub, to check for and download its own updates, and setup downloads only from GitHub (the wrapper and Wine, checked against pinned checksums) and Valve (the Steam installer).
- **Wine isn't a sandbox.** Windows programs run with the same access to your files as any app you run, and Wine shows them your whole Mac as drive `Z:`. Only install games and mods from sources you trust.
- **If macOS asks whether "wine" or "wineserver" may accept incoming network connections,** you can choose Deny. Online play usually works without it; allow it only if a game can't host or join sessions.
- To report a vulnerability, see [SECURITY.md](SECURITY.md).

## How it works

```
┌──────────────────────────────────────────────┐
│ Windows game (unchanged)                     │
├──────────────────────────────────────────────┤
│ Wine 11              Windows → macOS         │  files, windows, input, sound, network
│ DXMT or D3DMetal     DirectX → Metal         │  graphics
├──────────────────────────────────────────────┤
│ Rosetta 2            Intel → Apple Silicon   │  CPU instructions
├──────────────────────────────────────────────┤
│ macOS · Metal · Apple Silicon                │
└──────────────────────────────────────────────┘
```

Neither Steam nor your games are modified. Rosetta 2 translates their Intel code for Apple Silicon. Wine provides the Windows system functions they call, using macOS underneath. DXMT or D3DMetal turns their DirectX graphics into Metal. To other players, the Mac is just another Windows PC.

### Where things live

- `~/Library/Application Support/Vapor.noindex/Vapor Steam.app` holds everything. Spotlight doesn't search folders whose names end in `.noindex`, so it only finds the Vapor app. To see it in Finder, choose **Go → Go to Folder…** and paste the folder's path. Vapor 2.0 and DXMetal kept it in `~/Games`; Vapor offers to move it from there.
  - `Contents/SharedSupport/prefix` is the Windows drive: Wine's registry, and the C: drive with Steam and your games. `Contents/drive_c` is a shortcut to that C: drive. This is the only part an update keeps; everything else is replaced.
  - `Contents/Info.plist` stores the wrapper's settings, and which versions built it. To apply MetalFX and the frame rate limit, Vapor keeps a line for each in its "CLI Custom Commands" setting; anything else you add there is kept, including through updates.
  - Steam keeps each account's settings in `drive_c/Program Files (x86)/Steam/userdata/<account>/config/localconfig.vdf`. Vapor sets only the in-game overlay there, as `EnableGameOverlay`.
- The shader caches are in the Mac's cache folder: run `open $(getconf DARWIN_USER_CACHE_DIR)` and look in `d3dm/` (D3DMetal) and `dxmt/` (DXMT), with one folder per game.
- Vapor switches off Wine's menu builder (`winemenubuilder`), which would otherwise copy Windows shortcuts to the Mac's desktop as `.desktop` files whenever a program such as Steam's installer creates one.
- **Keeping it on an external drive:** before installing, edit the `INSTALL_PATH=` line near the top of `scripts/config.sh`, replacing `$HOME/Library/Application Support/Vapor.noindex/Vapor Steam.app` with something like `/Volumes/GameSSD/Vapor.noindex/Vapor Steam.app`, and install from Terminal. The drive must be formatted as APFS.

## Files

```
Vapor/
├── README.md
├── CHANGELOG.md
├── SECURITY.md
├── LICENSE
├── scripts/      setup.sh, run-steam.sh, status.sh, close-wine.sh, clear-caches.sh,
│                 diagnostics.sh, uninstall.sh, config.sh
├── app/          Vapor.swift, update-app.sh, build.sh, AppIcon.icns,
│                 dmg/ (the disk image window's background and layout)
├── tools/        update-pins.sh, release-notes.sh, dmg-window.sh, dmg-background.swift,
│                 clean-dsstore.py
└── .github/      workflows/checks.yml, release.yml, update-pins.yml
```

| File | What it does |
|---|---|
| `scripts/setup.sh` | Installs Vapor Steam, updates it (keeping Steam, games and settings), or moves an install from where an earlier version put it. Safe to run again: it skips finished steps. Steam must be closed. |
| `scripts/run-steam.sh` | Starts Steam, or shows its window, optionally changing the settings first (see [Launch arguments](#launch-arguments)). |
| `scripts/status.sh` | Shows the settings, whether an update is ready, whether Steam/Wine is running, and which translator a running game uses. |
| `scripts/close-wine.sh` | Quits everything running in Wine, including other Wine apps such as CrossOver. It asks before closing a running game, because unsaved progress is lost. It then asks Steam to exit properly, so Steam saves its state, and force-quits anything still running after 60 seconds, or after 10 if Steam isn't responding. |
| `scripts/clear-caches.sh` | Deletes the shader caches, after asking you to confirm. |
| `scripts/diagnostics.sh` | Prints versions, settings and status for a bug report, without names, file paths or accounts. |
| `scripts/uninstall.sh` | Deletes Vapor Steam (including any install where an earlier version put it), **including Steam, all installed games and saved sign-ins**, plus the shader caches, after asking you to confirm. |
| `scripts/config.sh` | Shared settings and helpers: Vapor's version, where the install lives, the pinned download links and their checksums, and how settings are read and changed. |
| `app/Vapor.swift` | The Vapor app's source code: one window that runs the scripts above, which are bundled inside it. |
| `app/update-app.sh` | How the app checks for, downloads and installs new versions of itself. |
| `app/build.sh` | Builds `Vapor.app` and its disk image into `app/build/`. Needs Apple's free Command Line Tools (`xcode-select --install`). |
| `app/dmg/` | The disk image window's background and layout, which `build.sh` copies into each disk image. |
| `tools/update-pins.sh` | Points `config.sh` at the newest Sikarugir wrapper and Wine 11 builds, with fresh checksums. |
| `tools/release-notes.sh` | Writes a release's notes from `CHANGELOG.md`. |
| `tools/dmg-window.sh` | Remakes `app/dmg/` after a design change: draws the background (`dmg-background.swift`), has Finder lay out the window, and removes what Finder's layout file records about the Mac it was made on (`clean-dsstore.py`). Run it on a Mac; macOS asks once to let it control Finder. |
| `.github/workflows/` | Checks each change, builds and publishes releases, and proposes newer wrapper and Wine versions daily. |

## Releasing

For maintainers:

1. **New wrapper or Wine versions:** each day, the *Update pins* GitHub Action looks for newer Sikarugir releases. When it finds some, it opens a pull request that updates the pins in `scripts/config.sh`, raises the version and adds a `CHANGELOG.md` entry. You can also run `zsh tools/update-pins.sh --bump` yourself.
2. **Test** the change on an install: run `zsh scripts/setup.sh`, start Steam and play a game.
3. **Merge**, then push a tag for the new version, e.g. `git tag v2.0.1 && git push origin v2.0.1`. The *Release* Action checks the tag matches `VAPOR_VERSION` in `config.sh`, builds the app and disk image, and publishes the release with its checksum. Vapor offers the update to everyone within a day.

For other changes, raise `VAPOR_VERSION` in `scripts/config.sh` and add a `CHANGELOG.md` entry yourself before tagging.

## Credits

- [Sikarugir](https://github.com/Sikarugir-App): the wrapper template and Wine 11 engine, which include DXMT and D3DMetal
- [DXMT](https://github.com/3Shain/dxmt) by 3Shain
- D3DMetal, from Apple's [Game Porting Toolkit](https://developer.apple.com/games/)
- [Wine](https://www.winehq.org), built from CrossOver's sources

## License

The code in this repository is released under the [MIT License](LICENSE). The wrapper, Wine, D3DMetal and DXMT that setup downloads are separate projects under their own licenses, and they aren't included in this repository.

Apple, Metal, Microsoft, DirectX, Windows, Valve, Steam, and the games and publishers mentioned here are trademarks of their respective owners. Vapor isn't affiliated with any of them.

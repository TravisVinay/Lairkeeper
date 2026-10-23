# Lairkeeper

A roguelike where you play the monster. By day you dig a dungeon of 5x5 rooms, pick where the
entrance and your lair go, lay permanent traps and recruit minions. By night the heroes your
infamy attracts file in through the gate, and you fight them turn by turn on the map you built.

Built with **Godot 4.7** (GL Compatibility renderer, so it runs on older PCs and phones).

## Run it

1. Open Godot 4.7, choose **Import**, and pick this folder's `project.godot`.
2. Press **F5** to play.

From a terminal:

```
"D:\godot engine\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path .
```

## Test it

`tests/sim.tscn` builds the real UI, opens a night, then plays two scripted runs with every
monster and prints how far each one got. `tools/check.ps1` runs it headless and shows only
errors and results:

```
powershell -File tools\check.ps1 -Sim
```

`tests/shot.tscn` opens a real window and saves day and night screenshots to `build/`.

## How the code is organized

| File | What it owns |
| --- | --- |
| `scripts/data.gd` | All content: monsters, spells, units, heroes, rooms and their furniture, traps, boons. Balance changes usually start here. |
| `scripts/game.gd` | The `Game` autoload: the current run, dungeon geometry (walls, doorways, line of sight, pathing) and every day action. Also saves meta progress to `user://meta.json`. |
| `scripts/battle.gd` | One night's fight: units, turns, spells, traps, room powers and hero AI. |
| `scripts/board.gd` | The map view: camera (fit by day, zoomed and draggable at night), drawing, and pointer input. |
| `scripts/sprites.gd` | Placeholder art drawn with shapes. Replace any function with real textures without touching game logic. |
| `scripts/main.gd` | The interface: header, day panels, night panels, overlays and the day/night layout switch. |
| `scripts/platform.gd` | The `Platform` autoload: Steam achievements through GodotSteam when it is installed, a no-op everywhere else. |

## Shipping it

### Export templates (needed for any build)

In the editor: **Editor > Manage Export Templates > Download and Install**. Then
**Project > Export** has presets ready for Windows, Linux and Android. Add macOS and iOS
there too; both need a Mac with Xcode to sign and build.

### Steam

1. Join Steamworks (one-time fee per game) and get an App ID.
2. Install **GodotSteam** from the Godot Asset Library (pick the GDExtension version that
   matches Godot 4.7). Once it is in `addons/`, the `Platform` autoload finds it on its own.
3. Put your App ID in `STEAM_APP_ID` in `scripts/platform.gd`, and create achievements in
   Steamworks with the IDs listed in `ACHIEVEMENTS` there.
4. Export the Windows (and Linux, for Steam Deck) builds and upload them with SteamPipe.

### iOS and Android

- **Android:** install Android Studio's SDK and a JDK, point Godot at them in Editor Settings,
  then export the Android preset. Google Play wants an `.aab`: tick "Use Gradle Build" and
  "Export Format: AAB", and sign with your upload key.
- **iOS:** export the iOS preset from a Mac, open the generated Xcode project, sign it with your
  Apple Developer account and upload through Xcode.
- The game already runs in landscape, accepts touch (taps count as clicks, drag to pan, and
  the +/− buttons zoom), and uses the mobile-friendly renderer.

## Known gaps before release

- Art is placeholder shapes. Commission or draw sprites and swap them into `sprites.gd`.
- No sound or music yet.
- The current run is not saved if the app closes mid-run (only meta progress is). Mobile
  stores expect this, so add run saving before shipping there.
- Touch pinch-to-zoom is not handled yet; trackpad pinch and the zoom buttons work.
- The UI font falls back to the system serif. Add a licensed font file for a consistent look.

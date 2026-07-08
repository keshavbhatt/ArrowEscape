# ArrowEscape

A calm **slide-the-arrows-off-the-board** puzzle for the desktop, inspired by
mobile titles like *Amaze GO!* and *Arrows – Puzzle Escape*.

Every arrow points a direction. **Click one to slide it off the board** — but
only if its whole lane to the edge is clear. Blocked clicks cost a heart. Clear
the board to win. It's pure move-order logic, no timer. Levels are generated
**solvable by construction**, so a board can never be stranded.

Built with **Qt 6 Quick (QML) + C++20 / CMake**, mirroring the sibling
*TypingMaster* scaffold.

## Architecture

```
CMakeLists.txt          # project, Qt, app-id, QML module
src/
  main.cpp              # QGuiApplication + QQmlApplicationEngine (AE_SHOT screenshot hook)
  AppInfo.h.in          # configured app-id / name / version
  core/
    ArrowBoard.*        # all game logic: list model of arrows, tap/collision,
                        #   hearts, win/lose, and the solvable-by-construction
                        #   level generator
  qml/
    Main.qml            # window, top bar, sounds, win/lose overlay
    Theme.qml           # calm palette singleton (light/dark)
    Board.qml           # square grid of slots + arrow pieces
    ArrowTile.qml       # one arrow: fly-off / shake / hint animations
    components/         # Hearts, IconButton, PillButton
assets/
  icons/                # app icon (SVG)
  sounds/               # whoosh / blocked / win (generated PCM WAV)
packaging/              # .desktop
DOCS/                   # game research & design study
```

**Design choices**

- Pure **Qt Quick** (no Widgets) — the satisfying fly-off animation is the whole
  feel of the genre, so the UI is GPU-accelerated QML with a C++ core.
- **`qt_add_qml_module`** with `QML_ELEMENT` — `ArrowBoard` is registered
  automatically; no manual `qmlRegisterType`.
- **Solvable by construction** — arrows are placed one at a time into a currently
  clear lane, so removing them in reverse order always solves the board and no
  state is ever a dead end.

## Build & run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/bin/arrowescape
```

Requires Qt ≥ 6.5 (developed against 6.10) with `Quick`, `QuickControls2`,
`Svg`, and `Multimedia`.

## Research

Game study and design notes live in [`DOCS/00-game-study.md`](DOCS/00-game-study.md).

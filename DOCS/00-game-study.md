# ArrowEscape — Game Study

Research notes for a desktop clone of the "slide-the-arrows-off-the-board" puzzle
family, based on two reference titles on Google Play:

| Ref | Title | Package | Publisher | Character |
|-----|-------|---------|-----------|-----------|
| A | **Arrows – Puzzle Escape** | `com.ecffri.arrows` | ecffri | Gamified: hearts, difficulty tiers, daily challenge |
| B | **Amaze GO!** (a.k.a. *Arrows GO!*) | `com.oakever.arrows` | Oakever / MWM | Minimal, meditative, 5000+ levels, thematic shapes |

Both are the **same core mechanic** with different skins. It is the same puzzle
genus as *Unblock Me / Rush Hour*, but pieces **leave the board** instead of
just sliding.

## The actual pieces (corrected after studying the screenshots)

The arrows are **NOT single coloured cells**. Each arrow is a **long winding
"snake"** — a thin hand-drawn line that threads through many grid cells, bending
up/down/left/right, and terminates in a **single arrowhead**. Dozens of these
snakes interlock so their bodies tangle like a maze, and collectively they draw
a **themed picture** (an anchor, a butterfly, a dog…).

Visual style is **ink on parchment**: a warm cream background, thin brown
strokes, small V-shaped arrowheads. No fills, no per-piece colour — the only
colour is the **blue highlight** on the selected/hinted arrow and the **blue
water-drop lives** in the top-left. A lightbulb **hint** (with a use count) and a
board/shuffle button sit at the bottom.

## The core mechanic

1. Each arrow occupies a connected **path of cells** ending in a head that points
   in one of the four cardinal directions (no diagonals).
2. **Tap an arrow** → it launches off the board in its head's direction, *only if
   the straight lane from the head to the edge is clear of other arrows' cells*.
   The body then threads out after the head.
3. If that lane is blocked by another snake's body, the move is **blocked**: it
   costs a **water drop**.
4. The winding **body is the obstacle** — it's what lies across other arrows'
   exit lanes. Removing a snake frees all its cells and opens lanes for others.
5. The level is **won** when the board is **completely cleared**.
6. The puzzle is entirely about **move order** — find a snake whose head lane is
   clear, remove it to open lanes, repeat. Logic and planning, **no timer**.

## Feature comparison

| Aspect | A — Arrows Puzzle Escape | B — Amaze GO! |
|--------|--------------------------|----------------|
| Arrow piece | Arrow tile on a grid | Colored block-shape, may span multiple cells |
| Directions | 4-way cardinal | 4-way cardinal |
| Lose condition | Lose a heart on a blocked tap | Lose a heart on a wrong tap |
| Hearts | Limited attempts per level | Blue "heart" counter in top bar |
| Hints | — | **Long-press** an arrow for guidance |
| Power-ups | Eraser (remove a blocker) | Hint |
| Difficulty | Tiers: Normal / Hard / Super Hard / Nightmare | Gentle ramp over 5000+ levels |
| Levels | 1000+ handcrafted, **daily challenge** | 5000+, some arranged as **thematic pictures** (butterfly, dog, anchor) |
| Length | "Short levels you can play in a minute" | Same |
| Offline | — | **Fully offline** |
| Feel | Puzzle challenge | **Meditative**, quiet muted visuals, satisfying *whoosh* as each arrow flies off |

## What makes a good level

- **Always solvable** — there must exist at least one order that clears the board.
- **Interlocking** — arrows block each other so the solution order is non-obvious.
- **A "key" move** — often one arrow that must go first to unlock a cascade.
- Difficulty scales with grid size, arrow count, and depth of the dependency
  chain (how many arrows must be removed before a given arrow can escape).

## Desktop adaptation notes

- Primary input is a **mouse click** on an arrow (the tap). Optional keyboard:
  arrow-key focus + Enter, or number/letter labels.
- The **whoosh + slide animation** is the single most important feel element —
  the reference titles live or die on how satisfying the exit animation is.
  Qt Quick's animation stack (NumberAnimation on x/y + opacity) is ideal.
- Board and level content should be **data, not code** (JSON), mirroring the
  sibling *TypingMaster* project, so new packs are a content drop.
- A **procedural generator that guarantees solvable boards** removes the need to
  hand-author thousands of levels — generate by placing arrows in reverse
  (spawn them one at a time in already-clear lanes), which is solvable by
  construction.

## Proposed scope for v0.1 (MVP)

- N×N grid, single-cell 4-direction arrows.
- Click to slide-and-exit with animation + sound; blocked move shakes + costs a heart.
- Procedural solvable-by-construction generator with a difficulty dial.
- Win/lose states, level counter, restart, hearts, a hint.
- Minimal themeable aesthetic (lean toward B's calm look), pure Qt Quick + C++ core.

## Sources

- Arrows Puzzle Escape rules — CrazyGames / walkthrough guides
- Amaze GO! (Arrows GO!) — MWM publisher page, Google Play / App Store listings

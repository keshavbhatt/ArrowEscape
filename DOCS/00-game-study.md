# ArrowEscape — Game Study

Design notes for the "slide-the-arrows-off-the-board" puzzle: what the mechanic
is, what makes a level good, and how the desktop build approaches it.

## The pieces

Each arrow is a **winding "snake"** — a thin hand-drawn line that threads through
many grid cells, bending up/down/left/right, and terminates in a **single
arrowhead**. The board is a fully-packed grid, so dozens of snakes interlock and
their bodies tangle like a maze.

Visual style is **ink on parchment**: a warm cream background, thin brown strokes,
small filled-triangle arrowheads. No fills, no per-piece colour — the only colour
is the **blue highlight** on the hinted arrow and the **blue water-drop lives** in
the top-left. A lightbulb **hint** and a restart button sit at the bottom.

## The core mechanic

1. Each arrow occupies a connected **path of cells** ending in a head that points
   in one of the four cardinal directions (no diagonals).
2. **Tap an arrow** → it launches off the board in its head's direction, *only if
   the straight lane from the head to the edge is clear of other arrows' cells*.
   The body then threads out after the head.
3. If that lane is blocked by another snake's body, the move is **blocked**: it
   costs a **water drop** (a life).
4. The winding **body is the obstacle** — it's what lies across other arrows' exit
   lanes. Removing a snake frees all its cells and opens lanes for others.
5. The level is **won** when the board is **completely cleared**.
6. The puzzle is entirely about **move order** — find a snake whose head lane is
   clear, remove it to open lanes, repeat. Logic and planning, **no timer**.

## What makes a good level

- **Always solvable** — there must exist at least one order that clears the board.
- **Fully packed** — a board with no gaps has almost no clear lanes at the start,
  so only a few edge arrows can move first; the player must unpick the tangle in
  order rather than clearing arrows trivially from the edges.
- **Interlocking** — arrows block each other so the solution order is non-obvious.
- Difficulty scales with grid size, arrow count, and how deep the dependency
  chains run (how many arrows must be removed before a given arrow can escape).

## How the build approaches it

- Primary input is a **mouse click** on an arrow (the tap). The board is
  **zoomable and pannable**, so large late-game boards stay readable.
- The **slide-off animation** is the single most important feel element: each
  snake threads out head-first along its own body, straightening as it exits.
- Levels are **procedurally generated, fully packed, and solvable by
  construction** via *reverse peeling*: snakes are stripped off a completely
  filled grid (the extreme cell of any row/column can always exit toward that
  edge), and the peel order is itself a valid solution. Each level is seeded by
  its number, so it is deterministic — retrying reproduces the same board.
- Difficulty **ramps with the level**: the grid grows, snakes lengthen, and
  arrows point deeper inward (longer, more tangled exit lanes) toward a hard
  plateau, giving hundreds of levels from a gentle Easy start to a dense Master
  board.

## Aesthetic & scope

- Pure **Qt Quick** (no Widgets) — the fly-off animation is GPU-accelerated QML
  over a C++ core, mirroring the sibling *TypingMaster* scaffold.
- Minimal, meditative look: calm parchment palette, light/dark themes, a soft
  piano soundtrack and whoosh/blocked sound effects, all toggleable in settings.
- Fully offline; progress and preferences are saved automatically.

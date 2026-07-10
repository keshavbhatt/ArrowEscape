# ArrowEscape — Monetization & Roadmap

A living plan for turning ArrowEscape into a one-time-purchase ("buy once, own
forever") game that still ships a genuinely complete **free** experience. Update
the checkboxes as pieces land.

---

## 1. The core insight

Levels are **infinite and procedurally generated**, so we cannot sell "more
levels" — the core loop must stay free. What people *do* pay for in calm puzzle
games is **collection, identity, and calm-friendly convenience**. So Pro sells a
*different flavour* of the same game (collectible content + personalisation +
quality-of-life), never access to the core.

**Guiding rule:** Free must feel like a finished game, not a demo. Pro must feel
like delight, not relief from artificial pain.

---

## 2. Business model

- **One-time purchase**, perpetual license. No subscription.
- Reuse the KTechpit **`AccountAndLicense`** backend (as vendored in the sibling
  *TypingMaster*): tiers **Free / 30-day Evaluation / Pro**. Pro unlocks
  everything below, including **all future content packs**.
- **No ads, no timers, no interruptions** — they would poison the meditative
  vibe. The only Pro touchpoint is one gentle, non-intrusive teaser (see §4).
- Price anchor: **$4.99 – $7.99** one-time ("unlock everything forever + all
  future packs").

---

## 3. The pillars

Center of gravity = **Pillar A (Picture Packs)** as the flagship reason to buy,
plus **Pillar B (Theme Studio)** for ongoing delight. C–E are bonus value.

### Pillar A — Picture Packs + Collection album  ⭐ flagship

Boards shaped like **pictures** (animals, objects, letters, seasonal sets). Solve
the tangle inside a silhouette; on completion the finished shape is revealed and
added to a **Collection album** (a sticker/trophy wall). Sells *completion*, not
content; visibly premium but never gates the core; evergreen via new pack drops.

- Free: 1 sample pack (a taste + the album UI).
- Pro: all packs + every future pack, forever.

**Why it's cheap to build:** the reverse-peeling generator is shape-agnostic — it
peels the extreme present cell of each row/column and exit rays pass through
empty (outside-mask) cells. A picture board is just *peeling inside a mask bitmap
instead of a full rectangle*, with the same guarantees (fully packed, no gaps,
always solvable). A pack = a folder of shape masks + names.

**Implementation checklist**
- [x] Extend `ArrowBoard::generate` to accept an optional **cell mask** (only
      mask cells get arrows; rays pass through non-mask cells to the edge).
      *(Done — `present` inits from `m_mask`; `startPicture()` invokable.)*
- [x] Verify solvability + full-mask-coverage on masked regions (peel invariant
      still holds). *(Prototype: heart/star/moon/diamond → 100% coverage,
      solvable, single-cell ~9%. Dev hook `AE_SHAPE`.)*
- [x] Mask asset format + `PictureCatalog`. *(JSON packs in `data/pictures/`,
      globbed into resources; `PictureCatalog` scans them, derives cols/rows +
      a stable per-picture seed, tracks completion in QSettings.)*
- [x] "Picture mode" board framing — dot-grid suppressed outside the shape
      (`pictureMode`). *(Still TODO: center/scale framing polish.)*
- [x] Collections are now **first-class on the HOME screen** (`HomeScreen.qml`):
      a "Levels" card + pack sections with tiles (completed/unlocked/locked + PRO
      badge, `PicturePreview` silhouettes). The 500-level grid sits behind the
      Levels card. *(TODO: per-pack progress count "n/m".)*
- [x] **Authoring tool** — `tools/mask_from_icon.py` (emoji / font glyph / PNG →
      grid mask, with fill or `outline` line-art mode) + `tools/build_packs.py`
      (one `GRID` constant for density; regenerates all packs with a solvability
      check). Packs at GRID=40: Shapes, Animals, Nature, Objects, Letters A–Z.
- [ ] Reveal animation on completion → drop into album. *(For now the cleared
      overlay switches to "Picture complete! → Collections".)*
- [x] Author starter packs — **Shapes** (free: heart/star/diamond/moon) and
      **Symbols** (Pro: plus/ring/letter-A/house). *(More/better shapes TODO.)*
- [x] Persist completed pictures (QSettings `pictures/completed`).
- [x] Gate Pro packs behind a `pro` flag (stub: `proEffective = pro || appDebug`;
      wire to real licensing in M0).

### Pillar B — Theme Studio

The game is aesthetic-driven (ink on parchment), so cosmetics convert well.

- Free: ~4 core themes (light/dark).
- Pro: custom **paper & ink** palettes (pick your own), plus premium theme packs
  (paper textures, ink colours, seasonal).

**Implementation checklist**
- [ ] Refactor `Theme.qml` to load a **named palette** (it's already token-based;
      add a palette registry / `data/themes/`).
- [ ] Theme picker screen (swatches, live preview).
- [ ] Custom-palette editor (paper, ink, accent, drop) with live preview + save.
- [ ] Persist selected/custom themes; gate custom + premium packs behind Pro.

### Pillar C — Calm quality-of-life

- Free: 3 lives + limited hints (already shipped).
- Pro: **unlimited hints**, no out-of-lives wait, and **Undo** (step back a move).

**Implementation checklist**
- [ ] `Undo`: snapshot stack of removed snakes; re-insert on undo (restore cells
      + owner map). Free: disabled or 1/level; Pro: unlimited.
- [ ] Hint quota: Free limited (counter), Pro unlimited.
- [ ] Lives: Free keeps the 3-drop + "out of lives" flow; Pro removes the wall.

### Pillar D — Daily Challenge + streaks

- Free: play today's board (seed = date).
- Pro: full **streak calendar**, history, and one **streak-freeze**.

**Implementation checklist**
- [ ] Daily board = deterministic seed from the date (generator already seeds by
      level; add a date-seed entry point).
- [ ] Daily screen + "played today" state; streak counter.
- [ ] Pro: month calendar view, history, streak-freeze token.

### Pillar E — Stats, achievements & progress

- Free: level counter (shipped).
- Pro: achievements, records, milestone badges.

**Implementation checklist**
- [ ] Track stats (levels cleared, perfect clears, best streak, pictures done).
- [ ] Achievements definitions + unlock toasts; a badges/stats screen.
- [ ] Gate the achievements screen / badges behind Pro (stats tracked for all).

---

## 4. Free-player guardrails (non-negotiable)

- Free ships the **entire core game**: infinite generated levels, the full
  difficulty ramp to Master, core light/dark themes, and a daily.
- **Exactly one** Pro touchpoint: a single locked "Picture Packs" tile in the
  level map that plays **one** free sample picture and shows the album. No ads,
  no timers, no repeated nags.
- Everything that could feel like "pay to remove pain" (lives/hints) stays
  *usable* for free — Pro only removes friction, never blocks progress. Boards
  are deterministic and retryable, so a life wall is never a hard stop.

---

## 5. Technical foundations we can build on

- **Generator is shape-agnostic** → Picture Packs are a mask, not a rewrite.
- **Licensing** → vendor `AccountAndLicense` + a thin `LicenseController`; gate
  with `enabled: License.isPro` bindings. Same pattern as TypingMaster.
- **Theme.qml is token-based** → Theme Studio is a palette registry + editor.
- **QtCore Settings** already persists progress/prefs → extend for collections,
  themes, daily streaks, stats.
- **Deterministic seeded boards** → Daily Challenge is a date-seed away.

---

## 6. Roadmap (phased)

Each phase is shippable on its own.

### M0 — Foundation (enables monetization)
- [x] Vendored `modules/AccountAndLicense` + `src/licensing/LicenseController`
      (QML singleton). Free / 5-day trial / Pro; `proEffective = LicenseController.pro`.
      Debug: `AE_TIER=free|trial|pro` forces a tier.
- [x] Pro gate + non-nagging **Upgrade to Pro** dialog (`upgradeRequested` →
      dialog → openCheckout/openPortal). Locked packs / the Colorful-arrows toggle
      open it; Settings shows an Upgrade button (free) or trial-days / Pro ✓.
- [x] Settings persistence groundwork (QSettings) in place.

### M1 — Flagship: Picture Packs (the reason to buy)
- [ ] Masked generation + solvability sweep.
- [ ] Picture mode + Collection album + reveal animation.
- [ ] Free sample pack + 3–4 Pro packs authored.
- [ ] Pro gating + the single level-map teaser tile.

### M2 — Theme Studio (ongoing delight)
- [ ] Palette registry + theme picker.
- [ ] Custom-palette editor; Pro gating.

### M3 — Retention & polish
- [ ] Daily Challenge + streaks (Pro calendar/freeze).
- [ ] Quality-of-life: Undo, unlimited hints, no life-wall (Pro).
- [ ] Stats + achievements (Pro badges).

### M4 — Growth
- [ ] Seasonal pack drops (recurring reason to return / convert).
- [ ] Shareable "completed picture" export/screenshot.

---

## 7. Open questions

- [ ] Exact one-time price ($4.99 vs $6.99 vs $7.99)?
- [ ] Evaluation length — reuse 30-day, or a "try 1 pack" model instead?
- [ ] How many pictures per pack, and how many packs at launch?
- [ ] Do we want any online (leaderboards for daily), or stay fully offline?
- [ ] Achievements: purely local, or tied to the KTechpit account?

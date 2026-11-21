# 🦁🐢 Legend of Lion Turtle

> A 1v1 elemental-bending PvP arena game for macOS, inspired by Avatar: The Last Airbender.

---

## 🎮 Overview

**Legend of Lion Turtle** is a native macOS arena fighter where two players battle using elemental bending arts over a local network. Choose your element, allocate stats, and fight for the chance to become the Avatar mid-round.

### Core Features

- **4 Elements** — Fire 🔥, Water 💧, Earth 🪨, Air 💨 — each with a unique fighting style
- **LAN Multiplayer** — Host/Join over Wi-Fi, one Mac hosts the authoritative simulation
- **Stat Builds** — 8 points across Attack, Defense, Mobility — unlock specializations at max
- **Raava Event** — At 60s, contest a glowing beam to become the Avatar and bend all 4 elements
- **Kingdom Rush Art Style** — Illustrated fantasy aesthetic with expressive 2D sprites

### Tech Stack

- **Engine:** Godot 4 (GDScript)
- **Platform:** macOS native
- **Networking:** Godot high-level multiplayer API (ENet)
- **Target:** 60 FPS, two-Mac LAN play

## 📁 Project Structure

```
legend-of-lion-turtle/
├── docs/
│   ├── design-system.md          # Scroll & Ink UI language, tokens, textures, components, screens
│   ├── screens/                  # screenshots of every screen
│   ├── bending-rules.md          # Avatar bending lore & PvP rule proposals
│   └── game-design-spec.md       # Full game design specification
├── project/                      # Godot 4.4 project
│   ├── assets/avatar_characters/ # 8 benders: SpriteFrames + atlases (pack v2)
│   ├── assets/avatar_bending/specials/ # 20 special-power effects (pack)
│   ├── assets/avatar_transformation/   # Raava transformation poses per bender + Raava effects (pack)
│   ├── assets/avatar_arenas/     # 16 arenas (4 per nation): paintings, collision, spawns, sources (pack)
│   ├── assets/fonts/             # Zhi Mang Xing, Kaisei Tokumin, Shippori Mincho B1 (SIL OFL)
│   ├── assets/ui/paint/          # painted UI textures (sky, sun, water, mountains, parchment, brushes, rods, ribbons)
│   ├── assets/ui/                # scroll_ink_theme.tres — generated project theme
│   ├── scenes/                   # ui/ (menu, lobby), arena/, characters/
│   ├── scripts/ui/kit/           # Scroll & Ink tokens, theme builder, paint helpers, UI components
│   ├── scripts/data/             # roster (benders), arenas, element names, taglines, attacks
│   ├── scripts/fx/               # power trails and blooms (additive light around attacks)
│   ├── tools/build_theme.gd      # regenerates the theme from the tokens
│   └── scripts/                  # autoload/ (GameManager, NetworkManager, UserSettings), ui/, arena/, characters/
├── tools/paint/gen_textures.py   # regenerates assets/ui/paint/*.png (Python: numpy, scipy, Pillow)
└── README.md
```

## 🏗️ Development Stages

1. ✅ Playable arena — movement, aiming, jumping, collision
2. ✅ Host/Join — synchronized movement & a real attack
3. ⬜ All 4 elements — 3 attacks per element
4. ✅ HP, victory, round reset — 300 HP, best-of-3 (round timer still to come)
5. ⬜ Stat allocation, random specials, all specializations
6. ✅ Raava event — contested merge, Avatar transformation, element switching (the Avatar switches the element of its bolt for now; full move sets come with Stage 3)
7. ⬜ Terrain interactions, arena themes, visuals, audio, settings

## 📦 The Mac app (no Godot needed)

`build/Legend of Lion Turtle.zip` is the game as a normal macOS app: universal (Apple silicon and Intel), macOS 11 or later. Unzip it and drag **Legend of Lion Turtle.app** into Applications. To give it to the second player, AirDrop the zip or the app.

The app is ad-hoc signed, not notarized. The first time the other Mac opens it:
1. Right-click (or Control-click) the app, choose **Open**, then **Open** again.
2. If macOS still refuses, go to System Settings → Privacy & Security, scroll down, and click **Open Anyway**.
3. If it says the app "is damaged", run `xattr -cr "/Applications/Legend of Lion Turtle.app"` in Terminal once.

When asked, allow incoming connections and local network access. LAN play needs both.

**Updating it from Terminal:** run `./update_app.sh` in the repo folder. It rebuilds the app with Godot, then installs it into Applications, clears the quarantine flag, and opens it. `./update_app.sh --no-build` installs the build that's already in `build/`.

**Rebuilding it by hand:** in Godot use Project → Export → **macOS** → Export Project. The preset is in `project/export_presets.cfg`. Godot needs the 4.4 export templates (Editor → Manage Export Templates → Download).

## 🚀 Getting Started

```bash
git clone git@github.com:adds-operations/legend-of-lion-turtle.git
cd legend-of-lion-turtle
# Open project/project.godot in Godot 4.4, then press Play (F5)
```

## 🌐 Playing over LAN (two Macs)

1. Both Macs on the same Wi-Fi / network.
2. **Mac A:** run the game → **Create Arena**. It shows its IP and port (7777).
3. **Mac B:** run the game → **Join Arena** → type Mac A's IP → **Connect**.
4. Both land in the lobby. The host picks the arena (**Q / E** or the arrows on the arena card). Pick an element, set your build (**B**, see below), press **READY**. A 3-second countdown starts the match.
5. Controls: **Arrow keys** move in any direction (360°: the facing turns smoothly, and letting go of a diagonal keeps you facing that diagonal) · **Z X C V** attack · **A** special · **Space** jump · **Hold A** in Raava's light to merge · **Esc** menu. There's no mouse: every power flies the way your bender faces, at any angle.
6. **Auto-aim** (on by default): every power is aimed at your rival, so the arrows are only for moving and dodging. Hold **Shift** to aim by hand for a moment. Turn it off or on any time from the **Esc** menu (or press **Q** there). Training pauses while the menu is open; a LAN match keeps running for your rival.

### Builds and signatures

Before a match, open the lobby's **2 · BUILD & SIGNATURE** tab (click it or press **B**; on the training card, **EDIT BUILD**) and spend **8 points** on three stats, 0–5 each. Click a pip or use ← →; the red seal counts the points left. Pressing READY with points unspent takes you to the build tab once. Points only make you stronger; they never change your powers.

| Stat | Per point |
| --- | --- |
| Attack | +5% damage |
| Defense | 4% less damage taken (all reduction capped at 50%) |
| Mobility | +4% move speed |

**Signature (A):** every bender has one fixed signature attack, their bending style. It is long range, much stronger than Z X C V, has a short windup (about 0.25 s, you stand still for it) and leaves the rival with a status. Every signature only hits fighters on the ground, so jumping is the dodge.

| Bender | Signature | What it does | Status |
| --- | --- | --- | --- |
| Ember Captain | Thunder Strike | instant lightning across the arena | Shocked: can't move or act 1 s |
| Sun Student | Sun Dragon | a fire dragon flying far | Burning: 4 damage every 0.5 s for 3 s |
| Ice Guard | Glacier Prison | ice spikes burst out of the ground in a line | Frozen: rooted 1.5 s (can still bend) |
| Tide Runner | Tidal Surge | a great wave that rolls the rival back | Soaked: 45% slower for 3.5 s |
| Stone Warden | Pillar Eruption | stone pillars erupt out of the ground | Stunned: can't move or act 0.9 s |
| Sand Outrider | Sand Tomb | a sand serpent skimming the ground | Buried: rooted 1.6 s |
| Temple Courier | Air Cannon | a compressed air sphere, huge knockback | Winded: can't attack, 25% slower, 2 s |
| Cloud Keeper | Tornado Lift | a travelling tornado | Swept up: lifted, helpless 1.2 s |

Hard control (shocked, stunned, frozen, buried, swept up) can't be chained: the target gets 1 s of immunity after it ends. Data: `project/scripts/data/specials.gd`; behaviour: `project/scripts/characters/signature_runner.gd`; status art: `project/scripts/fx/status_fx.gd`. Art: `assets/avatar_bending/signatures/<id>.png` (8 frames × windup / travel / impact / status rows); until those sheets are installed each signature borrows a row of the specials pack.

**Bending sources:** earth powers lift out of a crack in the ground before they fly; water benders hold a ribbon of water and, when it runs out (or after about 9 s), pull more from the nearest pool or river in the arena, or from the ground. Both are visual only and never delay an attack.

**Aim:** a power aimed within about 24° of the rival goes straight at them (leading a moving rival a little), and the hit area is the bender's whole body, not just their feet.

### Attacks and jumping

Each element has four powers, one per key:

| Element | Z | X | C | V |
| --- | --- | --- | --- | --- |
| Fire | Fire Bolt (fireball) | Flame Burst (three flame crescents) | Fire Wave (a wall of flame rolls forward, passes through) | Lightning (instant bolt along a line) |
| Water | Water Lash (short whip) | Ice Shard (fast) | Pushing Wave (churning waves, push) | Ice Spikes (crystals erupt along the ground) |
| Earth | Stone Shot (spinning rock) | Boulder (heavy, push) | Shockwave (rocks burst up along a line) | Ground Slam (stone ring all around you, push) |
| Air | Air Jab (fast air ball) | Compressed Gust (pressure crescent, push) | Knockback Blast (wind ring, big push) | Tornado (slow funnel, hits repeatedly) |

Every power is drawn with the special-powers pack art (`assets/avatar_bending/specials/`): windup frames at the hands, the active frame in flight, and the finish frame where it lands. The mapping is in `project/scripts/fx/bending_fx.gd`.

**As the Avatar,** Z X C V throw each element's best power (Lightning, Ice Spikes, Ground Slam and Tornado) at half the cooldown.

**Arrow combos:** tap arrows, then attack within about a third of a second. The last arrow you tap is "forward" (F). Two arrows tapped together count as one diagonal.

| Input | Move | Effect |
| --- | --- | --- |
| F, F, attack | Dash Strike | dash ~95 px forward, then cast |
| back, F, attack | Power Shot | ×1.5 damage, 30% bigger |
| side, F, attack | Curve Shot | bends toward the side you tapped first (Lightning goes out on the diagonal) |
| back, side, F, attack | Spread Shot | three at once, ±18° |

The move's name pops up above the ability strip.

**Hit combos:** hits landed within 1.6 s of each other chain up, and "3 Hit Combo" appears on screen. From the 3rd hit on, each hit deals +15% more, up to +60%. The chain breaks after 1.6 s without a hit, or as soon as you get hit.

**Height matters.** A power thrown from the ground flies low: jump over it. A power thrown mid-jump flies high and passes over anyone on the ground. It only hits someone who is also in the air.

**Hits land from any side,** including from behind: the hitbox is the fighter's footprint on the ground. Walls and rocks stop every power. Tuning lives in `project/scripts/data/elements.gd`.

Matches are **best of 3**. When a fighter reaches 0 HP the round result shows ("Round Won" / "Round Lost"), and 4 s later the next round starts in the same arena: full HP, back at the spawns, the Avatar gone, and Raava coming again at 60 s. The first to win 2 rounds wins the match ("Victory" / "Defeat"), then both players return to the lobby. If either player disconnects, the other returns to the main menu with a message and can host/join again without restarting.

**macOS firewall prompt:** the first time Mac A hosts, macOS may ask *"Do you want the application to accept incoming network connections?"* — click **Allow**. If you clicked Deny, re-enable it in System Settings → Network → Firewall → Options. If joining hangs at "Connecting…", this is almost always the cause, or the two Macs are on different networks (guest Wi-Fi often blocks device-to-device traffic).

### Networking model

- The host (peer 1) is authoritative for position, collision, jumps, cooldowns, HP, projectiles and round outcome.
- The joining player moves locally (client-side prediction) and streams its predicted position + aim each tick. The host checks each move against a speed budget and replays it through its own collision, so a client can't move faster than allowed or through walls.
- The host streams snapshots back at 60 Hz (unreliable, ordered). The owner reconciles against them using input sequence numbers; the other fighter is interpolated.
- Lobby changes, jumps, attacks, hits, spawns and round transitions use reliable RPCs.
- Every peer spawns both fighters under the same node names (their peer IDs), so RPC paths match everywhere.

## 🧪 Testing on one Mac

Run two instances from the repo root. Arguments after `--` are test shortcuts:

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path project -- --host &
$GODOT --path project -- --join=127.0.0.1
```

| Flag | Effect |
|------|--------|
| `--host` | Create an arena immediately |
| `--join=IP` | Join that IP immediately (`--join` alone = 127.0.0.1) |
| `--port=N` | Host on a different port |
| `--name=NAME` | Use this player name for this run |
| `--fighter=ID` | Pre-select a bender (sets the element too) |
| `--arena=ID` | Host on this arena (for example `moon_oasis`; see `scripts/data/arenas.gd`) |
| `--element=fire\|water\|earth\|air` | Pre-select an element in the lobby |
| `--auto-ready` | Press READY automatically |
| `--bot` | Your fighter moves, jumps and shoots on its own |
| `--log-sync` | Print both fighters' positions/HP (and Avatar element) once per second |
| `--raava-at=N` | Raava descends N seconds into the round instead of 60 (warning 10 s before) |
| `--bot-claim` | With `--bot`: walk into Raava's beam and hold Q |
| `--bot-passive` | With `--bot`: never shoot (lets the other bot finish a claim) |
| `--training` | Open the Training panel (add `--auto-ready` to start straight away) |
| `--partner=moving\|sparring` | Training: the partner's starting mode |

Fully automated sync check (no clicking):

```bash
$GODOT --headless --path project -- --host --auto-ready --bot --log-sync &
$GODOT --headless --path project -- --join --element=water --auto-ready --bot --log-sync
```

Both logs should show the same positions (within a few pixels), the same HP, and matching JUMP flags each second.

## 🖌️ UI design system — Scroll & Ink

The menus, lobby and HUD share one painted, storybook language inspired by the 2D sequences in Kung Fu Panda: a golden-hour landscape (dry-brushed sky, a sun ringed by brushed halos, karst mountains in ink wash, a glittering river), menus as hanging scrolls on lacquered rods, torn parchment, dry-brush buttons, and torn red banners in the wind. It's documented in [docs/design-system.md](docs/design-system.md).

- Tokens (colors, type, motion) live in `project/scripts/ui/kit/ui_tokens.gd`.
- Painted textures live in `project/assets/ui/paint/` and are generated by `tools/paint/gen_textures.py` (deterministic). Regenerate with `python3 tools/paint/gen_textures.py`.
- The project theme is built from the tokens and textures. After changing either, rebuild it:
  ```bash
  $GODOT --headless --path project --script res://tools/build_theme.gd
  ```
- Set a control's **Theme Type Variation** to `PrimaryButton`, `SecondaryButton`, `SmallButton`, `H1Label`, `EyebrowLabel` and so on.
- Components (`@tool`, so they preview in the editor) live in `project/scripts/ui/kit/`.

## 🗺️ Arenas

Sixteen arenas from the arena pack (`project/assets/avatar_arenas/`), four per nation. The host picks one in the lobby and it syncs to the other player; the last pick is remembered.

- The painting fills the whole screen: a camera zooms it to cover the window and drifts with the fight to keep both fighters in view. There's no frame or border. The camera snaps to whole screen pixels so the pixel art doesn't shimmer.
- Rocks and cover block movement and bolts. Bolts that leave the play area are removed.
- The arena list lives in `project/scripts/data/arenas.gd`.

## 🥋 Training Grounds (single player)

On the main menu, pick **TRAINING**, choose a bender and an arena, then press **START TRAINING**. It runs offline, with no second Mac.

- A **sparring partner** stands in the arena. Press **G** to cycle it: standing, moving, or sparring (it fires back).
- Press **1–4** to switch between Fire, Water, Earth and Air at any time. Z X C V then throw that element's four powers.
- **A** fires your bender's signature; change bender on the training card to try another.
- Press **T** to call Raava. The ring appears and the beam descends 3 s later, so you can rehearse the merge (hold **A**) as often as you like. If either of you is knocked down, the Avatar state ends.
- The HUD counts your hits, total damage, and damage over the last 5 s.
- Neither of you can lose: a fighter knocked down gets back up after a moment.
- Press **Esc** twice to leave.

Test shortcut: `--training --fighter=stone_warden --arena=ember_terrace --auto-ready --bot --bot-claim --raava-at=6 --partner=sparring`.

## 🌟 Raava and the Avatar

Once per round, one fighter can merge with Raava and bend all four elements for the rest of that round.

1. **50 s:** "Raava is arriving" with a countdown, and the hint "Enter the ring when the beam appears". Raava's ground ring and rising motes mark the spot. The host picks the most neutral of the arena's Raava markers.
2. **60 s:** Raava descends: the beam rises out of the ring with the spirit inside it, then holds.
3. **Claim:** stand in the circle and hold **A** for 1.5 s, grounded and still. Moving, jumping, attacking, taking a hit, or letting go resets it. If both fighters are in the circle, it's contested and neither progresses. Both players see the progress ring and a status line.
3b. **Raava leaves:** if nobody has merged 20 s after she descends, she rises away (the strip counts down) and there's no Avatar that round.
4. **Merge:** the host awards it once. The spirit sinks into the fighter as the beam collapses, and a small four-element burst plays with the bender's own fusion animation. The beam animation is `assets/avatar_transformation/raava/raava_beam.png`: 12 frames for arriving, rising, holding and absorbing. HP, cooldowns and stats are unchanged: no healing, no immunity.
5. **Avatar:** **Z X C V** become Fire, Water, Earth and Air, each element's best power (Lightning, Ice Spikes, Ground Slam, Tornado) at half the cooldown. The state lasts **25 s**. You'll see:
   - an Avatar bar above your HUD card showing Z X C V, their elements and the seconds left;
   - the ability tiles recolored per element;
   - on the fighter: a Raava-blue ring at the feet and the four elements circling, the active one brightest. This is drawn behind the sprite, so the sprite isn't covered.
6. **Round end:** the Avatar fades after 25 s, or when someone is defeated. The next round starts without it and Raava comes again. The result screen notes when the winner won as the Avatar.

The transformation poses (channel, fusion, Avatar-ready, four directions per bender) come from the transformation pack and are merged into each bender's own `SpriteFrames` at load (`Roster.fighter_frames`), so the character pack's files are untouched.

Same-Mac test: `--host --bot --bot-claim --raava-at=8` and `--join --bot --bot-passive`.

## 🎨 Characters and effects

**Benders** (`project/assets/avatar_characters/`, pack v2): eight original pixel-art fighters, two per element:

| Element | Benders |
| --- | --- |
| Fire | Ember Captain, Sun Student |
| Water | Ice Guard, Tide Runner |
| Earth | Stone Warden, Sand Outrider |
| Air | Temple Courier, Cloud Keeper |

- In the lobby, pick an element with 1–4. Click a bender's portrait, or press Tab, to swap between the element's two benders.
- In the arena, fighters face where they aim and animate from the synced game state: idle, walk, strike, jump start, airborne, land, hit and defeat, each in four directions.
- The character sprites are drawn exactly as supplied: no outline, tint or flash. Sides are shown by separate markers: a ground ring, a name tag and an HP bar (gold for you, indigo for your rival), so mirror matches stay readable.
- Attacks get a soft additive glow and a blurred gradient trail behind each bolt (`scripts/fx/`), drawn as separate layers so the sprites are untouched.
- The roster lives in `project/scripts/data/roster.gd`. To add a bender, add a row there and drop their `.png`/`.tres` into the folder.
- Test flag: `--fighter=<id>` (for example `--fighter=cloud_keeper`).

**Special powers** (`project/assets/avatar_bending/specials/`): windup, active and finish art for all 20 specials, plus the Air Spirit Form shader helper. They're installed and verified to load, and get wired in with the special-move system (Stage 5).

## 📄 Docs

- [UI Design System — Scroll & Ink](docs/design-system.md)
- [Bending Rules & Lore](docs/bending-rules.md)
- [Full Game Design Spec](docs/game-design-spec.md)

## License

MIT

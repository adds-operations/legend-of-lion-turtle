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
│   ├── bending-rules.md          # Avatar bending lore & PvP rule proposals
│   └── game-design-spec.md       # Full game design specification
├── project/                      # Godot 4 project (coming soon)
└── README.md
```

## 🏗️ Development Stages

1. ⬜ Playable arena — movement, aiming, jumping, collision
2. ⬜ Host/Join — synchronized movement & a real attack
3. ⬜ All 4 elements — 3 attacks per element
4. ⬜ HP, victory, round reset — 300 HP, 4-min rounds, best-of-3
5. ⬜ Stat allocation, random specials, all specializations
6. ⬜ Raava event — contested merge, Avatar transformation, element switching
7. ⬜ Terrain interactions, arena themes, visuals, audio, settings

## 🚀 Getting Started

```bash
git clone git@github.com:adds-operations/legend-of-lion-turtle.git
cd legend-of-lion-turtle
# Open the project/ folder in Godot 4
```

## 📄 Docs

- [Bending Rules & Lore](docs/bending-rules.md)
- [Full Game Design Spec](docs/game-design-spec.md)

## License

MIT

# **Factorio Minesweeper**

A fully-playable, tile-based **Minesweeper** experience inside Factorio.
Uses custom tile prototypes, reveal/flag/chord mechanics, async flood-fill, and automated archival of solved regions to keep performance smooth even on huge grids.

---

![minesweeper-overview](https://github.com/RedRafe/minesweeper/blob/main/archive/minesweeper-overview.png?raw=true)

## **Features**

### 🧨 Classic Minesweeper Gameplay
- Left-click to **reveal** tiles
- Right-click to **flag** suspected mines
- Settings to enable auto-**chord** to quickly reveal numbered tiles
- Chain-revealing is handled **asynchronously** to avoid lag

### 🏭 Factorio-Adapted Mechanics
- **Unlimited lives**, but stepping on a hidden mine triggers a *nuclear explosion* — walk carefully!  
- **Un-flagging incorrectly flagged empty tiles** will reveal a *small biter nest surprise*.  
- **Correctly marking mine tiles** (flagging real mines) rewards the player by spawning **resources**.

### 📊 Real-Time Stats & Leaderboards
- Tracks **per-player** and **per-force** stats (reveals, flags, mistakes, detonations, etc.)
- Persistent **leaderboard system** ranking top solvers and safest players
- Multiple stat overlays to choose from

### 🗺️ Procedural Field Generation
- Mines are generated using deterministic noise functions
- Built-in whitelisting for **Nauvis** mapgen, compatible with planets mods
- Safe early area around spawn

### 📦 Performance-Friendly
- Computations run over multiple ticks
- Solved areas are **archived** and replaced with blank tiles
- Entire chunks are auto-archived once cleared

### 🎮 Controls & Commands

| Action | Description |
|-------|-------------|
| **Reveal (LMB)** | Reveal a tile — if zero, flood-fills adjacent tiles |
| **Flag (RMB)** | Toggle a flag on a tile |
| **Chord** | Settings -> Player settings -> Chord |
| `/minesweeper-debug` | Turns ON/OFF the debug visualization tool (Admin only, debug) |
| `/minesweeper-solve` | Turns ON/OFF the auto-solver (Admin only, debug) |

---

## **Credits**

Credits to [tomthedeviant2](https://www.deviantart.com/tomthedeviant2/gallery) for the wonderful Minesweeper assets

Credits to [MewMew](https://github.com/M3wM3w) for original idea & implementation

Credits to [_CodeGreen](https://mods.factorio.com/user/_CodeGreen) for all the support, ideas, ptototype hacks

Credits to [notnotmelon](https://mods.factorio.com/user/notnotmelon) for the super otimized runtime scripts

---

## **Community & Support**

*Join my [Discord](https://discord.gg/pq6bWs8KTY)*

Found a bug? Want to share your board? Hop in and say hi!

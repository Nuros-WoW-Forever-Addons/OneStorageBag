# AI Context & Living Specification — OneStorageBag

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageBag
- **Current Version**: 0.0.2
- **Suite**: Part of the **OneSuite** family (OneStorage Inventory Suite)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageBag
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OneStorageBag/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneStorageBag-latest.zip` on push to `main`
- **Dependencies**: `OneStorageUtils`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Replace the fragmented multi-bag interface with a unified, high-performance all-in-one inventory display styled in authentic Blizzard Metal, with live search filtering, customizable column widths, bag defragmentation, and smart vendor hooks.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneStorageBag.toc`: Manifest, declares dependency on `OneStorageUtils`, SavedVariables (`OneStorageBagDB`).
- `Core.lua`: Master bag canvas creation, button grid pooling, search filter highlighter, column restructuring (`RefreshLayout`), money frame, cleanup button, and slash command dispatcher (`/onebag`, `/osbag`).
- `Hooks.lua`: Intercepts native Blizzard container open/close calls (`ToggleBackpack`, `OpenAllBags`, `CloseAllBags`) and registers event listeners for auto-opening on Merchant, Bank, Mail, Trade, and Auction windows.

### Global State & Database Schema (`OneStorageBagDB`)
```lua
OneStorageBagDB = {
    columns = 10,                      -- Column count (6 to 16)
    separateBags = true,               -- Display row dividers per bag
    showBagBar = false,                -- Expand equipped bag drawer
    autoOpenVendor = true,             -- Open on Merchant
    autoOpenBank = true,               -- Open on Bank
    autoOpenMail = true,               -- Open on Mailbox
    autoOpenTrade = true,              -- Open on Trade
    autoOpenAuction = true,            -- Open on Auction House
    position = {                       -- Saved window position
        point = "BOTTOMRIGHT",
        x = -60,
        y = 60
    }
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/onebag` or pressing `B`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.2
- **Persistent Bag Drawer Visibility**: Fixed issue where the equipped bag drawer (`showBagBar`) failed to persist across `/reload` and game sessions.
  - Updated `OneStorageBag:ToggleBagBar()` and options checkbox to immediately persist user preferences to `OneStorageBagDB.showBagBar`.
  - Added preference synchronization during `ADDON_LOADED`, `CreateFrame()`, and `Show()`, ensuring the bag drawer and canvas layout dynamically restore their expanded/collapsed state upon loading.
  - Added `/onebag bagbar`, `/onebag drawer`, and `/onebag bags` slash commands for toggling drawer visibility.
  - Aligned TOC metadata strictly to single-client target (`Interface: 16001`).

### Spin 0.0.1
- Master all-in-one container window with Blizzard Metal borders and title styling.
- Live item search with real-time text matching and slot opacity dimming.
- Toggle between separated bag rows and merged continuous grid.
- Collapsible bag bar drawer for equipped bag slot inspection.
- Auto-open hooks for NPC and environment interactions.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **Item Quality Color Borders**: Add colored border glow on item buttons matching item quality (Common, Uncommon, Rare, Epic, Legendary).
- [ ] **Item Level Overlay**: Display small item level badge on equippable gear in bags.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Special Container Category Tinting**: Subtle background tinting for specialty bags (Herb, Mining, Enchanting, Quiver/Ammo).
- [ ] **Free Slot Counter Badge**: Summary counter in the title bar showing free slots (e.g. `14 / 80 Free`).

### Priority 3: Low Priority / Exploration
- [ ] **Custom Category Sorting**: Grouping items by custom categories (Consumables, Quest, Trade Goods) within the window.

---

## 🧪 Testing & Verification Guide

- **Toggle Bags**: Press `B` or type `/onebag` — verify master bag opens cleanly.
- **Search Test**: Type "Potion" into the search box — confirm potion slots stay illuminated while others dim to 20% alpha.
- **Column Resizing**: Run `/osbag cols 12` — verify window dynamically widens to 12 columns.
- **Vendor Auto-Open**: Open a vendor window — confirm OneStorageBag opens automatically alongside it.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Secure Item Movement**: Never attempt to move or swap items during combat lockdown.
- **Container Button Template**: Modern WoW requires `ItemButton` template inheritance for proper native tooltip and drag-drop support.

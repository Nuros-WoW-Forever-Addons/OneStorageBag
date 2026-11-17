# AI Context & Living Specification — OneStorageBag

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageBag
- **Current Version**: 0.0.8
- **Suite**: Part of the **OneSuite** family (OneStorage Inventory Suite)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageBag
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/OneStorageBag/`
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
    largeMoney = false,                -- Display larger money text and coin icons
    openScrapOptions = false,          -- Automatically dock and open OneStorageScrap options with Bag options
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
2. **Implementation**: Execute changes. For bounded code generation, refactoring, or review, delegate to NVIDIA Nemotron 3 Super 120B via the `nemotron` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/onebag` or pressing `B`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.9
- **Alt Bag Snapshot Icon & Link Self-Healing**:
  - Implemented automatic on-the-fly healing in `UpdateButton()` for alt bag slots: resolves missing icons and links directly from `slotData.id` using `C_Item.GetItemIconByID` and `ContainerHelper.GetItemInfoSafe`.

### Spin 0.0.8
- **Static Read-Only Bank Button**:
  - Added bottom bar silver button `[Bank]` to the left of the character selector.
  - Clicking `[Bank]` toggles `OneStorageBank` directly in read-only snapshot mode, seamlessly synchronizing the selected alt or current character.

### Spin 0.0.7
- **Eliminated `UseContainerItem` Action Blocked Taint During Disenchant**:
  - Removed custom Lua `OnClick` and `OnDragStart` wrappers on `ContainerFrameItemButtonTemplate` buttons in `CreateItemButton`, preserving native untainted Blizzard execution.
  - Dynamically unregisters mouse clicks and drags via `btn:RegisterForClicks()` and `btn:RegisterForDrag()` when viewing cached alts (read-only mode), and restores them for live player inventory.

### Spin 0.0.6
- **First & Last Name Character Display**:
  - Dropdown button and character list display full character First and Last names on WoW Forever.
  - Alt snapshot frame title displays the character's full First and Last name.

### Spin 0.0.5
- **Cross-Character Inventory Viewer**:
  - Integrated `FrameHelper:CreateCharacterDropdown` at `BOTTOMRIGHT` opposite `moneyText`, featuring realmless class-colored character selection.
  - Added "Return to Self" button on the left of the dropdown when viewing an alt snapshot.
  - Seamless alt viewing in `RefreshLayout`, `UpdateButton`, `UpdateTitle`, `UpdateMoney`, and `UpdateBagBar`.
  - Read-only protection: clicks and drags on alt slots are disabled.
  - Enhanced Alt Tooltip toggle in Bag Options panel.

### Spin 0.0.4
- **OneStorage Scrap Options Docking Integration**: Added options to open and dock `OneStorageScrap` options directly from the Bag Options panel:
  - Added "OneStorage Scrap" section to Bag Options panel with an "Open Scrap Options" checkbox and silver "Scrap Options..." action button.
  - When selected or opened, `OneStorageScrapOptionsFrame` is anchored to the left of `OneStorageBagOptionsFrame` (`TOPRIGHT` to `TOPLEFT`, 0, 0) with matching strata and frame level.
  - While docked, moving the Bag Frame smoothly moves both docked options panels together.
  - Implemented preference persistence via `OneStorageBagDB.openScrapOptions`.
  - Added automatic cleanup: closing Bag Options automatically hides docked Scrap Options to prevent orphaned windows.
  - Added `/onebag scrap` and `/osbag scrapopt` slash commands.
  - Added `## OptionalDeps: OneStorageScrap` to TOC.

### Spin 0.0.3
- **Large Money Text Option**: Added an option to display larger money text and coin icons at the bottom of the bag frame:
  - Added "Large Money Text" checkbox in the Bag Options panel under "Display & Layout".
  - Enlarges the currency FontString from `GameFontHighlightSmall` (10pt) to `GameFontHighlightLarge` (16pt, fallback `GameFontHighlight`).
  - Scales inline gold, silver, and copper coin texture icons from 12px to 16px via `ContainerHelper:FormatMoney(copper, 16)`.
  - Added `/onebag money` and `/osbag largemoney` slash commands to toggle large money text.
  - Automatically docked options panel height adjusted to 405px to comfortably fit new settings.

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

# Changelog — OneStorageBag

All notable changes to **OneStorageBag** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.11] - 2026-11-22
### Fixed
- **Reset Character Selection on Close**:
  - Updated `OnBagHide()` to clear `viewingAlt` and reset the `CharSelect` dropdown to `UnitName("player")` whenever the bag window is closed (via `X`, `Escape`, keybind toggle, or `CloseAllBags`), so reopening the bag always defaults back to the logged-in character.

---

## [0.0.10] - 2026-11-20
### Fixed
- **Live Item & Cooldown Refresh During Combat**:
  - Separated non-protected item/visual refresh (`RefreshItems()`) from structural layout changes (`RefreshLayout()`).
  - During `InCombatLockdown()`, `RefreshLayout()` now defers structural frame/parent/anchor changes to `PLAYER_REGEN_ENABLED` while immediately executing `RefreshItems()` so item textures, stack counts, cooldowns, quality borders, and free-slot counts update live when opening or using items in combat.
  - Pre-builds and positions bag slot buttons on `PLAYER_LOGIN` so bags are ready even if opened for the first time in combat.
  - Added `BAG_UPDATE_COOLDOWN` event listener and guarded `RegisterForClicks`/`RegisterForDrag` in `UpdateButton()` against combat lockdown.

---

## [0.0.9] - 2026-11-15
### Fixed
- **Alt Bag Snapshot Icon & Link Self-Healing**:
  - Implemented automatic on-the-fly healing in `UpdateButton()` for alt bag slots: resolves missing icons and links directly from `slotData.id` using `C_Item.GetItemIconByID` and `ContainerHelper.GetItemInfoSafe`.

---

## [0.0.8] - 2026-11-15
### Added
- **Static Read-Only Bank Toggle Button**:
  - Added a silver `[Bank]` button to the bottom bar immediately to the left of the character dropdown.
  - Clicking `[Bank]` toggles the `OneStorageBank` window in static read-only snapshot mode without needing slash commands or visiting a banker NPC.
  - Automatically synchronizes character view: if currently inspecting an alt's bags, clicking `[Bank]` opens that same alt's bank snapshot.

---

## [0.0.7] - 2026-11-15
### Fixed
- **Eliminated `UseContainerItem` Action Blocked Taint During Disenchant / Spell Targeting**: Fixed `Forbidden function call: AddOn 'OneStorageBag' attempted to call 'UseContainerItem()'` when disenchanting, milling, prospecting, or using items in bags:
  - Removed custom Lua `OnClick` and `OnDragStart` wrappers on `ContainerFrameItemButtonTemplate` buttons in `CreateItemButton`, preserving Blizzard's native, untainted C-level execution path for item use and targeting.
  - Dynamically unregisters mouse clicks and drags via `btn:RegisterForClicks()` and `btn:RegisterForDrag()` when viewing cached alts (read-only mode), and restores them via `btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")` / `btn:RegisterForDrag("LeftButton")` for live player inventory.

---

## [0.0.6] - 2026-11-15
### Enhanced
- **First & Last Name Display**:
  - Character selector dropdown button and selection popup list now display full character First and Last names.
  - Bag window title displays the character's full First and Last name when inspecting an alt's bag snapshot.

---

## [0.0.5] - 2026-11-15
### Added
- **Cross-Character Inventory Viewer**:
  - Added bottom-right character dropdown opposite currency display, allowing players to view the bag contents of any character on their account without relogging.
  - Added "Return to Self" button immediately to the left of the dropdown when viewing an alt, cleanly restoring the live player inventory.
  - Alt snapshots display cached bag slots, items, stack counts, equipped bags, and money with full hover tooltips in safe read-only mode (clicks and drags disabled to avoid action-blocked errors).
  - Search filtering fully functions on cached alt items.
- **Enhanced Alt Tooltip Option**:
  - Added "Enhanced Alt Tooltip" checkbox to Bag Options panel under "Display & Layout" to toggle the cross-character item count sub-frame on or off.

---

## [0.0.4] - 2026-11-15
### Added
- **OneStorage Scrap Options Docking Integration**: Added options to open and dock the `OneStorageScrap` options panel directly from the Bag Options panel:
  - Added "OneStorage Scrap" section to the Bag Options panel with an "Open Scrap Options" checkbox and silver "Scrap Options..." action button.
  - When selected/opened, `OneStorageScrapOptionsFrame` opens cleanly anchored to the left of `OneStorageBagOptionsFrame` (`TOPRIGHT` to `TOPLEFT`, 0, 0) with synchronized strata and frame level.
  - While docked, moving the Bag Frame or Bag Options panel smoothly translates both panels together.
  - Added preference persistence via `OneStorageBagDB.openScrapOptions`, automatically opening docked Scrap Options whenever Bag Options is opened if enabled.
  - Added automatic cleanup: closing Bag Options automatically hides docked Scrap Options to avoid detached windows.
  - Added `/onebag scrap` and `/osbag scrapopt` slash commands to quickly open the docked options layout.
  - Declared `## OptionalDeps: OneStorageScrap` in `OneStorageBag.toc`.

---

## [0.0.3] - 2026-11-06
### Added
- **Large Money Text Option**: Added an option to display larger money text and coin icons at the bottom of the bag frame:
  - Added "Large Money Text" checkbox in the Bag Options panel under "Display & Layout".
  - Enlarges the currency FontString from `GameFontHighlightSmall` (10pt) to `GameFontHighlightLarge` (16pt, fallback `GameFontHighlight`).
  - Scales inline gold, silver, and copper coin texture icons from 12px to 16px via `ContainerHelper:FormatMoney(copper, 16)`.
  - Added `/onebag money` and `/osbag largemoney` slash commands to toggle large money text.
  - Automatically docked options panel height adjusted to 405px to comfortably fit new settings.

---

## [0.0.2] - 2026-10-17
### Fixed
- **Persistent Bag Drawer Visibility**: Fixed issue where the equipped bag drawer (`showBagBar`) failed to persist across `/reload` and game sessions.
  - Updated `OneStorageBag:ToggleBagBar()` and options checkbox to immediately persist user preferences to `OneStorageBagDB.showBagBar`.
  - Added preference synchronization during `ADDON_LOADED`, `CreateFrame()`, and `Show()`, ensuring the bag drawer and canvas layout dynamically restore their expanded/collapsed state upon loading.
  - Added `/onebag bagbar`, `/onebag drawer`, and `/onebag bags` slash commands for toggling drawer visibility.
  - Aligned TOC metadata strictly to single-client target (`Interface: 16001`).

---

## [0.0.1] - 2026-10-10
### Added
- **Unified Master Bag Window**: All-in-one container frame with Blizzard Metal aesthetic.
- **Dual Grid Layout Options**: Support for continuous merged grid and separated bag rows (`/osbag mode`).
- **Live Search Filtering**: Search query highlighting with unselected slot dimming.
- **Collapsible Bag Bar Drawer**: Expandable tray for inspecting and swapping equipped bags.
- **Interaction Hooks (`Hooks`)**: Automated open/close on Merchant, Bank, Mail, Trade, and Auction windows.
- **Scrap Indicators**: Visual scrap coin overlay on items identified as junk.

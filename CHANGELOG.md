# Changelog — OneStorageBag

All notable changes to **OneStorageBag** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

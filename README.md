# OneStorageBag

**OneStorageBag** is an all-in-one unified player inventory window for World of Warcraft featuring authentic Blizzard Metal styling, real-time search filtering, bag cleanup sorting, a collapsible bag bar drawer, and automated vendor interaction hooks.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🎒 **Unified All-In-One Inventory**: Replaces separate container windows with a single, consolidated inventory display.
- 🛡️ **Authentic Blizzard Metal Styling**: Framed with signature silver metal borders, dark slate insets, and metallic title bars powered by `OneStorageUtils`.
- 🔍 **Real-Time Live Search Filtering**: Type in the top search box to instantly highlight matching items and fade out non-matching inventory slots.
- 📐 **Flexible Layout Modes**:
  - **Merged Grid Mode**: Compact continuous grid of inventory slots.
  - **Separated Bags Mode**: Visual row dividers separating individual bag containers.
  - **Configurable Column Width**: Adjust from 6 to 16 columns (`/osbag cols <number>`).
- 🗄️ **Collapsible Bag Bar Drawer**: Click the bag icon to reveal or hide equipped bag slots for easy bag upgrades.
- 🧹 **One-Click Bag Cleanup**: Integrated cleanup button to defragment and sort inventory contents.
- 🪙 **Scrap Indicator Badges**: Automatically displays a gold coin badge on vendor junk items (integrated with `OneStorageScrap`).
- 🔄 **Smart Auto-Open Hooks**: Automatically opens and closes bags when interacting with Merchants, the Bank, Mailboxes, Trade windows, or the Auction House.

---

## 🛠️ Installation

Copy the `OneStorageBag` directory (along with `OneStorageUtils`) into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneStorageBag/
├── OneStorageBag.toc
├── Core.lua
├── Hooks.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/onebag` or `/osbag` | Open / toggle the unified bag window |
| `/osbag mode` or `/osbag separate` | Toggle between separated bag rows and merged continuous grid |
| `/osbag cols <6-16>` | Set the column width of the bag window |
| `/osbag bagbar` or `/osbag drawer` | Toggle equipped bag drawer visibility |
| `/osbag reset` | Reset bag window position to default |
| `/osbag options` | Open configuration options |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).

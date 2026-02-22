# ChatLootBidder Features

This document describes the complete feature set of the ChatLootBidder addon. Features are grouped by theme.

---

## 1. Session Lifecycle

A loot session is the core workflow: the Master Looter opens bidding on one or more items, raiders whisper their bids, and winners are resolved when the session ends.

- **Starting a session** (`/loot start [item-links] [timer]`) — opens bidding on the provided items plus any previously staged items. The player must be a raid assistant and Master Looter must be set. An optional timer (in seconds) can be appended; it defaults to the configured `TimerSeconds` (30s). If a session is already active, it is automatically ended before starting the new one.
- **Ending a session** (`/loot end`) — resolves all winners across all items, announces results to the configured channels, and clears the session state.
- **Clearing** (`/loot clear`) — wipes the current session or stage entirely. `/loot clear [item-link]` removes only that specific item from the stage (not from an active session). Clearing is irreversible.
- **Mid-session summary** (`/loot summary`) — posts the current bid state to the bid channel without ending the session.

---

## 2. Item Staging

Staging allows the Master Looter to queue items before officially starting a session, useful for bundling loot from multiple sources.

- **Manual staging** (`/loot stage [item-links]`) — adds items to the stage. Each invocation increments the count for that item (supporting duplicate drops).
- **Auto-staging** — when the `AutoStage` setting is enabled, the `LOOT_OPENED` event automatically stages items from a looted corpse filtered by rarity (`MinRarity` to `MaxRarity`, default: epic to legendary). Re-looting the same corpse uses a set-max strategy so items are not double-counted.
- **Unstaging** — individual items can be removed from the stage via GUI unstage buttons or `/loot clear [item-link]`.
- **Duplicate item support** — multiple copies of the same item are tracked by count and displayed as `(x2)`, `(x3)`, etc.
- **Stage limit** — up to 8 items can be staged at once.

---

## 3. Bidding Modes

The addon supports two mutually exclusive bidding modes, configurable via the GUI.

- **MSOS mode** (default) — Main Spec / Off Spec / Roll. No bid amounts are used. All MS bidders compete equally (ties broken by roll-off), then OS, then Roll. When a player bids MS or OS, a pending roll is automatically created for tie-breaking purposes.
- **DKP mode** — bid amounts are required with MS and OS bids. Highest bid wins within each tier. Configurable `MinBid` and `MaxBid` enforce bid range. Ties can optionally be broken by roll-off (controlled by `BreakTies` setting).

---

## 4. Bid Types and Processing

Raiders whisper the Master Looter to place bids during an active session. The bidder must be in the raid.

- **Main Spec (`ms`)** — highest priority tier. One MS bid per player per item. In DKP mode, a numeric amount is required.
- **Off Spec (`os`)** — second priority tier. One OS bid per player per item. In DKP mode, a numeric amount is required.
- **Roll (`roll`)** — lowest priority tier. The player declares intent to roll, then can `/random` to self-roll or let the addon auto-roll at session end.
- **Cancel (`cancel`)** — removes the player's MS and OS bids for that item. The roll value is preserved so re-bidding doesn't lose a prior self-roll.
- **Flexible syntax** — the addon accepts both `[item] ms 50` and `[item] 50 ms` orderings.

---

## 5. Bid Modifiers (Note Parameters)

After the bid tier and amount, raiders can append a note. Words at the beginning of the note are parsed as behavioral flags.

- **Alt flag** (`alt`) — marks the bid as coming from an alt character. In DKP mode, this applies the configured alt penalty to reduce the effective bid.
- **No-Reply flag** (`nr`) — suppresses the whispered bid confirmation from the addon.
- **Role flags** (`heal`, `dps`, `tank`) — informational markers attached to the bid. Currently not used in resolution logic.
- Flags must appear at the start of the note. Semicolons after flags are optional. Flags can appear in any order: `alt nr; my note` and `nr alt my note` are equivalent.

---

## 6. DKP Penalties

DKP mode supports two configurable penalties that alter effective bid values.

- **Alt Penalty** — a percentage reduction applied to bids flagged with `alt`. A 50% penalty on a bid of 100 yields an effective bid of 50.
- **Offspec Penalty** — a percentage that "promotes" OS bids to compete in the MS tier at a reduced value. A 50% penalty on an OS bid of 100 creates a phantom MS bid of 50. If the promoted OS bid wins and there were no natural MS bids, the winner is announced as OS at their original bid amount.
- **Combined penalties** — alt and offspec penalties are multiplicative. An alt OS bid with both 50% penalties would compete as an MS bid at 25% of the original value.
- **Display format** — penalized bids are shown as `effective(actual)` (e.g., `50(100)`).

---

## 7. Winner Resolution

When a session ends, winners are determined per item using a tiered priority system.

- **Tiered resolution** — bids are resolved in order: MS, then OS, then Roll. Each tier fills remaining item copies before the next tier is considered.
- **Duplicate item handling** — when multiple copies of an item drop, the available copies are split between SR claims and MS/OS/Roll bidding. Winners are selected until all copies are awarded or all bidders are exhausted.
- **Tie-breaking** — when multiple bidders tie (same bid amount in DKP, or all equal in MSOS), a roll-off determines the winner. In MSOS mode, ties always trigger a roll-off. In DKP mode, roll-offs are controlled by the `BreakTies` setting.
- **Roll-off mechanics** — tied bidders roll; the highest roller wins. If the roll-off itself ties, it recurses until resolved. Previously recorded self-rolls are reused; new rolls are generated for players who haven't rolled.
- **Winner announcement format** — DKP mode: `"PlayerX wins [Item] with a MS bid of 150"`. MSOS mode: `"PlayerX wins [Item] for MS"`. Roll wins: `"PlayerX wins [Item] with a roll of 85"`.
- **No bids** — if no bids are received for an item, `"No bids received for [Item]"` is announced.

---

## 8. Roll System

Rolling provides an alternative to point-based bidding and serves as the tie-breaking mechanism.

- **Self-rolling** — players use `/random` in-game. The addon captures `CHAT_MSG_SYSTEM` roll events matching the `%s rolls %d (%d-%d)` pattern and records them against pending roll bids. Only 1-100 rolls are accepted.
- **Auto-rolling** — at session end, any player with a pending roll bid (`-1`) who hasn't self-rolled receives a `math.random(1, 100)`.
- **Single-item shortcut** — when exactly one item is in the session, a bare `/random` (without first whispering `[item] roll`) automatically assigns the roll to that item.
- **Roll announcement** — when `RollAnnounce` is enabled, rolls are posted to the session channel. Multiple rolls are batched onto single chat lines (capped at ~200 characters per line) to reduce spam. If only one player rolled, the roll is not separately announced (it will appear in the winner announcement).
- **Roll ordering** — when a player has roll bids on multiple items, an incoming `/random` is assigned to the first item with a pending roll. For deterministic ordering, players should bid on one item, roll, then bid on the next.

---

## 9. Soft Reserve System

Soft Reserves (SR) overlay on top of MSOS mode, allowing raiders to pre-claim items before a loot session begins. SR is only available in MSOS mode.

### Management
- **Loading** (`/loot sr load [name]`) — loads or creates a named SR list. If no name is provided, defaults to today's date (`YY-MM-DD`). Multiple lists on the same day are indexed (e.g., `25-02-22`, `25-02-22-1`).
- **Unloading** (`/loot sr unload`) — deactivates the current SR list without deleting it.
- **Deleting** (`/loot sr delete [name]`) — permanently removes an SR list.

### Raider Interaction
- **Placing an SR** — whisper `sr [item-link]` or `sr exact-item-name` to the Master Looter. Item links are preferred; plain text must match exactly.
- **Querying** — whisper bare `sr` to see your current reservations and lock status.
- **Clearing** — whisper `sr clear` to remove all your reservations.
- **Multiple SRs** — when `DefaultMaxSoftReserves` allows more than 1, multiple item links can be sent in a single whisper. Exceeding the max pushes the oldest SR out.

### Locking
- **Manual lock/unlock** (`/loot sr lock`, `/loot sr unlock`) — toggles whether new SR bids are accepted.
- **Auto-lock** — when `AutoLockSoftReserve` is enabled, the SR list locks automatically when a loot session starts.
- **Edit lock** — while the SR edit frame is open, incoming SR bids are treated as locked.

### Resolution
- At session start, items with SRs from raid members are separated from the MS/OS/Roll bidding pool. SR'd copies are claimed first.
- If enough copies exist for all SRers, they win automatically and are notified immediately.
- If more SRers than copies, a roll-off determines winners among SRers.
- Non-SR copies remain available for normal MS/OS/Roll bidding.

### Additional Features
- **Auto-remove after win** — when `AutoRemoveSrAfterWin` is enabled, winning an SR item removes that reservation from the player's list.
- **Item validation** — when AtlasLoot is loaded, SR item names are validated against its database. Invalid names are rejected with a message; case mismatches are auto-corrected.
- **SR show** (`/loot sr show`) — lists all current SRs to the session channel. Players not in the raid are shown only to the Master Looter locally.
- **SR instructions** (`/loot sr instructions`) — posts usage directions to the session channel.

### Import/Export
Four encoding formats are supported via the SR edit frame or slash commands:
- **JSON** (`/loot sr json`) — `{ "Player": ["Item1", "Item2"] }` structure.
- **CSV** (`/loot sr csv`) — flattened `Player,Item` rows.
- **Semicolon** (`/loot sr semicolon`) — `Player ; Item1 ; Item2` per line.
- **RaidRes.Fly** (`/loot sr raidresfly`) — `[00:00]Player: Player - Item` format, compatible with [raidres.fly.dev](https://raidres.fly.dev) export.

---

## 10. Chat Channel Configuration

Three independently configurable channels control where different types of messages are sent.

- **Bid Channel** (default: `OFFICER`) — receives bid announcements (when enabled) and session summaries. Set via GUI or `/loot bid ChannelName`.
- **Session Announce Channel** (default: `RAID`) — receives session start messages, roll announcements, and SR instructions. Set via GUI or `/loot session ChannelName`.
- **Winner Announce Channel** (default: `RAID_WARNING`) — receives winner announcements and roll-off results. Set via GUI or `/loot win ChannelName`.
- **Custom channels** — any value not matching a static channel (`RAID`, `RAID_WARNING`, `SAY`, `EMOTE`, `PARTY`, `GUILD`, `OFFICER`, `YELL`) is treated as a custom channel name and routed via `GetChannelName`.

---

## 11. Announcement Controls

Three toggles control the verbosity of session output.

- **Bid Announce** (`BidAnnounce`, default: off) — when enabled, each incoming bid is echoed to the bid channel as it arrives.
- **Bid Summary** (`BidSummary`, default: off) — when enabled, a full summary of all bids is posted to the bid channel when a session ends.
- **Roll Announce** (`RollAnnounce`, default: on) — when enabled, roll results are announced to the session channel. When disabled, rolls are whispered privately to the roller.

---

## 12. GUI

The addon provides several GUI frames for configuration and session management.

- **Options panel** (`/loot` with no arguments) — toggles the main configuration panel where all settings are managed: mode selection, channel configuration, penalty sliders, auto-stage toggles, class color toggle, SR management buttons, and more.
- **Stage frame** — appears when items are staged. Displays up to 8 items with individual unstage buttons. Shows the current bidding mode in the header (e.g., `MSOS Mode`). Provides Start Session, End Session, and Clear buttons that show/hide contextually based on session state.
- **SR edit frame** — a text editor for viewing and editing SR data in JSON, CSV, semicolon, or RaidRes.Fly formats. Saving the editor contents decodes and replaces the current SR list. While open, incoming SR bids are blocked.
- **Frame position persistence** — the stage frame's position is saved to `ChatLootBidder_Store.Point` and restored on login.

---

## 13. Player Display

- **Class colors** (`ShowPlayerClassColors`, default: on) — player names in chat output are wrapped in their class color. This works independently of pfUI by using a built-in `RAID_CLASS_COLORS` table (falls back to pfUI's table if available). Disabling this allows more names to fit on a single chat line due to the 255-character line limit (each colored name adds ~25 hidden characters).
- **Player links** — player names are formatted as clickable `/Hplayer:` links in chat output.

---

## 14. Integration

- **NotChatLootBidder** — the companion raider addon. ChatLootBidder sends addon messages (`NotChatLootBidder` prefix) on session start (with mode and item list) and session end, allowing NotChatLootBidder to display a bidding UI for raiders.
- **BigWigs** — if the BigWigs boss mod is loaded and the timer is greater than 0, a BigWigs timer bar (`"Bidding Ends"`) is started when a session begins.
- **ChatThrottleLib** — all outgoing chat messages (whispers, channel messages, addon messages) are sent through ChatThrottleLib to respect Turtle server rate limits and avoid chat bans. The library uses a configurable line buffer (10 lines).
- **Version checking** — `VersionUtil` broadcasts the addon version via addon messages and alerts the Master Looter when a newer version is available.

---

## 15. Slash Commands

All commands use the `/loot` prefix (alias `/l`).

| Command | Description |
|---|---|
| `/loot` | Toggle the GUI options panel |
| `/loot help` | Show command summary and addon info |
| `/loot start [items] [timer]` | Start a loot session |
| `/loot end` | End the current session and announce winners |
| `/loot stage [items]` | Stage items for a future session |
| `/loot clear` | Clear the current session or stage |
| `/loot clear [item]` | Remove a specific item from the stage |
| `/loot summary` | Post current bid state to bid channel |
| `/loot debug [0-2]` | Set debug verbosity (0=off, 1=debug, 2=trace) |
| `/loot bid Channel` | Set the bid announce channel |
| `/loot session Channel` | Set the session announce channel |
| `/loot win Channel` | Set the winner announce channel |
| `/loot sr load [name]` | Load or create an SR list |
| `/loot sr unload` | Unload the current SR list |
| `/loot sr delete [name]` | Delete an SR list |
| `/loot sr show` | Display all current SRs |
| `/loot sr instructions` | Post SR instructions to session channel |
| `/loot sr lock` | Lock the SR list |
| `/loot sr unlock` | Unlock the SR list |
| `/loot sr json` | Open SR edit frame in JSON format |
| `/loot sr csv` | Open SR edit frame in CSV format |
| `/loot sr semicolon` | Open SR edit frame in semicolon format |
| `/loot sr raidresfly` | Open SR edit frame in RaidRes.Fly format |

---

## 16. Anti-Spam and Deduplication

- **Whisper deduplication** — identical whisper content from the same sender is ignored on consecutive receives. This prevents duplicate processing when the same whisper is read in multiple chat windows.
- **Roll batching** — when announcing rolls, multiple player rolls are combined onto single chat lines (up to ~200 characters) to minimize the number of messages sent.
- **Chat throttling** — ChatThrottleLib enforces rate limiting on all outgoing messages with priority levels (`ALERT` for whisper responses, `NORMAL` for channel messages, `BULK` for addon messages) to avoid triggering Turtle server chat bans.

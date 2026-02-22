# ChatLootBidder Architecture

## Overview

ChatLootBidder is a WoW 1.12 addon for managing loot distribution in raids via whisper-based bidding. A raid leader starts a loot session for one or more items; raiders bid by whispering the leader. The addon tracks bids, resolves winners by tier priority (SR > MS > OS > Roll), and announces results to raid chat.

## Runtime Environment

WoW 1.12 Lua has no module system (`require`, `module`, etc.). All addon files are loaded sequentially by the client in the order declared in the `.toc` file. Each file executes in the global scope. Cross-file communication happens through globals.

## Shared Namespace

All internal modules share state and functions through a single global table:

```
ChatLootBidderNS
```

This table is created by `CLB_Util.lua` (the first module loaded) and referenced as `local NS = ChatLootBidderNS` at the top of every subsequent module.

The name `ChatLootBidderNS` is used instead of the shorter `CLB` because `CLB` is already a global alias used externally for slash command dispatch.

## Module Layout

```
CLB_Util.lua           Namespace, shared state, pure utilities, raid helpers
CLB_Messaging.lua      Chat output, formatting, channel routing
CLB_SoftReserve.lua    Soft Reserve CRUD, encoding/decoding, validation
CLB_Bidding.lua        Whisper handling, bid processing, winner resolution
ChatLootBidder.lua     Session lifecycle, slash commands, event handlers, UI
```

Supporting files (not part of the core module graph):

```
i18n.lua               Localization strings
csv.lua                CSV parsing/formatting
json.lua               JSON parsing/formatting
VersionUtil.lua        Addon version checking
ChatThrottleLib.lua    Chat rate limiting (third-party)
*.xml                  UI frame definitions
```

## Load Order and Dependencies

Files load in TOC order. Each module may only depend on modules loaded before it.

```
CLB_Util.lua
  ^
  |
CLB_Messaging.lua
  ^
  |
CLB_SoftReserve.lua
  ^
  |
CLB_Bidding.lua
  ^
  |
ChatLootBidder.lua
```

There are no circular dependencies. Later modules call into earlier ones via `ChatLootBidderNS` fields; earlier modules never reference later ones.

## Module Responsibilities

### CLB_Util.lua

Creates the `ChatLootBidderNS` table and initializes shared mutable state fields (`session`, `sessionMode`, `stage`, `softReserveSessionName`, `softReservesLocked`, `lastWhisper`).

Provides domain-free utilities: table helpers, string parsing, item link extraction, number normalization, raid roster queries, channel validation. Nothing here knows about bidding rules, soft reserves, or loot distribution.

### CLB_Messaging.lua

Owns all user-facing output: error/info/debug messages to the default chat frame, whisper responses, and channel broadcasts. Also provides display formatting: class-colored player names, bid amount rendering, and error message templates.

Separates transport concerns from business logic so that callers never construct raw chat messages.

### CLB_SoftReserve.lua

Owns the Soft Reserve subsystem end-to-end: session creation, loading, unloading, deletion; player SR add/remove/query; lock/unlock; import/export in multiple formats (CSV, JSON, semicolon, RaidResFly); and item name validation against AtlasLoot data.

Frame methods for SR management (`HandleSrLoad`, `HandleSrShow`, `HandleEncoding`, `DecodeAndSave`, etc.) are defined here.

### CLB_Bidding.lua

Handles incoming whispers by overriding the global `ChatFrame_OnEvent`. Routes SR whispers to `CLB_SoftReserve`, and bid whispers through local parsing, validation, and recording logic.

Owns winner resolution: the `BidSummary` function orchestrates SR resolution, tier-by-tier (MS > OS > Roll) winner selection, roll-off tie-breaking, and result announcements. These are decomposed into focused local helpers (`RollOff`, `ResolveTierWinners`, `AnnounceWinner`, etc.).

### ChatLootBidder.lua

The orchestration layer. Handles addon initialization (`ADDON_LOADED` loads stored variables, registers slash commands, populates Options UI). Manages session lifecycle (`Start`, `End`, `Clear`, `Stage`, `Unstage`). Dispatches slash commands to the appropriate module. Handles WoW events (`CHAT_MSG_SYSTEM` for roll tracking, `LOOT_OPENED` for auto-staging, world enter/leave for frame persistence).

UI frame methods (`RedrawStage`, `EndSessionButtonShown`, `OnVerticalScroll`, etc.) live here alongside the frame-local button references they manipulate.

## Key Data Structures

### Session (`NS.session`)

`nil` when no session is active. When active, a table keyed by item link:

```
session[itemLink] = {
    count     = <total copies>,
    bidCopies = <copies open for MS/OS/Roll bidding>,
    sr        = { [player] = 1, ... },           -- soft reserve claims
    ms        = { [player] = amount, ... },      -- mainspec bids
    os        = { [player] = amount, ... },      -- offspec bids
    roll      = { [player] = rollValue, ... },   -- roll values (-1 = pending)
    cancel    = { [player] = true, ... },        -- canceled bids
    notes     = { [player] = "note text", ... },
    real      = { [player] = originalAmount, ... },
    ms_origin = { [player] = "os", ... },        -- tracks promoted OS bids
}
```

### Soft Reserve Storage (`ChatLootBidder_Store.SoftReserveSessions`)

Persistent across sessions via `SavedVariables`:

```
SoftReserveSessions[sessionName][playerName] = { itemName1, itemName2, ... }
```

### Stage (`NS.stage`)

Items queued for the next session start:

```
stage[itemLink] = count
```

### Persistent Config (`ChatLootBidder_Store`)

Saved between game sessions. Contains all user preferences (channels, timers, penalties, toggles) plus soft reserve session data.

## Bid Resolution Order

When a session ends, each item is resolved independently:

1. **Soft Reserve** -- SR claimants win their reserved copies. Contested SRs (more claimants than copies) are resolved by roll-off.
2. **Main Spec** -- Highest MS bid wins. Ties are broken by roll-off (or left to master looter in DKP mode with `BreakTies` off).
3. **Off Spec** -- Same rules as MS, for remaining copies.
4. **Roll** -- Random rolls for remaining copies.

In DKP mode, offspec bids are promoted into the MS tier with a configurable penalty, and alt penalties reduce effective bid amounts.

## Testing

Tests run outside the WoW client using standard Lua 5.1. `tests/wow_mocks.lua` stubs the WoW API surface (frames, chat, raid roster, loot). `tests/test_runner.lua` loads modules in TOC order, fires `ADDON_LOADED`, then discovers and runs `*_test.lua` files in random order.

Tests interact exclusively through public surfaces: slash commands (`SlashCmdList`), whisper simulation (`SendWhisper`), roll simulation (`SimulateRoll`), and chat log assertions (`assert_log_contains`). Internal module boundaries are not tested directly, which allows restructuring internals without changing tests.

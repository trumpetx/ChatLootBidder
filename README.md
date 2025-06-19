# Overview and Goals
This addon's primary goal is to manage the process of bidding and rolling on items in a Master Looter environment in a semi-automated way.  This addon is for Master Looters.  If you are a bidder/raider, you should check out the [NotChatLootBidder](https://github.com/trumpetx/NotChatLootBidder) addon.

__Goals:__
* __No addons are required__ for Raiders
* A Master Looter can start a loot session on one or more items and _concurrently_ receive bids on everything
* Raiders submit their bidding intention secretly by whispering the Master Looter
* Once complete, all winners are announced
* Compatible with a 1.12.1 / Turtle client

__Items that are not goals:__
* Keeping track of a Raider's "points" (Doing this probably means you want to use an entirely different addon)
* Making sure that a Raider has enough "points" to win after bidding (goes with the above)
* Automatically starting or ending a session
* Automatically distributing loot

# Directions and Setup
## Info / Help
* `/loot help` to see a summary of commands along with information about the addon
## Addon Setup
Most configuration should be set to a reasonable default
* `/loot` Show the GUI options menu
![image](https://github.com/user-attachments/assets/7524567e-e2ca-44a0-a3bc-4d530290acec)


* Custom Channels (unable to set in GUI)
  * `/loot bid CustomChannel` Set the "Bid Channel" to the custom channel "CustomChannel"
  * `/loot session CustomChannel` Sets the "Session Announce Channel" to the custom channel "CustomChannel"
  * `/loot win CustomChannel` Sets the "Winner Announce Channel" to the custom channel "CustomChannel"
* `/loot debug 2` Sets the debug level to `2` which is VERY SPAMMY.  `1` is slightly less spammy than `2`.  This should not be necessary unless you're trying to debug the addon behavior.  `0` is the default and returns the addon to non-spam-you mode.
## Raid Usage
Enabling Auto-Stage will render these chat commands unnecessary; however, they are still useful for testing.
* `/loot stage [item-link][item-link]` stage items for a session start.  This can be used to add items before officially starting the session (to bundle multiple boss loot, for example).
* `/loot start [item-link][item-link][item-link][item-link]` to start a new loot session with the declared items (along with any staged items).  Directions and item links will be listed to the "Session Channel".
  * `/loot start [item-link] 120` starts a session with a custom timer length of 120 seconds
  * The timer is just a suggestion, the Master Looter still needs to run `/loot end` to end the session.
  * While you don't technically need to be a Raid assistant to be a Master Looter, you must be one to use the addon.
  * You do not have to be the actual designated Master Looter in order to run the addon (e.g. separate the bid taker from the loot distibutor)
* `/loot clear` to clear the current bidding session or stage.  This clears all items, rolls, and bids completely.  It is not reversable: BE CAREFUL.
* `/loot clear [item-link]` to clear specific item(s) from the stage.  This can be reversed by `/loot stage [item-link]` and does not apply to sessions at all.
* `/loot summary` if a current session is active, post the current summary to the "Bid Channel"
* `/loot end` to end the current loot session.  Winners will be announced to the "Win Channel".  If enabled, a summary will be posted to the "Bid Channel".

Raiders bid after a session has been started:
* `/w Masterlooter [item-link] ms 100` to bid 100 points at the Main-Spec tier of bidding
* `/w Masterlooter [item-link] os 10` to bid 10 points at the Off-Spec tier of bidding
* `/w Masterlooter [item-link] roll` to declare that you would like to roll for this item
  * Once declared, you can then `/random` yourself to have your roll linked to your roll bid.  If you have multiple roll bids, your rolls are assigned in a non-deterministic order.  If you want to control the order of your rolls, bid first, then roll, bid second, then roll.
  * If you choose not to roll yourself, the addon will do a `math.random(1, 100)` on your behalf.  The only reason to roll yourself is if you (A) don't trust the Master Looter or (B) believe that your dice are better than other dice.
  * SPECIAL CASE - ONE ITEM ONLY: You may simply `/random` to have your roll applied to that item without `/w Masterlooter roll` first (since it's unambiguous which item you're rolling on)

Raiders can cancel bids:
* `/w Masterlooter [item-link] cancel` to cancel an existing bids (MS/OS/roll)
  * note: a roll is saved until the Loot Session is ended in case you re-roll on a given item
  * You can use this to change the "tier" of a bid from MS to OS, etc
  * If there are some roll bids where users did not roll on their own behalf, their rolls will be generated and posted to the "Session Channel" (if enabled) or whispered to them (if disabled)

## Soft Reserve Usage
### Raid Leader
Soft Reserves are like an extra meta-session on top of `/loot msos` mode.  The Master Looter can load a Soft Reserve list by executing the command: `/loot sr load` which takes an optional parameter of the list name.  For example, `/loot sr load bwl` will load the "bwl" list (to allow SRs to persist week to week if desired).  Not providing a list name will simply use today's date in the format YY-MM-DD for the list name.

Once the Soft Reserve list is loaded, you can perform the following actions (these also have GUI buttons in `/loot`)
* `/loot sr show` - list out (to the "Session Channel") all current Soft Reserve bids (non-raid members are not listed)
* `/loot sr instructions` - Spam basic Soft Reserve instructions to the "Session Channel"
* `/loot sr lock` - Lock the current Soft Reserve list
* `/loot sr unlock` - Unock the current Soft Reserve list
* `/loot sr delete` - Delete the currently loaded Soft Reserve list or `/loot sr delete list-name` to delete the 'list-name' list.
* `/loot sr unload` - Unload the current list and turn off Soft Reserve functionality.
* `/loot sr json` - Suspend Soft Reserve functionality and manually edit the loaded list in raw JSON format.  Use this mode for mass importing/exporting Soft Reserves from other tools.
* `/loot sr semicolon` - Suspend Soft Reserve functionality and manually edit the loaded list in raw semicolon-separated format.  Use this mode for mass importing/exporting Soft Reserves from other tools.
* `/loot sr csv` - Suspend Soft Reserve functionality and manually edit the loaded list in csv format.  Use this mode for mass importing/exporting Soft Reserves from other tools.
* `/loot sr raidresfly` - Suspend Soft Reserve functionality and manually edit the loaded list in [RaidRes.Fly](https://raidres.fly.dev) format.  There is no website import, but you can use the website export to import to this addon.

### Raiders (getting your SR bids in)
Whisper the Master Looter in the following format: `/w Masterlooter sr [item-link]`.  If it is successful, a reply will be sent to you.  If you do not have the item to link, you may use plain text, but beware **plain text bids must be EXACT**.  If you use item links, and the Master Looter has configured more than 1 SR, you can send them in at the same time: `/w Master looter sr [item-link-1][item-link-2]`.  If using plain-text bidding, only send 1 Soft Reserve bid at a time.

# Known Issues / FAQ
* The addon does not handle duplicate items at all.  Due to the data structures to prevent duplicates (using the item link as the key), this will be hard to change in the future.  Master Looters should be aware that this is a known issue and may never change.
* Looting a boss twice will load the items to the stage twice if a session was not started.

# Changelog

* 1.9.0
  * Adding an "Offspec Penalty" feature which only works for DKP mode.  This penalty will "upgrade" an OS bid (at the penalty %) to compete with MS bids.  For example, setting this value to 50% would mean that an OS bid of "10" would be the same as a MS bid of "5".  The addon handles all of the math and will display the calculated bid along with the actual bid like `5(10)`.  If the "Alt Penalty" is also in effect, the penalty is considered multiplicative.  So an alt OS bid would compete with a MS bid after accounting for both of those penalties.
* 1.8.1
  * Removing #(0) announces for rolls on alts
* 1.8.0
  * Adding in "Alt Penalty" which is entirely optional for DKP mode.  This value will alter bids coming in if the "Note" starts with the letters `a` `l` `t` case-insensitive.
    * `/loot debug 1` to see the value as you move the slider; showing the "value" on all of the sliders is a TODO enhancement
    * `/loot debug 0` to turn off the spam
* 1.7.5
  * Properly removing someone's SR when they win (when configured)
  * Fixing error when canceling a bid in SR mode
  * Announcing the item someone is bidding for when announce is enabed (previosuly only announced the tier/amt)
* 1.7.4
  * Updated ChatThrottleLib to get around Turtle chat bans
* 1.7.3
  * Fixing DKP mode (all sessions were started in MSOS mode)
* 1.7.2
  * Separating 'Delete' and 'Unload' into separate buttons
  * Separating 'Load' and 'Add' into separate buttons
  * Allowing 'Add' to create new raids on the same calendar day
* 1.7.1
  * Added a GUI for Soft Reserve Managing / Editing / Importing
* 1.7.0
  * **Adding a GUI for confiuration**
    * *Most slash-commands for configuration were removed and should now only be set via the GUI panel*
* 1.6.3
  * Added Soft Reserve name validation (Requires AtlasLoot [1.12.1](https://legacy-wow.com/vanilla-addons/atlasloot-enhanced/), [Turtle](https://turtle-wow.fandom.com/wiki/AtlasLoot))
* 1.6.1-2
  * Soft Reserve Bug Fixes
* 1.6.0
  * Changed MSOS mode to be the default after a fresh install
  * Added Soft Reserve functionality to MSOS mode
    * As the loot master, type `/loot sr load` to get started.  You can use defined SR raid names to persist entries from week to week (Ex/ `/loot sr load BWL`).  Valid `sr` subcommands are: `load, unload, delete, show, lock, unlock, instructions, json, csv, semicolon, and raidresfly`
    * When loaded, a Soft Reserve list can accept bids from raiders with: `/w Masterlooter sr [item-link]`.  A precise name in place of a link will work, but there is no validation.  Misspellings will not match future loot drops.
    * When a loot session is started, items that are SR'd will be removed from the MSOS bidding list. SR bidders will be notified via whisper.
    * When the loot session ends, SR items will be announced and/or rolled off.
    * Ability to import/export with various formats: csv, json, semicolon, raidresfly (Ex/ `/loot sr json`)
  * ~~Modified `/loot autostageloot` so that it takes it 2 parameters (min and max) so you can effectively filter out legendary drops and do epics only like this: `/loot autostageloot 4 4`~~
* 1.5.2
  * Added the "Mode" (MSOS or DKP) to the Stage GUI frame for the Master Looter's reference
* 1.5.1
    * ~~Enabling the setting of previously added properties:~~
    * ~~`/loot autostage` which will turn on/off the GUI popup when you loot a boss~~
    * ~~`/loot autostageloot` which sets the minimum rairity of what is put into the GUI stage (0-5); 4 (epic) is the default~~
* 1.5.0
  * ~~Adding MS/OS mode for non-bid raids `/loot msos` to switch modes and `/loot dkp` to switch back~~
* 1.4.4
  * Fixing a bug with duplicate whisper filtering that caused the same whisper from different people to be filtered
* 1.4.3
  * Preventing duplicate whisper responses if incoming whispers are read in multiple windows

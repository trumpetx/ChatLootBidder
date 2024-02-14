# Overview and Goals
This addon's primary goal is to manage the process of bidding and rolling on items in a Master Looter environment in a semi-automated way.

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
Currently, the addon is text-only.  TODO: Add a GUI for administration to get away from slash commands
## Info
* `/loot help` to see all of the available commands
* `/loot info` to show current settings
## Addon Setup
Most configuration should be set to a reasonable default.  When setting channel names, you can use ([these options](https://wowwiki-archive.fandom.com/wiki/API_SendChatMessage))  If you wish to use a custom channel, just set the value to your custom channel name.
* `/loot` Show the stage or end session window
* `/loot bid` Toggle bid announcing to the "Bid Channel"
* `/loot bid RAID` Set the bid announcing to `/ra` instead of the default: OFFICER. (note: this would make all bidding public instead of private)
* `/loot endsummary` Toggle the automatically posted end summary to the "Bid Channel"
* `/loot session YELL` Sets the "Session Channel" to YELL instead of the default: RAID
* `/loot win RAID` Sets the "Win Channel" to RAID instead of the default: RAID_WARNING
* `/loot roll` Toggle the roll announcing to the "Summary Channel" at the end of a Loot Session.  If disabled, the Raider will be whispered their generated roll instead.
* `/loot timer 45` Sets the BigWigs timer to 45 seconds instead of the default: 30
* `/loot maxbid 10000` Sets the max bid value at 10000 instead of the default: 5000.  You can thank very mean raiders for the need to create this setting :P.
  * The minimum bid is not settable via the interactive chat, but you can modify it in your addon lua settings.  It is 1 by default.
* `/loot debug 2` Sets the debug level to `2` which is VERY SPAMMY.  `1` is slightly less spammy than `2`.  This should not be necessary unless you're trying to debug the addon behavior.  `0` is the default and returns the addon to non-spam-you mode.
## Raid Usage
* `/loot stage [item-link][item-link]` stage items for a session start.  This can be used to add items before officially starting the session (to bundle multiple boss loot, for example).
* `/loot start [item-link][item-link][item-link][item-link]` to start a new loot session with the declared items (along with any staged items).  Directions and item links will be listed to the "Session Channel".
  * `/loot start [item-link] 120` starts a session with a custom timer length of 120 seconds
  * The timer is just a suggestion, the Master Looter still needs to run `/loot end` to end the session.
  * While you don't technically need to be a Raid assistant to be a Master Looter, you must be one to use the addon.
  * You do not have to be the actual designated Master Looter in order to run the addon (e.g. separate the bid taker from the loot distibutor)
* Raiders can then bid:
  * `/w Masterlooter [item-link] ms 100` to bid 100 points at the Main-Spec tier of bidding
  * `/w Masterlooter [item-link] os 10` to bid 10 points at the Off-Spec tier of bidding
  * `/w Masterlooter [item-link] roll` to declare that you would like to roll for this item
    * Once declared, you can then `/random` yourself to have your roll linked to your roll bid.  If you have multiple roll bids, your rolls are assigned in a non-deterministic order.  If you want to control the order of your rolls, bid first, then roll, bid second, then roll.
    * If you choose not to roll yourself, the addon will do a `math.random(1, 100)` on your behalf.  The only reason to roll yourself is if you (A) don't trust the Master Looter or (B) believe that your dice are better than other dice.
    * SPECIAL CASE - ONE ITEM ONLY: You may simply `/random` to have your roll applied to that item without `/w Masterlooter roll` first (since it's unambiguous which item you're rolling on)
* Raiders can cancel bids:
  * `/w Masterlooter [item-link] cancel` to cancel your existing bids (MS/OS/roll)
    * note: your roll is saved until the Loot Session is ended in case you re-roll on a given item
    * You can use this to change the "tier" of your bid from MS to OS, etc
* `/loot clear` to clear the current bidding session or stage.  This clears all items, rolls, and bids completely.  It is not reversable: BE CAREFUL.
* `/loot clear [item-link]` to clear specific item(s) from the stage.  This can be reversed by `/loot stage [item-link]` and does not apply to sessions at all.
* `/loot summary` if a current session is active, post the current summary to the "Bid Channel"
* `/loot end` to end the current loot session.  Winners will be announced to the "Win Channel".  If enabled, a summary will be posted to the "Bid Channel".
  * If there are some roll bids where users did not roll on their own behalf, their rolls will be generated and posted to the "Session Channel" (if enabled) or whispered to them (if disabled)

# Known Issues / FAQ
* Turtle can sometimes throttle messages even with the current `ThrottleChatLib` v.14.  The library has been tuned a little more to hopefully not allow this to happen again.

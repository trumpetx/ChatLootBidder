-- Functional tests for end-to-end ChatLootBidder sessions.
-- Tests exercise the addon through its public API: slash commands and whisper events.

local raidRoster = {
  { name = "TestPlayer", rank = 2, class = "PRIEST" },
  { name = "PlayerA", rank = 0, class = "MAGE" },
  { name = "PlayerB", rank = 0, class = "WARRIOR" },
  { name = "PlayerC", rank = 0, class = "ROGUE" },
}

local function SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "MSOS"
  ChatLootBidder_Store.ShowPlayerClassColors = false
  ChatLootBidder_Store.BreakTies = true
  ChatLootBidder_Store.BidAnnounce = false
  ChatLootBidder_Store.BidSummary = false
  ChatLootBidder_Store.OffspecPenalty = 0
  ChatLootBidder_Store.AltPenalty = 0
  ChatLootBidder_Store.ItemValidation = false
  ChatLootBidder_Store.AutoLockSoftReserve = false
  ChatLootBidder_Store.SoftReserveSessions = {}

  SetUpRaidMocks(raidRoster)
  ResetWhisperDedup()
  ClearChatLog()
end

local itemLink = "\124cffa335ee\124Hitem:19019:0:0:0:0:0:0:0:0\124h[Thunderfury, Blessed Blade of the Windseeker]\124h\124r"
local itemLink2 = "\124cffa335ee\124Hitem:18422:0:0:0:0:0:0:0:0\124h[Head of Onyxia]\124h\124r"

local CLB = SlashCmdList["ChatLootBidder"]

test("ms_wins_over_os", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end)

test("ms_tie_rolloff", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)
  CLB("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerA wins")
end)

test("soft_reserve_claims_item", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  CLB("start " .. itemLink .. " " .. itemLink2)

  SendWhisper("PlayerC", itemLink .. " ms")
  assert_log_contains("fully reserved via Soft Reserve and is not open for bidding")

  SendWhisper("PlayerB", itemLink2 .. " ms")

  CLB("end")
  assert_log_contains("PlayerA wins " .. itemLink .. " for SR")
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end)

test("dkp_highest_ms_wins", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms 100")
  SendWhisper("PlayerB", itemLink .. " os 250")
  SendWhisper("PlayerC", itemLink .. " ms 150")
  CLB("end")

  assert_log_contains("PlayerC wins " .. itemLink .. " with a MS bid of 150")
end)

test("os_wins_when_no_ms", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerB", itemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for OS")
end)

test("roll_only_with_auto_roll", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " roll")
  SendWhisper("PlayerB", itemLink .. " roll")
  CLB("end")

  assert_log_contains("wins " .. itemLink .. " with a roll of")
end)

test("no_bids_received", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  CLB("end")

  assert_log_contains("No bids received for " .. itemLink)
end)

test("cancel_excludes_from_resolution", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " cancel")
  CLB("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end)

test("rebid_after_cancel", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerB", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " cancel")
  SendWhisper("PlayerB", itemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for OS")
end)

test("dkp_alt_penalty", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.AltPenalty = 50

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms 100 alt")
  SendWhisper("PlayerB", itemLink .. " ms 60")
  CLB("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " with a MS bid of 60")
end)

test("dkp_os_only_displays_as_os", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " os 100")
  CLB("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " with a OS bid of 100")
end)

test("multi_item_independent_resolution", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink .. " " .. itemLink2)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink2 .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end)

test("multi_copy_same_item", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink .. " " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. itemLink .. " for MS")
end)

test("contested_sr_rolloff", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" },
    ["PlayerB"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  CLB("start " .. itemLink .. " " .. itemLink2)
  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)
  CLB("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for SR")
  assert_log_not_contains("PlayerA wins " .. itemLink .. " for SR")
end)

test("bid_rejected_not_in_raid", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("OutsidePlayer", itemLink .. " ms")
  
  assert_log_contains("You must be in the raid to send a bid on " .. itemLink)
end)

test("bid_rejected_max_exceeded", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.MaxBid = 5000

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms 5001")
  
  assert_log_contains("Bid for " .. itemLink .. " is too large, the maxiumum accepted bid is: 5000")
end)

test("bid_rejected_duplicate_ms", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerA", itemLink .. " ms duplicate")
  
  assert_log_contains("You already have a MS bid")
end)

test("stage_then_start", function()
  SetUpTestEnvironment()

  CLB("stage " .. itemLink)
  CLB("start")
  SendWhisper("PlayerA", itemLink .. " ms")
  CLB("end")
  
  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
end)

test("session_auto_ends_previous", function()
  SetUpTestEnvironment()

  CLB("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  CLB("start " .. itemLink2)
  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  
  SendWhisper("PlayerB", itemLink2 .. " ms")
  CLB("end")
  
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end)

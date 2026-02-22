-- Functional tests for end-to-end ChatLootBidder sessions.
-- Tests exercise the addon through its public API: slash commands and whisper events.

local function dump_log()
  local out = ""
  for _, entry in ipairs(TestChatLog) do
    out = out .. "[" .. tostring(entry.type) .. "] " .. (entry.dest and ("(" .. entry.dest .. ") ") or "") .. tostring(entry.msg) .. "\n"
  end
  return out
end

local function assert_log_contains(text)
  for _, entry in ipairs(TestChatLog) do
    if entry.msg and string.find(entry.msg, text, 1, true) then
      return true
    end
  end
  error("Expected chat to contain: " .. text .. "\n\nActual Log:\n" .. dump_log())
end

local function assert_log_not_contains(text)
  for _, entry in ipairs(TestChatLog) do
    if entry.msg and string.find(entry.msg, text, 1, true) then
      error("Expected chat NOT to contain: " .. text .. "\n\nActual Log:\n" .. dump_log())
    end
  end
end

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

  UnitName = function(unit)
    if unit == "player" then return "TestPlayer" end
    local idx = tonumber(string.match(unit, "^raid(%d+)$"))
    if idx and raidRoster[idx] then return raidRoster[idx].name end
    return nil
  end
  GetNumRaidMembers = function() return #raidRoster end
  UnitInRaid = function(unit) return 1 end
  GetRaidRosterInfo = function(index)
    local p = raidRoster[index]
    if p then return p.name, p.rank, 1, 1, 1, p.class end
    return nil
  end
  GetLootMethod = function() return "master", 0 end

  -- Reset lastWhisper deduplication by sending a unique dummy whisper
  arg1 = "__reset_" .. GetTime() .. "__"
  arg2 = "__reset__"
  ChatFrame_OnEvent("CHAT_MSG_WHISPER")

  ClearChatLog()
end

local function SendWhisper(sender, text)
  arg1 = text
  arg2 = sender
  ChatFrame_OnEvent("CHAT_MSG_WHISPER")
end

local function SimulateRoll(player, rollValue)
  ChatLootBidderFrame.CHAT_MSG_SYSTEM(player .. " rolls " .. rollValue .. " (1-100)")
end

local itemLink = "\124cffa335ee\124Hitem:19019:0:0:0:0:0:0:0:0\124h[Thunderfury, Blessed Blade of the Windseeker]\124h\124r"

-- ==========================================
-- Test: Single MS bid beats OS bid
-- ==========================================
local function test_ms_wins_over_os()
  print("  test: ms_wins_over_os")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " os")
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end

-- ==========================================
-- Test: Tied MS bids resolved by roll-off
-- ==========================================
local function test_ms_tie_rolloff()
  print("  test: ms_tie_rolloff")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerA wins")
end

-- ==========================================
-- Test: Soft Reserve claims item, blocking MS/OS bids
-- Two items: one fully SR'd (auto-won), one open for bidding (keeps session alive).
-- ==========================================
local itemLink2 = "\124cffa335ee\124Hitem:18422:0:0:0:0:0:0:0:0\124h[Head of Onyxia]\124h\124r"

local function test_soft_reserve_claims_item()
  print("  test: soft_reserve_claims_item")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink .. " " .. itemLink2)

  -- PlayerC tries to bid on the SR'd item
  SendWhisper("PlayerC", itemLink .. " ms")
  assert_log_contains("fully reserved via Soft Reserve and is not open for bidding")

  -- PlayerB bids on the open item
  SendWhisper("PlayerB", itemLink2 .. " ms")

  SlashCmdList["ChatLootBidder"]("end")
  assert_log_contains("PlayerA wins " .. itemLink .. " for SR")
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end

-- ==========================================
-- Test: DKP mode, highest MS bid wins, offspec penalty applied
-- ==========================================
local function test_dkp_highest_ms_wins()
  print("  test: dkp_highest_ms_wins")
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms 100")
  SendWhisper("PlayerB", itemLink .. " os 250")
  SendWhisper("PlayerC", itemLink .. " ms 150")
  SlashCmdList["ChatLootBidder"]("end")

  -- PlayerC (MS 150) > PlayerB (OS 250 penalized to 125 in MS) > PlayerA (MS 100)
  assert_log_contains("PlayerC wins " .. itemLink .. " with a MS bid of 150")
end

-- ==========================================
-- Test: OS wins when no MS bids placed
-- ==========================================
local function test_os_wins_when_no_ms()
  print("  test: os_wins_when_no_ms")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerB", itemLink .. " os")
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for OS")
end

-- ==========================================
-- Test: Roll-only bids with auto-roll generation
-- ==========================================
local function test_roll_only_with_auto_roll()
  print("  test: roll_only_with_auto_roll")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " roll")
  SendWhisper("PlayerB", itemLink .. " roll")
  SlashCmdList["ChatLootBidder"]("end")

  -- One of them should win with a roll. Since we don't mock math.random here,
  -- we can't assert exactly who wins, but we can assert the format.
  assert_log_contains("wins " .. itemLink .. " with a roll of")
end

-- ==========================================
-- Test: Empty session with zero bidders
-- ==========================================
local function test_no_bids_received()
  print("  test: no_bids_received")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("No bids received for " .. itemLink)
end

-- ==========================================
-- Test: Cancel bid exclusion + re-bid after cancel
-- ==========================================
local function test_cancel_excludes_from_resolution()
  print("  test: cancel_excludes_from_resolution")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  
  -- PlayerB cancels their bid
  SendWhisper("PlayerB", itemLink .. " cancel")

  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end

local function test_rebid_after_cancel()
  print("  test: rebid_after_cancel")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerB", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " cancel")
  SendWhisper("PlayerB", itemLink .. " os")

  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for OS")
end

-- ==========================================
-- Test: DKP alt penalty reduces effective bid
-- ==========================================
local function test_dkp_alt_penalty()
  print("  test: dkp_alt_penalty")
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.AltPenalty = 50

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  -- PlayerA effectively bids 50
  SendWhisper("PlayerA", itemLink .. " ms 100 alt")
  -- PlayerB effectively bids 60
  SendWhisper("PlayerB", itemLink .. " ms 60")
  
  SlashCmdList["ChatLootBidder"]("end")

  -- PlayerB should win
  assert_log_contains("PlayerB wins " .. itemLink .. " with a MS bid of 60")
end

-- ==========================================
-- Test: OS-only winner displays as OS, not MS
-- ==========================================
local function test_dkp_os_only_displays_as_os()
  print("  test: dkp_os_only_displays_as_os")
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  -- No MS bids exist
  SendWhisper("PlayerA", itemLink .. " os 100")
  
  SlashCmdList["ChatLootBidder"]("end")

  -- Winner should be announced as an OS bid, and display the original 100 amount
  assert_log_contains("PlayerA wins " .. itemLink .. " with a OS bid of 100")
end

-- ==========================================
-- Test: Two items, independent winners
-- ==========================================
local function test_multi_item_independent_resolution()
  print("  test: multi_item_independent_resolution")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink .. " " .. itemLink2)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink2 .. " ms")
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end

-- ==========================================
-- Test: 2 copies, 2 bidders, both win
-- ==========================================
local function test_multi_copy_same_item()
  print("  test: multi_copy_same_item")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink .. " " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  SendWhisper("PlayerB", itemLink .. " ms")
  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. itemLink .. " for MS")
end

-- ==========================================
-- Test: 2 SRers, 1 copy, rolloff to decide winner
-- ==========================================
local function test_contested_sr_rolloff()
  print("  test: contested_sr_rolloff")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" },
    ["PlayerB"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink .. " " .. itemLink2)

  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)

  SlashCmdList["ChatLootBidder"]("end")

  assert_log_contains("PlayerB wins " .. itemLink .. " for SR")
  assert_log_not_contains("PlayerA wins " .. itemLink .. " for SR")
end

-- ==========================================
-- Test: Non-raider bid rejected
-- ==========================================
local function test_bid_rejected_not_in_raid()
  print("  test: bid_rejected_not_in_raid")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  
  -- Send whisper from someone not in raidRoster
  SendWhisper("OutsidePlayer", itemLink .. " ms")
  
  assert_log_contains("You must be in the raid to send a bid on " .. itemLink)
end

-- ==========================================
-- Test: Bid over MaxBid rejected
-- ==========================================
local function test_bid_rejected_max_exceeded()
  print("  test: bid_rejected_max_exceeded")
  SetUpTestEnvironment()
  ChatLootBidder_Store.MaxBid = 5000

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  
  SendWhisper("PlayerA", itemLink .. " ms 5001")
  
  assert_log_contains("Bid for " .. itemLink .. " is too large, the maxiumum accepted bid is: 5000")
end

-- ==========================================
-- Test: Duplicate MS bid rejected
-- ==========================================
local function test_bid_rejected_duplicate_ms()
  print("  test: bid_rejected_duplicate_ms")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  
  SendWhisper("PlayerA", itemLink .. " ms")
  -- Second bid
  -- By sending a different message, we bypass the deduplication logic in ChatFrame_OnEvent
  -- (otherwise the identical whisper is silently ignored).
  SendWhisper("PlayerA", itemLink .. " ms duplicate")
  
  assert_log_contains("You already have a MS bid")
end

-- ==========================================
-- Test: Staged item included in session
-- ==========================================
local function test_stage_then_start()
  print("  test: stage_then_start")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("stage " .. itemLink)
  SlashCmdList["ChatLootBidder"]("start")
  
  SendWhisper("PlayerA", itemLink .. " ms")
  SlashCmdList["ChatLootBidder"]("end")
  
  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
end

-- ==========================================
-- Test: New session auto-ends old one
-- ==========================================
local function test_session_auto_ends_previous()
  print("  test: session_auto_ends_previous")
  SetUpTestEnvironment()

  SlashCmdList["ChatLootBidder"]("start " .. itemLink)
  SendWhisper("PlayerA", itemLink .. " ms")
  
  -- Starting a new session automatically ends the previous one
  SlashCmdList["ChatLootBidder"]("start " .. itemLink2)
  
  assert_log_contains("PlayerA wins " .. itemLink .. " for MS")
  
  SendWhisper("PlayerB", itemLink2 .. " ms")
  SlashCmdList["ChatLootBidder"]("end")
  
  assert_log_contains("PlayerB wins " .. itemLink2 .. " for MS")
end

test_ms_wins_over_os()
test_ms_tie_rolloff()
test_soft_reserve_claims_item()
test_dkp_highest_ms_wins()
test_os_wins_when_no_ms()
test_roll_only_with_auto_roll()
test_no_bids_received()
test_cancel_excludes_from_resolution()
test_rebid_after_cancel()
test_dkp_alt_penalty()
test_dkp_os_only_displays_as_os()
test_multi_item_independent_resolution()
test_multi_copy_same_item()
test_contested_sr_rolloff()
test_bid_rejected_not_in_raid()
test_bid_rejected_max_exceeded()
test_bid_rejected_duplicate_ms()
test_stage_then_start()
test_session_auto_ends_previous()

print("  All functional tests passed.")

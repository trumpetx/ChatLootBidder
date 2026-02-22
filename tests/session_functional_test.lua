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

test_ms_wins_over_os()
test_ms_tie_rolloff()
test_soft_reserve_claims_item()
test_dkp_highest_ms_wins()

print("  All functional tests passed.")

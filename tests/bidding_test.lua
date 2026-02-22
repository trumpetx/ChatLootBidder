-- Tests for FEATURES.md sections 3 (Bidding Modes), 4 (Bid Types), and 5 (Bid Modifiers).

test("bid_rejected_not_in_raid", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("OutsidePlayer", TestItemLink .. " ms")

  assert_log_contains("You must be in the raid to send a bid on " .. TestItemLink)
end)

test("bid_rejected_max_exceeded", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.MaxBid = 5000

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 5001")

  assert_log_contains("Bid for " .. TestItemLink .. " is too large, the maxiumum accepted bid is: 5000")
end)

test("bid_rejected_duplicate_ms", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerA", TestItemLink .. " ms duplicate")

  assert_log_contains("You already have a MS bid")
end)

test("bid_rejected_duplicate_os", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " os")
  SendWhisper("PlayerA", TestItemLink .. " os duplicate")

  assert_log_contains("You already have an OS bid")
end)

test("bid_on_item_not_in_session", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink2 .. " ms")

  assert_log_contains("There is no active loot session for " .. TestItemLink2)
end)

test("bid_flexible_syntax_reversed", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " 100 ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a MS bid of 100")
end)

test("dkp_min_bid_rejected", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.MinBid = 1

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 0")

  assert_log_contains("Invalid bid syntax")
end)

test("nr_flag_suppresses_confirmation", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms nr")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_not_contains("Main Spec bid received")
end)

test("bid_rejected_invalid_syntax", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " nonsense")

  assert_log_contains("Invalid bid syntax for " .. TestItemLink)
end)

test("bid_roll_already_recorded_via_random", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " roll")
  SimulateRoll("PlayerA", 77)
  ResetWhisperDedup()
  SendWhisper("PlayerA", TestItemLink .. " roll")

  assert_log_contains("Your roll of 77 has already been recorded")
end)

test("dkp_ms_overwrites_auto_generated_os", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " os 200")
  SendWhisper("PlayerA", TestItemLink .. " ms 150")
  SendWhisper("PlayerB", TestItemLink .. " ms 120")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a MS bid of 150")
end)

test("dkp_os_blocked_by_existing_ms", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 100")
  SendWhisper("PlayerA", TestItemLink .. " os 200")

  assert_log_contains("You already have a MS bid of 100(200) recorded")
end)

test("bid_announce_sends_to_channel", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.BidAnnounce = true
  ChatLootBidder_Store.BidChannel = "customchan"
  GetChannelName = function(channel)
    if channel == "customchan" then return 1 end
    return 0
  end

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")

  local found = false
  for _, entry in ipairs(TestChatLog) do
    if entry.type == "CHANNEL" and entry.msg and string.find(entry.msg, "<PlayerA> ms", 1, true) then
      found = true
      break
    end
  end
  assert(found, "Expected bid announcement sent to custom channel")
end)

test("bid_summary_sends_to_channel", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.BidSummary = true
  ChatLootBidder_Store.BidChannel = "OFFICER"

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("end")

  local found = false
  for _, entry in ipairs(TestChatLog) do
    if entry.type == "OFFICER" and entry.msg and string.find(entry.msg, "Main Spec", 1, true) then
      found = true
      break
    end
  end
  assert(found, "Expected summary sent to officer channel")
end)

test("self_bid_response_goes_to_message", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("TestPlayer", TestItemLink .. " ms")

  local foundDefault = false
  local foundWhisper = false
  for _, entry in ipairs(TestChatLog) do
    if entry.msg and string.find(entry.msg, "Main Spec bid", 1, true) then
      if entry.type == "DEFAULT" then foundDefault = true end
      if entry.type == "WHISPER" then foundWhisper = true end
    end
  end
  assert(foundDefault, "Expected self bid confirmation in default chat")
  assert(not foundWhisper, "Self bid confirmation should not be whispered")
end)

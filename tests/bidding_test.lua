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

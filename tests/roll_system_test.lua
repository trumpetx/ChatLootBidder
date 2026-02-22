-- Tests for FEATURES.md section 8 (Roll System).

test("roll_only_with_auto_roll", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " roll")
  SendWhisper("PlayerB", TestItemLink .. " roll")
  CLB("end")

  assert_log_contains("wins " .. TestItemLink .. " with a roll of")
end)

test("self_roll_recorded", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " roll")
  SimulateRoll("PlayerA", 75)
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a roll of 75")
end)

test("single_item_roll_shortcut", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SimulateRoll("PlayerA", 85)
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a roll of 85")
end)

test("roll_rejected_when_already_recorded", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " roll")
  SimulateRoll("PlayerA", 75)
  SimulateRoll("PlayerA", 99)

  assert_log_contains("Ignoring your roll of 99")
end)

test("auto_roll_whispered_when_announce_off", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.RollAnnounce = false

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " roll")
  SendWhisper("PlayerB", TestItemLink .. " roll")
  ClearChatLog()
  CLB("end")

  assert_log_contains("You roll")
  assert_log_contains("(1-100) for " .. TestItemLink)
end)

test("roll_ignored_without_bid_multi_item", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink .. " " .. TestItemLink2)
  SimulateRoll("PlayerA", 85)

  assert_log_contains("Ignoring your roll of 85")
end)

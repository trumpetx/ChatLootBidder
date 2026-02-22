-- Tests for FEATURES.md section 7 (Winner Resolution).

test("ms_wins_over_os", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end)

test("ms_tie_rolloff", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " ms")
  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " for MS")
  assert_log_not_contains("PlayerA wins")
end)

test("os_wins_when_no_ms", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerB", TestItemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " for OS")
end)

test("no_bids_received", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  CLB("end")

  assert_log_contains("No bids received for " .. TestItemLink)
end)

test("cancel_excludes_from_resolution", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " cancel")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_not_contains("PlayerB wins")
end)

test("rebid_after_cancel", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerB", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " cancel")
  SendWhisper("PlayerB", TestItemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " for OS")
end)

test("multi_item_independent_resolution", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink .. " " .. TestItemLink2)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink2 .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. TestItemLink2 .. " for MS")
end)

test("multi_copy_same_item", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink .. " " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. TestItemLink .. " for MS")
end)

test("multi_copy_mixed_tiers", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink .. " " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " os")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. TestItemLink .. " for OS")
end)

test("summary_without_end", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.BidSummary = true

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("summary")

  assert_log_contains("Main Spec:")
  assert_log_not_contains("wins " .. TestItemLink)
end)

test("summary_no_session_errors", function()
  SetUpTestEnvironment()

  CLB("summary")

  assert_log_contains("There is no existing session")
end)

test("multi_copy_partial_bids", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink .. " " .. TestItemLink .. " " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("No bids received for " .. TestItemLink)
end)

test("many_rollers_split_announce", function()
  SetUpTestEnvironment()

  local roster = {
    { name = "TestPlayer", rank = 2, class = "PRIEST" },
    { name = "PlayerAaaaaaaaa", rank = 0, class = "MAGE" },
    { name = "PlayerBbbbbbbbb", rank = 0, class = "WARRIOR" },
    { name = "PlayerCcccccccc", rank = 0, class = "ROGUE" },
    { name = "PlayerDdddddddd", rank = 0, class = "HUNTER" },
    { name = "PlayerEeeeeeeee", rank = 0, class = "WARLOCK" },
    { name = "PlayerFffffffff", rank = 0, class = "DRUID" },
    { name = "PlayerGgggggggg", rank = 0, class = "PALADIN" },
    { name = "PlayerHhhhhhhhh", rank = 0, class = "PRIEST" },
    { name = "PlayerIiiiiiiii", rank = 0, class = "MAGE" },
    { name = "PlayerJjjjjjjjj", rank = 0, class = "WARRIOR" },
    { name = "PlayerKkkkkkkkk", rank = 0, class = "ROGUE" },
  }
  SetUpRaidMocks(roster)

  CLB("start " .. TestItemLink)
  for i = 2, #roster do
    SendWhisper(roster[i].name, TestItemLink .. " roll")
  end
  ClearChatLog()
  CLB("end")

  local rollBroadcastLines = 0
  for _, entry in ipairs(TestChatLog) do
    if entry.type == "RAID" and entry.msg and string.find(entry.msg, "(", 1, true) then
      rollBroadcastLines = rollBroadcastLines + 1
    end
  end
  assert(rollBroadcastLines >= 2, "Expected split roll announcements in RAID chat")
end)

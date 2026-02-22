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

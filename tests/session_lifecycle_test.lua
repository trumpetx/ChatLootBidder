-- Tests for FEATURES.md sections 1 (Session Lifecycle) and 2 (Item Staging).

test("stage_then_start", function()
  SetUpTestEnvironment()

  CLB("stage " .. TestItemLink)
  CLB("start")
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
end)

test("session_auto_ends_previous", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("start " .. TestItemLink2)
  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")

  SendWhisper("PlayerB", TestItemLink2 .. " ms")
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink2 .. " for MS")
end)

test("clear_stage", function()
  SetUpTestEnvironment()

  CLB("stage " .. TestItemLink)
  CLB("clear")

  assert_log_contains("Cleared the stage")
end)

test("clear_specific_staged_item", function()
  SetUpTestEnvironment()

  CLB("stage " .. TestItemLink)
  CLB("stage " .. TestItemLink2)
  CLB("clear " .. TestItemLink)
  ClearChatLog()
  CLB("start")

  SendWhisper("PlayerA", TestItemLink .. " ms")
  assert_log_contains("There is no active loot session for " .. TestItemLink)

  SendWhisper("PlayerA", TestItemLink2 .. " ms")
  CLB("end")
  assert_log_contains("PlayerA wins " .. TestItemLink2 .. " for MS")
end)

test("session_requires_raid_assistant", function()
  SetUpTestEnvironment()
  SetUpRaidMocks({
    { name = "TestPlayer", rank = 0, class = "PRIEST" },
    { name = "PlayerA", rank = 0, class = "MAGE" },
  })

  CLB("start " .. TestItemLink)

  assert_log_contains("You must be a raid leader or assistant")
end)

test("session_requires_master_looter", function()
  SetUpTestEnvironment()
  GetLootMethod = function() return "free", nil end

  CLB("start " .. TestItemLink)

  assert_log_contains("Master Looter must be set")
end)

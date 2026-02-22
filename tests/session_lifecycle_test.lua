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

test("start_fully_srd_items_auto_ends", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()
  CLB("start " .. TestItemLink)

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for SR")
  CLB("end")
  assert_log_contains("There is no existing session")
end)

test("stage_with_count_idempotent", function()
  SetUpTestEnvironment()

  ChatLootBidderFrame:Stage(TestItemLink, 2)
  ChatLootBidderFrame:Stage(TestItemLink, 2)
  CLB("start")
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. TestItemLink .. " for MS")
end)

test("loot_opened_auto_stages", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.AutoStage = true
  ChatLootBidder_Store.MinRarity = 4
  ChatLootBidder_Store.MaxRarity = 5

  GetNumLootItems = function() return 3 end
  GetLootSlotInfo = function(i)
    if i == 1 then return nil, "Thunderfury", 1, 4, nil, nil, nil, nil end
    if i == 2 then return nil, "Head of Onyxia", 1, 5, nil, nil, nil, nil end
    return nil, "Junk Item", 1, 2, nil, nil, nil, nil
  end
  GetLootSlotLink = function(i)
    if i == 1 then return TestItemLink end
    if i == 2 then return TestItemLink2 end
    return "\124cff1eff00\124Hitem:12345:0:0:0:0:0:0:0:0\124h[Junk Item]\124h\124r"
  end

  ChatLootBidderFrame.LOOT_OPENED()
  ClearChatLog()
  CLB("start")
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink2 .. " ms")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
  assert_log_contains("PlayerB wins " .. TestItemLink2 .. " for MS")
  assert_log_not_contains("Junk Item")
end)

test("slash_sr_rejected_in_dkp_mode", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"

  CLB("sr load testList")

  assert_log_contains("You need to be in MSOS mode to modify Soft Reserve sessions")
end)

test("slash_unknown_sr_subcommand", function()
  SetUpTestEnvironment()

  CLB("sr testBogusCommand")

  assert_log_contains("Unknown 'sr' subcommand: testBogusCommand")
  assert_log_contains("Valid values are: load, unload, delete, show, lock, unlock, json, semicolon, raidresfly, csv, instructions")
end)

test("slash_debug_sets_level", function()
  SetUpTestEnvironment()

  CLB("debug 2")

  assert(ChatLootBidder_Store.DebugLevel == 2, "Expected DebugLevel to be set to 2")
  assert_log_contains("Debug level set to 2")
end)

test("slash_clear_empty_stage_no_session", function()
  SetUpTestEnvironment()

  CLB("clear " .. TestItemLink)

  assert_log_contains("The stage is empty")
end)

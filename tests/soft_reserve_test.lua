-- Tests for FEATURES.md section 9 (Soft Reserve System).

test("soft_reserve_claims_item", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  CLB("start " .. TestItemLink .. " " .. TestItemLink2)

  SendWhisper("PlayerC", TestItemLink .. " ms")
  assert_log_contains("fully reserved via Soft Reserve and is not open for bidding")

  SendWhisper("PlayerB", TestItemLink2 .. " ms")

  CLB("end")
  assert_log_contains("PlayerA wins " .. TestItemLink .. " for SR")
  assert_log_contains("PlayerB wins " .. TestItemLink2 .. " for MS")
end)

test("contested_sr_rolloff", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" },
    ["PlayerB"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  CLB("start " .. TestItemLink .. " " .. TestItemLink2)
  SimulateRoll("PlayerA", 50)
  SimulateRoll("PlayerB", 99)
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " for SR")
  assert_log_not_contains("PlayerA wins " .. TestItemLink .. " for SR")
end)

test("sr_whisper_place_and_query", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ClearChatLog()
  SendWhisper("PlayerA", "sr " .. TestItemLink)

  assert_log_contains("Your Soft Reserve is currently [ Thunderfury, Blessed Blade of the Windseeker ]")
end)

test("sr_whisper_clear", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  ClearChatLog()
  SendWhisper("PlayerA", "sr clear")

  assert_log_contains("Your Soft Reserve is currently not set")
end)

test("sr_rejected_no_session_loaded", function()
  SetUpTestEnvironment()

  SendWhisper("PlayerA", "sr " .. TestItemLink)

  assert_log_contains("There is no Soft Reserve session loaded")
end)

test("sr_rejected_not_in_raid", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ClearChatLog()
  SendWhisper("OutsidePlayer", "sr " .. TestItemLink)

  assert_log_contains("You must be in the raid to place a Soft Reserve")
end)

test("sr_locked_rejects_new_bids", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  CLB("sr lock")
  ClearChatLog()
  SendWhisper("PlayerA", "sr " .. TestItemLink)

  assert_log_contains("Your Soft Reserve is currently not set")
  assert_log_contains("LOCKED")
end)

test("sr_auto_lock_on_session_start", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.AutoLockSoftReserve = true

  CLB("sr load testList")
  ClearChatLog()
  CLB("start " .. TestItemLink)

  assert_log_contains("Soft Reserves for testList are now LOCKED")
end)

test("sr_auto_remove_after_win", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.AutoRemoveSrAfterWin = true

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()

  CLB("start " .. TestItemLink .. " " .. TestItemLink2)
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " for SR")
  assert_log_contains("You are no longer reserving: Thunderfury, Blessed Blade of the Windseeker")
end)

test("sr_unload_via_slash_command", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  ClearChatLog()
  CLB("sr unload")

  assert_log_contains("Unloaded Soft Reserve session: testList")
  ResetWhisperDedup()
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  assert_log_contains("There is no Soft Reserve session loaded")
end)

test("sr_name_fix_whispered_to_bidder", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = true
  AtlasLoot_Data = {
    ["AtlasLootItems"] = {
      ["TestBoss"] = {
        { 19019, "INV_Sword", "=q4=Thunderfury, Blessed Blade of the Windseeker", "=ds=", "5%" },
      }
    }
  }

  CLB("sr load testList")
  ClearChatLog()
  SendWhisper("PlayerA", "sr thunderfury, blessed blade of the windseeker")

  assert_log_contains("fixed to Thunderfury, Blessed Blade of the Windseeker")
  assert_log_contains("Your Soft Reserve is currently [ Thunderfury, Blessed Blade of the Windseeker ]")
  AtlasLoot_Data = nil
end)

test("sr_max_reserves_exceeded_pushes_oldest", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  ClearChatLog()
  SendWhisper("PlayerA", "sr " .. TestItemLink2)

  assert_log_contains("You are no longer reserving: Thunderfury")
  assert_log_contains("Your Soft Reserve is currently [ Head of Onyxia ]")
end)

test("csv_import_with_whitespace_in_names", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false

  CLB("sr load testList")
  SrEditFrameHeaderString.GetText = function() return "csv" end
  local parentFrame = { Hide = function() end }
  ChatLootBidderFrame:DecodeAndSave('" PlayerA ","Band of Accuria"\n" PlayerA ","Quick Strike Ring"', parentFrame)

  local srs = ChatLootBidder_Store.SoftReserveSessions["testList"]
  assert(srs ~= nil, "SR session should exist")
  assert(srs["PlayerA"] ~= nil, "Trimmed key 'PlayerA' should exist")
  assert(srs[" PlayerA "] == nil, "Untrimmed key should not exist")
  assert(#srs["PlayerA"] == 2, "PlayerA should have 2 SRs, got " .. #srs["PlayerA"])
  assert(srs["PlayerA"][1] == "Band of Accuria", "First SR should be Band of Accuria")
  assert(srs["PlayerA"][2] == "Quick Strike Ring", "Second SR should be Quick Strike Ring")
end)

test("sr_delete_current_session", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  ClearChatLog()
  CLB("sr delete")

  assert_log_contains("Deleted currently loaded Soft Reserve session: testList")
  ResetWhisperDedup()
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  assert_log_contains("There is no Soft Reserve session loaded")
end)

test("sr_delete_named_session", function()
  SetUpTestEnvironment()

  CLB("sr load activeList")
  ChatLootBidder_Store.SoftReserveSessions["targetList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" }
  }
  ClearChatLog()
  CLB("sr delete targetList")

  assert_log_contains("Deleted Soft Reserve session: targetList")
  assert(ChatLootBidder_Store.SoftReserveSessions["targetList"] == nil, "Expected named SR list to be deleted")
  assert(ChatLootBidder_Store.SoftReserveSessions["activeList"] ~= nil, "Expected active SR list to remain")
end)

test("sr_delete_nonexistent_errors", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ClearChatLog()
  CLB("sr delete doesNotExist")

  assert_log_contains("No Soft Reserve session exists with the label: doesNotExist")
end)

test("sr_show_displays_reserves", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Thunderfury, Blessed Blade of the Windseeker" },
    ["PlayerB"] = { "Head of Onyxia" }
  }
  ClearChatLog()
  CLB("sr show")

  assert_log_contains("Soft Reserve Bids:")
  assert_log_contains("PlayerA: Thunderfury, Blessed Blade of the Windseeker")
  assert_log_contains("PlayerB: Head of Onyxia")
end)

test("sr_show_no_session_errors", function()
  SetUpTestEnvironment()

  CLB("sr show")

  assert_log_contains("No Soft Reserve session loaded")
end)

test("sr_instructions_broadcasts", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  ClearChatLog()
  CLB("sr instructions")

  assert_log_contains("Set your SR: /w TestPlayer sr")
  assert_log_contains("Get your current SR: /w TestPlayer sr")
  assert_log_contains("Clear your current SR: /w TestPlayer sr clear")
end)

test("sr_load_without_name_creates_default", function()
  SetUpTestEnvironment()

  CLB("sr load")

  assert_log_contains("New Soft Reserve list [")
  assert(ChatLootBidderFrame:LoadedSoftReserveSession() ~= nil, "Expected a default SR session to be loaded")
end)

test("sr_toggle_lock_without_command", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  assert(not ChatLootBidderFrame:IsLocked(), "Expected SR to start unlocked")

  ChatLootBidderFrame:ToggleSrLock()
  assert(ChatLootBidderFrame:IsLocked(), "Expected SR to be locked after toggle")

  ChatLootBidderFrame:ToggleSrLock()
  assert(not ChatLootBidderFrame:IsLocked(), "Expected SR to be unlocked after second toggle")
end)

test("sr_lock_no_session_errors", function()
  SetUpTestEnvironment()

  CLB("sr lock")

  assert_log_contains("No Soft Reserve session loaded")
end)

test("sr_add_invalid_item_rejected", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = true
  AtlasLoot_Data = {
    ["AtlasLootItems"] = {
      ["TestBoss"] = {
        { 19019, "INV_Sword", "=q4=Thunderfury, Blessed Blade of the Windseeker", "=ds=", "5%" },
      }
    }
  }

  CLB("sr load testList")
  ClearChatLog()
  SendWhisper("PlayerA", "sr DefinitelyNotAnAtlasLootItem")

  assert_log_contains("does not appear to be a valid item name")
  AtlasLoot_Data = nil
end)

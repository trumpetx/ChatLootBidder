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

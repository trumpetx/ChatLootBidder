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

test("sr_max_reserves_exceeded_pushes_oldest", function()
  SetUpTestEnvironment()

  CLB("sr load testList")
  SendWhisper("PlayerA", "sr " .. TestItemLink)
  ClearChatLog()
  SendWhisper("PlayerA", "sr " .. TestItemLink2)

  assert_log_contains("You are no longer reserving: Thunderfury")
  assert_log_contains("Your Soft Reserve is currently [ Head of Onyxia ]")
end)

-- Sanity tests: default store state after LoadVariables (run via ADDON_LOADED in test_runner).

test("default_store_state", function()
  ResetAddonState()

  assert(ChatLootBidder_Store ~= nil, "ChatLootBidder_Store should exist after addon load")

  assert(ChatLootBidder_Store.DefaultSessionMode == "MSOS", "DefaultSessionMode default")
  assert(ChatLootBidder_Store.BidChannel == "OFFICER", "BidChannel default")
  assert(ChatLootBidder_Store.SessionAnnounceChannel == "RAID", "SessionAnnounceChannel default")
  assert(ChatLootBidder_Store.WinnerAnnounceChannel == "RAID_WARNING", "WinnerAnnounceChannel default")

  assert(ChatLootBidder_Store.TimerSeconds == 30, "TimerSeconds default")
  assert(ChatLootBidder_Store.MaxBid == 5000, "MaxBid default")
  assert(ChatLootBidder_Store.MinBid == 1, "MinBid default")
  assert(ChatLootBidder_Store.MinRarity == 4, "MinRarity default")
  assert(ChatLootBidder_Store.MaxRarity == 5, "MaxRarity default")

  assert(ChatLootBidder_Store.SoftReserveSessions ~= nil, "SoftReserveSessions table exists")
  assert(type(ChatLootBidder_Store.SoftReserveSessions) == "table", "SoftReserveSessions is table")

  -- Booleans: DefaultTrue/DefaultFalse behavior
  assert(ChatLootBidder_Store.ItemValidation == true, "ItemValidation default true")
  assert(ChatLootBidder_Store.RollAnnounce == true, "RollAnnounce default true")
  assert(ChatLootBidder_Store.BidAnnounce == false, "BidAnnounce default false")
  assert(ChatLootBidder_Store.BreakTies == true, "BreakTies default true")
end)

test("set_prop_value_updates_store", function()
  SetUpTestEnvironment()

  ChatLootBidderFrame:SetPropValue("BidChannel", "GUILD")
  assert(ChatLootBidder_Store.BidChannel == "GUILD", "Expected BidChannel update through SetPropValue")

  ChatLootBidderFrame:SetPropValue("ChatLootBidderOptionsFrameSessionAnnounceChannel", "RAID_WARNING", "ChatLootBidderOptionsFrame")
  assert(ChatLootBidder_Store.SessionAnnounceChannel == "RAID_WARNING", "Expected prefixed property update through SetPropValue")
end)

test("extract_params_with_semicolons", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.AltPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 100 alt;")
  SendWhisper("PlayerB", TestItemLink .. " ms 60")
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " with a MS bid of 60")
end)
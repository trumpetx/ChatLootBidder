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
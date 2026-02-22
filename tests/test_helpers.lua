-- Shared test constants and setup used across all test files.

TestItemLink = "\124cffa335ee\124Hitem:19019:0:0:0:0:0:0:0:0\124h[Thunderfury, Blessed Blade of the Windseeker]\124h\124r"
TestItemLink2 = "\124cffa335ee\124Hitem:18422:0:0:0:0:0:0:0:0\124h[Head of Onyxia]\124h\124r"

DefaultRaidRoster = {
  { name = "TestPlayer", rank = 2, class = "PRIEST" },
  { name = "PlayerA", rank = 0, class = "MAGE" },
  { name = "PlayerB", rank = 0, class = "WARRIOR" },
  { name = "PlayerC", rank = 0, class = "ROGUE" },
}

CLB = SlashCmdList["ChatLootBidder"]

function ResetAddonState()
  CLB("clear")
  ChatLootBidder_Store = {}
  this = ChatLootBidderFrame
  ChatLootBidderFrame.ADDON_LOADED("ChatLootBidder")

  -- Reset module-local SR state (softReserveSessionName + softReservesLocked)
  -- by loading a temp session, unlocking, then unloading
  ChatLootBidderFrame:HandleSrLoad("__test_reset__")
  ChatLootBidderFrame:ToggleSrLock("unlock")
  ChatLootBidderFrame:HandleSrUnload()
  ChatLootBidder_Store.SoftReserveSessions = {}

  ResetWhisperDedup()
  ClearChatLog()
end

function SetUpTestEnvironment()
  ResetAddonState()

  ChatLootBidder_Store.DefaultSessionMode = "MSOS"
  ChatLootBidder_Store.ShowPlayerClassColors = false
  ChatLootBidder_Store.BreakTies = true
  ChatLootBidder_Store.BidAnnounce = false
  ChatLootBidder_Store.BidSummary = false
  ChatLootBidder_Store.OffspecPenalty = 0
  ChatLootBidder_Store.AltPenalty = 0
  ChatLootBidder_Store.ItemValidation = false
  ChatLootBidder_Store.AutoLockSoftReserve = false
  ChatLootBidder_Store.AutoRemoveSrAfterWin = true
  ChatLootBidder_Store.SoftReserveSessions = {}

  SetUpRaidMocks(DefaultRaidRoster)
end

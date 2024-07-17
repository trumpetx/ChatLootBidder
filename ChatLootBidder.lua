local ChatLootBidder = ChatLootBidderFrame
if ChatLootBidder == nil then print("XML Error"); return end
local startSessionButton = getglobal(ChatLootBidder:GetName() .. "StartSession")
local endSessionButton = getglobal(ChatLootBidder:GetName() .. "EndSession")
local clearSessionButton = getglobal(ChatLootBidder:GetName() .. "ClearSession")

local gfind = string.gmatch or string.gfind
math.randomseed(time() * 100000000000)
for i=1,3 do
  math.random(10000, 65000)
end

local function Roll()
  return math.random(1, 100)
end

local addonName = "ChatLootBidder"
local addonTitle = GetAddOnMetadata(addonName, "Title")
local addonNotes = GetAddOnMetadata(addonName, "Notes")
local addonVersion = GetAddOnMetadata(addonName, "Version")
local addonAuthor = GetAddOnMetadata(addonName, "Author")
local chatPrefix = "<CL> "
local me = UnitName("player")
-- Roll tracking heavily borrowed from RollTracker: http://www.wowace.com/projects/rolltracker/
if GetLocale() == 'deDE' then RANDOM_ROLL_RESULT = "%s w\195\188rfelt. Ergebnis: %d (%d-%d)"
elseif RANDOM_ROLL_RESULT == nil then RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)" end -- Using english language https://vanilla-wow-archive.fandom.com/wiki/WoW_constants if not set
local rollRegex = string.gsub(string.gsub(string.gsub("%s rolls %d (%d-%d)", "([%(%)%-])", "%%%1"), "%%s", "%(.+%)"), "%%d", "%(%%d+%)")

ChatLootBidder_ChatFrame_OnEvent = ChatFrame_OnEvent

local softReserveSessionName = nil
local softReservesLocked = false
local session = nil
local sessionMode = nil
local stage = nil
local lastWhisper = nil

local function DefaultFalse(prop) return prop == true end
local function DefaultTrue(prop) return prop == nil or DefaultFalse(prop) end

local function LoadVariables()
  ChatLootBidder_Store = ChatLootBidder_Store or {}
  ChatLootBidder_Store.RollAnnounce = DefaultTrue(ChatLootBidder_Store.RollAnnounce)
  ChatLootBidder_Store.AutoStage = DefaultTrue(ChatLootBidder_Store.AutoStage)
  ChatLootBidder_Store.BidAnnounce = DefaultFalse(ChatLootBidder_Store.BidAnnounce)
  ChatLootBidder_Store.BidSummary = DefaultFalse(ChatLootBidder_Store.BidSummary)
  ChatLootBidder_Store.BidChannel = ChatLootBidder_Store.BidChannel or "OFFICER"
  ChatLootBidder_Store.SessionAnnounceChannel = ChatLootBidder_Store.SessionAnnounceChannel or "RAID"
  ChatLootBidder_Store.WinnerAnnounceChannel = ChatLootBidder_Store.WinnerAnnounceChannel or "RAID_WARNING"
  ChatLootBidder_Store.DebugLevel = ChatLootBidder_Store.DebugLevel or 0
  ChatLootBidder_Store.TimerSeconds = ChatLootBidder_Store.TimerSeconds or 30
  ChatLootBidder_Store.MaxBid = ChatLootBidder_Store.MaxBid or 5000
  ChatLootBidder_Store.MinBid = ChatLootBidder_Store.MinBid or 1
  ChatLootBidder_Store.MinRarity = ChatLootBidder_Store.MinRarity or 4
  ChatLootBidder_Store.MaxRarity = ChatLootBidder_Store.MaxRarity or 5
  ChatLootBidder_Store.DefaultSessionMode = ChatLootBidder_Store.DefaultSessionMode or "MSOS" -- DKP | MSOS
  ChatLootBidder_Store.BreakTies = DefaultTrue(ChatLootBidder_Store.BreakTies)
  ChatLootBidder_Store.AddonVersion = addonVersion
  ChatLootBidder_Store.SoftReserveSessions = ChatLootBidder_Store.SoftReserveSessions or {}
  ChatLootBidder_Store.AutoRemoveSrAfterWin = DefaultTrue(ChatLootBidder_Store.AutoRemoveSrAfterWin)
  ChatLootBidder_Store.AutoLockSoftReserve = DefaultTrue(ChatLootBidder_Store.AutoLockSoftReserve)
  -- TODO: Make this custom per Soft Reserve session and make this the default when a new list is started
  ChatLootBidder_Store.DefaultMaxSoftReserves = 1
end

local function ToWholeNumber(numberString, default)
  if default == nil then default = 0 end
  if numberString == nil then return default end
  local num = math.floor(tonumber(numberString) or default)
  if default == num then return default end
  return math.max(num, default)
end

local function Error(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. chatPrefix .. "|cffff0000 "..message)
end

local function Message(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff".. chatPrefix .."|r "..message)
end

local function Debug(message)
	if ChatLootBidder_Store.DebugLevel > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff".. chatPrefix .."|cffffff00 "..message)
	end
end

local function Trace(message)
	if ChatLootBidder_Store.DebugLevel > 1 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff".. chatPrefix .."|cffffff00 "..message)
	end
end

local ShowHelp = function()
	Message("/loot - Show the stage or end session window")
	Message("/loot info - Show current settings")
  Message("/loot stage [itm1] [itm2] - Stage item(s) for a future session start")
	Message("/loot start [itm1] [itm2] [#timer_optional] - Start a session for item(s) + staged items(s)")
  Message("/loot end - End a loot session and announce winner(s)")
  Message("/loot dkp - Switch to DKP Session Mode")
  Message("/loot msos - Switch to MS/OS Session Mode")
  Message("/loot sr load [name]  - Load a SR list (by name, optional)")
  Message("Visit https://github.com/trumpetx/ChatLootBidder for a full listing of commands and instructions")
end

local function TrueOnOff(val)
  return val and "On" or "Off"
end

local ShowInfo = function()
  Message("Bid announcing is " .. TrueOnOff(ChatLootBidder_Store.BidAnnounce))
  Message("Roll announcing is " .. TrueOnOff(ChatLootBidder_Store.RollAnnounce))
  Message("Bid summary at end is " .. TrueOnOff(ChatLootBidder_Store.BidSummary))
  Message("Bid announce channel set to " .. ChatLootBidder_Store.BidChannel)
  Message("Session announce channel set to " .. ChatLootBidder_Store.SessionAnnounceChannel)
  Message("Winner announce channel set to " .. ChatLootBidder_Store.WinnerAnnounceChannel)
  Message("BigWigs default loot timer set to " .. ChatLootBidder_Store.TimerSeconds .. " seconds")
  Message("Maximum bid set to " .. ChatLootBidder_Store.MaxBid)
  Message("Auto-stage is " .. TrueOnOff(ChatLootBidder_Store.AutoStage))
  Message("Auto-stage loot level is set to min=" .. ChatLootBidder_Store.MinRarity .. ", max=" .. ChatLootBidder_Store.MaxRarity .. " (0=gray - 5=legendary)")
  Message("Session Mode set to " .. ChatLootBidder_Store.DefaultSessionMode)
  Message("Break Ties mode (DKP only) is " .. TrueOnOff(ChatLootBidder_Store.BreakTies))
	if ChatLootBidder_Store.DebugLevel > 0 then Message("Debug Level set to " .. ChatLootBidder_Store.DebugLevel) end
	Message(addonNotes .. " for bugs and suggestions")
	Message("Written by " .. addonAuthor)
  if ChatLootBidder_Store.DebugLevel > 1 then
    Trace("Session: " .. (session == nil and "None" or ""))
    for k,v in pairs(session or {}) do
      Trace("  " .. k)
      Trace("  MS")
      for k2,v2 in pairs(session[k]["ms"]) do
        Trace("    " .. k2 .. " - " .. v2)
      end
      Trace("  OS")
      for k2,v2 in pairs(session[k]["os"]) do
        Trace("    " .. k2 .. " - " .. v2)
      end
      Trace("  ROLL")
      for k2,v2 in pairs(session[k]["roll"]) do
        Trace("    " .. k2 .. " - " .. v2)
      end
    end
  end
end

local function GetRaidIndex(unitName)
  if UnitInRaid("player") == 1 then
     for i = 1, GetNumRaidMembers() do
        if UnitName("raid"..i) == unitName then
           return i
        end
     end
  end
  return 0
end

local function IsInRaid(unitName)
  return GetRaidIndex(unitName) ~= 0
end

local function IsRaidAssistant(unitName)
  _, rank = GetRaidRosterInfo(GetRaidIndex(unitName));
  return rank ~= 0
end

local function GetPlayerClass(unitName)
  _, _, _, _, _, playerClass = GetRaidRosterInfo(GetRaidIndex(unitName));
  return playerClass
end

local function IsMasterLooterSet()
  local method, _ = GetLootMethod()
  return method == "master"
end

local function IsStaticChannel(channel)
  channel = channel == nil and nil or string.upper(channel)
  return channel == "RAID" or channel == "RAID_WARNING" or channel == "SAY" or channel == "EMOTE" or channel == "PARTY" or channel == "GUILD" or channel == "OFFICER"
end

local function IsTableEmpty(tbl)
  if tbl == nil then return true end
  local next = next
  return next(tbl) == nil
end

-- Flatten a Player: [ SR1, SR2 ] structure into: { [Player, SR1], [Player, SR2] }
local function Flatten(tbl)
  if tbl == nil then return {} end
  local flattened = {}
  local k, arr, v
  for k, arr in pairs(tbl) do
    for _,v in pairs(arr) do
      table.insert(flattened, { k, v })
    end
  end
  return flattened
end

-- Take a [[Player, SR1], [Player, SR2]] data structure and Map it: { Player: [ SR1, SR2 ] }
local function UnFlatten(tbl)
  if tbl == nil then return {} end
  local unflattened = {}
  local arr
  for _, arr in pairs(tbl) do
    if unflattened[arr[1]] == nil then unflattened[arr[1]] = {} end
    if arr[2] ~= nil then
      table.insert(unflattened[arr[1]], arr[2])
    end
  end
  return unflattened
end

local function TableContains(table, element)
  local value
  for _,value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

local function ParseItemNameFromItemLink(i)
  local _, _ , n = string.find(i, "|h.(.-)]")
  return n
end

local function TableLength(tbl)
  if tbl == nil then return 0 end
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

local function SplitBySpace(str)
  local commandlist = { }
  local command
  for command in gfind(str, "[^ ]+") do
    table.insert(commandlist, command)
  end
  return commandlist
end

local function GetKeysWhere(tbl, fn)
  if tbl == nil then return {} end
  local keys = {}
  for key,value in pairs(tbl) do
    if fn == nil or fn(key, value) then
      table.insert(keys, key)
    end
  end
  return keys
end

local function GetKeys(tbl)
  return GetKeysWhere(tbl)
end

local function GetKeysSortedByValue(tbl)
  local keys = GetKeys(tbl)
  table.sort(keys, function(a, b)
    return tbl[a] > tbl[b]
  end)
  return keys
end

local function SendToChatChannel(channel, message, prio)
  if IsStaticChannel(channel) then
    ChatThrottleLib:SendChatMessage(prio or "NORMAL", shortName, message, channel)
  else
    local channelIndex = GetChannelName(channel)
    if channelIndex > 0 then
      ChatThrottleLib:SendChatMessage(prio or "NORMAL", shortName, message, "CHANNEL", nil, channelIndex)
    else
      Error(channel .. " <Not In Channel> " .. message)
    end
  end
end

local function MessageBidSummaryChannel(message, force)
  if ChatLootBidder_Store.BidSummary or force then
    SendToChatChannel(ChatLootBidder_Store.BidChannel, message)
    Trace("<SUMMARY>" .. message)
  else
    Debug("<SUMMARY>" .. message)
  end
end

local function MessageBidChannel(message)
  if ChatLootBidder_Store.BidAnnounce then
    SendToChatChannel(ChatLootBidder_Store.BidChannel, message)
    Trace("<BID>" .. message)
  else
    Debug("<BID>" .. message)
  end
end

local function MessageWinnerChannel(message)
  SendToChatChannel(ChatLootBidder_Store.WinnerAnnounceChannel, message)
  Trace("<WIN>" .. message)
end

local function MessageStartChannel(message)
  SendToChatChannel(ChatLootBidder_Store.SessionAnnounceChannel, message)
  Trace("<START>" .. message)
end

local function SendResponse(message, bidder)
  if bidder == me then
    Message(message)
  else
    ChatThrottleLib:SendChatMessage("ALERT", shortName, message, "WHISPER", nil, bidder)
  end
end

local function AppendNote(note)
  return (note == nil or note == "") and "" or " [ " .. note .. " ]"
end

local function PlayerWithClassColor(unit)
  if RAID_CLASS_COLORS and pfUI then -- pfUI loads class colors
    local unitClass = GetPlayerClass(unit)
    local colorStr = RAID_CLASS_COLORS[unitClass].colorStr
    if colorStr and string.len(colorStr) == 8 then
      return "\124c" .. colorStr .. "\124Hplayer:" .. unit .. "\124h" .. unit .. "\124h\124r"
    end
  end
  return unit
end

local function Srs(n)
  local n = n or softReserveSessionName
  local srs = ChatLootBidder_Store.SoftReserveSessions[n]
  if srs ~= nil then return srs end
  ChatLootBidder_Store.SoftReserveSessions[n] = {}
  return ChatLootBidder_Store.SoftReserveSessions[n];
end

local function HandleSrRemove(bidder, item)
  local itemName = ParseItemNameFromItemLink(item)
  if Srs()[bidder] == nil then
    Srs()[bidder] = {}
  end
  local sr = Srs()[bidder]
  local i, v
  for i,v in pairs(sr) do
    if v == itemName then
        table.remove(sr,i)
        SendResponse("You are no longer reserving: " .. itemName, bidder)
        return
    end
  end
end

local function BidSummary(announceWinners)
  if session == nil then
    Error("There is no existing session")
    return
  end
  local summaries = {}
  for item,itemSession in pairs(session) do
    local sr = itemSession["sr"] or {}
    local ms = itemSession["ms"] or {}
    local ofs = itemSession["os"] or {}
    local roll = itemSession["roll"]
    local cancel = itemSession["cancel"] or {}
    local notes = itemSession["notes"] or {}
    local needsRoll = IsTableEmpty(sr) and IsTableEmpty(ms) and IsTableEmpty(ofs)
    if announceWinners and needsRoll then
      for bidder,r in roll do
        if r == -1 then
          r = Roll()
          roll[bidder] = r
          if ChatLootBidder_Store.RollAnnounce then
            MessageStartChannel(PlayerWithClassColor(bidder) .. " rolls " .. r .. " (1-100) for " .. item)
          else
            SendResponse("You roll " .. r .. " (1-100) for " .. item, bidder)
          end
        end
      end
    end
    local winner = {}
    local winnerBid = nil
    local winnerTier = nil
    local header = true
    local summary = {}
    if not IsTableEmpty(sr) then
      local sortedMainspecKeys = GetKeysSortedByValue(sr)
      for k,bidder in pairs(sortedMainspecKeys) do
        if IsTableEmpty(winner) then table.insert(summary, item) end
        if header then table.insert(summary, "- Soft Reserve:"); header = false end
        local bid = sr[bidder]
        if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "sr"
        elseif not IsTableEmpty(winner) and winnerTier == "sr" and winnerBid == bid then table.insert(winner, bidder) end
        table.insert(summary, "-- " .. PlayerWithClassColor(bidder) .. ": " .. bid)
      end
    end
    header = true
    if not IsTableEmpty(ms) then
      local sortedMainspecKeys = GetKeysSortedByValue(ms)
      for k,bidder in pairs(sortedMainspecKeys) do
        if cancel[bidder] == nil then
          if IsTableEmpty(winner) then table.insert(summary, item) end
          if header then table.insert(summary, "- Main Spec:"); header = false end
          local bid = ms[bidder]
          if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "ms"
          elseif not IsTableEmpty(winner) and winnerTier == "ms" and winnerBid == bid then table.insert(winner, bidder) end
          table.insert(summary, "-- " .. PlayerWithClassColor(bidder) .. ": " .. bid .. AppendNote(notes[bidder]))
        end
      end
    end
    header = true
    if not IsTableEmpty(ofs) then
      local sortedOffspecKeys = GetKeysSortedByValue(ofs)
      for k,bidder in pairs(sortedOffspecKeys) do
        if cancel[bidder] == nil and ms[bidder] == nil then
          if IsTableEmpty(winner) then table.insert(summary, item) end
          if header then table.insert(summary, "- Off Spec:"); header = false end
          local bid = ofs[bidder]
          if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "os"
          elseif not IsTableEmpty(winner) and winnerTier == "os" and winnerBid == bid then table.insert(winner, bidder) end
          table.insert(summary, "-- " .. PlayerWithClassColor(bidder) .. ": " .. bid .. AppendNote(notes[bidder]))
        end
      end
    end
    header = true
    if not IsTableEmpty(roll) then
      local sortedRollKeys = GetKeysSortedByValue(roll)
      for k,bidder in pairs(sortedRollKeys) do
        if cancel[bidder] == nil and ms[bidder] == nil and ofs[bidder] == nil then
          if IsTableEmpty(winner) then table.insert(summary, item) end
          if header then table.insert(summary, "- Rolls:"); header = false end
          local bid = roll[bidder]
          if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "roll"
          elseif not IsTableEmpty(winner) and winnerTier == "roll" and winnerBid == bid then table.insert(winner, bidder) end
          table.insert(summary, "-- " .. PlayerWithClassColor(bidder) .. ": " .. bid .. AppendNote(notes[bidder]))
        end
      end
    end
    local breakTies = ChatLootBidder_Store.BreakTies or sessionMode ~= "DKP"
    if getn(winner) > 1 then
      if sessionMode == "DKP" then
        MessageWinnerChannel(table.concat(winner, ", ") .. " tied with a ".. string.upper(winnerTier) .. " bid of " .. winnerBid .. ", rolling it off:")
      else
        MessageWinnerChannel(table.concat(winner, ", ") .. " bid ".. string.upper(winnerTier) ..", rolling it off:")
      end
      while getn(winner) > 1 and breakTies do
        local winningRoll = 0
        for _,bidder in winner do
          local r = roll[bidder]
          if r == -1 or r == nil then
            r = Roll()
            roll[bidder] = r
            MessageWinnerChannel(PlayerWithClassColor(bidder) .. " rolls " .. r .. " (1-100) for " .. item)
          else
            r = roll[bidder]
            MessageWinnerChannel(PlayerWithClassColor(bidder) .. " already rolled " .. r .. " (1-100) for " .. item)
          end
          if winningRoll < r then winningRoll = r end
        end
        local newWinner = {}
        for _,bidder in winner do
          if roll[bidder] == winningRoll then
            table.insert(newWinner, bidder)
          end
          roll[bidder] = -1
        end
        winner = newWinner
      end
    end
    if IsTableEmpty(winner) then
      if announceWinners then MessageStartChannel("No bids received for " .. item) end
      table.insert(summary, item .. ": No Bids")
    elseif announceWinners then
      local winnerMessage = table.concat(winner, ", ") .. (getn(winner) > 1 and " tie for " or " wins ") .. item
      if sessionMode == "DKP" then
        winnerMessage = winnerMessage .. " with a " .. (winnerTier == "roll" and "roll of " or (string.upper(winnerTier) .. " bid of ")) .. winnerBid
      else
        winnerMessage = winnerMessage .. " for " .. string.upper(winnerTier)
      end
      MessageWinnerChannel(winnerMessage)
    end
    table.insert(summaries, summary)
    if winnerTier == "sr" and ChatLootBidder_Store.DefaultAutoRemoveSrAfterWin then
      HandleSrRemove(winner[1], item)
    end
  end
  for _,summary in summaries do
    for _,line in summary do
      MessageBidSummaryChannel(line)
    end
  end
end

function ChatLootBidder:End()
  ChatThrottleLib:SendAddonMessage("BULK", "NotChatLootBidder", "endSession=1", "RAID")
  BidSummary(true)
  session = nil
  sessionMode = nil
  stage = nil
  endSessionButton:Hide()
  ChatLootBidder:Hide()
end

local function GetItemLinks(str)
  local itemLinks = {}
  local _start, _end, _lastEnd = nil, -1, -1
  while true do
    _start, _end = string.find(str, "|c.-|H.-|h|r", _end + 1)
    if _start == nil then
      return itemLinks, _lastEnd
    end
    _lastEnd = _end
    table.insert(itemLinks, string.sub(str, _start, _end))
  end
end

function ChatLootBidder:Start(items, timer, mode)
  if not IsRaidAssistant(me) then Error("You must be a raid leader or assistant in a raid to start a loot session"); return end
  if not IsMasterLooterSet() then Error("Master Looter must be set to start a loot session"); return end
  local mode = mode ~= nil and mode or ChatLootBidder_Store.DefaultSessionMode
  if session ~= nil then ChatLootBidder:End() end
  local stageList = GetKeysWhere(stage, function(k,v) return v == true end)
  if items == nil then
    items = stageList
  else
    for _, v in pairs(stageList) do
      table.insert(items, v)
    end
  end
  if IsTableEmpty(items) then Error("You must provide at least a single item to bid on"); return end
  ChatLootBidder:EndSessionButtonShown()
  session = {}
  stage = nil
  if ChatLootBidder_Store.AutoLockSoftReserve and softReserveSessionName ~= nil and not softReservesLocked then
    softReservesLocked = true
    MessageStartChannel("Soft Reserves for " .. softReserveSessionName .. " are now LOCKED")
  end
  local srs = mode == "MSOS" and softReserveSessionName ~= nil and ChatLootBidder_Store.SoftReserveSessions[softReserveSessionName] or {}
  local startChannelMessage = {}
  table.insert(startChannelMessage, "Bid on the following items")
  table.insert(startChannelMessage, "-----------")
  local bidAddonMessage = "mode=" .. mode .. ",items="
  for k,i in pairs(items) do
    local itemName = ParseItemNameFromItemLink(i)
    local srsOnItem = GetKeysWhere(srs, function(player, playerSrs) return IsInRaid(player) and TableContains(playerSrs, itemName) end)
    local srLen = TableLength(srsOnItem)
    local exampleItem = "[item-link]"
    session[i] = {}
    if srLen == 0 then
      exampleItem = i
      table.insert(startChannelMessage, i)
      bidAddonMessage = bidAddonMessage .. string.gsub(i, ",", "~~~")
      session[i]["ms"] = {}
      session[i]["os"] = {}
      session[i]["roll"] = {}
      session[i]["cancel"] = {}
      session[i]["notes"] = {}
    else
      session[i]["sr"] = {}
      session[i]["roll"] = {}
      for _,sr in pairs(srsOnItem) do
        session[i]["sr"][sr] = 1
        session[i]["roll"][sr] = -1
        if srLen > 1 then
          SendResponse("Your Soft Reserve for " .. i .. " is contested by " .. (srLen-1) .. " other player" .. (srLen == 2 and "" or "s") .. ". '/random' now to record your own roll or do nothing for the addon to roll for you at the end of the session.", sr)
        else
          SendResponse("You won " .. i .. " with your Soft Reserve!", srsOnItem[1])
        end
      end
    end
  end
  table.insert(startChannelMessage, "-----------")
  table.insert(startChannelMessage, "/w " .. PlayerWithClassColor(me) .. " " .. exampleItem .. " ms/os/roll" .. (mode == "DKP" and " #bid" or "") .. " [optional-note]")
  if TableLength(startChannelMessage) > 4 then
    local l
    for _, l in pairs(startChannelMessage) do
      MessageStartChannel(l)
    end
    if timer == nil or timer < 0 then timer = ChatLootBidder_Store.TimerSeconds end
    if BigWigs and timer > 0 then BWCB(timer, "Bidding Ends") end
    ChatThrottleLib:SendAddonMessage("BULK", "NotChatLootBidder", bidAddonMessage, "RAID")
  else
    -- Everything was SR'd - just end now
    ChatLootBidder:End()
  end
end

function ChatLootBidder:Clear(stageOnly)
  if session == nil or stageOnly then
    if IsTableEmpty(stage) then
      Message("There is no active session or stage")
    else
      stage = nil
      Message("Cleared the stage")
      ChatLootBidder:RedrawStage()
    end
  else
    session = nil
    Message("Cleared the current loot session")
  end
end

function ChatLootBidder:Unstage(item, redraw)
  stage[item] = false
  if redraw then ChatLootBidder:RedrawStage() end
end

local function HandleSrDelete(providedName)
  if softReserveSessionName == nil and providedName == nil then
    Error("No Soft Reserve session loaded or provided for deletion")
  elseif providedName == nil then
    ChatLootBidder_Store.SoftReserveSessions[softReserveSessionName] = nil
    Message("Deleted currently loaded Soft Reserve session: " .. softReserveSessionName)
    softReserveSessionName = nil
  elseif ChatLootBidder_Store.SoftReserveSessions[providedName] == nil then
    Error("No Soft Reserve session exists with the label: " .. providedName)
  else
    ChatLootBidder_Store.SoftReserveSessions[providedName] = nil
    Message("Deleted Soft Reserve session: " .. providedName)
  end
end

local function HandleSrLoad(providedName)
  softReserveSessionName = providedName or date("%y-%m-%d")
  Message("Soft Reserve list [" .. softReserveSessionName .. "] loaded with " .. TableLength(Srs()) .. " players with soft reserves")
end

local function HandleSrUnload()
  if softReserveSessionName == nil then
    Error("No Soft Reserve session loaded")
  else
    Message("Unloaded Soft Reserve session: " .. softReserveSessionName)
    softReserveSessionName = nil
  end
end

local function HandleSrShow()
  if softReserveSessionName == nil then
    Error("No Soft Reserve session loaded")
  else
    local srs = Srs()
    if IsTableEmpty(srs) then
      Error("No Soft Reserves placed yet")
      return
    end
    MessageStartChannel("Soft Reserve Bids:")
    local keys = GetKeys(srs)
    table.sort(keys)
    local player
    for _, player in pairs(keys) do
      local sr = srs[player]
      if IsInRaid(player) and not IsTableEmpty(sr) then
        MessageStartChannel(PlayerWithClassColor(player) .. ": " .. table.concat(sr, ", "))
      end
    end
  end
end

local function EncodeSemicolon()
  local encoded = ""
  for k,v in pairs(Srs()) do
    encoded = encoded .. k
    for _, sr in pairs(v) do
      encoded = encoded .. " ; " .. sr
    end
    encoded = encoded .. "\n"
  end
  return encoded
end

local function EncodeRaidResFly()
  local encoded = ""
  local flat = Flatten(Srs())
  for _,arr in flat do
    -- [00:00]Autozhot: Autozhot - Band of Accuria
    encoded = (encoded or "") .. "[00:00]"..arr[1]..": "..arr[1].." - "..arr[2].."\n"
  end
  return encoded
end

-- This is the most simple pretty print function possible applciable to { key : [value, value, value] } structures only
local function PrettyPrintJson(encoded)
  encoded = string.gsub(encoded, "{", "{\n")
  encoded = string.gsub(encoded, "}", "\n}")
  encoded = string.gsub(encoded, "],", "],\n")
  return encoded
end

local InitSlashCommands = function()
	SLASH_ChatLootBidder1, SLASH_ChatLootBidder2 = "/l", "/loot"
	SlashCmdList["ChatLootBidder"] = function(message)
		local commandlist = SplitBySpace(message)
    if commandlist[1] == nil then
      if session == nil then
        ChatLootBidder:StartSessionButtonShown()
      else
        ChatLootBidder:EndSessionButtonShown()
      end
    elseif commandlist[1] == "help" then
			ShowHelp()
    elseif commandlist[1] == "autostage" then
      ChatLootBidder_Store.AutoStage = not ChatLootBidder_Store.AutoStage
      Message("Auto-Stage mode is " .. TrueOnOff(ChatLootBidder_Store.AutoStage))
    elseif commandlist[1] == "autostageloot" then
      local min = ToWholeNumber(commandlist[2], -1)
      local max = ToWholeNumber(commandlist[3], -1)
      if min > 5 or min < 0 or max > 5 or max < 0 then
        Error("Provide a loot-level range (inclusive): /loot autostageloot 4 4")
      else
        ChatLootBidder_Store.MinRarity = min
        ChatLootBidder_Store.MaxRarity = max
      end
      Message("Auto-stage loot level is set to min=" .. ChatLootBidder_Store.MinRarity .. ", max=" .. ChatLootBidder_Store.MaxRarity .. " (0=gray - 5=legendary)")
    elseif commandlist[1] == "breakties" then
      ChatLootBidder_Store.BreakTies = not ChatLootBidder_Store.BreakTies
      Message("Break Ties mode is " .. TrueOnOff(ChatLootBidder_Store.BreakTies))
    elseif commandlist[1] == "msos" or commandlist[1] == "dkp" then
      ChatLootBidder_Store.DefaultSessionMode = string.upper(commandlist[1])
      Message("Session Mode set to " .. ChatLootBidder_Store.DefaultSessionMode)
      ChatLootBidder:RedrawStage()
    elseif commandlist[1] == "sr" then
      if ChatLootBidder_Store.DefaultSessionMode ~= "MSOS" then
        Error("You need to be in MSOS mode to modify Soft Reserve sessions.  `/loot msos` to change modes.")
        return
      end
      local subcommand = commandlist[2]
      if commandlist[2] == "load" then
        HandleSrLoad(commandlist[3])
        SrEditFrame:Hide()
      elseif commandlist[2] == "unload" then
        HandleSrUnload()
        SrEditFrame:Hide()
      elseif commandlist[2] == "delete" then
        HandleSrDelete(commandlist[3])
        if commandlist[3] == nil or commandlist[3] == softReserveSessionName then
          SrEditFrame:Hide()
        end
      elseif commandlist[2] == "show" then
        HandleSrShow()
      elseif commandlist[2] == "csv" or commandlist[2] == "json" or commandlist[2] == "semicolon" or commandlist[2] == "raidresfly" then
        if softReserveSessionName == nil then
          Error("No Soft Reserve list is loaded")
        elseif not SrEditFrame:IsVisible() then
          SrEditFrame:Show()
          local encoded
          if commandlist[2] == "csv" then
            encoded = csv:toCSV(Flatten(Srs()))
          elseif commandlist[2] == "json" then
            encoded = PrettyPrintJson(json.encode(Srs()))
          elseif commandlist[2] == "semicolon" then
            encoded = EncodeSemicolon()
          elseif commandlist[2] == "raidresfly" then
            encoded = EncodeRaidResFly()
          end
          SrEditFrameText:SetText(encoded)
          SrEditFrameHeaderString:SetText(commandlist[2])
        else
          SrEditFrame:Hide()
        end
      elseif commandlist[2] == "lock" or commandlist[2] == "unlock" then
        if softReserveSessionName == nil then
          Error("No Soft Reserve session loaded")
        else
          softReservesLocked = commandlist[2] == "lock"
          MessageStartChannel("Soft Reserves for " .. softReserveSessionName .. " are now " .. string.upper(commandlist[2]) .. "ED")
        end
      elseif commandlist[2] == "instructions" then
        MessageStartChannel("Set your SR: /w " .. PlayerWithClassColor(me) .. " sr [item-link or exact-item-name]")
        MessageStartChannel("Get your current SR: /w " .. PlayerWithClassColor(me) .. " sr")
        MessageStartChannel("Clear your current SR: /w " .. PlayerWithClassColor(me) .. " sr clear")
      else
        Error("Unknown 'sr' subcommand: " .. (commandlist[2] == nil and "nil" or commandlist[2]))
        Error("Valid values are: load, unload, delete, show, lock, unlock, json, semicolon, raidresfly, csv, instructions")
      end
    elseif commandlist[1] == "debug" then
      ChatLootBidder_Store.DebugLevel = ToWholeNumber(commandlist[2])
      Message("Debug level set to " .. ChatLootBidder_Store.DebugLevel)
    elseif commandlist[1] == "timer" then
      ChatLootBidder_Store.TimerSeconds = ToWholeNumber(commandlist[2])
      Message("BigWigs default loot timer set to " .. ChatLootBidder_Store.TimerSeconds .. "  seconds")
    elseif commandlist[1] == "timer" then
      ChatLootBidder_Store.MaxBid = math.max(ToWholeNumber(commandlist[2]), 1)
      Message("Maximum bid set to " .. ChatLootBidder_Store.MaxBid)
    elseif commandlist[1] == "bid" then
      if commandlist[2] == nil then
        ChatLootBidder_Store.BidAnnounce = not ChatLootBidder_Store.BidAnnounce
        Message("Bid announcing is " .. TrueOnOff(ChatLootBidder_Store.BidAnnounce))
      else
        ChatLootBidder_Store.BidChannel = commandlist[2]
        Message("Bid announce channel set to " .. ChatLootBidder_Store.BidChannel)
      end
    elseif commandlist[1] == "roll" then
      ChatLootBidder_Store.RollAnnounce = not ChatLootBidder_Store.RollAnnounce
      Message("Roll announcing is " .. TrueOnOff(ChatLootBidder_Store.RollAnnounce))
    elseif commandlist[1] == "endsummary" then
      ChatLootBidder_Store.BidSummary = not ChatLootBidder_Store.BidSummary
      Message("Bid summary at end is " .. TrueOnOff(ChatLootBidder_Store.BidSummary))
    elseif commandlist[1] == "session" then
      if commandlist[2] == nil then
        Error("A channel name (like SAY, RAID, RAID_WARNING, etc) must be provided")
      else
        ChatLootBidder_Store.SessionAnnounceChannel = commandlist[2]
        Message("Session announce channel set to " .. ChatLootBidder_Store.SessionAnnounceChannel)
      end
    elseif commandlist[1] == "win" then
      if commandlist[2] == nil then
        Error("A channel name (like SAY, RAID, RAID_WARNING, etc) must be provided")
      else
        ChatLootBidder_Store.WinnerAnnounceChannel = commandlist[2]
        Message("Winner announce channel set to " .. ChatLootBidder_Store.WinnerAnnounceChannel)
      end
		elseif commandlist[1] == "info" then
      ShowInfo()
    elseif commandlist[1] == "end" then
      ChatLootBidder:End()
    elseif commandlist[1] == "clear" then
      if commandlist[2] == nil then
        ChatLootBidder:Clear()
      elseif stage == nil then
        Error("The stage is empty")
      else
        local itemLinks = GetItemLinks(message)
        for _, item in pairs(itemLinks) do
          ChatLootBidder:Unstage(item)
        end
      end
      ChatLootBidder:RedrawStage()
    elseif commandlist[1] == "stage" then
      local itemLinks = GetItemLinks(message)
      for _, item in pairs(itemLinks) do
        local item = item
        ChatLootBidder:Stage(item, true)
      end
      ChatLootBidder:RedrawStage()
    elseif commandlist[1] == "summary" then
      BidSummary()
    elseif commandlist[1] == "start" then
      local itemLinks = GetItemLinks(message)
      local optionalTimer = ToWholeNumber(commandlist[getn(commandlist)], -1)
      ChatLootBidder:Start(itemLinks, optionalTimer)
		end
  end
end

local function IsValidTier(tier)
  return tier == "ms" or tier == "os" or tier == "roll" or tier == "cancel"
end

local function InvalidBidSyntax(item)
  local bidExample = " " .. (ChatLootBidder_Store.MinBid + 9)
  return "Invalid bid syntax for " .. item .. ".  The proper format is: '[item-link] ms" .. (sessionMode == "DKP" and bidExample or "") .. "' or '[item-link] os" .. (sessionMode == "DKP" and bidExample or "") .. "' or '[item-link] roll'"
end

local function of(amt)
  return sessionMode == "DKP" and (" of " .. amt) or ""
end

local function HandleSrQuery(bidder)
  local sr = Srs(softReserveSessionName)[bidder]
  local msg = "Your Soft Reserve is currently " .. (sr == nil and "not set" or ("[ " .. table.concat(sr, ", ") .. " ]"))
  if softReservesLocked then
    msg = msg .. " LOCKED"
  end
  SendResponse(msg, bidder)
end

local function HandleSrAdd(bidder, itemName)
  if Srs(softReserveSessionName)[bidder] == nil then
    Srs(softReserveSessionName)[bidder] = {}
  end
  local sr = Srs(softReserveSessionName)[bidder]
  table.insert(sr, itemName)
  if TableLength(sr) > ChatLootBidder_Store.DefaultMaxSoftReserves then
    local pop = table.remove(sr, 1)
    if not TableContains(sr, pop) then
      SendResponse("You are no longer reserving: " .. pop, bidder)
    end
  end
end

function ChatFrame_OnEvent(event)
  -- Non-whispers are ignored; Don't react to duplicate whispers (multiple windows, usually)
  if event ~= "CHAT_MSG_WHISPER" or lastWhisper == (arg1 .. arg2) then
    ChatLootBidder_ChatFrame_OnEvent(event)
    return
  end
  lastWhisper = arg1 .. arg2
  local bidder = arg2

  -- Parse string for a item links
  local items, itemIndexEnd = GetItemLinks(arg1)
  local item = items[1]

  -- Handle SR Bids
  local commandlist = SplitBySpace(arg1)
  if (softReserveSessionName ~= nil and string.lower(commandlist[1] or "") == "sr") then
    if not IsInRaid(bidder) then
      SendResponse("You must be in the raid to place a Soft Reserve", bidder)
      return
    end
    if softReserveSessionName == nil then
      SendResponse("There is no Soft Reserve session loaded", bidder)
      return
    end
    -- If we're manually editing the SRs, treat it like being locked for incoming additions
    local softReservesLocked = softReservesLocked or SrEditFrame:IsVisible()
    if TableLength(commandlist) == 1 or softReservesLocked then
      -- skip, query do the query at the end
    elseif commandlist[2] == "clear" or commandlist[2] == "delete" or commandlist[2] == "remove" then
      Srs(softReserveSessionName)[bidder] = nil
    elseif item ~= nil then
      local _i
      for _,_i in pairs(items) do
        HandleSrAdd(bidder, ParseItemNameFromItemLink(_i))
      end
    else
      table.remove(commandlist, 1)
      HandleSrAdd(bidder, table.concat(commandlist, " "))
    end
    HandleSrQuery(bidder)
  -- Ignore all other whispers unless there is an active loot session and there is an item link in the whisper
  elseif session ~= nil and item ~= nil then
    local itemSession = session[item]
    if itemSession == nil then
      local invalidBid = "There is no active loot session for " .. item
      SendResponse(invalidBid, bidder)
      return
    end
    if not IsInRaid(arg2) then
      local invalidBid = "You must be in the raid to send a bid on " .. item
      SendResponse(invalidBid, bidder)
      return
    end
    local mainSpec = itemSession["ms"]
    local offSpec = itemSession["os"]
    local roll = itemSession["roll"]
    local cancel = itemSession["cancel"]
    local notes = itemSession["notes"]

    local bid = SplitBySpace(string.sub(arg1, itemIndexEnd + 1))
    local tier = bid[1] and string.lower(bid[1]) or nil
    local amt = bid[2] and string.lower(bid[2]) or nil

    if IsValidTier(tier) then
      amt = ToWholeNumber(amt)
    elseif IsValidTier(amt) then
      -- The bidder mixed up the ms ## to ## ms, handle the mixup
      local oldTier = tier
      tier = amt;
      amt = ToWholeNumber(oldTier)
    else
      SendResponse(InvalidBidSyntax(item), bidder)
      return
    end
    if tier == "cancel" then
      local cancelBid = "Bid canceled for " .. item
      cancel[bidder] = true
      mainSpec[bidder] = nil
      offSpec[bidder] = nil
      notes[bidder] = nil
      MessageBidChannel("<" .. PlayerWithClassColor(bidder) .. "> " .. cancelBid)
      SendResponse(cancelBid, bidder)
      return
    end
    if amt > ChatLootBidder_Store.MaxBid then
      local invalidBid = "Bid for " .. item .. " is too large, the maxiumum accepted bid is: " .. ChatLootBidder_Store.MaxBid
      SendResponse(invalidBid, bidder)
      return
    end
    -- If they had previously canceled, remove them and allow the new bid to continue
    cancel[bidder] = nil
    if tier == "roll" then
      if roll[bidder] ~= nil and roll[bidder] ~= -1 then
        SendResponse("Your roll of " .. roll[bidder] .. " has already been recorded", bidder)
        return
      end
    elseif sessionMode == "DKP" then
      if amt < ChatLootBidder_Store.MinBid then
        SendResponse(InvalidBidSyntax(item), bidder)
        return
      end
      -- remove amount from the table for note concat
      table.remove(bid, 2)
    else
      amt = 1
    end
    -- remove tier from the table for note concat
    table.remove(bid, 1)
    local note = table.concat(bid, " ")
    notes[bidder] = note
    local received
    if tier == "ms" then
      mainSpec[bidder] = amt
      if sessionMode == "MSOS" then roll[bidder] = roll[bidder] or -1 end
      received = "Main Spec bid" .. of(amt) .. " received for " .. item .. AppendNote(note)
    elseif mainSpec[bidder] ~= nil then
      SendResponse("You already have a MS bid" .. of(mainSpec[bidder]) .. " recorded. Use '[item-link] cancel' to cancel your current MS bid.", bidder)
      return
    elseif tier == "os" then
      offSpec[bidder] = amt
      if sessionMode == "MSOS" then roll[bidder] = roll[bidder] or -1 end
      received = "Off Spec bid" .. of(amt) .. " received for " .. item .. AppendNote(note)
    elseif offSpec[bidder] ~= nil then
      SendResponse("You already have an OS bid" .. of(offSpec[bidder]) .. " recorded. Use '[item-link] cancel' to cancel your current MS bid.", bidder)
      return
    elseif tier == "roll" then
      roll[bidder] = -1
      received = "Your roll bid for " .. item .. " has been received" .. AppendNote(note) .. ".  '/random' now to record your own roll or do nothing for the addon to roll for you at the end of the session."
    end
    MessageBidChannel("<" .. PlayerWithClassColor(bidder) .. "> " .. tier .. ((sessionMode == "MSOS" or amt == nil or tier == "roll") and "" or (" " .. amt)))
    SendResponse(received, bidder)
    return
  else
    ChatLootBidder_ChatFrame_OnEvent(event)
  end
end

function ChatLootBidder:StartSessionButtonShown()
  ChatLootBidder:Show()
  startSessionButton:Show()
  clearSessionButton:Show()
end

function ChatLootBidder:EndSessionButtonShown()
  ChatLootBidder:Show()
  startSessionButton:Hide()
  clearSessionButton:Hide()
  endSessionButton:Show()
  ChatLootBidder:SetHeight(50)
  for i = 1, 8 do
    local stageItem = getglobal(ChatLootBidder:GetName() .. "Item"..i)
    local unstageButton = getglobal(ChatLootBidder:GetName() .. "UnstageButton"..i)
    unstageButton:Hide()
    stageItem:SetText("")
    stageItem:Hide()
  end
end

function ChatLootBidder:RedrawStage()
  local i=1, k, show
  for k, show in pairs(stage or {}) do
    if show then
      if i == 9 then Error("You may only stage up to 8 items.  Use /loot clear [itm] to clear specific items or /clear to wipe it clean."); return end
      if not ChatLootBidder:IsVisible() then
        ChatLootBidder:StartSessionButtonShown()
      end
      local stageItem = getglobal(ChatLootBidder:GetName() .. "Item"..i)
      local unstageButton = getglobal(ChatLootBidder:GetName() .. "UnstageButton"..i)
      unstageButton:Show()
      stageItem:SetText(k)
      stageItem:Show()
      i = i + 1
    end
  end
  if i == 1 then -- if none shown
    ChatLootBidder:Hide()
  else
    ChatLootBidder:SetHeight(240-(160-i*20))
    for i = i, 8 do
      local stageItem = getglobal(ChatLootBidder:GetName() .. "Item"..i)
      local unstageButton = getglobal(ChatLootBidder:GetName() .. "UnstageButton"..i)
      unstageButton:Hide()
      stageItem:SetText("")
      stageItem:Hide()
    end
  end
  getglobal(ChatLootBidder:GetName() .. "HeaderString"):SetText(ChatLootBidder_Store.DefaultSessionMode .. " Mode")
end

function ChatLootBidder:Stage(i, force)
  stage = stage or {}
  if force or stage[i] == nil then
    stage[i] = true
  end
end

function ChatLootBidder.CHAT_MSG_SYSTEM(msg)
  if session == nil then return end
  local _, _, name, roll, low, high = string.find(msg, rollRegex)
	if name then
    if tonumber(low) > 1 or tonumber(high) > 100 then return end -- invalid roll
    if name == me and tonumber(high) <= 40 then return end -- master looter using pfUI's random loot distribution
    local existingWhy = ""
    for item,itemSession in pairs(session) do
      local existingRoll = itemSession["roll"][name]
      if existingRoll == -1 or ((1 == getn(GetKeys(session))) and existingRoll == nil) then
        itemSession["roll"][name] = tonumber(roll)
        SendResponse("Your roll of " .. roll .. " been recorded for " .. item, name)
        return
      elseif (existingRoll or 0) > 0 then
        existingWhy = existingWhy .. "Your roll of " .. existingRoll .. " has already been recorded for " .. item .. ". "
      end
    end
    if string.len(existingWhy) > 0 then
      SendResponse("Ignoring your roll of " .. roll .. ". " .. existingWhy, name)
    elseif sessionMode == "DKP" then
      SendResponse("Ignoring your roll of " .. roll .. ". You must first declare that you are rolling on an item first: '[item-link] roll'", name)
    else
      SendResponse("Ignoring your roll of " .. roll .. ". You must bid on an item before rolling on it: '[item-link] ms/os/roll'", name)
    end
	end
end

function ChatLootBidder.ADDON_LOADED()
  LoadVariables()
  InitSlashCommands()
  this:UnregisterEvent("ADDON_LOADED")
end

function ChatLootBidder.CHAT_MSG_ADDON(addonTag, stringMessage, channel, sender)
  if VersionUtil:CHAT_MSG_ADDON(addonName, function(ver)
    Message("New version " .. ver .. " of " .. addonTitle .. " is available! Upgrade now at " .. addonNotes)
  end) then return end
end

function ChatLootBidder.PARTY_MEMBERS_CHANGED()
  VersionUtil:PARTY_MEMBERS_CHANGED(addonName)
end

function ChatLootBidder.PLAYER_ENTERING_WORLD()
  VersionUtil:PLAYER_ENTERING_WORLD(addonName)
  if ChatLootBidder_Store.Point and getn(ChatLootBidder_Store.Point) == 4 then
    ChatLootBidder:SetPoint(ChatLootBidder_Store.Point[1], "UIParent", ChatLootBidder_Store.Point[2], ChatLootBidder_Store.Point[3], ChatLootBidder_Store.Point[4])
  end
end

function ChatLootBidder.PLAYER_LEAVING_WORLD()
  local point, _, relativePoint, xOfs, yOfs = ChatLootBidder:GetPoint()
  ChatLootBidder_Store.Point = {point, relativePoint, xOfs, yOfs}
end

function ChatLootBidder.LOOT_OPENED()
  if session ~= nil then return end
  if not ChatLootBidder_Store.AutoStage then return end
  if not IsMasterLooterSet() or not IsRaidAssistant(me) then return end
  local i
  for i=1, GetNumLootItems() do
    local lootIcon, lootName, lootQuantity, rarity, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)
    -- print(lootIcon, lootName, lootQuantity, rarity, locked, isQuestItem, questId, isActive)
    if rarity >= ChatLootBidder_Store.MinRarity and rarity <= ChatLootBidder_Store.MaxRarity then
      ChatLootBidder:Stage(GetLootSlotLink(i))
    end
  end
  ChatLootBidder:RedrawStage()
end

local function Trim(str)
  local _start, _end, _match = string.find(str, '^%s*(.-)%s*$')
  return _match or ""
end


-- [00:00]Autozhot: Autozhot - Band of Accuria
local function ParseRaidResFly(text)
  local line, t = nil, {}
  for line in gfind(text, '([^\n]+)') do
    local _, _, name, item = string.find(line, "^.-: ([%a]-) . (.-)$")
    name = Trim(name)
    item = Trim(item)
    if t[name] == nil then t[name] = {} end
    table.insert(t[name], item)
  end
  return t
end

-- Autozhot ; Band of Accuria ; Giantstalker Boots
local function ParseSemicolon(text)
  local t, line, part, k, v = {}, nil, nil, nil, {}
  for line in gfind(text, '([^\n]+)') do
    for part in gfind(line, '([^;]+)') do
      if k == nil then
        k = Trim(part)
      else
        local sr = Trim(part)
        table.insert(v, sr)
      end
    end
    t[k] = v
    k = nil
    v = {}
  end
  return t
end

function ChatLootBidder:DecodeAndSave(text, parent)
  local encoding = SrEditFrameHeaderString:GetText()
  local t
  if encoding == "json" then
    t = json.decode(text)
  elseif encoding == "csv" then
    t = UnFlatten(csv:fromCSV(text))
  elseif encoding == "raidresfly" then
    t = ParseRaidResFly(text)
  elseif encoding == "semicolon" then
    t = ParseSemicolon(text)
  else
    Error("No encoding provided")
    return
  end
  ChatLootBidder_Store.SoftReserveSessions[softReserveSessionName] = t
  parent:Hide()
end

--
-- Taken from https://github.com/laytya/WowLuaVanilla which took it from SuperMacro
function ChatLootBidder:OnVerticalScroll(scrollFrame)
	local offset = scrollFrame:GetVerticalScroll();
	local scrollbar = getglobal(scrollFrame:GetName().."ScrollBar");

	scrollbar:SetValue(offset);
	local min, max = scrollbar:GetMinMaxValues();
	local display = false;
	if ( offset == 0 ) then
	    getglobal(scrollbar:GetName().."ScrollUpButton"):Disable();
	else
	    getglobal(scrollbar:GetName().."ScrollUpButton"):Enable();
	    display = true;
	end
	if ((scrollbar:GetValue() - max) == 0) then
	    getglobal(scrollbar:GetName().."ScrollDownButton"):Disable();
	else
	    getglobal(scrollbar:GetName().."ScrollDownButton"):Enable();
	    display = true;
	end
	if ( display ) then
		scrollbar:Show();
	else
		scrollbar:Hide();
	end
end

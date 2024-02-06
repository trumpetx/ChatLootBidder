local gfind = string.gmatch or string.gfind
math.randomseed(time() * 100000000000)
for i=1,3 do
  math.random(10000, 65000)
end

local addonNotes = GetAddOnMetadata("ChatLootBidder", "Notes")
local addonVersion = GetAddOnMetadata("ChatLootBidder", "Version")
local addonAuthor = GetAddOnMetadata("ChatLootBidder", "Author")
local shortName = "CL"
local chatPrefix = "<" .. shortName .. "> "
local upgradeMessageShown = false
local loginchannels = { "BATTLEGROUND", "RAID", "GUILD" }
local groupchannels = { "BATTLEGROUND", "RAID" }
local me = UnitName("player")
local itemRegex = "|c.-|H.-|h|r"
-- Roll tracking heavily borrowed from RollTracker: http://www.wowace.com/projects/rolltracker/
if GetLocale() == 'deDE' then RANDOM_ROLL_RESULT = "%s w\195\188rfelt. Ergebnis: %d (%d-%d)"
elseif RANDOM_ROLL_RESULT == nil then RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)" end -- Using english language https://vanilla-wow-archive.fandom.com/wiki/WoW_constants if not set
local rollRegex = string.gsub(string.gsub(string.gsub("%s rolls %d (%d-%d)", "([%(%)%-])", "%%%1"), "%%s", "%(.+%)"), "%%d", "%(%%d+%)")

ChatLootBidder_ChatFrame_OnEvent = ChatFrame_OnEvent

local session = nil

local function LoadVariables()
  ChatLootBidder_Store = ChatLootBidder_Store or {}
  ChatLootBidder_Store.RollAnnounce = ChatLootBidder_Store.RollAnnounce or true
  ChatLootBidder_Store.BidAnnounce = ChatLootBidder_Store.BidAnnounce or false
  ChatLootBidder_Store.BidSummary = ChatLootBidder_Store.BidSummary or true
  ChatLootBidder_Store.BidChannel = ChatLootBidder_Store.BidChannel or "OFFICER"
  ChatLootBidder_Store.SessionAnnounceChannel = ChatLootBidder_Store.SessionAnnounceChannel or "RAID"
  ChatLootBidder_Store.WinnerAnnounceChannel = ChatLootBidder_Store.WinnerAnnounceChannel or "RAID_WARNING"
  ChatLootBidder_Store.DebugLevel = ChatLootBidder_Store.DebugLevel or 0
  ChatLootBidder_Store.TimerSeconds = ChatLootBidder_Store.TimerSeconds or 30
  ChatLootBidder_Store.MaxBid = ChatLootBidder_Store.MaxBid or 5000
  ChatLootBidder_Store.MinBid = ChatLootBidder_Store.MinBid or 1
end

local function ToWholeNumber(numberString, default)
  if default == nil then default = 0 end
  if numberString == nil then return default end
  local num = math.floor(tonumber(numberString) or default)
  if default == num then return default end
  return math.max(num, 0)
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
	Message("/loot info  - Show current settings")
	Message("/loot start [itm1] [itm2] [#timer_optional] - Start a session for item(s)")
  Message("/loot end  - End a loot session and announce winner(s)")
  Message("/loot clear  - Clears a current loot session")
  Message("/loot summary  - Post the current loot session summary to the bid channel")
  Message("/loot bid  - Toggle incoming bid announcements")
  Message("/loot roll  - Toggle generated roll announcements to summary channel")
  Message("/loot endsummary  - Toggle bid summary announcements")
  Message("/loot bid [channel]  - Set the channel for bids and/or summaries")
  Message("/loot session [channel]  - Set the channel for session start")
  Message("/loot win [channel]  - Set the channel for win announcements")
  Message("/loot timer #seconds  - Seconds for a BigWigs default loot timer bar")
  Message("/loot maxbid #number  - The maximum bid allowed to be considered valid")
	Message("/loot debug [0-2]  - Set the debug level (1 = debug, 2 = trace)")
	Message(addonNotes .. " for bugs and suggestions")
	Message("Written by " .. addonAuthor)
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
	Message("Debug Level set to " .. ChatLootBidder_Store.DebugLevel)
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

local function IsTableEmpty(table)
  local next = next
  return next(table) == nil
end

local function GetKeys(tbl)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end
  return keys
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
    ChatThrottleLib:SendChatMessage(prio or "BULK", shortName, message, channel)
  else
    local channelIndex = GetChannelName(channel)
    if channelIndex > 0 then
      ChatThrottleLib:SendChatMessage(prio or "BULK", shortName, message, "CHANNEL", nil, channelIndex)
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
  SendToChatChannel(ChatLootBidder_Store.WinnerAnnounceChannel, message, "NORMAL")
  Trace("<WIN>" .. message)
end

local function MessageStartChannel(message)
  SendToChatChannel(ChatLootBidder_Store.SessionAnnounceChannel, message, "NORMAL")
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

local function BidSummary(announceWinners)
  if session == nil then
    Error("There is no existing session")
    return
  end
  local summaries = {}
  for item,itemSession in pairs(session) do
    local ms = itemSession["ms"]
    local ofs = itemSession["os"]
    local roll = itemSession["roll"]
    local cancel = itemSession["cancel"]
    local notes = itemSession["notes"]
    local needsRoll = IsTableEmpty(ms) and IsTableEmpty(ofs)
    if announceWinners and needsRoll then
      for bidder,r in roll do
        if r == -1 then
          r = math.random(1, 100)
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
    if IsTableEmpty(winner) then
      if announceWinners then MessageStartChannel("No bids received for " .. item) end
      table.insert(summary, item .. ": No Bids")
    elseif announceWinners then
      local winnerMessage = table.concat(winner, ", ") .. (getn(winner) > 1 and " tie for " or " wins ") .. item .. " with a " .. (winnerTier == "roll" and "roll of " or (string.upper(winnerTier) .. " bid of ")) .. winnerBid
      MessageWinnerChannel(winnerMessage)
    end
    table.insert(summaries, summary)
  end
  for _,summary in summaries do
    for _,line in summary do
      MessageBidSummaryChannel(line)
    end
  end
end

local function End()
  BidSummary(true)
  session = nil
end

local function GetItemLinks(str, start)
  local itemLinks = {}
  local _start, _end = nil, -1
  while true do
    _start, _end = string.find(str, itemRegex, _end + 1)
    if _start == nil then
      return itemLinks
    end
    table.insert(itemLinks, string.sub(str, _start, _end))
  end
end

local function Start(items, timer)
  if session ~= nil then End() end
  if IsTableEmpty(items) then Error("You must provide at least a single item to bid on"); return end
  if not IsRaidAssistant(me) then Error("You must be a raid leader or assistant in a raid to start a loot session"); return end
  if not IsMasterLooterSet() then Error("Master Looter must be set to start a loot session"); return end

  session = {}
  MessageStartChannel("Bid on the following items")
  MessageStartChannel("-----------")
  local bidAddonMessage = "sender=" .. me .. ",items="
  for k,i in pairs(items) do
    MessageStartChannel(i)
    bidAddonMessage = bidAddonMessage .. i
    session[i] = {}
    session[i]["ms"] = {}
    session[i]["os"] = {}
    session[i]["roll"] = {}
    session[i]["cancel"] = {}
    session[i]["notes"] = {}
  end
  MessageStartChannel("-----------")
  MessageStartChannel("/w " .. PlayerWithClassColor(me) .. " " .. items[1] .. " ms/os/roll #bid [optional-note]")
  if timer == -1 then timer = ChatLootBidder_Store.TimerSeconds end
  if BigWigs and timer > 0 then BWCB(timer, "Bidding Ends") end
  ChatThrottleLib:SendAddonMessage("BULK", "NotChatLootBidder", bidAddonMessage, "RAID")
end

local InitSlashCommands = function()
	SLASH_ChatLootBidder1, SLASH_ChatLootBidder2 = "/l", "/loot"
	SlashCmdList["ChatLootBidder"] = function(message)
		local commandlist = { }
		local command
		for command in gfind(message, "[^ ]+") do
			table.insert(commandlist, command)
		end
    if commandlist[1] == nil or commandlist[1] == "help" then
			ShowHelp()
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
      End()
    elseif commandlist[1] == "clear" then
      if session == nil then
        Message("There is no active session")
      else
        session = nil
        Message("Cleared the current loot session")
      end
    elseif commandlist[1] == "summary" then
      BidSummary()
    elseif commandlist[1] == "start" then
      local itemLinks = GetItemLinks(table.concat(commandlist, " "))
      local optionalTimer = ToWholeNumber(commandlist[getn(commandlist)], -1)
      Start(itemLinks, optionalTimer)
		end
  end
end

local function SendVersionMessage(chan)
	local msg = "sender=" .. me .. ",version=" .. addonVersion
	Trace("Sent: " .. msg)
	ChatThrottleLib:SendAddonMessage("BULK", shortName, msg, chan)
end

--pfUI.api.strsplit
local function strsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local function SemverCompare(ver1, ver2)
	local major, minor, fix = strsplit(".", ver1)
	local ver1Num = tonumber(major*10000 + minor*100 + fix)
	major, minor, fix = strsplit(".", ver2)
	local ver2Num = tonumber(major*10000 + minor*100 + fix)
	return ver1Num - ver2Num
end

local function ParseMessage(message)
	local t={}
	for kvp in gfind(message, "([^,]+)") do
		local key = nil
		for entry in gfind(kvp, "([^=]+)") do
			if key == nil then
				key = entry
			else
				t[key] = entry
			end
	  end
	end
	return t
end

local function HandleVersionMessage(message)
  if SemverCompare(message["version"], addonVersion) <= 0 then
    Trace(message["sender"] .. " has version " .. message["version"])
    return
  end
  Trace("I have version " .. addonVersion .. " and " .. message["sender"] .. " has version " .. message["version"])
  if not upgradeMessageShown then
    Message("New version available (" .. message["version"] .. ") ! " .. addonNotes)
    upgradeMessageShown = true
  end
end

local function IsValidTier(tier)
  return tier == "ms" or tier == "os" or tier == "roll" or tier == "cancel"
end

function ChatFrame_OnEvent(event)
  if event == "CHAT_MSG_WHISPER" and session ~= nil then
    _start, _end = string.find(arg1, itemRegex, 0)
    if _start ~= nil then
      local bidder = arg2

      local item = string.sub(arg1, _start, _end)
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

      local bidString = _end == nil and arg1 or string.sub(arg1, _end + 1)
      local bid = {}
      for word in gfind(bidString, "[^ ]+") do
        table.insert(bid, word)
      end
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
        local invalidBid = "Invalid bid syntax for " .. item .. ".  The proper format is: '[item-link] ms 10' or '[item-link] os 10' or '[item-link] roll'"
        SendResponse(invalidBid, bidder)
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
      else
        if amt < 1 then
          local invalidBid = "Invalid bid syntax for " .. item .. ".  The proper format is: '[item-link] ms 10' or '[item-link] os 10' or '[item-link] roll'"
          SendResponse(invalidBid, bidder)
          return
        end
        -- remove amount from the table for note concat
        table.remove(bid, 2)
      end
      -- remove tier from the table for note concat
      table.remove(bid, 1)
      local note = table.concat(bid, " ")
      notes[bidder] = note
      local received
      if tier == "ms" then
        mainSpec[bidder] = amt
        received = "Main Spec bid of " .. amt .. " received for " .. item .. AppendNote(note)
      elseif mainSpec[bidder] ~= nil then
        local invalidBid = "You already have a MS bid of " .. mainSpec[bidder] .. " recorded. Use '[item-link] cancel' to cancel your current MS bid."
        SendResponse(invalidBid, bidder)
        return
      elseif tier == "os" then
        offSpec[bidder] = amt
        received = "Off Spec bid of " .. amt .. " received for " .. item .. AppendNote(note)
      elseif offSpec[bidder] ~= nil then
        local invalidBid = "You already have an OS bid of " .. offSpec[bidder] .. " recorded. Use '[item-link] cancel' to cancel your current MS bid."
        SendResponse(invalidBid, bidder)
        return
      elseif tier == "roll" then
        roll[bidder] = -1
        received = "Your roll bid has been received" .. AppendNote(note) .. ".  '/random' now to record your own roll or do nothing for the addon to roll for you at the end of the session."
      end
      MessageBidChannel("<" .. PlayerWithClassColor(bidder) .. "> " .. received)
      SendResponse(received, bidder)
      return
    end
  end
	ChatLootBidder_ChatFrame_OnEvent(event);
end

local function HandleRoll(msg)
  if session == nil then return end
  local _, _, name, roll, low, high = string.find(msg, rollRegex)
	if name then
    if tonumber(low) > 1 or tonumber(high) > 100 then return end -- invalid roll
    local onlyOneItem = getn(GetKeys(session)) == 1
    for item,itemSession in pairs(session) do
      local existingRoll = itemSession["roll"][name]
      if existingRoll == -1 or (onlyOneItem and existingRoll == nil) then
        itemSession["roll"][name] = tonumber(roll)
        SendResponse("Your roll of " .. roll .. " been recorded for " .. item, name)
        return
      elseif onlyOneItem and (existingRoll or 0) > 0 then
        SendResponse("Your roll of " .. existingRoll .. " has already been recorded for " .. item, bidder)
        return
      end
    end
    SendResponse("Ignoring your roll of " .. roll .. ".  You must first declare that you are rolling on an item first: '[item-link] roll'", name)
	end
end

ChatLootBidderFrame = CreateFrame("Frame")
ChatLootBidderFrame:RegisterEvent("ADDON_LOADED")
ChatLootBidderFrame:RegisterEvent("CHAT_MSG_ADDON")
ChatLootBidderFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ChatLootBidderFrame:RegisterEvent("CHAT_MSG_SYSTEM")
ChatLootBidderFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "ChatLootBidder" then
      LoadVariables()
      InitSlashCommands()
      ChatLootBidderFrame:UnregisterEvent("ADDON_LOADED")
  elseif event == "CHAT_MSG_SYSTEM" then
    HandleRoll(arg1)
	elseif event == "CHAT_MSG_ADDON" and arg1 == shortName then
		Trace("Received: " .. arg2)
		local message = ParseMessage(arg2)
    if message["version"] ~= nil then
      HandleVersionMessage(message)
    end
	elseif event == "PARTY_MEMBERS_CHANGED" then
		local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
		if (this.currentGroupSize or 0) < groupsize then
			for _, chan in pairs(groupchannels) do
				SendVersionMessage(chan)
			end
		end
		this.currentGroupSize = groupSize
	elseif event == "PLAYER_ENTERING_WORLD" then
		for _, chan in pairs(loginchannels) do
			SendVersionMessage(chan)
		end
	end
end)

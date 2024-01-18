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
ChatLootBidder_ChatFrame_OnEvent = ChatFrame_OnEvent

local session = nil

local function LoadVariables()
  ChatLootBidder_Store = ChatLootBidder_Store or {}
  ChatLootBidder_Store.BidAnnounce = ChatLootBidder_Store.BidAnnounce or false
  ChatLootBidder_Store.BidSummary = ChatLootBidder_Store.BidSummary or true
  ChatLootBidder_Store.BidChannel = ChatLootBidder_Store.BidChannel or "OFFICER"
  ChatLootBidder_Store.SessionAnnounceChannel = ChatLootBidder_Store.SessionAnnounceChannel or "RAID"
  ChatLootBidder_Store.WinnerAnnounceChannel = ChatLootBidder_Store.WinnerAnnounceChannel or "RAID_WARNING"
  ChatLootBidder_Store.DebugLevel = ChatLootBidder_Store.DebugLevel or 0
  ChatLootBidder_Store.TimerSeconds = ChatLootBidder_Store.TimerSeconds or 30
  ChatLootBidder_Store.MaxBid = ChatLootBidder_Store.MaxBid or 5000
  ChatLootBidder_Store.MinBid = ChatLootBidder_Store.MinBid or 0
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
  Message("/loot summary  - Post the summary")
  Message("/loot bid  - Toggle incoming bid announcements")
  Message("/loot summary  - Toggle bid summary announcements")
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
  Message("Bid summary is " .. TrueOnOff(ChatLootBidder_Store.BidSummary))
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

local function IsStaticChannel(channel)
  channel = channel == nil and nil or string.upper(channel)
  return channel == "RAID" or channel == "RAID_WARNING" or channel == "SAY" or channel == "EMOTE" or channel == "PARTY" or channel == "GUILD" or channel == "OFFICER"
end

local function IsTableEmpty(table)
  local next = next
  return next(table) == nil
end

local function GetKeysSortedByValue(tbl)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end

  table.sort(keys, function(a, b)
    return tbl[a] > tbl[b]
  end)
  return keys
end

local function SendToChatChannel(channel, message)
  if IsStaticChannel(channel) then
    SendChatMessage(message, channel)
  else
    local channelIndex = GetChannelName(channel)
    if channelIndex > 0 then
      SendChatMessage(message, "CHANNEL", "Common", channelIndex)
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

local function BidSummary(announceWinners)
  for item,itemSession in pairs(session) do
    MessageBidSummaryChannel(item)
    local ms = itemSession["ms"]
    local ofs = itemSession["os"]
    local roll = itemSession["roll"]
    local winner = {}
    local winnerBid = nil
    local winnerTier = nil
    if not IsTableEmpty(ms) then
      local sortedMainspecKeys = GetKeysSortedByValue(ms)
      MessageBidSummaryChannel("- Main Spec:")
      for k,bidder in pairs(sortedMainspecKeys) do
        local bid = ms[bidder]
        if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "ms"
        elseif not IsTableEmpty(winner) and winnerTier == "ms" and winnerBid == bid then table.insert(winner, bidder) end
        -- Remove offspec and roll bids if they also MS bid
        if ofs[bidder] ~= nil then table.remove(ofs, bidder) end
        if roll[bidder] ~= nil then table.remove(roll, bidder) end
        MessageBidSummaryChannel("-- " .. bidder .. ": " .. bid)
      end
    end
    if not IsTableEmpty(ofs) then
      local sortedOffspecKeys = GetKeysSortedByValue(ofs)
      MessageBidSummaryChannel("- Off Spec:")
      for k,bidder in pairs(sortedOffspecKeys) do
        local bid = ofs[bidder]
        if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "os"
        elseif not IsTableEmpty(winner) and winnerTier == "os" and winnerBid == bid then table.insert(winner, bidder) end
        -- Remove roll bids if they also OS bid
        if roll[bidder] ~= nil then table.remove(roll, bidder) end
        MessageBidSummaryChannel("-- " .. bidder .. ": " .. bid)
      end
    end
    if not IsTableEmpty(roll) then
      MessageBidSummaryChannel("- Rolls:")
      local sortedRollKeys = GetKeysSortedByValue(roll)
      for k,bidder in pairs(sortedRollKeys) do
        local bid = roll[bidder]
        if IsTableEmpty(winner) then table.insert(winner, bidder); winnerBid = bid; winnerTier = "roll"
        elseif not IsTableEmpty(winner) and winnerTier == "roll" and winnerBid == bid then table.insert(winner, bidder) end
        MessageBidSummaryChannel("-- " .. bidder .. ": " .. bid)
      end
    end
    if IsTableEmpty(winner) and announceWinners then
      MessageStartChannel("No bids received for " .. item)
      MessageBidSummaryChannel("- No Bids")
    else
      local winnerMessage = table.concat(winner, ", ") .. " wins " .. item .. " with a " .. (winnerTier == "roll" and "roll of " or (string.upper(winnerTier) .. " bid of ")) .. winnerBid
      MessageWinnerChannel(winnerMessage)
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
  if IsTableEmpty(items) then Error("You must provide at least a single item to bid on") end
  session = {}
  MessageStartChannel("-----------")
  MessageStartChannel("Bid on the following items")
  MessageStartChannel("-----------")
  for k,i in pairs(items) do
    MessageStartChannel(i)
    session[i] = {}
    session[i]["ms"] = {}
    session[i]["os"] = {}
    session[i]["roll"] = {}
  end
  MessageStartChannel("-----------")
  MessageStartChannel("/w " .. "\124cffffffff\124Hplayer:" .. me .. "\124h" .. me .. "\124h\124r" .. " [item-link] ms/os/roll #bid [optional-note]")
  if timer == -1 then timer = ChatLootBidder_Store.TimerSeconds end
  if BigWigs and timer > 0 then BWCB(timer, "Bidding Ends") end
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
    elseif commandlist[1] == "summary" then
      ChatLootBidder_Store.BidSummary = not ChatLootBidder_Store.BidSummary
      Message("Bid summary is " .. TrueOnOff(ChatLootBidder_Store.BidSummary))
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
    elseif commandlist[1] == "summary" then
      BidSummary()
		end
  end
end

local function SendVersionMessage(chan)
	local msg = "sender=" .. me .. ",version=" .. addonVersion
	Trace("Sent: " .. msg)
	SendAddonMessage(shortName, msg, chan)
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
  if SemverCompare(message["version"], addonVersion) >= 0 then
    Trace(message["sender"] .. " has version " .. addonVersion)
    return
  end
  Trace("I have version " .. addonVersion .. " and " .. message["sender"] .. " has version " .. message["version"])
  if not upgradeMessageShown then
    Message("New version available (" .. arg2 .. ")! " .. addonNotes)
    upgradeMessageShown = true
  end
end

function ChatFrame_OnEvent(event)
  if event == "CHAT_MSG_WHISPER" and session ~= nil then
    _start, _end = string.find(arg1, itemRegex, 0)
    local item
    if _start ~= nil then
      item = string.sub(arg1, _start, _end)
    end
    local bidString = _end == nil and arg1 or string.sub(arg1, _end + 1)
    local bid = {}
		for word in gfind(bidString, "[^ ]+") do
			table.insert(bid, word)
		end
    local bidder = arg2
    local tier = bid[1] and string.lower(bid[1]) or nil
    local amt = ToWholeNumber(bid[2])
    if item ~= nil and (tier == "ms" or tier == "os" or tier == "roll") then
      local itemSession = session[item]
      if itemSession == nil then
        local invalidBid = "There is no active loot session for " .. item .. "."
        MessageBidChannel(invalidBid .. "  <" .. arg2 .. "> " .. arg1)
        SendChatMessage(invalidBid, "WHISPER", "Common", bidder)
        return
      end
      if amt > ChatLootBidder_Store.MaxBid then
        local invalidBid = "Bid for " .. item .. " is too large, the maxiumum accepted bid is: " .. ChatLootBidder_Store.MaxBid
        MessageBidChannel("<" .. arg2 .. "> " .. invalidBid)
        SendChatMessage(invalidBid, "WHISPER", "Common", bidder)
        return
      end
      local mainSpec = itemSession["ms"]
      local offSpec = itemSession["os"]
      local roll = itemSession["roll"]
      if tier == "roll" then
        if roll[bidder] ~= nil then
          MessageBidChannel("Duplicate ROLL bid received from " .. bidder .. " for " .. item .. "; keeping current roll of " .. roll[bidder] .. ".")
          SendChatMessage("Your roll of " .. roll[bidder] .. " has already been recorded", "WHISPER", "Common", bidder)
          return
        end
        amt = math.random(1, 100)
      else
        table.remove(bid, 2)
      end
      table.remove(bid, 1)
      if amt > 0 then
        local note = table.concat(bid, " ")
        local received
        if tier == "ms" then mainSpec[bidder] = amt; received = "Main Spec bid of " end
        if tier == "os" then offSpec[bidder] = amt; received = "Off Spec bid of " end
        if tier == "roll" then roll[bidder] = amt; received = "Roll of " end
        received = received .. amt .. " received for " .. item .. (note == "" and "" or " [ " .. note .. " ]")
        MessageBidChannel(received)
        SendChatMessage(received, "WHISPER", "Common", bidder)
        return
      end
    end
  end
	ChatLootBidder_ChatFrame_OnEvent(event);
end

ChatLootBidderFrame = CreateFrame("Frame")
ChatLootBidderFrame:RegisterEvent("ADDON_LOADED")
ChatLootBidderFrame:RegisterEvent("CHAT_MSG_ADDON")
ChatLootBidderFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ChatLootBidderFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "ChatLootBidder" then
      LoadVariables()
      InitSlashCommands()
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

local NS = ChatLootBidderNS

if not RAID_CLASS_COLORS then
  RAID_CLASS_COLORS = {
    ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    ["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, colorStr = "ff69ccf0" },
    ["ROGUE"]   = { r = 1,    g = 0.96, b = 0.41, colorStr = "fffff569" },
    ["DRUID"]   = { r = 1,    g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
    ["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
    ["SHAMAN"]  = { r = 0.14, g = 0.35, b = 1.0,  colorStr = "ff0070de" },
    ["PRIEST"]  = { r = 1,    g = 1,    b = 1,    colorStr = "ffffffff" },
    ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
    ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
  }
end

function NS.Error(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. NS.chatPrefix .. "|cffff0000 " .. message)
end

function NS.Message(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. NS.chatPrefix .. "|r " .. message)
end

function NS.Debug(message)
  if ChatLootBidder_Store.DebugLevel > 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. NS.chatPrefix .. "|cffffff00 " .. message)
  end
end

function NS.Trace(message)
  if ChatLootBidder_Store.DebugLevel > 1 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. NS.chatPrefix .. "|cffffff00 " .. message)
  end
end

function NS.SendToChatChannel(channel, message, prio)
  if NS.IsStaticChannel(channel) then
    ChatThrottleLib:SendChatMessage(prio or "NORMAL", NS.addonName, message, channel)
  else
    local channelIndex = GetChannelName(channel)
    if channelIndex > 0 then
      ChatThrottleLib:SendChatMessage(prio or "NORMAL", NS.addonName, message, "CHANNEL", nil, channelIndex)
    else
      NS.Error(channel .. " <Not In Channel> " .. message)
    end
  end
end

function NS.MessageBidSummaryChannel(message, force)
  if ChatLootBidder_Store.BidSummary or force then
    NS.SendToChatChannel(ChatLootBidder_Store.BidChannel, message)
    NS.Trace("<SUMMARY>" .. message)
  else
    NS.Debug("<SUMMARY>" .. message)
  end
end

function NS.MessageBidChannel(message)
  if ChatLootBidder_Store.BidAnnounce then
    NS.SendToChatChannel(ChatLootBidder_Store.BidChannel, message)
    NS.Trace("<BID>" .. message)
  else
    NS.Debug("<BID>" .. message)
  end
end

function NS.MessageWinnerChannel(message)
  NS.SendToChatChannel(ChatLootBidder_Store.WinnerAnnounceChannel, message)
  NS.Trace("<WIN>" .. message)
end

function NS.MessageStartChannel(message)
  if NS.IsInRaid(NS.me) then
    NS.SendToChatChannel(ChatLootBidder_Store.SessionAnnounceChannel, message)
  else
    NS.Message(message)
  end
  NS.Trace("<START>" .. message)
end

function NS.SendResponse(message, bidder)
  if bidder == NS.me then
    NS.Message(message)
  else
    ChatThrottleLib:SendChatMessage("ALERT", NS.addonName, message, "WHISPER", nil, bidder)
  end
end

function NS.AppendNote(note)
  return (note == nil or note == "") and "" or " [ " .. note .. " ]"
end

function NS.PlayerWithClassColor(unit)
  if ChatLootBidder_Store.ShowPlayerClassColors then
    local unitClass = NS.GetPlayerClass(unit)
    if unitClass and RAID_CLASS_COLORS[unitClass] then
      local colorStr = RAID_CLASS_COLORS[unitClass].colorStr
      if colorStr and string.len(colorStr) == 8 then
        return "\124c" .. colorStr .. "\124Hplayer:" .. unit .. "\124h" .. unit .. "\124h\124r"
      end
    end
  end
  return unit
end

function NS.PlayersWithClassColors(players)
  local coloredPlayers = {}
  for _, player in pairs(players) do
    table.insert(coloredPlayers, NS.PlayerWithClassColor(player))
  end
  return table.concat(coloredPlayers, ", ")
end

function NS.realAmt(amt, real)
  if real ~= nil and amt ~= real then
    return amt .. "(" .. real .. ")"
  end
  return amt
end

function NS.InvalidBidSyntax(item)
  local bidExample = " " .. (ChatLootBidder_Store.MinBid + 9)
  return "Invalid bid syntax for " .. item .. ".  The proper format is: '[item-link] ms" .. (NS.sessionMode == "DKP" and bidExample or "") .. "' or '[item-link] os" .. (NS.sessionMode == "DKP" and bidExample or "") .. "' or '[item-link] roll'"
end

function NS.of(amt, real)
  if NS.sessionMode == "DKP" then
    return " of " .. NS.realAmt(amt, real)
  end
  return ""
end

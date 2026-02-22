local NS = ChatLootBidderNS
local T = ChatLootBidder_i18n
local startSessionButton = getglobal(ChatLootBidderFrame:GetName() .. "StartSession")
local endSessionButton = getglobal(ChatLootBidderFrame:GetName() .. "EndSession")
local clearSessionButton = getglobal(ChatLootBidderFrame:GetName() .. "ClearSession")

if GetLocale() == "deDE" then
  RANDOM_ROLL_RESULT = "%s w\195\188rfelt. Ergebnis: %d (%d-%d)"
elseif RANDOM_ROLL_RESULT == nil then
  RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
end
local rollRegex = string.gsub(string.gsub(string.gsub("%s rolls %d (%d-%d)", "([%(%)%-])", "%%%1"), "%%s", "%(.+%)"), "%%d", "%(%%d+%)")

local function LoadVariables()
  ChatLootBidder_Store = ChatLootBidder_Store or {}
  ChatLootBidder_Store.ItemValidation = NS.DefaultTrue(ChatLootBidder_Store.ItemValidation)
  ChatLootBidder_Store.RollAnnounce = NS.DefaultTrue(ChatLootBidder_Store.RollAnnounce)
  ChatLootBidder_Store.AutoStage = NS.DefaultTrue(ChatLootBidder_Store.AutoStage)
  ChatLootBidder_Store.BidAnnounce = NS.DefaultFalse(ChatLootBidder_Store.BidAnnounce)
  ChatLootBidder_Store.BidSummary = NS.DefaultFalse(ChatLootBidder_Store.BidSummary)
  ChatLootBidder_Store.BidChannel = ChatLootBidder_Store.BidChannel or "OFFICER"
  ChatLootBidder_Store.SessionAnnounceChannel = ChatLootBidder_Store.SessionAnnounceChannel or "RAID"
  ChatLootBidder_Store.WinnerAnnounceChannel = ChatLootBidder_Store.WinnerAnnounceChannel or "RAID_WARNING"
  ChatLootBidder_Store.DebugLevel = ChatLootBidder_Store.DebugLevel or 0
  ChatLootBidder_Store.TimerSeconds = ChatLootBidder_Store.TimerSeconds or 30
  ChatLootBidder_Store.MaxBid = ChatLootBidder_Store.MaxBid or 5000
  ChatLootBidder_Store.MinBid = ChatLootBidder_Store.MinBid or 1
  ChatLootBidder_Store.AltPenalty = ChatLootBidder_Store.AltPenalty or 0
  ChatLootBidder_Store.OffspecPenalty = ChatLootBidder_Store.OffspecPenalty or 0
  ChatLootBidder_Store.MinRarity = ChatLootBidder_Store.MinRarity or 4
  ChatLootBidder_Store.MaxRarity = ChatLootBidder_Store.MaxRarity or 5
  ChatLootBidder_Store.DefaultSessionMode = ChatLootBidder_Store.DefaultSessionMode or "MSOS"
  ChatLootBidder_Store.BreakTies = NS.DefaultTrue(ChatLootBidder_Store.BreakTies)
  ChatLootBidder_Store.AddonVersion = NS.addonVersion
  ChatLootBidder_Store.SoftReserveSessions = ChatLootBidder_Store.SoftReserveSessions or {}
  ChatLootBidder_Store.AutoRemoveSrAfterWin = NS.DefaultTrue(ChatLootBidder_Store.AutoRemoveSrAfterWin)
  ChatLootBidder_Store.AutoLockSoftReserve = NS.DefaultTrue(ChatLootBidder_Store.AutoLockSoftReserve)
  ChatLootBidder_Store.ShowPlayerClassColors = NS.DefaultTrue(ChatLootBidder_Store.ShowPlayerClassColors)
  ChatLootBidder_Store.DefaultMaxSoftReserves = 1
end

function ChatLootBidderFrame:SetPropValue(propName, propValue, prefix)
  if prefix then
    propName = string.sub(propName, strlen(prefix)+1)
  end
  if ChatLootBidder_Store[propName] ~= nil then
    ChatLootBidder_Store[propName] = propValue
    local v = propValue
    if type(v) == "boolean" then
      v = v and "on" or "off"
    end
    NS.Debug((T[propName] or propName) .. " is " .. tostring(v))

    if propName == "DefaultSessionMode" then
      ChatLootBidderFrame:RedrawStage()
    end
  else
    NS.Error(propName .. " is not initialized")
  end
end

local function ShowHelp()
  NS.Message("/loot - Open GUI Options")
  NS.Message("/loot stage [itm1] [itm2] - Stage item(s) for a future session start")
  NS.Message("/loot start [itm1] [itm2] [#timer_optional] - Start a session for item(s) + staged items(s)")
  NS.Message("/loot end - End a loot session and announce winner(s)")
  NS.Message("/loot sr load [name]  - Load a SR list (by name, optional)")
  NS.Message(NS.addonNotes .. " for detailed instructions, bugs, and suggestions")
  NS.Message("Written by " .. NS.addonAuthor)
end

function ChatLootBidderFrame:End()
  ChatThrottleLib:SendAddonMessage("BULK", "NotChatLootBidder", "endSession=1", "RAID")
  NS.BidSummary(true)
  NS.session = nil
  NS.sessionMode = nil
  NS.stage = nil
  endSessionButton:Hide()
  ChatLootBidderFrame:Hide()
end

function ChatLootBidderFrame:Start(items, timer, mode)
  if not NS.IsRaidAssistant(NS.me) then NS.Error("You must be a raid leader or assistant in a raid to start a loot session"); return end
  if not NS.IsMasterLooterSet() then NS.Error("Master Looter must be set to start a loot session"); return end
  mode = mode ~= nil and mode or ChatLootBidder_Store.DefaultSessionMode
  if NS.session ~= nil then ChatLootBidderFrame:End() end

  local itemCounts = {}
  local itemOrder = {}
  if NS.stage then
    for link, count in pairs(NS.stage) do
      if count and count > 0 then
        itemCounts[link] = count
        table.insert(itemOrder, link)
      end
    end
  end
  if items then
    for _, link in pairs(items) do
      if not itemCounts[link] then
        table.insert(itemOrder, link)
      end
      itemCounts[link] = (itemCounts[link] or 0) + 1
    end
  end
  if NS.IsTableEmpty(itemCounts) then NS.Error("You must provide at least a single item to bid on"); return end

  ChatLootBidderFrame:EndSessionButtonShown()
  NS.session = {}
  NS.sessionMode = mode
  NS.stage = nil

  if ChatLootBidder_Store.AutoLockSoftReserve and NS.softReserveSessionName ~= nil and not NS.softReservesLocked then
    NS.softReservesLocked = true
    NS.MessageStartChannel("Soft Reserves for " .. NS.softReserveSessionName .. " are now LOCKED")
  end

  local srs = mode == "MSOS" and NS.softReserveSessionName ~= nil and ChatLootBidder_Store.SoftReserveSessions[NS.softReserveSessionName] or {}
  local startChannelMessage = {}
  table.insert(startChannelMessage, "Bid on the following items")
  table.insert(startChannelMessage, "-----------")
  local bidAddonMessage = "mode=" .. mode .. ",items="
  local exampleItem

  for _,i in pairs(itemOrder) do
    local count = itemCounts[i]
    local itemName = NS.ParseItemNameFromItemLink(i)
    local srsOnItem = NS.GetKeysWhere(srs, function(player, playerSrs) return NS.IsInRaid(player) and NS.TableContains(playerSrs, itemName) end)
    local srLen = NS.TableLength(srsOnItem)
    local srCopies = math.min(srLen, count)
    local bidCopies = count - srCopies
    NS.session[i] = {}
    NS.session[i]["count"] = count
    NS.session[i]["bidCopies"] = bidCopies
    NS.session[i]["cancel"] = {}
    NS.session[i]["roll"] = {}
    NS.session[i]["real"] = {}

    if srCopies > 0 then
      NS.session[i]["sr"] = {}
      for _,sr in pairs(srsOnItem) do
        NS.session[i]["sr"][sr] = 1
        NS.session[i]["roll"][sr] = -1
      end
      table.insert(startChannelMessage, i .. " SR (" .. srCopies .. ")")
      if srLen <= srCopies then
        for _,sr in pairs(srsOnItem) do
          NS.SendResponse("You won " .. i .. " with your Soft Reserve!", sr)
        end
      else
        for _,sr in pairs(srsOnItem) do
          NS.SendResponse("Your Soft Reserve for " .. i .. " is contested by " .. (srLen-1) .. " other player" .. (srLen == 2 and "" or "s") .. ". '/random' now to record your own roll or do nothing for the addon to roll for you at the end of the session.", sr)
        end
      end
    end

    if bidCopies > 0 then
      exampleItem = i
      NS.session[i]["ms"] = {}
      NS.session[i]["os"] = {}
      NS.session[i]["notes"] = {}
      local bidLabel = i .. (bidCopies > 1 and " (x" .. bidCopies .. ")" or "")
      table.insert(startChannelMessage, bidLabel)
      bidAddonMessage = bidAddonMessage .. string.gsub(i, ",", "~~~")
    end
  end

  table.insert(startChannelMessage, "-----------")
  if exampleItem then
    table.insert(startChannelMessage, "/w " .. NS.PlayerWithClassColor(NS.me) .. " " .. exampleItem .. " ms/os/roll" .. (mode == "DKP" and " #bid" or "") .. " [optional-note]")
    local l
    for _, l in pairs(startChannelMessage) do
      NS.MessageStartChannel(l)
    end
    if timer == nil or timer < 0 then timer = ChatLootBidder_Store.TimerSeconds end
    if BigWigs and timer > 0 then BWCB(timer, "Bidding Ends") end
    ChatThrottleLib:SendAddonMessage("BULK", "NotChatLootBidder", bidAddonMessage, "RAID")
  else
    ChatLootBidderFrame:End()
  end
end

function ChatLootBidderFrame:Clear(stageOnly)
  if NS.session == nil or stageOnly then
    if NS.IsTableEmpty(NS.stage) then
      NS.Message("There is no active session or stage")
    else
      NS.stage = nil
      NS.Message("Cleared the stage")
      ChatLootBidderFrame:RedrawStage()
    end
  else
    NS.session = nil
    NS.Message("Cleared the current loot session")
  end
end

function ChatLootBidderFrame:Unstage(item, redraw)
  if NS.stage[item] then
    NS.stage[item] = NS.stage[item] - 1
    if NS.stage[item] <= 0 then NS.stage[item] = nil end
  end
  if redraw then ChatLootBidderFrame:RedrawStage() end
end

local function HandleChannel(prop, channel)
  if NS.IsStaticChannel(channel) then channel = string.upper(channel) end
  ChatLootBidder_Store[prop] = channel
  NS.Message(T[prop] .. " announce channel set to " .. channel)
  getglobal("ChatLootBidderOptionsFrame" .. prop):SetValue(channel)
end

local function InitSlashCommands()
  SLASH_ChatLootBidder1, SLASH_ChatLootBidder2 = "/l", "/loot"
  SlashCmdList["ChatLootBidder"] = function(message)
    local commandlist = NS.SplitBySpace(message)
    if commandlist[1] == nil then
      if ChatLootBidderOptionsFrame:IsVisible() then
        ChatLootBidderOptionsFrame:Hide()
      else
        ChatLootBidderOptionsFrame:Show()
      end
    elseif commandlist[1] == "help" or commandlist[1] == "info" then
      ShowHelp()
    elseif commandlist[1] == "sr" then
      if ChatLootBidder_Store.DefaultSessionMode ~= "MSOS" then
        NS.Error("You need to be in MSOS mode to modify Soft Reserve sessions.  `/loot` to change modes.")
        return
      end
      if commandlist[2] == "load" then
        ChatLootBidderFrame:HandleSrLoad(commandlist[3])
      elseif commandlist[2] == "unload" then
        ChatLootBidderFrame:HandleSrUnload()
      elseif commandlist[2] == "delete" then
        ChatLootBidderFrame:HandleSrDelete(commandlist[3])
      elseif commandlist[2] == "show" then
        ChatLootBidderFrame:HandleSrShow()
      elseif commandlist[2] == "csv" or commandlist[2] == "json" or commandlist[2] == "semicolon" or commandlist[2] == "raidresfly" then
        ChatLootBidderFrame:HandleEncoding(commandlist[2])
      elseif commandlist[2] == "lock" or commandlist[2] == "unlock" then
        ChatLootBidderFrame:ToggleSrLock(commandlist[2])
      elseif commandlist[2] == "instructions" then
        ChatLootBidderFrame:HandleSrInstructions()
      else
        NS.Error("Unknown 'sr' subcommand: " .. (commandlist[2] == nil and "nil" or commandlist[2]))
        NS.Error("Valid values are: load, unload, delete, show, lock, unlock, json, semicolon, raidresfly, csv, instructions")
      end
    elseif commandlist[1] == "debug" then
      ChatLootBidder_Store.DebugLevel = NS.ToWholeNumber(commandlist[2])
      NS.Message("Debug level set to " .. ChatLootBidder_Store.DebugLevel)
    elseif commandlist[1] == "bid" and commandlist[2] then
      HandleChannel("BidChannel", commandlist[2])
    elseif commandlist[1] == "session" and commandlist[2] then
      HandleChannel("SessionAnnounceChannel", commandlist[2])
    elseif commandlist[1] == "win" and commandlist[2] then
      HandleChannel("WinnerAnnounceChannel", commandlist[2])
    elseif commandlist[1] == "end" then
      ChatLootBidderFrame:End()
    elseif commandlist[1] == "clear" then
      if commandlist[2] == nil then
        ChatLootBidderFrame:Clear()
      elseif NS.stage == nil then
        NS.Error("The stage is empty")
      else
        local itemLinks = NS.GetItemLinks(message)
        for _, item in pairs(itemLinks) do
          ChatLootBidderFrame:Unstage(item)
        end
      end
      ChatLootBidderFrame:RedrawStage()
    elseif commandlist[1] == "stage" then
      local itemLinks = NS.GetItemLinks(message)
      for _, item in pairs(itemLinks) do
        ChatLootBidderFrame:Stage(item)
      end
      ChatLootBidderFrame:RedrawStage()
    elseif commandlist[1] == "summary" then
      NS.BidSummary()
    elseif commandlist[1] == "start" then
      local itemLinks = NS.GetItemLinks(message)
      local optionalTimer = NS.ToWholeNumber(commandlist[getn(commandlist)], -1)
      ChatLootBidderFrame:Start(itemLinks, optionalTimer)
    end
  end
end

local function LoadText()
  local k,v,g
  for k,v in pairs(T) do
    if type(k) == "string" then
      g = getglobal("ChatLootBidderOptionsFrame" .. k .. "Text")
      if g then g:SetText(v) end
    end
  end
end

local function LoadValues()
  local k,v,g,t
  for k,v in pairs(ChatLootBidder_Store) do
    t = type(v)
    g = getglobal("ChatLootBidderOptionsFrame" .. k)
    if g and g.SetChecked and t == "boolean" then
      g:SetChecked(v)
    elseif g and k == "DefaultSessionMode" then
      g:SetValue(v == "MSOS" and 1 or 0)
    elseif g and g.SetValue and (t == "string" or t == "number") then
      g:SetValue(v)
    else
      NS.Trace(k .. " <noGui> " .. tostring(v))
    end
  end
end

function ChatLootBidderFrame:StartSessionButtonShown()
  ChatLootBidderFrame:Show()
  startSessionButton:Show()
  clearSessionButton:Show()
end

function ChatLootBidderFrame:EndSessionButtonShown()
  ChatLootBidderFrame:Show()
  startSessionButton:Hide()
  clearSessionButton:Hide()
  endSessionButton:Show()
  ChatLootBidderFrame:SetHeight(50)
  for i = 1, 8 do
    local stageItem = getglobal(ChatLootBidderFrame:GetName() .. "Item" .. i)
    local unstageButton = getglobal(ChatLootBidderFrame:GetName() .. "UnstageButton" .. i)
    unstageButton:Hide()
    stageItem:SetText("")
    stageItem:Hide()
  end
end

function ChatLootBidderFrame:RedrawStage()
  local i = 1
  for k, count in pairs(NS.stage or {}) do
    if count and count > 0 then
      if i == 9 then NS.Error("You may only stage up to 8 items.  Use /loot clear [itm] to clear specific items or /clear to wipe it clean."); return end
      if not ChatLootBidderFrame:IsVisible() then
        ChatLootBidderFrame:StartSessionButtonShown()
      end
      local stageItem = getglobal(ChatLootBidderFrame:GetName() .. "Item" .. i)
      local unstageButton = getglobal(ChatLootBidderFrame:GetName() .. "UnstageButton" .. i)
      unstageButton:Show()
      stageItem:SetText(k .. (count > 1 and " (x" .. count .. ")" or ""))
      stageItem:Show()
      i = i + 1
    end
  end
  if i == 1 then
    ChatLootBidderFrame:Hide()
  else
    ChatLootBidderFrame:SetHeight(240-(160-i*20))
    for j = i, 8 do
      local stageItem = getglobal(ChatLootBidderFrame:GetName() .. "Item" .. j)
      local unstageButton = getglobal(ChatLootBidderFrame:GetName() .. "UnstageButton" .. j)
      unstageButton:Hide()
      stageItem:SetText("")
      stageItem:Hide()
    end
  end
  getglobal(ChatLootBidderFrame:GetName() .. "HeaderString"):SetText(ChatLootBidder_Store.DefaultSessionMode .. " Mode")
end

function ChatLootBidderFrame:Stage(i, count)
  NS.stage = NS.stage or {}
  if count then
    NS.stage[i] = math.max(NS.stage[i] or 0, count)
  else
    NS.stage[i] = (NS.stage[i] or 0) + 1
  end
end

function ChatLootBidderFrame.CHAT_MSG_SYSTEM(msg)
  if NS.session == nil then return end
  local _, _, name, roll, low, high = string.find(msg, rollRegex)
  if name then
    if tonumber(low) > 1 or tonumber(high) > 100 then return end
    if name == NS.me and tonumber(high) <= 40 then return end
    local existingWhy = ""
    for item,itemSession in pairs(NS.session) do
      local existingRoll = itemSession["roll"][name]
      if existingRoll == -1 or ((1 == getn(NS.GetKeys(NS.session))) and existingRoll == nil) then
        itemSession["roll"][name] = tonumber(roll)
        NS.SendResponse("Your roll of " .. roll .. " been recorded for " .. item, name)
        return
      elseif (existingRoll or 0) > 0 then
        existingWhy = existingWhy .. "Your roll of " .. existingRoll .. " has already been recorded for " .. item .. ". "
      end
    end
    if string.len(existingWhy) > 0 then
      NS.SendResponse("Ignoring your roll of " .. roll .. ". " .. existingWhy, name)
    elseif NS.sessionMode == "DKP" then
      NS.SendResponse("Ignoring your roll of " .. roll .. ". You must first declare that you are rolling on an item first: '/w " .. NS.me .. " [item-link] roll'", name)
    else
      NS.SendResponse("Ignoring your roll of " .. roll .. ". You must bid on an item before rolling on it: '/w " .. NS.me .. " [item-link] ms/os/roll'", name)
    end
  end
end

function ChatLootBidderFrame.ADDON_LOADED(loadedAddonName)
  if loadedAddonName == NS.addonName then
    LoadVariables()
    InitSlashCommands()
    LoadText()
    LoadValues()
    this:UnregisterEvent("ADDON_LOADED")
  end
end

function ChatLootBidderFrame.CHAT_MSG_ADDON(addonTag, stringMessage, channel, sender)
  if VersionUtil:CHAT_MSG_ADDON(NS.addonName, function(ver)
    NS.Message("New version " .. ver .. " of " .. NS.addonTitle .. " is available! Upgrade now at " .. NS.addonNotes)
  end) then return end
end

function ChatLootBidderFrame.PARTY_MEMBERS_CHANGED()
  VersionUtil:PARTY_MEMBERS_CHANGED(NS.addonName)
end

function ChatLootBidderFrame.PLAYER_ENTERING_WORLD()
  VersionUtil:PLAYER_ENTERING_WORLD(NS.addonName)
  if ChatLootBidder_Store.Point and getn(ChatLootBidder_Store.Point) == 4 then
    ChatLootBidderFrame:SetPoint(ChatLootBidder_Store.Point[1], "UIParent", ChatLootBidder_Store.Point[2], ChatLootBidder_Store.Point[3], ChatLootBidder_Store.Point[4])
  end
end

function ChatLootBidderFrame.PLAYER_LEAVING_WORLD()
  local point, _, relativePoint, xOfs, yOfs = ChatLootBidderFrame:GetPoint()
  ChatLootBidder_Store.Point = {point, relativePoint, xOfs, yOfs}
end

function ChatLootBidderFrame.LOOT_OPENED()
  if NS.session ~= nil then return end
  if not ChatLootBidder_Store.AutoStage then return end
  if not NS.IsMasterLooterSet() or not NS.IsRaidAssistant(NS.me) then return end
  local lootCounts = {}
  for i=1, GetNumLootItems() do
    local lootIcon, lootName, lootQuantity, rarity, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)
    if rarity >= ChatLootBidder_Store.MinRarity and rarity <= ChatLootBidder_Store.MaxRarity then
      local link = GetLootSlotLink(i)
      lootCounts[link] = (lootCounts[link] or 0) + 1
    end
  end
  for link, count in pairs(lootCounts) do
    ChatLootBidderFrame:Stage(link, count)
  end
  ChatLootBidderFrame:RedrawStage()
end

function ChatLootBidderFrame:OnVerticalScroll(scrollFrame)
  local offset = scrollFrame:GetVerticalScroll()
  local scrollbar = getglobal(scrollFrame:GetName() .. "ScrollBar")

  scrollbar:SetValue(offset)
  local min, max = scrollbar:GetMinMaxValues()
  local display = false
  if offset == 0 then
    getglobal(scrollbar:GetName() .. "ScrollUpButton"):Disable()
  else
    getglobal(scrollbar:GetName() .. "ScrollUpButton"):Enable()
    display = true
  end
  if (scrollbar:GetValue() - max) == 0 then
    getglobal(scrollbar:GetName() .. "ScrollDownButton"):Disable()
  else
    getglobal(scrollbar:GetName() .. "ScrollDownButton"):Enable()
    display = true
  end
  if display then
    scrollbar:Show()
  else
    scrollbar:Hide()
  end
end

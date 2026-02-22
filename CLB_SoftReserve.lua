local NS = ChatLootBidderNS

function NS.Srs(n)
  local name = n or NS.softReserveSessionName
  local srs = ChatLootBidder_Store.SoftReserveSessions[name]
  if srs ~= nil then return srs end
  ChatLootBidder_Store.SoftReserveSessions[name] = {}
  return ChatLootBidder_Store.SoftReserveSessions[name]
end

function ChatLootBidderFrame:LoadedSoftReserveSession()
  if NS.softReserveSessionName then
    return unpack({NS.softReserveSessionName, ChatLootBidder_Store.SoftReserveSessions[NS.softReserveSessionName]})
  end
  return unpack({nil, nil})
end

function NS.HandleSrRemove(bidder, item)
  local itemName = NS.ParseItemNameFromItemLink(item)
  if NS.Srs()[bidder] == nil then
    NS.Srs()[bidder] = {}
  end
  local sr = NS.Srs()[bidder]
  local i, v
  for i, v in pairs(sr) do
    if v == itemName then
      table.remove(sr, i)
      NS.SendResponse("You are no longer reserving: " .. itemName, bidder)
      return
    end
  end
end

local function craftName(appender)
  return date("%y-%m-%d") .. (appender == 0 and "" or ("-" .. appender))
end

local function AtlasLootLoaded()
  return (AtlasLoot_Data and AtlasLoot_Data["AtlasLootItems"]) ~= nil
end

local function ValidateItemName(n)
  if not ChatLootBidder_Store.ItemValidation or not AtlasLootLoaded() then return unpack({-1, n, -1, "", ""}) end
  for raidBossKey,raidBoss in pairs(AtlasLoot_Data["AtlasLootItems"]) do
    for _,dataSet in pairs(raidBoss) do
      if dataSet then
        local itemNumber, icon, nameQuery, _, dropRate = unpack(dataSet)
        if nameQuery then
          local _start, _end, _quality, _name = string.find(nameQuery, '^=q(%d)=(.-)$')
          if _name and string.lower(_name) == string.lower(n) then
            return unpack({itemNumber, _name, _quality, raidBossKey, dropRate})
          end
        end
      end
    end
  end
  return nil
end

function NS.HandleSrQuery(bidder)
  local sr = NS.Srs(NS.softReserveSessionName)[bidder]
  local msg = "Your Soft Reserve is currently " .. (sr == nil and "not set" or ("[ " .. table.concat(sr, ", ") .. " ]"))
  if NS.softReservesLocked then
    msg = msg .. " LOCKED"
  end
  NS.SendResponse(msg, bidder)
end

local function HandleSrAdd(bidder, itemName)
  itemName = NS.Trim(itemName)
  if NS.Srs(NS.softReserveSessionName)[bidder] == nil then
    NS.Srs(NS.softReserveSessionName)[bidder] = {}
  end
  local sr = NS.Srs(NS.softReserveSessionName)[bidder]
  local itemNumber, nameFix, _quality, raidBoss, dropRate = ValidateItemName(itemName)
  if itemNumber == nil then
    NS.SendResponse(itemName .. " does not appear to be a valid item name (AtlasLoot).  If this is incorrect, the Loot Master will need to manually input the item name or disable item validation.", bidder)
  else
    if nameFix ~= itemName then
      NS.SendResponse(itemName .. " fixed to " .. nameFix, bidder)
      itemName = nameFix
    end
    table.insert(sr, itemName)
    if NS.TableLength(sr) > ChatLootBidder_Store.DefaultMaxSoftReserves then
      local pop = table.remove(sr, 1)
      if not NS.TableContains(sr, pop) then
        NS.SendResponse("You are no longer reserving: " .. pop, bidder)
      end
    end
  end
  ChatLootBidderOptionsFrame_Reload()
end

function ChatLootBidderFrame:HandleSrDelete(providedName)
  if NS.softReserveSessionName == nil and providedName == nil then
    NS.Error("No Soft Reserve session loaded or provided for deletion")
  elseif providedName == nil then
    ChatLootBidder_Store.SoftReserveSessions[NS.softReserveSessionName] = nil
    NS.Message("Deleted currently loaded Soft Reserve session: " .. NS.softReserveSessionName)
    NS.softReserveSessionName = nil
  elseif ChatLootBidder_Store.SoftReserveSessions[providedName] == nil then
    NS.Error("No Soft Reserve session exists with the label: " .. providedName)
  else
    ChatLootBidder_Store.SoftReserveSessions[providedName] = nil
    NS.Message("Deleted Soft Reserve session: " .. providedName)
  end
  if providedName == nil or providedName == NS.softReserveSessionName then
    SrEditFrame:Hide()
  end
end

function ChatLootBidderFrame:HandleSrAddDefault()
  local appender = 0
  while ChatLootBidder_Store.SoftReserveSessions[craftName(appender)] ~= nil do
    appender = appender + 1
  end
  NS.softReserveSessionName = craftName(appender)
  NS.Srs()
  NS.Message("New Soft Reserve list [" .. NS.softReserveSessionName .. "] loaded")
  SrEditFrame:Hide()
  ChatLootBidderOptionsFrame_Init(NS.softReserveSessionName)
end

function ChatLootBidderFrame:HandleSrLoad(providedName)
  if providedName then
    NS.softReserveSessionName = providedName
    local srs = NS.Srs()
    NS.ValidateFixAndWarn(srs)
    NS.Message("Soft Reserve list [" .. NS.softReserveSessionName .. "] loaded with " .. NS.TableLength(srs) .. " players with soft reserves")
    SrEditFrame:Hide()
    ChatLootBidderOptionsFrame_Init(NS.softReserveSessionName)
  else
    ChatLootBidderFrame:HandleSrAddDefault()
  end
end

function ChatLootBidderFrame:HandleSrUnload()
  if NS.softReserveSessionName == nil then
    NS.Error("No Soft Reserve session loaded")
  else
    NS.Message("Unloaded Soft Reserve session: " .. NS.softReserveSessionName)
    NS.softReserveSessionName = nil
  end
  ChatLootBidderOptionsFrame_Reload()
  SrEditFrame:Hide()
end

function ChatLootBidderFrame:HandleSrInstructions()
  NS.MessageStartChannel("Set your SR: /w " .. NS.PlayerWithClassColor(NS.me) .. " sr [item-link or exact-item-name]")
  NS.MessageStartChannel("Get your current SR: /w " .. NS.PlayerWithClassColor(NS.me) .. " sr")
  NS.MessageStartChannel("Clear your current SR: /w " .. NS.PlayerWithClassColor(NS.me) .. " sr clear")
end

function ChatLootBidderFrame:HandleSrShow()
  if NS.softReserveSessionName == nil then
    NS.Error("No Soft Reserve session loaded")
  else
    local srs = NS.Srs()
    if NS.IsTableEmpty(srs) then
      NS.Error("No Soft Reserves placed yet")
      return
    end
    NS.MessageStartChannel("Soft Reserve Bids:")
    local keys = NS.GetKeys(srs)
    table.sort(keys)
    local player
    for _, player in pairs(keys) do
      local sr = srs[player]
      if not NS.IsTableEmpty(sr) then
        local msg = NS.PlayerWithClassColor(player) .. ": " .. table.concat(sr, ", ")
        if NS.IsInRaid(player) then
          NS.MessageStartChannel(msg)
        else
          NS.Message(msg)
        end
      end
    end
  end
end

local function EncodeSemicolon()
  local encoded = ""
  for k,v in pairs(NS.Srs()) do
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
  local flat = NS.Flatten(NS.Srs())
  for _,arr in pairs(flat) do
    encoded = (encoded or "") .. "[00:00]" .. arr[1] .. ": " .. arr[1] .. " - " .. arr[2] .. "\n"
  end
  return encoded
end

local function PrettyPrintJson(encoded)
  if encoded == "[]" then return "{}" end
  encoded = string.gsub(encoded, "{", "{\n")
  encoded = string.gsub(encoded, "}", "\n}")
  encoded = string.gsub(encoded, "],", "],\n")
  return encoded
end

function ChatLootBidderFrame:HandleEncoding(encodingType)
  if NS.softReserveSessionName == nil then
    NS.Error("No Soft Reserve list is loaded")
  else
    local encoded
    if encodingType == "csv" then
      encoded = csv:toCSV(NS.Flatten(NS.Srs()))
    elseif encodingType == "json" then
      encoded = PrettyPrintJson(json.encode(NS.Srs()))
    elseif encodingType == "semicolon" then
      encoded = EncodeSemicolon()
    elseif encodingType == "raidresfly" then
      encoded = EncodeRaidResFly()
    end
    if not SrEditFrame:IsVisible() then
      SrEditFrame:Show()
    elseif SrEditFrameHeaderString:GetText() == encodingType then
      SrEditFrame:Hide()
    end
    SrEditFrameText:SetText(encoded)
    SrEditFrameHeaderString:SetText(encodingType)
  end
end

function ChatLootBidderFrame:ToggleSrLock(command)
  if NS.softReserveSessionName == nil then
    NS.Error("No Soft Reserve session loaded")
  else
    if command then
      NS.softReservesLocked = command == "lock"
    else
      NS.softReservesLocked = not NS.softReservesLocked
    end
    NS.MessageStartChannel("Soft Reserves for " .. NS.softReserveSessionName .. " are now " .. (NS.softReservesLocked and "LOCKED" or "UNLOCKED"))
  end
end

function ChatLootBidderFrame:IsLocked()
  return NS.softReservesLocked
end

local function ParseRaidResFly(text)
  local line, t = nil, {}
  for line in NS.gfind(text, '([^\n]+)') do
    local _, _, name, item = string.find(line, "^.-: ([%a]-) . (.-)$")
    name = NS.Trim(name)
    item = NS.Trim(item)
    if t[name] == nil then t[name] = {} end
    table.insert(t[name], item)
  end
  return t
end

local function ParseSemicolon(text)
  local t, line, part, k, v = {}, nil, nil, nil, {}
  for line in NS.gfind(text, '([^\n]+)') do
    for part in NS.gfind(line, '([^;]+)') do
      if k == nil then
        k = NS.Trim(part)
      else
        local sr = NS.Trim(part)
        table.insert(v, sr)
      end
    end
    t[k] = v
    k = nil
    v = {}
  end
  return t
end

function NS.ValidateFixAndWarn(t)
  local k,k2,v,i,len
  for k,v in pairs(t) do
    len = getn(v)
    if len > ChatLootBidder_Store.DefaultMaxSoftReserves then
      NS.Error(k .. " has " .. len .. " soft reserves loaded (max=" .. ChatLootBidder_Store.DefaultMaxSoftReserves .. ")")
    end
    for k2,i in pairs(v) do
      local itemNumber, nameFix, _, _, _ = ValidateItemName(i)
      if itemNumber == nil then
        NS.Error(i .. " does not appear to be a valid item name (AtlasLoot)")
      elseif nameFix ~= i then
        NS.Message(i .. " fixed to " .. nameFix)
        v[k2] = nameFix
      end
    end
  end
end

function ChatLootBidderFrame:DecodeAndSave(text, parent)
  local encoding = SrEditFrameHeaderString:GetText()
  local t
  if encoding == "json" then
    t = json.decode(text)
  elseif encoding == "csv" then
    t = NS.UnFlatten(csv:fromCSV(text))
  elseif encoding == "raidresfly" then
    t = ParseRaidResFly(text)
  elseif encoding == "semicolon" then
    t = ParseSemicolon(text)
  else
    NS.Error("No encoding provided")
    return
  end
  NS.ValidateFixAndWarn(t)
  ChatLootBidder_Store.SoftReserveSessions[NS.softReserveSessionName] = t
  ChatLootBidderOptionsFrame_Reload()
  parent:Hide()
end

function NS.HandleSrWhisper(bidder, commandlist, items, item)
  if not NS.IsInRaid(bidder) then
    NS.SendResponse("You must be in the raid to place a Soft Reserve", bidder)
    return
  end
  local isLocked = NS.softReservesLocked or SrEditFrame:IsVisible()
  if NS.TableLength(commandlist) == 1 or isLocked then
  elseif commandlist[2] == "clear" or commandlist[2] == "delete" or commandlist[2] == "remove" then
    NS.Srs(NS.softReserveSessionName)[bidder] = nil
  elseif item ~= nil then
    local _i
    for _,_i in pairs(items) do
      HandleSrAdd(bidder, NS.ParseItemNameFromItemLink(_i))
    end
  else
    table.remove(commandlist, 1)
    HandleSrAdd(bidder, table.concat(commandlist, " "))
  end
  NS.HandleSrQuery(bidder)
end

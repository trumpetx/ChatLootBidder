ChatLootBidderNS = ChatLootBidderNS or {}
local NS = ChatLootBidderNS

NS.session = nil
NS.sessionMode = nil
NS.stage = nil
NS.softReserveSessionName = nil
NS.softReservesLocked = false
NS.lastWhisper = nil

NS.gfind = string.gmatch or string.gfind

NS.addonName = "ChatLootBidder"
NS.addonTitle = GetAddOnMetadata(NS.addonName, "Title")
NS.addonNotes = GetAddOnMetadata(NS.addonName, "Notes")
NS.addonVersion = GetAddOnMetadata(NS.addonName, "Version")
NS.addonAuthor = GetAddOnMetadata(NS.addonName, "Author")
NS.chatPrefix = "<CL> "
NS.me = UnitName("player")

function NS.Roll()
  return math.random(1, 100)
end

function NS.DefaultFalse(prop)
  return prop == true
end

function NS.DefaultTrue(prop)
  return prop == nil or NS.DefaultFalse(prop)
end

function NS.Trim(str)
  local _start, _end, _match = string.find(str, '^%s*(.-)%s*$')
  return _match or ""
end

function NS.ToWholeNumber(numberString, default)
  if default == nil then default = 0 end
  if numberString == nil then return default end
  local num = math.floor(tonumber(numberString) or default)
  if default == num then return default end
  return math.max(num, default)
end

function NS.GetRaidIndex(unitName)
  if UnitInRaid("player") == 1 then
     for i = 1, GetNumRaidMembers() do
        if UnitName("raid"..i) == unitName then
           return i
        end
     end
  end
  return 0
end

function NS.IsInRaid(unitName)
  return NS.GetRaidIndex(unitName) ~= 0
end

function NS.IsRaidAssistant(unitName)
  _, rank = GetRaidRosterInfo(NS.GetRaidIndex(unitName))
  return rank ~= 0
end

function NS.GetPlayerClass(unitName)
  _, _, _, _, _, playerClass = GetRaidRosterInfo(NS.GetRaidIndex(unitName))
  return playerClass
end

function NS.IsMasterLooterSet()
  local method, _ = GetLootMethod()
  return method == "master"
end

function NS.IsStaticChannel(channel)
  channel = channel == nil and nil or string.upper(channel)
  return channel == "RAID" or channel == "RAID_WARNING" or channel == "SAY" or channel == "EMOTE" or channel == "PARTY" or channel == "GUILD" or channel == "OFFICER" or channel == "YELL"
end

function NS.IsTableEmpty(tbl)
  if tbl == nil then return true end
  local next = next
  return next(tbl) == nil
end

function NS.Flatten(tbl)
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

function NS.UnFlatten(tbl)
  if tbl == nil then return {} end
  local unflattened = {}
  local arr
  for _, arr in pairs(tbl) do
    local key = NS.Trim(arr[1])
    if unflattened[key] == nil then unflattened[key] = {} end
    if arr[2] ~= nil then
      table.insert(unflattened[key], NS.Trim(arr[2]))
    end
  end
  return unflattened
end

function NS.TableContains(tbl, element)
  local value
  for _,value in pairs(tbl) do
    if value == element then
      return true
    end
  end
  return false
end

function NS.ParseItemNameFromItemLink(i)
  local _, _ , n = string.find(i, "\124h%[(.-)%]\124h")
  return n
end

function NS.TableLength(tbl)
  if tbl == nil then return 0 end
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

function NS.SplitBySpace(str)
  local commandlist = { }
  local command
  for command in NS.gfind(str, "[^ ]+") do
    table.insert(commandlist, command)
  end
  return commandlist
end

function NS.GetKeysWhere(tbl, fn)
  if tbl == nil then return {} end
  local keys = {}
  for key,value in pairs(tbl) do
    if fn == nil or fn(key, value) then
      table.insert(keys, key)
    end
  end
  return keys
end

function NS.GetKeys(tbl)
  return NS.GetKeysWhere(tbl)
end

function NS.GetKeysSortedByValue(tbl)
  local keys = NS.GetKeys(tbl)
  table.sort(keys, function(a, b)
    return tbl[a] > tbl[b]
  end)
  return keys
end

function NS.GetItemLinks(str)
  local itemLinks = {}
  local _start, _end, _lastEnd = nil, -1, -1
  while true do
    _start, _end = string.find(str, "\124c.-\124H.-\124h.-\124h\124r", _end + 1)
    if _start == nil then
      return itemLinks, _lastEnd
    end
    _lastEnd = _end
    table.insert(itemLinks, string.sub(str, _start, _end))
  end
end

function NS.IsValidTier(tier)
  return tier == "ms" or tier == "os" or tier == "roll" or tier == "cancel"
end

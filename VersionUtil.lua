VERSION_UTIL_VERSION = 1

if VersionUtil and (VersionUtil.version >= VERSION_UTIL_VERSION) then return end
VersionUtil = {}
VersionUtil.version = VERSION_UTIL_VERSION
VersionUtil.loginchannels = { "BATTLEGROUND", "RAID", "PARTY", "GUILD" }
VersionUtil.groupchannels = { "BATTLEGROUND", "RAID", "PARTY" }
VersionUtil.debug = false
VersionUtil.upgradeMessageShown = {}
VersionUtil.addonVersions = {}
VersionUtil.groupSize = {}
VersionUtil.me = UnitName("player")
local gfind = string.gmatch or string.gfind
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local GetAddOnMetadata = GetAddOnMetadata
local SendAddonMessage = SendAddonMessage

local function SendVersionMessage(addonName, channel, addonVersion)
	local msg = "sender=" .. VersionUtil.me .. ",version=" .. addonVersion -- TODO: remove sender, is unsed once we get everyone to upgrade
	if VersionUtil.debug then print("Sending: [" .. msg .. "] to " .. channel) end
  if ChatThrottleLib then
    ChatThrottleLib:SendAddonMessage("BULK", addonName, msg, channel)
  else
    SendAddonMessage(addonName, msg, channel)
  end
end

---pfUI.api.strsplit
local function strsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local function SemverCompare(ver1, ver2)
	local major, minor, fix, patch = strsplit(".", ver1)
	local ver1Num = tonumber((major or 0)*1000000 + (minor or 0)*10000 + (fix or 0)*100 + (patch or 0))
	major, minor, fix, patch = strsplit(".", ver2)
	local ver2Num = tonumber((major or 0)*1000000 + (minor or 0)*10000 + (fix or 0)*100 + (patch or 0))
	return ver1Num - ver2Num
end

local function GetAddonVersion(addonName)
  if addonName == nil then return nil end
  local addonVersion = VersionUtil.addonVersions[addonName]
  if addonVersion ~= nil then return addonVersion end
  addonVersion = GetAddOnMetadata(addonName, "Version")
  VersionUtil.addonVersions[addonName] = addonVersion
  return addonVersion
end

--- Parse a string message into a Table.
-- Commas and equal signs are not escaped
-- @param message a comma separated key value pair list with equal signs separating the keys and values
-- @return a Table with the parsed KVPs from the message
function VersionUtil:ParseMessage(message)
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

---
-- @param addonName required, should match the same name used for other handlers
-- @param groupChannels an optional Table array of string channels to send messages to [default: { "BATTLEGROUND", "RAID", "PARTY", "GUILD" }]
function VersionUtil:PARTY_MEMBERS_CHANGED(addonName, groupChannels)
  local addonVersion = GetAddonVersion(addonName)
  if addonVersion == nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000 Your Add-On needs to provide the Addon Name which corresponds with the .toc file name (ADDONNAME.toc) for VersionUtil:PARTY_MEMBERS_CHANGED(addonName)")
    return
  end
  local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
  if (VersionUtil.groupSize[addonName] or 0) < groupsize then
    for _, chan in pairs(groupChannels or VersionUtil.groupchannels) do
      SendVersionMessage(addonName, chan, addonVersion)
    end
  end
  VersionUtil.groupSize[addonName] = groupSize
end

---
-- @param addonName required, should match the same name used for other handlers
-- @param loginChannels an optional Table array of string channels to send messages to ( default: { "BATTLEGROUND", "RAID", "PARTY" } )
function VersionUtil:PLAYER_ENTERING_WORLD(addonName, loginChannels)
  local addonVersion = GetAddonVersion(addonName)
  if addonVersion == nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000 Your Add-On needs to provide the Addon Name which corresponds with the .toc file name (ADDONNAME.toc) for VersionUtil:PLAYER_ENTERING_WORLD(addonName)")
    return
  end
  for _, chan in pairs(loginChannels or VersionUtil.loginchannels) do
    SendVersionMessage(addonName, chan, addonVersion)
  end
end

---
-- @param addonName required, should match the same name used for other handlers
-- @param upgradeMessageFunction an optional function(newVersion) to be called if an upgrade is detected [default: function(ver) DEFAULT_CHAT_FRAME:AddMessage("New version " .. ver .. " of " .. addonName .. " is available!") end]
-- @param stringMessage an optional override of the comma separated key value pair list with equal signs separating the keys and values [default: arg2 global value]
-- @param sender an optional override of the sender of the message [default: arg4 global value]
-- @return true if the message is a version message and it was handled; false if it was not a version message or was not handled
function VersionUtil:CHAT_MSG_ADDON(addonName, upgradeMessageFunction, stringMessage, sender)
  if arg1 ~= addonName then return false end -- arg1 is global of the 'tag' sent by the addon
  if stringMessage == nil then stringMessage = arg2 end -- arg2 is the global of the message received
  if sender == nil then sender = arg4 end -- arg4 is the sender of the message
  local addonVersion = GetAddonVersion(addonName)
  if addonVersion == nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000 Your Add-On needs to provide the Addon Name which corresponds with the .toc file name (ADDONNAME.toc) for VersionUtil:CHAT_MSG_ADDON(addonName, message)")
    return false
  end
  local message = VersionUtil:ParseMessage(stringMessage)
  if message["version"] == nil then return false end -- This is not a version message
  if sender == VersionUtil.me then return true end -- Ignore my own sends
  if SemverCompare(message["version"], addonVersion) <= 0 then
    if VersionUtil.debug then print(sender .. " has version " .. message["version"]) end
    return true
  end
  if VersionUtil.debug then print("I have version " .. addonVersion .. " and " .. sender .. " has version " .. message["version"]) end
  if not VersionUtil.upgradeMessageShown[addonName] then
    if upgradeMessageFunction == nil then
      upgradeMessageFunction = function(ver) DEFAULT_CHAT_FRAME:AddMessage("New version " .. ver .. " of " .. addonName .. " is available!") end
    end
    upgradeMessageFunction(message["version"])
    VersionUtil.upgradeMessageShown[addonName] = true
  end
  return true
end

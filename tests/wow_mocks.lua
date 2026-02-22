-- Minimal WoW API mocks so addon Lua can load outside the game.
-- Only stubs used at load time or by code under test.

local function stub_frame(name)
  local f = {
    _name = name or "StubFrame",
    GetName = function(self) return self._name end,
    SetScript = function() end,
    SetPoint = function() end,
    GetPoint = function() return "TOP", "UIParent", "CENTER", 0, 0 end,
    Hide = function() end,
    Show = function() end,
    SetHeight = function() end,
    IsVisible = function() return false end,
    SetText = function() end,
    SetValue = function() end,
    SetChecked = function() end,
    Disable = function() end,
    Enable = function() end,
    RegisterEvent = function() end,
    UnregisterEvent = function() end,
  }
  return f
end

-- Lua 5.1: getn was removed; WoW and some addons still use it.
if not getn then
  getn = function(t) return #t end
end

-- WoW strlen (same as string.len)
if not strlen then
  strlen = function(s) return string.len(s) end
end

min = math.min
max = math.max
tinsert = table.insert
tremove = table.remove
format = string.format

function GetFramerate() return 60 end
function date(fmt) return os.date(fmt) end

-- getglobal: return a stub frame for any name (addon uses dynamic names).
function getglobal(name)
  if _G[name] then return _G[name] end
  local stub = stub_frame(name)
  _G[name] = stub
  return stub
end

-- CreateFrame: return stub; ChatThrottleLib and XML-created frames use it.
function CreateFrame(frameType, name, parent)
  local f = stub_frame(name or "Unnamed")
  if name then _G[name] = f end
  return f
end

-- Frames that exist before addon load (created by XML in-game; we create stubs).
ChatLootBidderFrame = stub_frame("ChatLootBidderFrame")
ChatLootBidderOptionsFrame = stub_frame("ChatLootBidderOptionsFrame")
SrEditFrame = stub_frame("SrEditFrame")
SrEditFrameHeaderString = stub_frame("SrEditFrameHeaderString")
SrEditFrameText = stub_frame("SrEditFrameText")
UIParent = stub_frame("UIParent")

-- Options.lua functions (defined in XML/Options.lua, not loaded in tests)
function ChatLootBidderOptionsFrame_Init(name) end
function ChatLootBidderOptionsFrame_Reload() end

-- TOC metadata
function GetAddOnMetadata(addonName, key)
  if addonName ~= "ChatLootBidder" then return nil end
  local meta = { Title = "Chat Loot Bidder", Notes = "Loot bidding", Version = "1.11.2", Author = "TrumpetX" }
  return meta[key]
end

function UnitName(unit) return "TestPlayer" end
function GetLocale() return "enUS" end

-- Chat: addon prints here; we capture if tests need to assert.
TestChatLog = {}
function ClearChatLog()
  TestChatLog = {}
end

DEFAULT_CHAT_FRAME = { 
  AddMessage = function(self, msg) 
    table.insert(TestChatLog, { type = "DEFAULT", msg = msg })
  end 
}

-- ChatFrame_OnEvent: addon saves and replaces this.
function ChatFrame_OnEvent(event) end

-- VersionUtil / raid
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function SendAddonMessage(prefix, msg, kind) end
function SendAddOnMessage(prefix, msg, kind) end
SendAddonMessage = SendAddonMessage or SendAddOnMessage
function SendChatMessage(text, chatType, lang, dest)
  table.insert(TestChatLog, { type = chatType, msg = text, dest = dest })
end
function GetTime() return os.clock() end

-- ChatThrottleLib stub: bypass throttle/queue, just deliver messages directly.
ChatThrottleLib = {
  SendChatMessage = function(self, prio, prefix, text, chattype, language, destination)
    SendChatMessage(text, chattype, language, destination)
  end,
  SendAddonMessage = function(self, prio, prefix, text, chattype)
    SendAddonMessage(prefix, text, chattype)
  end,
}

-- Raid roster (addon may call these)
function UnitInRaid(unit) return nil end
function GetRaidRosterInfo(index) return nil, 0, nil, nil, nil, nil end
function GetLootMethod() return "free", nil end
function GetChannelName(channel) return 0 end

-- Optional AtlasLoot
function AtlasLootLoaded() return false end

-- Slash commands (InitSlashCommands sets these)
SlashCmdList = SlashCmdList or {}

-- RANDOM_ROLL_RESULT: set by addon if nil; we leave nil so addon sets it.

function dump_log()
  local out = ""
  for _, entry in ipairs(TestChatLog) do
    out = out .. "[" .. tostring(entry.type) .. "] " .. (entry.dest and ("(" .. entry.dest .. ") ") or "") .. tostring(entry.msg) .. "\n"
  end
  return out
end

function assert_log_contains(text)
  for _, entry in ipairs(TestChatLog) do
    if entry.msg and string.find(entry.msg, text, 1, true) then
      return true
    end
  end
  error("Expected chat to contain: " .. text .. "\n\nActual Log:\n" .. dump_log())
end

function assert_log_not_contains(text)
  for _, entry in ipairs(TestChatLog) do
    if entry.msg and string.find(entry.msg, text, 1, true) then
      error("Expected chat NOT to contain: " .. text .. "\n\nActual Log:\n" .. dump_log())
    end
  end
end

function ResetWhisperDedup()
  arg1 = "__reset_" .. GetTime() .. "__"
  arg2 = "__reset__"
  ChatFrame_OnEvent("CHAT_MSG_WHISPER")
end

function SendWhisper(sender, text)
  arg1 = text
  arg2 = sender
  ChatFrame_OnEvent("CHAT_MSG_WHISPER")
end

function SimulateRoll(player, rollValue)
  ChatLootBidderFrame.CHAT_MSG_SYSTEM(player .. " rolls " .. rollValue .. " (1-100)")
end

function SetUpRaidMocks(roster)
  UnitName = function(unit)
    if unit == "player" then return "TestPlayer" end
    local idx = tonumber(string.match(unit, "^raid(%d+)$"))
    if idx and roster[idx] then return roster[idx].name end
    return nil
  end
  GetNumRaidMembers = function() return #roster end
  UnitInRaid = function(unit) return 1 end
  GetRaidRosterInfo = function(index)
    local p = roster[index]
    if p then return p.name, p.rank, 1, 1, 1, p.class end
    return nil
  end
  GetLootMethod = function() return "master", 0 end
end

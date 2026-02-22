-- Minimal test runner: loads WoW mocks, addon, then all *_test.lua files.
-- Run from addon root: lua tests/test_runner.lua

local tests_dir = "tests"
local addon_root = "."

-- 1. Load WoW API mocks (defines globals)
dofile(tests_dir .. "/wow_mocks.lua")

-- 2. Load addon Lua files in TOC order (skip XML)
local toc_files = {
  -- ChatThrottleLib.lua is stubbed in wow_mocks.lua
  "VersionUtil.lua",
  "csv.lua",
  "json.lua",
  "i18n.lua",
  "ChatLootBidder.lua",
}
for _, name in ipairs(toc_files) do
  dofile(addon_root .. "/" .. name)
end

-- Fire ADDON_LOADED so addon initializes (LoadVariables, InitSlashCommands, etc.)
this = ChatLootBidderFrame
ChatLootBidderFrame.ADDON_LOADED("ChatLootBidder")

-- 3. Run all *_test.lua files
_passed, _failed = 0, 0
function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    _passed = _passed + 1
    io.write("  PASS " .. name .. "\n")
  else
    _failed = _failed + 1
    io.stderr:write("  FAIL " .. name .. "\n")
    io.stderr:write("    " .. tostring(err) .. "\n")
  end
end

local test_files = {
  tests_dir .. "/chat_loot_bidder_test.lua",
  tests_dir .. "/session_functional_test.lua",
}

for _, path in ipairs(test_files) do
  io.write("Running " .. path:match("([^/\\]+)$") .. "\n")
  dofile(path)
end

io.write("\n" .. _passed .. " passed, " .. _failed .. " failed\n")
if _failed > 0 then os.exit(1) end

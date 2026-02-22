-- Tests for VersionUtil parsing and version comparisons via CHAT_MSG_ADDON behavior.

test("parse_message_kvp", function()
  local msg = VersionUtil:ParseMessage("sender=PlayerA,version=1.2.3,extra=ok")
  assert(msg["sender"] == "PlayerA", "Expected sender field")
  assert(msg["version"] == "1.2.3", "Expected version field")
  assert(msg["extra"] == "ok", "Expected extra field")
end)

test("semver_compare_newer", function()
  local upgradedTo = nil
  VersionUtil.upgradeMessageShown = {}
  arg1 = "ChatLootBidder"

  local handled = VersionUtil:CHAT_MSG_ADDON(
    "ChatLootBidder",
    function(ver) upgradedTo = ver end,
    "sender=PlayerA,version=2.0.0",
    "PlayerA"
  )

  assert(handled == true, "Expected newer version message to be handled")
  assert(upgradedTo == "2.0.0", "Expected upgrade callback for newer version")
end)

test("semver_compare_older", function()
  local upgradedTo = nil
  VersionUtil.upgradeMessageShown = {}
  arg1 = "ChatLootBidder"

  local handled = VersionUtil:CHAT_MSG_ADDON(
    "ChatLootBidder",
    function(ver) upgradedTo = ver end,
    "sender=PlayerA,version=1.0.0",
    "PlayerA"
  )

  assert(handled == true, "Expected older version message to be handled")
  assert(upgradedTo == nil, "Expected no upgrade callback for older version")
end)

test("semver_compare_equal", function()
  local upgradedTo = nil
  VersionUtil.upgradeMessageShown = {}
  arg1 = "ChatLootBidder"

  local handled = VersionUtil:CHAT_MSG_ADDON(
    "ChatLootBidder",
    function(ver) upgradedTo = ver end,
    "sender=PlayerA,version=1.11.2",
    "PlayerA"
  )

  assert(handled == true, "Expected equal version message to be handled")
  assert(upgradedTo == nil, "Expected no upgrade callback for equal version")
end)

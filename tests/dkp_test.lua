-- Tests for FEATURES.md section 6 (DKP Penalties).

test("dkp_highest_ms_wins", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 100")
  SendWhisper("PlayerB", TestItemLink .. " os 250")
  SendWhisper("PlayerC", TestItemLink .. " ms 150")
  CLB("end")

  assert_log_contains("PlayerC wins " .. TestItemLink .. " with a MS bid of 150")
end)

test("dkp_alt_penalty", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.AltPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms 100 alt")
  SendWhisper("PlayerB", TestItemLink .. " ms 60")
  CLB("end")

  assert_log_contains("PlayerB wins " .. TestItemLink .. " with a MS bid of 60")
end)

test("dkp_os_only_displays_as_os", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " os 100")
  CLB("end")

  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a OS bid of 100")
end)

test("dkp_offspec_penalty_wins_over_ms", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " os 200")
  SendWhisper("PlayerB", TestItemLink .. " ms 80")
  CLB("end")

  -- PlayerA OS 200 with 50% penalty -> effective MS 100, beats PlayerB's 80
  -- Natural MS bid exists so winner displays as MS with effective(actual)
  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a MS bid of 100(200)")
end)

test("dkp_combined_alt_and_offspec_penalty", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.DefaultSessionMode = "DKP"
  ChatLootBidder_Store.AltPenalty = 50
  ChatLootBidder_Store.OffspecPenalty = 50

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " os 400 alt")
  SendWhisper("PlayerB", TestItemLink .. " ms 80")
  CLB("end")

  -- PlayerA: OS 400, alt penalty 50% -> 200, offspec penalty 50% -> MS 100
  -- Beats PlayerB's MS 80; real bid was 400
  assert_log_contains("PlayerA wins " .. TestItemLink .. " with a MS bid of 100(400)")
end)

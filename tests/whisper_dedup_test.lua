-- Tests for FEATURES.md section 16 (Anti-Spam and Deduplication).

test("duplicate_whisper_ignored", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerA", TestItemLink .. " ms")
  CLB("end")

  -- If dedup failed, second whisper would trigger "already have a MS bid"
  assert_log_not_contains("You already have a MS bid")
  assert_log_contains("PlayerA wins " .. TestItemLink .. " for MS")
end)

test("same_whisper_different_sender_not_filtered", function()
  SetUpTestEnvironment()

  CLB("start " .. TestItemLink)
  SendWhisper("PlayerA", TestItemLink .. " ms")
  SendWhisper("PlayerB", TestItemLink .. " ms")
  CLB("end")

  -- Both bids processed: identical text but different senders triggers roll-off
  assert_log_contains("rolling it off")
end)

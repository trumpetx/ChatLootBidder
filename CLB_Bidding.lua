local NS = ChatLootBidderNS

ChatLootBidder_ChatFrame_OnEvent = ChatFrame_OnEvent

local function RollOff(candidates, targetCount, roll, item, breakTies)
  if getn(candidates) <= targetCount then return candidates end
  while getn(candidates) > targetCount and breakTies do
    local winningRoll = 0
    for _,bidder in ipairs(candidates) do
      local r = roll[bidder]
      if r == -1 or r == nil then
        r = NS.Roll()
        roll[bidder] = r
        NS.MessageWinnerChannel(NS.PlayerWithClassColor(bidder) .. " rolls " .. r .. " (1-100) for " .. item)
      else
        NS.MessageWinnerChannel(NS.PlayerWithClassColor(bidder) .. " already rolled " .. r .. " (1-100) for " .. item)
      end
      if winningRoll < r then winningRoll = r end
    end
    local newCandidates = {}
    for _,bidder in ipairs(candidates) do
      if roll[bidder] == winningRoll then
        table.insert(newCandidates, bidder)
      end
      roll[bidder] = -1
    end
    candidates = newCandidates
  end
  if getn(candidates) > targetCount then
    local capped = {}
    for idx = 1, targetCount do
      table.insert(capped, candidates[idx])
    end
    return capped
  end
  return candidates
end

local function ResolvePendingRolls(itemSession, item, announceWinners, needsRoll)
  if not announceWinners then return end
  local roll = itemSession["roll"] or {}
  for bidder,r in pairs(roll) do
    if r == -1 then
      r = NS.Roll()
      roll[bidder] = r
      if NS.TableLength(roll) > 1 and needsRoll and not ChatLootBidder_Store.RollAnnounce then
        NS.SendResponse("You roll " .. r .. " (1-100) for " .. item, bidder)
      end
    end
  end
end

local function BuildSrSection(item, itemSession, summary, announceWinners, breakTies)
  local sr = itemSession["sr"] or {}
  local roll = itemSession["roll"] or {}
  local srWinners = {}
  local bidCopies = itemSession["bidCopies"] or 1
  local srCopies = (itemSession["count"] or 1) - bidCopies
  local header = true
  if not NS.IsTableEmpty(sr) then
    local sortedSrKeys = NS.GetKeysSortedByValue(sr)
    for _,bidder in ipairs(sortedSrKeys) do
      if NS.IsTableEmpty(summary) then table.insert(summary, item) end
      if header then table.insert(summary, "- Soft Reserve:"); header = false end
      table.insert(summary, "-- " .. NS.PlayerWithClassColor(bidder) .. ": " .. sr[bidder])
    end
    if announceWinners then
      local srTarget = math.min(srCopies, getn(sortedSrKeys))
      if getn(sortedSrKeys) > srTarget then
        NS.MessageWinnerChannel(NS.PlayersWithClassColors(sortedSrKeys) .. " SR'd " .. item .. ", rolling it off for " .. srTarget .. (srTarget == 1 and " copy:" or " copies:"))
        srWinners = RollOff(sortedSrKeys, srTarget, roll, item, breakTies)
      else
        srWinners = sortedSrKeys
      end
      for _,w in ipairs(srWinners) do
        NS.MessageWinnerChannel(NS.PlayerWithClassColor(w) .. " wins " .. item .. " for SR")
        if ChatLootBidder_Store.AutoRemoveSrAfterWin then
          NS.HandleSrRemove(w, item)
        end
      end
    end
  end
  return srWinners
end

local function BuildBidSections(item, itemSession, summary, announceWinners, needsRoll)
  local ms = itemSession["ms"] or {}
  local ofs = itemSession["os"] or {}
  local roll = itemSession["roll"] or {}
  local sr = itemSession["sr"] or {}
  local cancel = itemSession["cancel"] or {}
  local notes = itemSession["notes"] or {}
  local real = itemSession["real"] or {}

  local header = true
  local msBidders = {}
  if not NS.IsTableEmpty(ms) then
    local sortedMsKeys = NS.GetKeysSortedByValue(ms)
    for _,bidder in ipairs(sortedMsKeys) do
      if cancel[bidder] == nil then
        if NS.IsTableEmpty(summary) then table.insert(summary, item) end
        if header then table.insert(summary, "- Main Spec:"); header = false end
        local bid = ms[bidder]
        if not (itemSession["ms_origin"] and itemSession["ms_origin"][bidder] == "os") then
          table.insert(summary, "-- " .. NS.PlayerWithClassColor(bidder) .. ": " .. NS.realAmt(bid, real[bidder]) .. NS.AppendNote(notes[bidder]))
        end
        table.insert(msBidders, { bidder = bidder, bid = bid })
      end
    end
  end

  header = true
  local osBidders = {}
  if not NS.IsTableEmpty(ofs) then
    local sortedOsKeys = NS.GetKeysSortedByValue(ofs)
    for _,bidder in ipairs(sortedOsKeys) do
      if cancel[bidder] == nil and (ms[bidder] == nil or (itemSession["ms_origin"] and itemSession["ms_origin"][bidder] == "os")) then
        if NS.IsTableEmpty(summary) then table.insert(summary, item) end
        if header then table.insert(summary, "- Off Spec:"); header = false end
        table.insert(summary, "-- " .. NS.PlayerWithClassColor(bidder) .. ": " .. NS.realAmt(ofs[bidder], real[bidder]) .. NS.AppendNote(notes[bidder]))
        if ms[bidder] == nil then
          table.insert(osBidders, { bidder = bidder, bid = ofs[bidder] })
        end
      end
    end
  end

  header = true
  local rollBidders = {}
  if not NS.IsTableEmpty(roll) then
    local sortedRollKeys = NS.GetKeysSortedByValue(roll)
    local announceRollString = ""
    for _,bidder in ipairs(sortedRollKeys) do
      if cancel[bidder] == nil and ms[bidder] == nil and ofs[bidder] == nil and sr[bidder] == nil then
        if NS.IsTableEmpty(summary) then table.insert(summary, item) end
        if header then table.insert(summary, "- Rolls:"); header = false end
        table.insert(summary, "-- " .. NS.PlayerWithClassColor(bidder) .. ": " .. roll[bidder] .. NS.AppendNote(notes[bidder]))
        table.insert(rollBidders, { bidder = bidder, bid = roll[bidder] })
        if announceWinners and needsRoll and ChatLootBidder_Store.RollAnnounce then
          if string.len(announceRollString) > 200 then
            NS.MessageStartChannel(announceRollString)
            announceRollString = NS.PlayerWithClassColor(bidder) .. "(" .. roll[bidder] .. ")"
          elseif string.len(announceRollString) == 0 then
            announceRollString = "Rolls for " .. item .. " (1-100): " .. NS.PlayerWithClassColor(bidder) .. "(" .. roll[bidder] .. ")"
          else
            announceRollString = announceRollString .. ", " .. NS.PlayerWithClassColor(bidder) .. "(" .. roll[bidder] .. ")"
          end
        end
      end
    end
    if getn(sortedRollKeys) > 1 and string.len(announceRollString) > 0 then
      NS.MessageStartChannel(announceRollString)
    end
  end

  return msBidders, osBidders, rollBidders
end

local function ResolveTierWinners(item, tiers, remaining, roll, breakTies)
  local winners = {}
  for _, tierInfo in ipairs(tiers) do
    if remaining <= 0 then break end
    local groups = {}
    local currentGroup = nil
    local currentBid = nil
    for _, entry in ipairs(tierInfo.bidders) do
      if currentBid ~= entry.bid then
        currentGroup = {}
        currentBid = entry.bid
        table.insert(groups, { bid = currentBid, members = currentGroup })
      end
      table.insert(currentGroup, entry.bidder)
    end
    for _, group in ipairs(groups) do
      if remaining <= 0 then break end
      if getn(group.members) <= remaining then
        for _, bidder in ipairs(group.members) do
          table.insert(winners, { bidder = bidder, tier = tierInfo.name, bid = group.bid })
          remaining = remaining - 1
        end
      else
        if NS.sessionMode == "DKP" then
          NS.MessageWinnerChannel(NS.PlayersWithClassColors(group.members) .. " tied with a " .. string.upper(tierInfo.name) .. " bid of " .. group.bid .. ", rolling it off:")
        else
          NS.MessageWinnerChannel(NS.PlayersWithClassColors(group.members) .. " bid " .. string.upper(tierInfo.name) .. ", rolling it off:")
        end
        local groupWinners = RollOff(group.members, remaining, roll, item, breakTies)
        for _, bidder in ipairs(groupWinners) do
          table.insert(winners, { bidder = bidder, tier = tierInfo.name, bid = group.bid })
          remaining = remaining - 1
        end
      end
    end
  end
  return winners, remaining
end

local function AnnounceWinner(item, itemSession, winner)
  local ms = itemSession["ms"] or {}
  local ofs = itemSession["os"] or {}
  local cancel = itemSession["cancel"] or {}
  local real = itemSession["real"] or {}
  local winnerMessage = NS.PlayerWithClassColor(winner.bidder) .. " wins " .. item
  if NS.sessionMode == "DKP" then
    local displayTier = winner.tier
    local displayBidAmount = winner.bid
    local winnerFromOffspec = winner.tier == "ms" and itemSession["ms_origin"] and itemSession["ms_origin"][winner.bidder] == "os"
    if winnerFromOffspec then
      local hasNaturalMainspecBids = false
      for bidder, bid in pairs(ms) do
        if cancel[bidder] == nil and not (itemSession["ms_origin"] and itemSession["ms_origin"][bidder] == "os") then
          hasNaturalMainspecBids = true
          break
        end
      end
      if not hasNaturalMainspecBids then
        displayTier = "os"
        displayBidAmount = ofs[winner.bidder]
      end
    end
    winnerMessage = winnerMessage .. " with a " .. (winner.tier == "roll" and "roll of " or (string.upper(displayTier) .. " bid of "))
    if winner.tier ~= "roll" then
      winnerMessage = winnerMessage .. NS.realAmt(displayBidAmount, real[winner.bidder])
    else
      winnerMessage = winnerMessage .. winner.bid
    end
  elseif winner.tier == "roll" then
    winnerMessage = winnerMessage .. " with a roll of " .. winner.bid
  else
    winnerMessage = winnerMessage .. " for " .. string.upper(winner.tier)
  end
  NS.MessageWinnerChannel(winnerMessage)
end

function NS.BidSummary(announceWinners)
  if NS.session == nil then
    NS.Error("There is no existing session")
    return
  end
  local summaries = {}
  for item,itemSession in pairs(NS.session) do
    local sr = itemSession["sr"] or {}
    local ms = itemSession["ms"] or {}
    local ofs = itemSession["os"] or {}
    local roll = itemSession["roll"] or {}
    local bidCopies = itemSession["bidCopies"] or 1
    local needsRoll = NS.IsTableEmpty(sr) and NS.IsTableEmpty(ms) and NS.IsTableEmpty(ofs)
    local breakTies = ChatLootBidder_Store.BreakTies or NS.sessionMode ~= "DKP"

    ResolvePendingRolls(itemSession, item, announceWinners, needsRoll)

    local summary = {}
    local srWinners = BuildSrSection(item, itemSession, summary, announceWinners, breakTies)
    local msBidders, osBidders, rollBidders = BuildBidSections(item, itemSession, summary, announceWinners, needsRoll)
    local remaining = bidCopies

    if announceWinners then
      local tiers = {
        { name = "ms", bidders = msBidders },
        { name = "os", bidders = osBidders },
        { name = "roll", bidders = rollBidders },
      }
      local bidWinners
      bidWinners, remaining = ResolveTierWinners(item, tiers, remaining, roll, breakTies)

      for _, winner in ipairs(bidWinners) do
        AnnounceWinner(item, itemSession, winner)
      end

      if NS.IsTableEmpty(srWinners) and NS.IsTableEmpty(bidWinners) then
        NS.MessageStartChannel("No bids received for " .. item)
        table.insert(summary, item .. ": No Bids")
      elseif remaining > 0 then
        NS.MessageStartChannel("No bids received for " .. item)
      end
    else
      if NS.IsTableEmpty(msBidders) and NS.IsTableEmpty(osBidders) and NS.IsTableEmpty(rollBidders) and NS.IsTableEmpty(sr) then
        table.insert(summary, item .. ": No Bids")
      end
    end

    table.insert(summaries, summary)
  end

  for _,summary in pairs(summaries) do
    for _,line in pairs(summary) do
      NS.MessageBidSummaryChannel(line)
    end
  end
end

local function ExtractParams(message, params)
  for _, word in pairs(NS.SplitBySpace(string.lower(message))) do
    if string.len(word) > 1 and string.sub(word, -1) == ";" then
      word = string.sub(word, 1, -2)
    end
    if params[word] ~= nil then
      params[word] = true
    else
      break
    end
  end
  return params
end

local function HandleBidWhisper(bidder, whisperText, item, itemSession, itemIndexEnd)
  if itemSession == nil then
    NS.SendResponse("There is no active loot session for " .. item, bidder)
    return
  end
  if not NS.IsInRaid(bidder) then
    NS.SendResponse("You must be in the raid to send a bid on " .. item, bidder)
    return
  end
  if itemSession["ms"] == nil then
    NS.SendResponse(item .. " is fully reserved via Soft Reserve and is not open for bidding", bidder)
    return
  end

  local mainSpec = itemSession["ms"]
  local offSpec = itemSession["os"]
  local roll = itemSession["roll"]
  local cancel = itemSession["cancel"]
  local notes = itemSession["notes"]
  local real = itemSession["real"]

  local bid = NS.SplitBySpace(string.sub(whisperText, itemIndexEnd + 1))
  local tier = bid[1] and string.lower(bid[1]) or nil
  local amt = bid[2] and string.lower(bid[2]) or nil

  if NS.IsValidTier(tier) then
    amt = NS.ToWholeNumber(amt)
  elseif NS.IsValidTier(amt) then
    local oldTier = tier
    tier = amt
    amt = NS.ToWholeNumber(oldTier)
  else
    NS.SendResponse(NS.InvalidBidSyntax(item), bidder)
    return
  end

  if tier == "cancel" then
    local cancelBid = "Bid canceled for " .. item
    cancel[bidder] = true
    mainSpec[bidder] = nil
    offSpec[bidder] = nil
    notes[bidder] = nil
    real[bidder] = nil
    NS.MessageBidChannel("<" .. NS.PlayerWithClassColor(bidder) .. "> " .. cancelBid)
    NS.SendResponse(cancelBid, bidder)
    return
  end

  if amt > ChatLootBidder_Store.MaxBid then
    NS.SendResponse("Bid for " .. item .. " is too large, the maxiumum accepted bid is: " .. ChatLootBidder_Store.MaxBid, bidder)
    return
  end

  cancel[bidder] = nil
  if tier == "roll" then
    if roll[bidder] ~= nil and roll[bidder] ~= -1 then
      NS.SendResponse("Your roll of " .. roll[bidder] .. " has already been recorded", bidder)
      return
    end
  elseif NS.sessionMode == "DKP" then
    if amt < ChatLootBidder_Store.MinBid then
      NS.SendResponse(NS.InvalidBidSyntax(item), bidder)
      return
    end
    table.remove(bid, 2)
  else
    amt = 1
  end

  table.remove(bid, 1)
  local note = table.concat(bid, " ")
  local params = ExtractParams(note, {
    ["heal"] = false,
    ["dps"] = false,
    ["tank"] = false,
    ["alt"] = false,
    ["nr"] = false
  })

  real[bidder] = amt
  if NS.sessionMode == "DKP" and ChatLootBidder_Store.AltPenalty > 0 and params.alt then
    NS.Trace("Alt penalty is " .. ChatLootBidder_Store.AltPenalty .. "%")
    amt = (amt * 100 - amt * ChatLootBidder_Store.AltPenalty) / 100
  end
  notes[bidder] = note
  local received

  if tier == "ms" then
    if itemSession["ms_origin"] and itemSession["ms_origin"][bidder] == "os" then
      mainSpec[bidder] = amt
      itemSession["ms_origin"][bidder] = nil
    elseif mainSpec[bidder] ~= nil then
      NS.SendResponse("You already have a MS bid" .. NS.of(mainSpec[bidder], real[bidder]) .. " recorded. Use '[item-link] cancel' to cancel your current MS bid.", bidder)
      return
    else
      mainSpec[bidder] = amt
    end
    if NS.sessionMode == "MSOS" then roll[bidder] = roll[bidder] or -1 end
    received = "Main Spec bid" .. NS.of(amt, real[bidder]) .. " received for " .. item .. NS.AppendNote(note)
  elseif tier == "os" then
    if offSpec[bidder] ~= nil then
      NS.SendResponse("You already have an OS bid" .. NS.of(offSpec[bidder], real[bidder]) .. " recorded. Use '[item-link] cancel' to cancel your current OS bid.", bidder)
      return
    end
    if NS.sessionMode == "DKP" and ChatLootBidder_Store.OffspecPenalty > 0 and mainSpec[bidder] ~= nil and (not itemSession["ms_origin"] or itemSession["ms_origin"][bidder] ~= "os") then
      NS.SendResponse("You already have a MS bid" .. NS.of(mainSpec[bidder], real[bidder]) .. " recorded. Use '[item-link] cancel' to cancel your current MS bid before placing an OS bid.", bidder)
      return
    end
    offSpec[bidder] = amt
    if NS.sessionMode == "MSOS" then roll[bidder] = roll[bidder] or -1 end
    received = "Off Spec bid" .. NS.of(amt, real[bidder]) .. " received for " .. item .. NS.AppendNote(note)

    if NS.sessionMode == "DKP" and ChatLootBidder_Store.OffspecPenalty > 0 then
      NS.Trace("Offspec penalty is " .. ChatLootBidder_Store.OffspecPenalty .. "%")
      local ms_amt = (amt * 100 - amt * ChatLootBidder_Store.OffspecPenalty) / 100
      mainSpec[bidder] = ms_amt
      itemSession["ms_origin"] = itemSession["ms_origin"] or {}
      itemSession["ms_origin"][bidder] = "os"
    end
  elseif tier == "roll" then
    roll[bidder] = -1
    received = "Your roll bid for " .. item .. " has been received" .. NS.AppendNote(note) .. ".  '/random' now to record your own roll or do nothing for the addon to roll for you at the end of the session."
  end

  NS.MessageBidChannel("<" .. NS.PlayerWithClassColor(bidder) .. "> " .. tier .. ((NS.sessionMode == "MSOS" or amt == nil or tier == "roll") and "" or (" " .. NS.realAmt(amt, real[bidder]))) .. " " .. item)
  if not params.nr then
    NS.SendResponse(received, bidder)
  end
end

function ChatFrame_OnEvent(event)
  if event ~= "CHAT_MSG_WHISPER" or NS.lastWhisper == (arg1 .. arg2) then
    ChatLootBidder_ChatFrame_OnEvent(event)
    return
  end
  NS.lastWhisper = arg1 .. arg2
  local bidder = arg2
  local items, itemIndexEnd = NS.GetItemLinks(arg1)
  local item = items[1]

  local commandlist = NS.SplitBySpace(arg1)
  local srCommand = string.lower(commandlist[1] or "") == "sr"
  if srCommand and NS.softReserveSessionName == nil then
    NS.SendResponse("There is no Soft Reserve session loaded", bidder)
    return
  end

  if srCommand then
    NS.HandleSrWhisper(bidder, commandlist, items, item)
    return
  end

  if NS.session ~= nil and item ~= nil then
    local itemSession = NS.session[item]
    HandleBidWhisper(bidder, arg1, item, itemSession, itemIndexEnd)
    return
  end

  ChatLootBidder_ChatFrame_OnEvent(event)
end

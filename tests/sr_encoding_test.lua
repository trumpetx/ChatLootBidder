-- Tests for SR encoding/decoding branches.

local function SetUpSrEditorCapture()
  local state = { text = "", header = "", visible = false }

  SrEditFrame.IsVisible = function() return state.visible end
  SrEditFrame.Show = function() state.visible = true end
  SrEditFrame.Hide = function() state.visible = false end
  SrEditFrameText.SetText = function(_, text) state.text = text end
  SrEditFrameHeaderString.SetText = function(_, text) state.header = text end
  SrEditFrameHeaderString.GetText = function() return state.header end

  return state
end

test("encode_decode_csv_roundtrip", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false
  local editor = SetUpSrEditorCapture()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Band of Accuria", "Quick Strike Ring" },
    ["PlayerB"] = { "Perdition's Blade" },
  }

  ChatLootBidderFrame:HandleEncoding("csv")
  assert(string.find(editor.text, "PlayerA", 1, true) ~= nil, "Expected CSV output for PlayerA")

  ChatLootBidder_Store.SoftReserveSessions["testList"] = {}
  local parentFrame = { Hide = function() end }
  ChatLootBidderFrame:DecodeAndSave(editor.text, parentFrame)

  local srs = ChatLootBidder_Store.SoftReserveSessions["testList"]
  assert(#srs["PlayerA"] == 2, "Expected 2 CSV-decoded SRs for PlayerA")
  assert(srs["PlayerA"][1] == "Band of Accuria", "Expected first CSV SR preserved")
  assert(srs["PlayerB"][1] == "Perdition's Blade", "Expected PlayerB CSV SR preserved")
end)

test("encode_decode_semicolon_roundtrip", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false
  local editor = SetUpSrEditorCapture()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Band of Accuria", "Quick Strike Ring" },
    ["PlayerB"] = { "Perdition's Blade" },
  }

  ChatLootBidderFrame:HandleEncoding("semicolon")
  assert(string.find(editor.text, "PlayerA ; Band of Accuria ; Quick Strike Ring", 1, true) ~= nil, "Expected semicolon output")

  ChatLootBidder_Store.SoftReserveSessions["testList"] = {}
  local parentFrame = { Hide = function() end }
  ChatLootBidderFrame:DecodeAndSave(editor.text, parentFrame)

  local srs = ChatLootBidder_Store.SoftReserveSessions["testList"]
  assert(#srs["PlayerA"] == 2, "Expected 2 semicolon-decoded SRs for PlayerA")
  assert(srs["PlayerB"][1] == "Perdition's Blade", "Expected semicolon decode for PlayerB")
end)

test("encode_decode_raidresfly_roundtrip", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false
  local editor = SetUpSrEditorCapture()

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {
    ["PlayerA"] = { "Band of Accuria" },
    ["PlayerB"] = { "Perdition's Blade" },
  }

  ChatLootBidderFrame:HandleEncoding("raidresfly")
  assert(string.find(editor.text, "[00:00]PlayerA: PlayerA - Band of Accuria", 1, true) ~= nil, "Expected raidresfly output")

  ChatLootBidder_Store.SoftReserveSessions["testList"] = {}
  local parentFrame = { Hide = function() end }
  ChatLootBidderFrame:DecodeAndSave(editor.text, parentFrame)

  local srs = ChatLootBidder_Store.SoftReserveSessions["testList"]
  assert(srs["PlayerA"][1] == "Band of Accuria", "Expected raidresfly decode for PlayerA")
  assert(srs["PlayerB"][1] == "Perdition's Blade", "Expected raidresfly decode for PlayerB")
end)

test("flatten_unflatten_roundtrip", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false

  local flat = {
    { "PlayerA", "Band of Accuria" },
    { "PlayerA", "Quick Strike Ring" },
    { "PlayerB", "Perdition's Blade" },
  }
  local csvDoc = csv:toCSV(flat)
  local parsedFlat = csv:fromCSV(csvDoc)

  CLB("sr load testList")
  SrEditFrameHeaderString.GetText = function() return "csv" end
  local parentFrame = { Hide = function() end }
  ChatLootBidderFrame:DecodeAndSave(csv:toCSV(parsedFlat), parentFrame)

  local srs = ChatLootBidder_Store.SoftReserveSessions["testList"]
  assert(#srs["PlayerA"] == 2, "Expected flattened/unflattened PlayerA values")
  assert(srs["PlayerA"][2] == "Quick Strike Ring", "Expected second value after roundtrip")
  assert(srs["PlayerB"][1] == "Perdition's Blade", "Expected PlayerB value after roundtrip")
end)

test("pretty_print_json_empty", function()
  SetUpTestEnvironment()
  ChatLootBidder_Store.ItemValidation = false
  local editor = SetUpSrEditorCapture()
  local oldJson = json
  json = {
    encode = function() return "[]" end
  }

  CLB("sr load testList")
  ChatLootBidder_Store.SoftReserveSessions["testList"] = {}
  ChatLootBidderFrame:HandleEncoding("json")

  assert(editor.text == "{}", "Expected empty SR JSON to be pretty-printed as {}")
  json = oldJson
end)

-- Tests for csv.lua encoding paths.

test("csv_to_csv_basic", function()
  local doc = csv:toCSV({
    { "PlayerA", "Band of Accuria" },
    { "PlayerB", "Perdition's Blade" },
  })

  assert(string.find(doc, "PlayerA,Band of Accuria", 1, true) ~= nil, "Expected first CSV line")
  assert(string.find(doc, "PlayerB,Perdition's Blade", 1, true) ~= nil, "Expected second CSV line")
end)

test("csv_escape_with_commas_and_quotes", function()
  local doc = csv:toCSV({
    { "PlayerA", "Band, of \"Accuria\"" },
  })

  assert(string.find(doc, "PlayerA,\"Band, of \"\"Accuria\"\"\"", 1, true) ~= nil, "Expected escaped CSV field")
end)

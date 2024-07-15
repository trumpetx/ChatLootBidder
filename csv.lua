CSV_VERSION = "2020.09.22"

if csv and (csv.version >= CSV_VERSION) then return end
csv = {}
csv.version = CSV_VERSION
local gfind = string.gmatch or string.gfind
--
-- http://lua-users.org/wiki/CsvUtils
--

-- Used to escape "'s by toCSV
local function escapeCSV(s)
  if string.find(s, '[,"]') then
    s = '"' .. string.gsub(s, '"', '""') .. '"'
  end
  return s
end

-- Convert from CSV string to table (converts a single line of a CSV file)
local function lineFromCSV(s)
  s = s .. ','        -- ending comma
  local t = {}        -- table to collect fields
  local fieldstart = 1
  repeat
    -- next field is quoted? (start with `"'?)
    if string.find(s, '^"', fieldstart) then
      local a, c
      local i  = fieldstart
      repeat
        -- find closing quote
        a, i, c = string.find(s, '"("?)', i+1)
      until c ~= '"'    -- quote not followed by quote?
      if not i then error('unmatched "') end
      local f = string.sub(s, fieldstart+1, i-1)
      table.insert(t, (string.gsub(f, '""', '"')))
      fieldstart = string.find(s, ',', i) + 1
    else                -- unquoted; find next comma
      local nexti = string.find(s, ',', fieldstart)
      table.insert(t, string.sub(s, fieldstart, nexti-1))
      fieldstart = nexti + 1
    end
  until fieldstart > string.len(s)
  return t
end

-- Convert from table to CSV string
local function lineToCSV(tt)
  local s = ""
-- ChM 23.02.2014: changed pairs to ipairs
-- assumption is that fromCSV and toCSV maintain data as ordered array
  for _,p in pairs(tt) do
    s = s .. "," .. escapeCSV(p)
  end
  return string.sub(s, 2)      -- remove first comma
end

function csv:toCSV(flatTable)
  local doc = ""
  for _,line in pairs(flatTable) do
    doc = doc .. lineToCSV(line) .. "\n"
  end
  return doc
end

function csv:fromCSV(doc)
  local flatTable = {}
  for line in gfind(doc, '([^\n]+)') do
    table.insert(flatTable, lineFromCSV(line))
  end
  return flatTable
end

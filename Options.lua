function ChatLootBidderOptionsFrame_InitializeChannelDropdown(level, menulist)
  if level == nil then
    -- Initialize the "outer Frame" to include a :SetValue() method which we can use externally
    local widgetName = this:GetName()
    local propName = string.sub(widgetName, strlen(this:GetParent():GetName())+1)
    this.SetValue = function(self, value)
      getglobal(widgetName .. "Text"):SetText((ChatLootBidder_i18n[propName] or propName) .. ": " .. value)
      CloseDropDownMenus()
    end
  elseif level == 1 then
    local widget = this:GetParent()
    local widgetName = widget:GetName()
    local propName = string.sub(widgetName, strlen(widget:GetParent():GetName())+1)
    for _,c in pairs({"RAID","RAID_WARNING","OFFICER","PARTY","GUILD","SAY","YELL","EMOTE"}) do
      local channel = {}
      channel.text = c
      channel.func = function()
        getglobal("ChatLootBidderFrame"):SetPropValue(propName, channel.text)
        widget:SetValue(channel.text)
      end
      UIDropDownMenu_AddButton(channel)
    end
  end
end

function ChatLootBidderOptionsFrame_Back()
  if not ChatLootBidder_Store then return end
  local k,prev
  for k,_ in pairs(ChatLootBidder_Store.SoftReserveSessions) do
    if ChatLootBidderOptionsFrameCurrentSoftReserve:GetText() == k and prev ~= nil then
      break
    end
    prev = k
  end
  ChatLootBidderOptionsFrameCurrentSoftReserve:SetText(prev or "No List")
end

function ChatLootBidderOptionsFrame_Next()
  if not ChatLootBidder_Store then return end
  local k,isNext
  for k,_ in pairs(ChatLootBidder_Store.SoftReserveSessions) do
    if isNext then
      ChatLootBidderOptionsFrameCurrentSoftReserve:SetText(k)
      return
    end
    if ChatLootBidderOptionsFrameCurrentSoftReserve:GetText() == k then
      isNext = true
    end
  end
  k = next(ChatLootBidder_Store.SoftReserveSessions)
  ChatLootBidderOptionsFrameCurrentSoftReserve:SetText(k or "No List")
end

function ChatLootBidderOptionsFrame_Reload()
  local srName, sr = ChatLootBidderFrame:LoadedSoftReserveSession()
  if sr then
    local players = 0
    local items = 0
    for _,i in pairs(sr) do
      players = players + 1
      items = items + getn(i)
    end
    ChatLootBidderOptionsFrameCurrentSoftReserveLoaded:SetText("Loaded: " .. srName)
    ChatLootBidderOptionsFrameCurrentSoftReservePlayers:SetText("Players: " .. players)
    ChatLootBidderOptionsFrameCurrentSoftReserveItems:SetText("Items: " .. items)
  else
    ChatLootBidderOptionsFrameCurrentSoftReserveLoaded:SetText("Loaded: ")
    ChatLootBidderOptionsFrameCurrentSoftReservePlayers:SetText("Players: ")
    ChatLootBidderOptionsFrameCurrentSoftReserveItems:SetText("Items: ")
  end
end

function ChatLootBidderOptionsFrame_Delete()
  local listName = ChatLootBidderOptionsFrameCurrentSoftReserve:GetText()
  if listName == "No List" then return end
  ChatLootBidderOptionsFrame_Next()
  ChatLootBidderFrame:HandleSrDelete(listName)
  ChatLootBidderOptionsFrame_Reload()
end

function ChatLootBidderOptionsFrame_Load()
  local listName = ChatLootBidderOptionsFrameCurrentSoftReserve:GetText()
  if listName == "No List" then listName = nil end
  ChatLootBidderFrame:HandleSrLoad(listName)
  ChatLootBidderOptionsFrame_Reload()
end

function ChatLootBidderOptionsFrame_Init(providedName)
  if providedName then
    ChatLootBidderOptionsFrameCurrentSoftReserve:SetText(providedName)
  else
    ChatLootBidderOptionsFrame_Back()
  end
  ChatLootBidderOptionsFrame_Reload()
end

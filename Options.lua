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

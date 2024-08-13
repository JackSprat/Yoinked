local AceGUI = LibStub("AceGUI-3.0")

local itemSpacing = {{0, 350, 0}, {15, 50, 20}, {20, 50, 20}, {20, 50, 20}, {35, 20, 35}, {0, 90, 0}}
local configFrame

function Yoinked:AddRowToTable(scrollTable, itemID, valueRow, context)

    local listItem = AceGUI:Create("SimpleGroup")
    listItem:SetFullWidth(true)
    listItem:SetLayout("Flow")
    scrollTable:AddChild(listItem)

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetWidth(itemSpacing[1][2])
    itemLabel:SetText(select(1, C_Item.GetItemInfo(itemID)))
    itemLabel:SetImage(select(10, C_Item.GetItemInfo(itemID)))
    itemLabel.frame:Show()
    listItem:AddChild(itemLabel)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[1][3] + itemSpacing[2][1])
    listItem:AddChild(spacer)

    local bagAmount = AceGUI:Create("EditBox")
    bagAmount:SetWidth(itemSpacing[2][2])
    bagAmount:SetText(valueRow.bagAmount)
    bagAmount:DisableButton(true)
    bagAmount:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value then self.db[context].rules[itemID].bagAmount = value end
    end)
    bagAmount.frame:Show()
    listItem:AddChild(bagAmount)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[2][3] + itemSpacing[3][1])
    listItem:AddChild(spacer)

    local bagCap = AceGUI:Create("EditBox")
    bagCap:SetWidth(itemSpacing[3][2])
    bagCap:SetText(valueRow.bagCap)
    bagCap:DisableButton(true)
    bagCap:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value then self.db[context].rules[itemID].bagCap = value end
    end)
    bagCap.frame:Show()
    listItem:AddChild(bagCap)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[3][3] + itemSpacing[4][1])
    listItem:AddChild(spacer)

    local priority = AceGUI:Create("EditBox")
    priority:SetText(valueRow.priority)
    priority:SetWidth(itemSpacing[4][2])
    priority:DisableButton(true)
    priority:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value and value >= 1 and value <= 10 then self.db[context].rules[itemID].priority = value end
    end)
    priority.frame:Show()
    listItem:AddChild(priority)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[4][3] + itemSpacing[5][1])
    listItem:AddChild(spacer)

    local itemEnabled = AceGUI:Create("CheckBox")
    itemEnabled:SetValue(valueRow.enabled)
    itemEnabled:SetWidth(itemSpacing[5][2])
    itemEnabled:SetLabel("")
    itemEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db[context].rules[itemID].enabled = value
    end)
    itemEnabled.frame:Show()
    listItem:AddChild(itemEnabled)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[5][3] + itemSpacing[6][1])
    listItem:AddChild(spacer)

    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText("Delete")
    deleteButton:SetWidth(itemSpacing[6][2])
    deleteButton:SetCallback("OnClick", function(_,_)
        self.db[context].rules[itemID] = nil
        listItem:Release()
    end)
    deleteButton.frame:Show()
    listItem:AddChild(deleteButton)
end

function Yoinked:DrawRuleContainer(container, context)

    local contextLabels = {
        ["char"] = "These rules apply to only " .. UnitName("player") .. ".",
        ["class"] = "These rules apply to every " .. select(1, UnitClass("player")) .. ", if enabled.",
        ["global"] = "These rules apply to every character on the account, if the character is enabled.",
        ["profile"] = "These rules apply to every character with the " .. self.db:GetCurrentProfile() .. " profile, if enabled."
    }

    local addBox = AceGUI:Create("EditBox")
    addBox:SetWidth(400)
    addBox:SetLabel("Add Item:")
    addBox:SetCallback("OnEnter", function(...)
        if CursorHasItem() then
            local infoType, itemID, _ = GetCursorInfo()
            if infoType == "item" then
                addBox:SetText(itemID)
                ClearCursor()
            end
        end
    end)

    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(50)

    local desc = AceGUI:Create("Label")
    desc:SetText(contextLabels[context])
    desc:SetWidth(200)

    container:AddChild(addBox)
    container:AddChild(spacer)
    container:AddChild(desc)

    local moduleEnabled = AceGUI:Create("CheckBox")
    moduleEnabled:SetValue(self.db.char[context .. "Enabled"])
    moduleEnabled:SetWidth(90)
    moduleEnabled:SetLabel("Enabled")
    moduleEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db.char[context .. "Enabled"] = value
    end)
    moduleEnabled.frame:Show()
    container:AddChild(moduleEnabled)

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetFullWidth(true)
    itemLabel:SetText("")
    itemLabel.frame:Show()
    container:AddChild(itemLabel)

    local titleGroup = AceGUI:Create("SimpleGroup")
    titleGroup:SetFullWidth(true)
    titleGroup:SetLayout("Flow")
    container:AddChild(titleGroup)

    local titleItems = AceGUI:Create("Heading")
    titleItems:SetWidth(350)
    titleItems:SetText("Items")
    titleGroup:AddChild(titleItems)

    local titleBagAmount = AceGUI:Create("Heading")
    titleBagAmount:SetWidth(90)
    titleBagAmount:SetText("Bag Amount")
    titleGroup:AddChild(titleBagAmount)

    local titleBagCap = AceGUI:Create("Heading")
    titleBagCap:SetWidth(90)
    titleBagCap:SetText("Bag Cap")
    titleGroup:AddChild(titleBagCap)

    local titlePriority = AceGUI:Create("Heading")
    titlePriority:SetText("Priority")
    titlePriority:SetWidth(90)
    titleGroup:AddChild(titlePriority)

    local titleItemEnabled = AceGUI:Create("Heading")
    titleItemEnabled:SetText("Enabled")
    titleItemEnabled:SetWidth(90)
    titleGroup:AddChild(titleItemEnabled)

    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    scrollcontainer:SetLayout("Fill")

    container:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scrollcontainer:AddChild(scroll)
    for i,v in pairs(self.db[context].rules) do

        self:AddRowToTable(scroll, i, v, context)

    end

    addBox:SetCallback("OnTextChanged", function(_,_,value)

        itemLabel:SetText("")
        itemLabel:SetImage("")

        value = tonumber(value)

        if not value or value == "fail" or value == "" or not C_Item.DoesItemExistByID(value) then
            return
        end

        local item = Item:CreateFromItemID(value)

        item:ContinueOnItemLoad(function()
            if item and item:GetItemName() then
                itemLabel:SetText(item:GetItemName())
                itemLabel:SetImage(item:GetItemIcon())
            else
                itemLabel:SetText("")
                itemLabel:SetImage("")
            end
        end)
    end)

    addBox:SetCallback("OnEnterPressed", function(_,_,text)
        local value = tonumber(text)
        if value and C_Item.GetItemInfo(value) then
            self.db[context].rules[value] = {bagAmount=20, bagCap = 20, priority=10, enabled=true}
            self:AddRowToTable(scroll, value, self.db[context].rules[value])
        end
    end)
end

function Yoinked:CreateUIFrame()

    --don't execute if there's an existing frame open
    if configFrame and configFrame:IsShown() then return end

    --#TODO: refactor to pass context with function rather than attaching to container
    local function SelectGroup(container, _, context)
        container:ReleaseChildren()
        self:DrawRuleContainer(container, context)
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Yoinked")
    frame:SetStatusText("Yoinked Config")

    if Yoinked.db.profile.configWidth and Yoinked.db.profile.configWidth > 0 then
        frame:SetWidth(Yoinked.db.profile.configWidth)
        frame:SetHeight(Yoinked.db.profile.configHeight)
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Yoinked.db.profile.configX, Yoinked.db.profile.configY)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER")
        frame:SetWidth(875)
    end

    frame:SetCallback("OnClose", function(widget)
        Yoinked.db.profile.configX, Yoinked.db.profile.configY, Yoinked.db.profile.configWidth, Yoinked.db.profile.configHeight = frame.frame:GetBoundsRect()
        AceGUI:Release(widget)
    end)
    frame:SetLayout("Fill")

    local tab =  AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    tab:SetTabs({{text="Character", value="char"}, {text="Class", value="class"}, {text="Global", value="global"}, {text="Profile", value="profile"}})
    tab:SetCallback("OnGroupSelected", SelectGroup)
    tab:SelectTab("global")

    frame:AddChild(tab)

    configFrame = frame
end
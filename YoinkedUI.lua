local AceGUI = LibStub("AceGUI-3.0")

local function CreateConfigUI()

    local backgroundFrameClass = LibStub('Poncho-2.0'):NewClass('Frame', 'YoinkedBG')

    local bgFrame = backgroundFrameClass()
    bgFrame:SetWidth(400)
    bgFrame:SetHeight(300)
    bgFrame.texture = bgFrame:CreateTexture()
    bgFrame.texture:SetAllPoints(bgFrame)
    bgFrame.texture:SetColorTexture(0,0,0,0.5)
    bgFrame:Show()
end

function Yoinked:AddRowToTable(scrollTable, itemID, valueRow, context)
    local listItem = AceGUI:Create("InlineGroup")
    listItem:SetFullWidth(true)
    listItem:SetLayout("Flow")
    listItem.frame:SetPoint("TOPLEFT", 0, -50)
    scrollTable:AddChild(listItem)

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetWidth(335)
    itemLabel:SetText(select(1, C_Item.GetItemInfo(itemID)))
    itemLabel:SetImage(select(10, C_Item.GetItemInfo(itemID)))
    listItem:AddChild(itemLabel)

    local bagAmount = AceGUI:Create("EditBox")
    bagAmount:SetWidth(90)
    bagAmount:SetText(valueRow.bagAmount)
    bagAmount:DisableButton(true)
    bagAmount:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value then self.db[context].rules[itemID].bagAmount = value end
    end)
    listItem:AddChild(bagAmount)

    local bagCap = AceGUI:Create("EditBox")
    bagCap:SetWidth(90)
    bagCap:SetText(valueRow.bagCap)
    bagCap:DisableButton(true)
    bagCap:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value then self.db[context].rules[itemID].bagCap = value end
    end)
    listItem:AddChild(bagCap)

    local priority = AceGUI:Create("EditBox")
    priority:SetText(valueRow.priority)
    priority:SetWidth(90)
    priority:DisableButton(true)
    priority:SetCallback("OnEnterPressed", function(_,_,value)
        value = tonumber(value)
        if value and value >= 1 and value <= 10 then self.db[context].rules[itemID].priority = value end
    end)
    listItem:AddChild(priority)

    local itemEnabled = AceGUI:Create("CheckBox")
    itemEnabled:SetValue(valueRow.enabled)
    itemEnabled:SetWidth(90)
    itemEnabled:SetLabel("")
    itemEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db[context].rules[itemID].enabled = value
    end)
    listItem:AddChild(itemEnabled)

    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText("Delete")
    deleteButton:SetWidth(100)
    deleteButton:SetCallback("OnClick", function(_,_)
        self.db[context].rules[itemID] = nil
        listItem:Release()
    end)
    listItem:AddChild(deleteButton)
end

function Yoinked:DrawRuleContainer(container)
    local context = container.context
    local addBox = AceGUI:Create("EditBox")
    addBox:SetWidth(400)
    container:AddChild(addBox)

    local desc = AceGUI:Create("Label")
    desc:SetText(container.label)
    desc:SetWidth(200)
    container:AddChild(desc)

    local moduleEnabled = AceGUI:Create("CheckBox")
    moduleEnabled:SetValue(self.db[container.context].enabled)
    moduleEnabled:SetWidth(90)
    moduleEnabled:SetLabel("")
    moduleEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db[container.context].enabled = value
    end)
    container:AddChild(moduleEnabled)

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetFullWidth(true)
    itemLabel:SetText("")
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
        value = tonumber(value)
        if value and C_Item.GetItemInfo(value) then
            itemLabel:SetText(select(1, C_Item.GetItemInfo(value)))
            itemLabel:SetImage(select(10, C_Item.GetItemInfo(value)))
        elseif value and not C_Item.GetItemInfo(value) then
            itemLabel:SetText("")
            itemLabel:SetImage("")
        end
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
    CreateConfigUI()
--#TODO: Rewrite to use base UI

    --temporarily disabled base UI experimentation
    --local frame = CreateBGFrame("YoinkedBG", 0, 0, 500, 500)
    --local smallFrame = CreateSimpleFrame("YoinkedFrame1", frame, 10, 10, 480, 480)
    --frame:Show()
    --smallFrame:Show()


    local function DrawCharacterTab(container)

        container.context = "char"
        container.label = "These rules apply to only " .. UnitName("player") .. "."
        Yoinked:DrawRuleContainer(container)

    end

    local function DrawClassTab(container)

        container.context = "class"
        container.label = "These rules apply to every " .. select(1, UnitClass("player")) .. ", if enabled."

        Yoinked:DrawRuleContainer(container)

    end

    local function DrawGlobalTab(container)

        container.context = "global"
        container.label = "These rules apply to every character on the account, if the character is enabled."

        Yoinked:DrawRuleContainer(container)

    end

    local function DrawProfileTab(container)

        container.context = "profile"
        container.label = "These rules apply to every character with the " .. self.db:GetCurrentProfile() .. " profile, if enabled."

        Yoinked:DrawRuleContainer(container)

    end

    --#TODO: refactor to pass context with function rather than attaching to container
    local function SelectGroup(container, _, group)
        container:ReleaseChildren()
        if group == "charactertab" then
            DrawCharacterTab(container)
        elseif group == "classtab" then
            DrawClassTab(container)
        elseif group == "globaltab" then
            DrawGlobalTab(container)
        elseif group == "profiletab" then
            DrawProfileTab(container)
        end
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Yoinked")
    frame:SetStatusText("Yoinked Config")
    frame:SetWidth(875)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetLayout("Fill")
    _G["YoinkedGUI"] = frame.frame
    tinsert(UISpecialFrames, "YoinkedGUI")

    local tab =  AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    tab:SetTabs({{text="Character", value="charactertab"}, {text="Class", value="classtab"}, {text="Global", value="globaltab"}, {text="Profile", value="profiletab"}})
    tab:SetCallback("OnGroupSelected", SelectGroup)
    tab:SelectTab("globaltab")

    frame:AddChild(tab)
end
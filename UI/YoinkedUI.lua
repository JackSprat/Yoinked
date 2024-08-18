local AceGUI = LibStub("AceGUI-3.0")
local Sushi = LibStub('Sushi-3.2')

local itemSpacing = {{0, 350, 0}, {15, 50, 20}, {20, 50, 20}, {20, 50, 20}, {35, 20, 35}, {0, 90, 0}}
local titleSpacing = {{0, 350, 0}, {5, 70, 10}, {20, 50, 20}, {20, 50, 20}, {20, 50, 20}, {0, 90, 0}}
local configFrame
local newConfigFrame
local contexts = {[1] = "Global", [2] = "Class", [3] = "Profile", [4] = "Char"}

function Yoinked:AddRowToTable(scrollTable, itemID, valueRow, context)

    local item = Item:CreateFromItemID(itemID)

    self:DebugPrint("UI", 4, "Adding row to table for " .. itemID .. " in context " .. context)
    local listItem = AceGUI:Create("SimpleGroup")
    listItem:SetFullWidth(true)
    listItem:SetLayout("Flow")
    scrollTable:AddChild(listItem)

    self:DebugPrint("UI", 6, "Adding Label with width " .. itemSpacing[1][2] .. ", item ID " .. select(1, C_Item.GetItemInfoInstant(itemID)) .. " and icon " .. select(5, C_Item.GetItemInfoInstant(itemID)))
    local itemLabel = AceGUI:Create("InteractiveLabel")
    itemLabel:SetWidth(itemSpacing[1][2])
    itemLabel:SetText(select(1, C_Item.GetItemInfoInstant(itemID)))
    itemLabel:SetImage(select(5, C_Item.GetItemInfoInstant(itemID)))
    itemLabel:SetCallback("OnEnter", function()
        self:DebugPrint("UI", 6, "Showing tooltip for " .. itemID)
        GameTooltip:SetOwner(itemLabel.frame, "ANCHOR_TOPLEFT", 0, 25)
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    itemLabel:SetCallback("OnLeave", function()
        self:DebugPrint("UI", 6, "Hiding tooltip for " .. itemID)
        GameTooltip:Hide()
    end)
    listItem:AddChild(itemLabel)

    --Set item name after it has been cached, default to showing item ID if it can't be found
    item:ContinueOnItemLoad(function()
        local name = item:GetItemName()
        itemLabel:SetText(name)
    end)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(itemSpacing[1][3] + itemSpacing[2][1]))
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

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(itemSpacing[2][3] + itemSpacing[3][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[2][3] + itemSpacing[3][1])
    listItem:AddChild(spacer)

    self:DebugPrint("UI", 6, "Adding bag cap box with width " .. tostring(itemSpacing[3][2]) .. " and text " .. valueRow.bagCap)
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

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(itemSpacing[3][3] + itemSpacing[4][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[3][3] + itemSpacing[4][1])
    listItem:AddChild(spacer)

    self:DebugPrint("UI", 6, "Adding priority box with width " .. tostring(itemSpacing[4][2]) .. " and text " .. valueRow.priority)
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

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(itemSpacing[4][3] + itemSpacing[5][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[4][3] + itemSpacing[5][1])
    listItem:AddChild(spacer)

    self:DebugPrint("UI", 6, "Adding enabled checkbox with width " .. itemSpacing[5][2] .. " and text " .. tostring(valueRow.enabled))
    local itemEnabled = AceGUI:Create("CheckBox")
    itemEnabled:SetValue(valueRow.enabled)
    itemEnabled:SetWidth(itemSpacing[5][2])
    itemEnabled:SetLabel("")
    itemEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db[context].rules[itemID].enabled = value
    end)
    itemEnabled.frame:Show()
    listItem:AddChild(itemEnabled)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(itemSpacing[5][3] + itemSpacing[6][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(itemSpacing[5][3] + itemSpacing[6][1])
    listItem:AddChild(spacer)

    self:DebugPrint("UI", 6, "Adding delete button with width " .. tostring(itemSpacing[6][2]))
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
        ["char"] = UnitName("player") .. " rules:",
        ["class"] = select(1, UnitClass("player")) .. " rules:",
        ["global"] = "Global rules:",
        ["profile"] = self.db:GetCurrentProfile() .. " profile rules:"
    }

    -- Container rule creation
    local addBox = AceGUI:Create("EditBox")
    addBox:SetWidth(100)
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

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetText("")
    itemLabel:SetWidth(350)

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

    local moduleEnabled = AceGUI:Create("CheckBox")
    moduleEnabled:SetValue(self.db.char[context .. "Enabled"])
    moduleEnabled:SetWidth(200)
    moduleEnabled:SetLabel(contextLabels[context] .. (self.db.char[context .. "Enabled"] and "Enabled" or "Disabled"))
    moduleEnabled:SetCallback("OnValueChanged", function(_,_,value)
        self.db.char[context .. "Enabled"] = value
        moduleEnabled:SetLabel(contextLabels[context] .. (value and "Enabled" or "Disabled"))
    end)
    moduleEnabled.frame:Show()

    container:AddChild(addBox)
    container:AddChild(itemLabel)
    container:AddChild(moduleEnabled)


    -- Table header 
    local titleGroup = AceGUI:Create("SimpleGroup")
    titleGroup:SetFullWidth(true)
    titleGroup:SetLayout("Flow")
    container:AddChild(titleGroup)

    local titleItems = AceGUI:Create("InteractiveLabel")
    titleItems:SetWidth(titleSpacing[1][2])
    titleItems:SetHeight(20)
    titleItems:SetText("Items")
    titleGroup:AddChild(titleItems)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(titleSpacing[1][3] + titleSpacing[2][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(titleSpacing[1][3] + titleSpacing[2][1])
    titleGroup:AddChild(spacer)

    local titleBagAmount = AceGUI:Create("InteractiveLabel")
    titleBagAmount:SetWidth(titleSpacing[2][2])
    titleBagAmount:SetText("Bag Amount")
    titleBagAmount:SetCallback("OnEnter", function() end)
    titleBagAmount:SetCallback("OnLeave", function() end)
    titleGroup:AddChild(titleBagAmount)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(titleSpacing[2][3] + titleSpacing[3][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(titleSpacing[2][3] + titleSpacing[3][1])
    titleGroup:AddChild(spacer)

    local titleBagCap = AceGUI:Create("InteractiveLabel")
    titleBagCap:SetWidth(titleSpacing[3][2])
    titleBagCap:SetText("Bag Cap")
    titleGroup:AddChild(titleBagCap)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(titleSpacing[3][3] + titleSpacing[4][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(titleSpacing[3][3] + titleSpacing[4][1])
    titleGroup:AddChild(spacer)

    local titlePriority = AceGUI:Create("InteractiveLabel")
    titlePriority:SetText("Priority")
    titlePriority:SetWidth(titleSpacing[4][2])
    titleGroup:AddChild(titlePriority)

    self:DebugPrint("UI", 9, "Adding spacer with width " .. tostring(titleSpacing[4][3] + titleSpacing[5][1]))
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(titleSpacing[4][3] + titleSpacing[5][1])
    titleGroup:AddChild(spacer)

    local titleItemEnabled = AceGUI:Create("InteractiveLabel")
    titleItemEnabled:SetText("Enabled")
    titleItemEnabled:SetWidth(titleSpacing[5][2])
    titleGroup:AddChild(titleItemEnabled)

    -- Table
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

    addBox:SetCallback("OnEnterPressed", function(_,_,text)
        local value = tonumber(text)
        if value and C_Item.GetItemInfo(value) then
            self.db[context].rules[value] = {bagAmount=20, bagCap = 20, priority=10, enabled=true}
            self:AddRowToTable(scroll, value, self.db[context].rules[value])
        end
    end)
    
end

local function CreateBaseUIFrame()
    newConfigFrame = CreateFrame("Frame", "YoinkedConfigUI", UIParent, "PortraitFrameTemplate")
    local color = CreateColorFromHexString("FF1E1D20")
    local r, g, b = color:GetRGB()
    newConfigFrame.Bg:SetColorTexture(r, g, b, 0.8)
    newConfigFrame.Bg.colorTexture = {r, g, b, 0.8}

    local text = "Yoinked " --.. Yoinked.version
    YoinkedConfigUITitleText:SetText(text)

    tinsert(UISpecialFrames, newConfigFrame:GetName())
    newConfigFrame:SetMovable(true)
    newConfigFrame:EnableMouse(true)
    newConfigFrame:SetResizable(true)
    newConfigFrame:SetWidth(800)
    newConfigFrame:SetHeight(500)
    newConfigFrame:SetResizeBounds(800, 500, 1600, 1000)
    newConfigFrame:SetFrameStrata("DIALOG")
    newConfigFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    YoinkedConfigUIPortrait:SetTexture([[Interface\AddOns\Yoinked\Assets\YOINKED-ICON-256s]])

    newConfigFrame.TitleContainer:SetScript("OnMouseDown", function()
        newConfigFrame:StartMoving()
    end)
    newConfigFrame.TitleContainer:SetScript("OnMouseUp", function()
        newConfigFrame:StopMovingOrSizing()
    end)

    local resizeButton = CreateFrame("Button", nil, newConfigFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT")
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        newConfigFrame:StartSizing("BOTTOMRIGHT")
    end)

    resizeButton:SetScript("OnMouseUp", function(self, button)
        newConfigFrame:StopMovingOrSizing()
    end)
end

function Yoinked:CreateUIFrame(testMode)

    if testMode then

        if newConfigFrame and newConfigFrame:IsShown() then return end
        if not newConfigFrame then

            CreateBaseUIFrame()

            local ruleSelectorContainer = CreateFrame("Frame", "YoinkedRuleSelectorContainer", newConfigFrame, "InsetFrameTemplate3")
            ruleSelectorContainer:SetPoint("TOPLEFT", newConfigFrame, "TOPLEFT", 20, -100)
            ruleSelectorContainer:SetWidth(300)
            ruleSelectorContainer:SetPoint("BOTTOM", newConfigFrame, "BOTTOM", 0, 20)

            local ruleSelectorSearchBox = CreateFrame("EditBox", "ToinkedRuleSelectorSearchBox", newConfigFrame, "InputBoxTemplate")
            ruleSelectorSearchBox:SetPoint("BOTTOMLEFT", ruleSelectorContainer, "TOPLEFT", 6, 5)
            ruleSelectorSearchBox:SetSize(293, 20)
            ruleSelectorSearchBox:SetAutoFocus(false)
            ruleSelectorSearchBox:SetScript("OnTextChanged", function() end)

            local ruleSelectorScrollBox = CreateFrame("Frame", nil, ruleSelectorContainer, "WowScrollBoxList")
            ruleSelectorScrollBox:SetPoint("TOPLEFT", ruleSelectorContainer, "TOPLEFT", 3, -3)
            ruleSelectorScrollBox:SetPoint("BOTTOMRIGHT", ruleSelectorContainer, "BOTTOMRIGHT", -20, 3)

            local ruleSelectorScrollBar = CreateFrame("EventFrame", nil, newConfigFrame, "MinimalScrollBar")
            ruleSelectorScrollBar:SetPoint("TOPRIGHT", ruleSelectorContainer, "TOPRIGHT", -8, -6)
            ruleSelectorScrollBar:SetPoint("BOTTOMRIGHT", ruleSelectorContainer, "BOTTOMRIGHT", -8, 6)

            local ruleSelectorDataProvider = CreateDataProvider()
            local ruleSelectorScrollView = CreateScrollBoxListLinearView()
            ruleSelectorScrollView:SetDataProvider(ruleSelectorDataProvider)

            ScrollUtil.InitScrollBoxListWithScrollBar(ruleSelectorScrollBox, ruleSelectorScrollBar, ruleSelectorScrollView)

            -- The first argument here can either be a frame type or frame template. We're just passing the "UIPanelButtonTemplate" template here
            ruleSelectorScrollView:SetElementExtent(45)
            ruleSelectorScrollView:SetElementInitializer("YoinkedRuleContainerButtonTemplate",  function (button, data)
                local buttonText = data.buttonText
                button:SetText(data.itemID .. "\n" .. buttonText)
                button.ItemIcon:SetTexture(data.textureID)
                button.ItemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end)

            for i = 1, 15 do
                local myData = {
                    itemID = 191383,
                    textureID = 967534,
                    buttonText = "Elemental Potion of Ultimate Power " .. i,
                }

                ruleSelectorDataProvider:Insert(myData)
            end

            local ruleDisplayContainer = CreateFrame("Frame", "YoinkedRuleDisplayContainer", newConfigFrame, "InsetFrameTemplate3")
            ruleDisplayContainer:SetPoint("TOPLEFT", newConfigFrame, "TOPLEFT", 350, -100)
            ruleDisplayContainer:SetPoint("BOTTOMRIGHT", newConfigFrame, "BOTTOMRIGHT", -20, 20)

            
            local function createDisplayContainer(contextID)

                local itemID = 191383

                local headerString = "Yoinked" .. contexts[contextID] .. "DisplayContainer"

                local containerHeight = ruleDisplayContainer:GetHeight()-6
                local step = containerHeight/4

                local displayContainer = CreateFrame("Frame", headerString, ruleDisplayContainer, "YoinkedRuleDisplayTemplate")
                displayContainer:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -(contextID-1)*step - 3)
                displayContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -contextID*step - 3)

                local title = Sushi.Header(displayContainer, contexts[contextID])
                title:SetWidth(200)
                title:SetUnderlined(true)
                title:SetPoint('TOPLEFT', displayContainer, 'TOPLEFT', 10, -8)

                local enabled = Sushi.Check(displayContainer, 'Enabled')
                enabled:SetPoint('TOPRIGHT', displayContainer, 'TOPRIGHT', -2, -2)
                enabled:SetText("Enabled")
                enabled:SetWidth(90)
                enabled:SetCall('OnClick', function(check, mouseButton, checked)
                    if checked then
                        enabled:SetText("Enabled")
                        enabled:SetWidth(90)
                    else
                        enabled:SetText("Disabled")
                        enabled:SetWidth(90)
                    end
                end)

                local boxCap = Sushi.BoxEdit(displayContainer)
                boxCap:SetWidth(120)
                boxCap:SetPoint('TOPLEFT', displayContainer, 'TOPLEFT', 143, -60)
                boxCap:SetText("test")

                local frame = CreateFrame("Frame", nil, displayContainer)
                frame:SetPoint("BOTTOMRIGHT", boxCap, "TOPRIGHT", -2, 0)
                frame.tex = frame:CreateTexture()
                frame.tex:SetAllPoints(frame)
                frame.tex:SetTexture(413587)
                frame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                frame:SetSize(20, 20)

                local f = CreateFrame("Frame", nil, displayContainer)
                f:SetPoint("CENTER", frame, "CENTER", 0, 0)
                f:SetSize(32, 32)
                f.tex = f:CreateTexture()
                f.tex:SetAllPoints(f)
                f.tex:SetTexture("interface/spellbook/rotationiconframe")

                local arrowFrame = CreateFrame("Frame", nil, frame)
                arrowFrame:SetPoint("RIGHT", frame, "LEFT", 5, 0)
                arrowFrame.tex = arrowFrame:CreateTexture()
                arrowFrame.tex:SetAllPoints(arrowFrame)
                arrowFrame.tex:SetTexture("interface/moneyframe/arrow-right-disabled")
                arrowFrame:SetSize(16, 16)

                local frame = CreateFrame("Frame", nil, displayContainer)
                frame:SetPoint("RIGHT", arrowFrame, "LEFT", -3, 0)
                frame.tex = frame:CreateTexture()
                frame.tex:SetAllPoints(frame)
                frame.tex:SetTexture(133633)
                frame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                frame:SetSize(20, 20)

                local f = CreateFrame("Frame", nil, displayContainer)
                f:SetPoint("CENTER", frame, "CENTER", 0, 0)
                f:SetSize(32, 32)
                f.tex = f:CreateTexture()
                f.tex:SetAllPoints(f)
                f.tex:SetTexture("interface/spellbook/rotationiconframe")

                local boxYoink = Sushi.BoxEdit(displayContainer)
                boxYoink:SetWidth(120)
                boxYoink:SetPoint('TOPLEFT', displayContainer, 'TOPLEFT', 13, -60)
                boxYoink:SetText("test")

                local frame = CreateFrame("Frame", nil, displayContainer)
                frame:SetPoint("BOTTOMLEFT", boxYoink, "TOPLEFT", -2, 0)
                frame.tex = frame:CreateTexture()
                frame.tex:SetAllPoints(frame)
                frame.tex:SetTexture(413587)
                frame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                frame:SetSize(20, 20)

                local f = CreateFrame("Frame", nil, displayContainer)
                f:SetPoint("CENTER", frame, "CENTER", 0, 0)
                f:SetSize(32, 32)
                f.tex = f:CreateTexture()
                f.tex:SetAllPoints(f)
                f.tex:SetTexture("interface/spellbook/rotationiconframe")

                local arrowFrame = CreateFrame("Frame", nil, frame)
                arrowFrame:SetPoint("LEFT", frame, "RIGHT", 3, 0)
                arrowFrame.tex = arrowFrame:CreateTexture()
                arrowFrame.tex:SetAllPoints(arrowFrame)
                arrowFrame.tex:SetTexture("interface/moneyframe/arrow-right-disabled")
                arrowFrame:SetSize(16, 16)

                local frame = CreateFrame("Frame", nil, displayContainer)
                frame:SetPoint("LEFT", arrowFrame, "RIGHT", -5, 0)
                frame.tex = frame:CreateTexture()
                frame.tex:SetAllPoints(frame)
                frame.tex:SetTexture(133633)
                frame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                frame:SetSize(20, 20)

                local f = CreateFrame("Frame", nil, displayContainer)
                f:SetPoint("CENTER", frame, "CENTER", 0, 0)
                f:SetSize(32, 32)
                f.tex = f:CreateTexture()
                f.tex:SetAllPoints(f)
                f.tex:SetTexture("interface/spellbook/rotationiconframe")

            end

            for contextID = 1, 4 do
                createDisplayContainer(contextID)
            end

            newConfigFrame:SetScript("OnSizeChanged", function(frame)
                print("size changed")
                YoinkedGlobalDisplayContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -ruleDisplayContainer:GetHeight()/4)
                YoinkedClassDisplayContainer:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -ruleDisplayContainer:GetHeight()/4)
                YoinkedClassDisplayContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -ruleDisplayContainer:GetHeight()/2)
                YoinkedCharDisplayContainer:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -ruleDisplayContainer:GetHeight()/2)
                YoinkedCharDisplayContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -ruleDisplayContainer:GetHeight()*(3/4))
                YoinkedProfileDisplayContainer:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -ruleDisplayContainer:GetHeight()*(3/4))
                YoinkedProfileDisplayContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -ruleDisplayContainer:GetHeight()+3)
            end)
            
        end

        newConfigFrame:Show()

    else

        if configFrame and configFrame:IsShown() then return end

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

    --don't execute if there's an existing frame open
    
end
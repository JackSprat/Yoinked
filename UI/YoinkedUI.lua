local Sushi = LibStub('Sushi-3.2')

local newConfigFrame
local currentDisplayedID = 0
local searchFilterText

local ruleDisplayHeader, ruleDisplayIcon, ruleSelectorAddBoxHighlight, ruleSelectorScrollView

---@table<Context, Frame>
local yoinkedDisplayContainers = {}

local tooltipFrame
local helpMode = false

---@param frameInput {}|Frame
---@param text string
local function SetTooltip(frameInput, text)
    if frameInput.SetCall then
        frameInput:SetCall('OnEnter', function()
            if helpMode then 
                tooltipFrame:ClearAllPoints()
                tooltipFrame:Show()
                tooltipFrame:SetPoint('BOTTOM', frameInput, 'TOP', 0, 30)
                tooltipFrame:SetText(text)
            end
        end)
        frameInput:SetCall('OnLeave', function() tooltipFrame:Hide() end)
    else 
        frameInput:SetScript('OnEnter', function()
            if helpMode then
                tooltipFrame:ClearAllPoints()
                tooltipFrame:Show()
                tooltipFrame:SetPoint('BOTTOM', frameInput, 'TOP', 0, 30)
                tooltipFrame:SetText(text)
            end
        end)
        frameInput:SetScript('OnLeave', function() tooltipFrame:Hide() end)

    end
end

function Yoinked:OnCursorChanged()
    if ruleSelectorAddBoxHighlight then
        if CursorHasItem() then
            ruleSelectorAddBoxHighlight:Show()
        else
            ruleSelectorAddBoxHighlight:Hide()
        end
    end
end

---@param parent Frame
---@param size number
---@param texture string|number
---@return table|Frame
local function CreateBorderedIcon(parent, size, texture)
    local baseIcon = CreateFrame("Frame", nil, parent)
    baseIcon.tex = baseIcon:CreateTexture()
    baseIcon.tex:SetAllPoints(baseIcon)
    baseIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if texture then baseIcon.tex:SetTexture(texture) end
    baseIcon:SetSize(size, size)

    local borderIcon = CreateFrame("Frame", nil, baseIcon)
    borderIcon:SetPoint("CENTER", baseIcon, "CENTER", 0, 0)
    borderIcon:SetSize(size*(48/30), size*(48/30))
    borderIcon.tex = borderIcon:CreateTexture()
    borderIcon.tex:SetAllPoints(borderIcon)
    borderIcon.tex:SetTexture("interface/spellbook/rotationiconframe")

    return baseIcon
end

local function DisplayRule()

    local itemID = currentDisplayedID
    Yoinked:DebugPrint("UI", 6, "Displaying rule for " .. itemID)

    for context in pairs(YOINKED_CONTEXTS) do
        yoinkedDisplayContainers[context].SetRuleContents(Yoinked:GetRule(context, itemID))
    end

    if not ruleDisplayHeader then return end

    if itemID and itemID > 0 then
        local item = Item:CreateFromItemID(itemID)
    
        item:ContinueOnItemLoad(function()

            ruleDisplayHeader:SetText(item:GetItemName())
            ruleDisplayIcon.tex:SetTexture(item:GetItemIcon())
        end)
    else 
        ruleDisplayHeader:SetText("Select a Rule")
        ruleDisplayIcon.tex:SetTexture("")
    end

end

local function RefreshRuleSelector()
    
    local dataProvider = CreateDataProvider()
    ruleSelectorScrollView:SetDataProvider(dataProvider)
    
    for i, v in pairs(Yoinked:ConstructRuleset()) do

        if C_Item.DoesItemExistByID(i) then
            local item = Item:CreateFromItemID(i)

            item:ContinueOnItemLoad(function()

                local myData = {
                    itemID = item:GetItemID(),
                    textureID = item:GetItemIcon(),
                    buttonText = item:GetItemName()
                }

                local searchExists = not(searchFilterText == nil or searchFilterText == "")
                local itemIDMatch = false
                local itemNameMatch = false

                if searchExists then
                    Yoinked:DebugPrint("UI", 8, "Searching for: " .. searchFilterText)
                    itemIDMatch = string.find(tostring(item:GetItemID()):lower(), searchFilterText:lower(), 1, true) and true or false
                    itemNameMatch = string.find(item:GetItemName():lower(), searchFilterText:lower(), 1, true) and true or false
                end
                Yoinked:DebugPrint("UI", 8, "Item filtered: " .. item:GetItemID() .. ", " .. item:GetItemName() .. ", search string: " .. (searchFilterText and searchFilterText or "empty") .. ", id match: " .. tostring(itemIDMatch) .. ", name match: " .. tostring(itemNameMatch) .. ". Inserting? " .. tostring((not searchExists) or itemIDMatch or itemNameMatch))
                if (not searchExists) or itemIDMatch or itemNameMatch then dataProvider:Insert(myData) end

            end)

        end

    end

end
local function CreateRuleSelector()

    local ruleSelectorContainer = CreateFrame("Frame", "YoinkedRuleSelectorContainer", newConfigFrame, "InsetFrameTemplate3")
    ruleSelectorContainer:SetPoint("TOPLEFT", newConfigFrame, "TOPLEFT", 20, -100)
    ruleSelectorContainer:SetWidth(300)
    ruleSelectorContainer:SetPoint("BOTTOM", newConfigFrame, "BOTTOM", 0, 20)

    local ruleSelectorSearchBox = CreateFrame("EditBox", "YoinkedRuleSelectorSearchBox", newConfigFrame, "InputBoxTemplate")
    ruleSelectorSearchBox:SetPoint("BOTTOMLEFT", ruleSelectorContainer, "TOPLEFT", 6, 5)
    ruleSelectorSearchBox:SetSize(293, 20)
    ruleSelectorSearchBox:SetAutoFocus(false)
    ruleSelectorSearchBox:SetScript("OnTextChanged", function()
        Yoinked:DebugPrint("UI", 8, "Search text changed: " .. ruleSelectorSearchBox:GetText())
        searchFilterText = ruleSelectorSearchBox:GetText()
        RefreshRuleSelector()
    end)
    ruleSelectorSearchBox:SetText("")
    SetTooltip(ruleSelectorSearchBox, "Search the rules you have added a little easier. Can search item name or ID")

    local ruleSelectorScrollBox = CreateFrame("Frame", nil, ruleSelectorContainer, "WowScrollBoxList")
    ruleSelectorScrollBox:SetPoint("TOPLEFT", ruleSelectorContainer, "TOPLEFT", 3, -48)
    ruleSelectorScrollBox:SetPoint("BOTTOMRIGHT", ruleSelectorContainer, "BOTTOMRIGHT", -20, 3)

    local ruleSelectorScrollBar = CreateFrame("EventFrame", nil, newConfigFrame, "MinimalScrollBar")
    ruleSelectorScrollBar:SetPoint("TOPRIGHT", ruleSelectorContainer, "TOPRIGHT", -8, -51)
    ruleSelectorScrollBar:SetPoint("BOTTOMRIGHT", ruleSelectorContainer, "BOTTOMRIGHT", -8, 6)

    local ruleSelectorDataProvider = CreateDataProvider()
    ruleSelectorScrollView = CreateScrollBoxListLinearView()
    ruleSelectorScrollView:SetDataProvider(ruleSelectorDataProvider)

    ScrollUtil.InitScrollBoxListWithScrollBar(ruleSelectorScrollBox, ruleSelectorScrollBar, ruleSelectorScrollView)

    local ruleSelectorAddBox = CreateFrame("Button", "YoinkedRuleSelectorAddBox", ruleSelectorContainer, "YoinkedRuleContainerButtonTemplate")
    SetTooltip(ruleSelectorAddBox, "Drag an item here to add a rule for it")
    ruleSelectorAddBox:SetPoint("TOPLEFT", ruleSelectorContainer, "TOPLEFT", 0, -3)
    ruleSelectorAddBox:SetSize(300, 45)
    ruleSelectorAddBox.ItemIcon:SetTexture(135769)
    ruleSelectorAddBox.ItemIcon:SetPoint("CENTER", ruleSelectorAddBox, "CENTER", 0, 0)
    ruleSelectorAddBox:SetScript("OnMouseUp", function() 
        if CursorHasItem() then
            local infoType, itemID, _ = GetCursorInfo()
            Yoinked:DebugPrint("UI", 6, "Adding rule for " .. itemID)
            if infoType ~= "item" then return end
            Yoinked:DebugPrint("UI", 8, "Confirmed item: " .. itemID)
            if not itemID or not C_Item.GetItemInfo(itemID) then
                Yoinked:DebugPrint("UI", 6, "Item is not a valid item")
                return
            end
            for context, _ in pairs(YOINKED_CONTEXTS) do
                Yoinked:DebugPrint("UI", 8, "Adding rule for " .. itemID .. " in context " .. context)
                Yoinked:SetRule(context, itemID, 0, 0, 10, true, true, false)
            end

            RefreshRuleSelector()

        end

    end)

    ruleSelectorAddBoxHighlight = CreateFrame("Frame", nil, ruleSelectorAddBox)
    ruleSelectorAddBoxHighlight:SetPoint("TOPLEFT", ruleSelectorAddBox, "TOPLEFT")
    ruleSelectorAddBoxHighlight:SetSize(300, 45)
    ruleSelectorAddBoxHighlight.tex = ruleSelectorAddBoxHighlight:CreateTexture()
    ruleSelectorAddBoxHighlight.tex:SetAllPoints(ruleSelectorAddBoxHighlight)
    ruleSelectorAddBoxHighlight.tex:SetTexture("interface/addons/yoinked/assets/YOINKED-BUTTON-HIGHLIGHT-LARGE-GREEN")
    ruleSelectorAddBoxHighlight.tex:SetTexCoord(0, 0.55, 0, 0.7175)
    ruleSelectorAddBoxHighlight:Hide()

    ruleSelectorScrollView:SetElementExtent(45)
    ruleSelectorScrollView:SetElementInitializer("YoinkedRuleContainerButtonTemplate",  function (button, data)
        local buttonText = data.buttonText
        button:SetText(data.itemID .. "\n" .. buttonText)
        button.ItemIcon:SetTexture(data.textureID)
        button.ItemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button:SetScript("OnClick", function()
            currentDisplayedID = data.itemID
            DisplayRule()

        end)
    end)

    RefreshRuleSelector()

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

    tooltipFrame = Sushi.Glowbox(newConfigFrame, 'Hover for information')
    tooltipFrame:SetPoint('BOTTOM', UIParent, 'TOP', 0, 30)
    tooltipFrame:SetFrameStrata("TOOLTIP")

    local helpButton = Sushi.HelpButton(newConfigFrame)
    helpButton:SetTip('Help', 'Click to open help tooltips')
    helpButton:SetPoint('TOPRIGHT', -10, -40)
    helpButton:SetText('Hello')
    helpButton:SetCall('OnClick', function()
        helpMode = not helpMode
        tooltipFrame:SetShown(helpMode)
        tooltipFrame:SetPoint('BOTTOM', helpButton, 'TOP', 0, 30)
        if helpMode then
            tooltipFrame:SetText("Help enabled. Mouse over the interface to learn more.")
        end
    end)

end

local function CreateRuleDisplay()

    local ruleDisplayContainer = CreateFrame("Frame", "YoinkedRuleDisplayContainer", newConfigFrame, "InsetFrameTemplate3")
    ruleDisplayContainer:SetPoint("TOPLEFT", newConfigFrame, "TOPLEFT", 350, -100)
    ruleDisplayContainer:SetPoint("BOTTOMRIGHT", newConfigFrame, "BOTTOMRIGHT", -20, 20)

    ruleDisplayHeader = Sushi.Header(ruleDisplayContainer, "")
    ruleDisplayHeader:SetWidth(300)
    ruleDisplayHeader:SetUnderlined(true)
    ruleDisplayHeader:SetText("Select a Rule")
    ruleDisplayHeader:SetPoint('BOTTOMLEFT', ruleDisplayContainer, 'TOPLEFT', 50, 10)
    SetTooltip(ruleDisplayHeader, "The current item you have selected, and are viewing the rules of below")

    ruleDisplayIcon = CreateBorderedIcon(ruleDisplayHeader, 30, "")
    ruleDisplayIcon:SetPoint("RIGHT", ruleDisplayHeader, "LEFT", -18, 0)
    SetTooltip(ruleDisplayHeader, "The current icon you have selected, and are viewing the rules of below")

    local ruleDisplayDeleteButton = Sushi.RedButton(ruleDisplayContainer, "Delete")
    SetTooltip(ruleDisplayDeleteButton, "Delete the currently selected rule")
    ruleDisplayDeleteButton:SetWidth(100)
    ruleDisplayDeleteButton:SetHeight(20)
    ruleDisplayDeleteButton:SetPoint("LEFT", ruleDisplayHeader, "RIGHT", 0, 0)
    ruleDisplayDeleteButton:SetScript("OnClick", function(self)

        if currentDisplayedID and currentDisplayedID > 0 then
            Yoinked:DeleteRule(currentDisplayedID)
            currentDisplayedID = 0
            RefreshRuleSelector()
            DisplayRule()
        end
    end)

    ---@param context Context
    local function createDisplayContainer(context)

        local contextID = YOINKED_CONTEXTS[context].id
        local headerString = "Yoinked" .. YOINKED_CONTEXTS[context].displayString .. "DisplayContainer"

        local containerHeight = ruleDisplayContainer:GetHeight()-6
        local step = containerHeight/4

        local ruleDisplayContextContainer = CreateFrame("Frame", headerString, ruleDisplayContainer, "YoinkedRuleDisplayTemplate")
        ruleDisplayContextContainer:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -(contextID-1)*step - 3)
        ruleDisplayContextContainer:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -contextID*step - 3)

        yoinkedDisplayContainers[context] = ruleDisplayContextContainer

        local ruleDisplayTitle = Sushi.Header(ruleDisplayContextContainer, YOINKED_CONTEXTS[context].displayString)
        ruleDisplayTitle:SetWidth(80)
        ruleDisplayTitle:SetUnderlined(true)
        ruleDisplayTitle:SetPoint('TOPLEFT', ruleDisplayContextContainer, 'TOPLEFT', 30, -8)
        ruleDisplayTitle:SetJustifyH("RIGHT")
        SetTooltip(ruleDisplayTitle, YOINKED_CONTEXTS[context].tooltipString)

        local ruleDisplayDescription = Sushi.Header(ruleDisplayContextContainer, YOINKED_CONTEXTS[context].descriptionString)
        ruleDisplayDescription:SetWidth(150)
        ruleDisplayDescription:SetUnderlined(false)
        ruleDisplayDescription:SetPoint('TOPLEFT', ruleDisplayContextContainer, 'TOPLEFT', 120, -8)
        SetTooltip(ruleDisplayDescription, YOINKED_CONTEXTS[context].tooltipString)

        local ruleCapEditbox = Sushi.BoxEdit(ruleDisplayContextContainer)
        ruleCapEditbox:SetWidth(120)
        ruleCapEditbox:SetPoint('TOPLEFT', ruleDisplayContextContainer, 'TOPLEFT', 143, -60)
        ruleCapEditbox:SetText("")
        ruleCapEditbox:SetCall("OnText", function(boxEdit, text)
            local currentID = currentDisplayedID
            Yoinked:SetRuleBagCap(context, currentID, text)
        end)
        SetTooltip(ruleCapEditbox, "This is the bag limit. Any items over this amount will be automatically sent to the bank when you open the interface.")

        local ruleAmountEditbox = Sushi.BoxEdit(ruleDisplayContextContainer)
        ruleAmountEditbox:SetWidth(120)
        ruleAmountEditbox:SetPoint('TOPLEFT', ruleDisplayContextContainer, 'TOPLEFT', 13, -60)
        ruleAmountEditbox:SetText("")
        ruleAmountEditbox:SetCall("OnText", function(box, text)
            local currentID = currentDisplayedID
            Yoinked:SetRuleBagAmount(context, currentID, text)
        end)
        SetTooltip(ruleAmountEditbox, "This is the yoink amount. The addon will try to fill your bags to this amount.")


        local right2 = CreateBorderedIcon(ruleDisplayContextContainer, 20, 413587)
        right2:SetPoint("BOTTOMRIGHT", ruleCapEditbox, "TOPRIGHT", -2, 0)

        local arrowFrameRight = CreateFrame("Frame", nil, right2)
        arrowFrameRight:SetPoint("RIGHT", right2, "LEFT", 5, 0)
        arrowFrameRight.tex = arrowFrameRight:CreateTexture()
        arrowFrameRight.tex:SetAllPoints(arrowFrameRight)
        arrowFrameRight.tex:SetTexture("interface/moneyframe/arrow-right-disabled")
        arrowFrameRight:SetSize(16, 16)

        local right1 = CreateBorderedIcon(ruleDisplayContextContainer, 20, 133633)
        right1:SetPoint("RIGHT", arrowFrameRight, "LEFT", -3, 0)

        local left1 = CreateBorderedIcon(ruleDisplayContextContainer, 20, 413587)
        left1:SetPoint("BOTTOMLEFT", ruleAmountEditbox, "TOPLEFT", -2, 0)

        local arrowFrameLeft = CreateFrame("Frame", nil, left1)
        arrowFrameLeft:SetPoint("LEFT", left1, "RIGHT", 3, 0)
        arrowFrameLeft.tex = arrowFrameLeft:CreateTexture()
        arrowFrameLeft.tex:SetAllPoints(arrowFrameLeft)
        arrowFrameLeft.tex:SetTexture("interface/moneyframe/arrow-right-disabled")
        arrowFrameLeft:SetSize(16, 16)

        local left2 = CreateBorderedIcon(ruleDisplayContextContainer, 20, 133633)
        left2:SetPoint("LEFT", arrowFrameLeft, "RIGHT", -5, 0)

        local rulePrioritySlider = Sushi.Slider(ruleDisplayContextContainer, "Priority", 1, 1, 10, 1)
        rulePrioritySlider:SetRange(1, 10, "Low", "High")
        rulePrioritySlider:SetCall('OnValue', function(slider, value)
            local currentID = currentDisplayedID
            Yoinked:SetRulePriority(context, currentID, value)
        end)
        rulePrioritySlider:SetPoint("BOTTOMRIGHT", ruleDisplayContextContainer, "BOTTOMRIGHT", -10, 20)
        rulePrioritySlider:SetWidth(140)
        SetTooltip(rulePrioritySlider, "Rule importance. If more than one rule is enabled for an item, whichever rule has the higher priority set will be used.")

        local ruleAmountEnabledCheckbox = Sushi.Check(left2, '')
        local ruleCapEnabledCheckbox = Sushi.Check(right1, '')

        local function updateContextState()

            local contextEnabled = Yoinked:GetContextEnabled(context)
            local _, _, _, ruleEnabled, amountEnabled, capEnabled = Yoinked:GetRule(context, currentDisplayedID)

            local interactEnabled = contextEnabled and ruleEnabled

            ruleDisplayDescription:SetNormalFontObject(interactEnabled and GameFontNormalLeft or GameFontNormalLeftGrey)
            ruleDisplayTitle:SetNormalFontObject(interactEnabled and GameFontNormalLeft or GameFontNormalLeftGrey)
            
            ruleCapEditbox:SetEnabled(interactEnabled)
            ruleCapEditbox:SetShown(capEnabled)
            ruleAmountEditbox:SetEnabled(interactEnabled)
            ruleAmountEditbox:SetShown(amountEnabled)
            rulePrioritySlider:SetEnabled(interactEnabled)
            ruleAmountEnabledCheckbox:SetEnabled(interactEnabled)
            ruleAmountEnabledCheckbox:SetChecked(amountEnabled)
            ruleCapEnabledCheckbox:SetEnabled(interactEnabled)
            ruleCapEnabledCheckbox:SetChecked(capEnabled)

            left1.tex:SetDesaturated(not interactEnabled)
            left2.tex:SetDesaturated(not interactEnabled)

            right1.tex:SetDesaturated(not interactEnabled)
            right2.tex:SetDesaturated(not interactEnabled)

        end

        ruleAmountEnabledCheckbox:SetPoint('LEFT', left2, 'RIGHT', 10, 0)
        ruleAmountEnabledCheckbox:SetText("")
        ruleAmountEnabledCheckbox:SetWidth(20)
        ruleAmountEnabledCheckbox:SetCall('OnClick', function(check, mouseButton, checked)
            local currentID = currentDisplayedID
            ruleAmountEnabledCheckbox:SetWidth(20)
            Yoinked:SetRuleAmountEnabled(context, currentID, checked)
            updateContextState()
        end)
        SetTooltip(ruleAmountEnabledCheckbox, "Enable or disable this rule yoinking items from your bank.")

        ruleCapEnabledCheckbox:SetPoint('RIGHT', right1, 'LEFT', -10, 0)
        ruleCapEnabledCheckbox:SetText("")
        ruleCapEnabledCheckbox:SetWidth(20)
        ruleCapEnabledCheckbox:SetCall('OnClick', function(check, mouseButton, checked)
            local currentID = currentDisplayedID
            ruleCapEnabledCheckbox:SetWidth(20)
            Yoinked:SetRuleCapEnabled(context, currentID, checked)
            updateContextState()
        end)
        SetTooltip(ruleCapEnabledCheckbox, "Enable or disable this rule sending excess items from your bags to bank.")

        local ruleEnabledCheckbox = Sushi.Check(ruleDisplayContextContainer, 'Enabled')
        ruleEnabledCheckbox:SetPoint('TOPRIGHT', ruleDisplayContextContainer, 'TOPRIGHT', -2, -2)
        ruleEnabledCheckbox:SetText("Enabled")
        ruleEnabledCheckbox:SetWidth(90)
        ruleEnabledCheckbox:SetCall('OnClick', function(check, mouseButton, checked)
            local currentID = currentDisplayedID
            ruleEnabledCheckbox:SetText(checked and "Enabled" or "Disabled")
            ruleEnabledCheckbox:SetWidth(90)
            Yoinked:SetRuleEnabled(context, currentID, checked)
            updateContextState()
        end)
        SetTooltip(ruleEnabledCheckbox, "Enable or disable this rule pulling items from your bank.")

        ruleDisplayContextContainer.SetRuleContents = function(bagAmount, bagCap, priority, enabled, bagAmountEnabled, bagCapEnabled)
            ruleCapEditbox:SetValue(bagCap and bagCap or 0)
            ruleAmountEditbox:SetValue(bagAmount and bagAmount or 0)
            ruleEnabledCheckbox:SetValue(enabled and true or false)
            ruleEnabledCheckbox:SetText(enabled and "Enabled" or "Disabled")
            ruleEnabledCheckbox:SetWidth(90)
            rulePrioritySlider:SetValue(priority and priority or 1)
            ruleAmountEnabledCheckbox:SetValue(bagAmountEnabled and true or false)
            ruleCapEnabledCheckbox:SetValue(bagCapEnabled and true or false)

            updateContextState()
        end

        local contextEnabledState = Sushi.Check(ruleDisplayContextContainer, '')
        contextEnabledState:SetPoint('TOPLEFT', ruleDisplayContextContainer, 'TOPLEFT', 2, 0)
        contextEnabledState:SetWidth(20)
        contextEnabledState:SetChecked(Yoinked:GetContextEnabled(context))
        contextEnabledState:SetCall('OnClick', function(check, mouseButton, checked)
            contextEnabledState:SetWidth(20)
            if checked ~= nil then Yoinked:SetContextEnabled(context, checked) end
            updateContextState()
        end)
        SetTooltip(contextEnabledState, "Set if " .. context .. " rules are enabled for " .. UnitName("player"))

        updateContextState()

    end

    for context in pairs(YOINKED_CONTEXTS) do
        createDisplayContainer(context)
    end

    newConfigFrame:SetScript("OnSizeChanged", function(frame)
        local containerHeight = ruleDisplayContainer:GetHeight()-6
        local step = containerHeight/4

        for context, info in pairs(YOINKED_CONTEXTS) do
        yoinkedDisplayContainers[context]:SetPoint("TOPLEFT", ruleDisplayContainer, "TOPLEFT", 3, -(info.id-1)*step - 3)
        yoinkedDisplayContainers[context]:SetPoint("BOTTOMRIGHT", ruleDisplayContainer, "TOPRIGHT", -3, -info.id*step - 3)
        end
    end)
end

function Yoinked:CreateUIFrame()

    if newConfigFrame and newConfigFrame:IsShown() then return end
    if not newConfigFrame then

        CreateBaseUIFrame()

        CreateRuleSelector()

        CreateRuleDisplay()
        
    end

    newConfigFrame:Show()

end
---@class Yoinked: AceAddon,AceConsole-3.0,AceEvent-3.0

---@alias Context
---|"global"
---|"class"
---|"profile"
---|"char"

---@alias Rule
---|{bagAmount: number, bagCap: number, priority: number, enabled: boolean, amountEnabled: boolean, capEnabled: boolean}

---@type table<Context, table<number, string>>
YOINKED_CONTEXTS = {
    global = {
        id = 1,
        displayString = "Global",
        descriptionString = "",
        tooltipString = "These rules will be applied to every character on your account",
        contextString = "across your account."
    },
    class = {
        id = 2,
        displayString = "Class",
        descriptionString = WrapTextInColorCode(select(1, UnitClass("player")),
            C_ClassColor.GetClassColor(select(2, UnitClass("player"))):GenerateHexColor()),
        tooltipString = "These rules will be applied to every " .. select(1, UnitClass("player")) .. " on your account",
        contextString = "on every " .. select(1, UnitClass("player")) .. "."
    },
    profile = {
        id = 3,
        displayString = "Profile",
        descriptionString = "",
        tooltipString = "",
        contextString = ""
    },
    char = {
        id = 4,
        displayString = "Character",
        descriptionString = UnitName("player"),
        tooltipString = "These rules will only be applied to " .. UnitName("player"),
        contextString = "on " .. UnitName("player") .. "."
    }
}


Yoinked = LibStub("AceAddon-3.0"):NewAddon("Yoinked", "AceEvent-3.0", "AceConsole-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local bankTicker

---@type table
local extractionResults
local eventFrame

---@type table<number, table<number, {itemID: number, itemCount: number}>>
local containerCache = {}

---@param containers table<number, number>
function Yoinked:UpdateCacheItems(containers)
    for _, containerID in pairs(containers) do
        if not containerCache[containerID] then containerCache[containerID] = {} end
        for containerSlot = 1, C_Container.GetContainerNumSlots(containerID) do
            local slot = C_Container.GetContainerItemInfo(containerID, containerSlot)
            if slot then
                containerCache[containerID][containerSlot] = {
                    itemID = C_Container.GetContainerItemInfo(containerID,
                        containerSlot).itemID,
                    itemCount = C_Container.GetContainerItemInfo(containerID, containerSlot)
                        .stackCount
                }
            else
                containerCache[containerID][containerSlot] = { itemID = 0, itemCount = 0 }
            end
        end
    end
end

function Yoinked:DebugPrint(category, verbosity, ...)
    if Yoinked:GetConfigDebugEnabled() then
        local status, res = pcall(format, ...)
        local prepend = ""
        if status then
            if DLAPI then
                if category then prepend = category .. "~" end
                if verbosity then prepend = prepend .. tostring(verbosity) .. "~" end
                DLAPI.DebugLog("Yoinked", prepend .. res)
            else
                print(res)
            end
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function Yoinked:OnInitialize()
    --#TODO: Add minimap icon
    self:InitialiseDatabase()
    AceConfig:RegisterOptionsTable("Yoinked", self:GetOptions())
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("Yoinked", "Yoinked")

    self:RegisterChatCommand("Yoinked", "ChatCommand")
    self:ConstructRuleset()

    YOINKED_CONTEXTS.profile.tooltipString = "These rules will be applied to every character with the " ..
        Yoinked:GetConfigProfileName() .. " profile"
    YOINKED_CONTEXTS.profile.contextString = "when the " .. Yoinked:GetConfigProfileName() .. " profile is active."
    YOINKED_CONTEXTS.profile.descriptionString = Yoinked:GetConfigProfileName()
end

---@diagnostic disable-next-line: duplicate-set-field
function Yoinked:OnEnable()
    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            local type = ...
            if type == 8 then
                Yoinked:OnBankFrameOpened()
            end
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            local type = ...
            if type == 8 then
                Yoinked:OnBankFrameClosed()
            end
        end
    end)
    self:RegisterEvent("CURSOR_CHANGED", "OnCursorChanged")
end

---@diagnostic disable-next-line: duplicate-set-field
function Yoinked:OnDisable()
    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    self:UnregisterEvent("CURSOR_CHANGED")
end

local locations = {[0] = "Backpack", [1] = "Bag 1", [2] = "Bag 2", [3] = "Bag 3", [4] = "Bag 4", [5] = "Reagent Bag", [6] = "Bank Bag 1", [7] = "Bank Bag 2", [8] = "Bank Bag 3", [9] = "Bank Bag 4", [10] = "Bank Bag 5", [11] = "Bank Bag 6", [12] = "Bank Bag 7", [13] = "Warbank Tab 1", [14] = "Warbank Tab 2", [15] = "Warbank Tab 3", [16] = "Warbank Tab 4", [17] = "Warbank Tab 5", [-1] = "Bank", [-3] = "Reagent Bank"}

local function getLocationStrings(locationIDs)

    local locationString = ""
    for locationID, _ in pairs(locationIDs) do
        if locationString == "" then 
            locationString = locations[locationID]
        else
            locationString = locationString .. ", " .. locations[locationID]
        end
    end
    return locationString

end

function Yoinked:DisplayExtractionResults()
    Yoinked:DebugPrint("BankEvent", 6, "Displaying extraction results")
    DevTools_Dump(extractionResults)
    if #extractionResults == 0 then
        print("No items extracted")
    end
    
    for itemID, result in pairs(extractionResults) do
        local item = Item:CreateFromItemID(itemID)
        local locationsFrom = getLocationStrings(result[2])
        local locationsTo = getLocationStrings(result[3])
        item:ContinueOnItemLoad(function ()
            print("Extracted " .. result[1] .. " of item " .. item:GetItemName() .. ", moved from " .. locationsFrom .. " to " .. locationsTo)
        end)
        
    end
end

function Yoinked:ExtractionInteract(manuallyActivated)
    Yoinked:DebugPrint("BankEvent", 6, "Extraction interaction. Manual? " .. tostring(manuallyActivated))
    -- Can be called either by bank open or button click. Only run auto open if nothing else is happening, manual click determine what to do
    local autoExtract = Yoinked:GetConfigAutoExtractEnabled()

    if not autoExtract and not manuallyActivated then return end
    if (not manuallyActivated and (bankTicker or extractionResults)) then 
        Yoinked:DebugPrint("BankEvent", 6, "Auto extraction attempted while extraction in progress or completed")
            return
        end
    if bankTicker then 
        Yoinked:DebugPrint("BankEvent", 6, "Extraction running, manual interaction. Stopping extraction")
        Yoinked:StopExtraction()
        return
    end
    if extractionResults then
        Yoinked:DebugPrint("BankEvent", 6, "Extraction not running, results exist. Displaying results")
        Yoinked:DisplayExtractionResults()
        return
    end
    local containersBank = {}
    local containersBag = {}
    local containersSoulbound = {}
    --initialise enabled soulbound only containers for use as soulbound item
    if Yoinked:GetConfigBankEnabled() then
        table.insert(containersSoulbound, BANK_CONTAINER)
        table.insert(containersBank, BANK_CONTAINER)
        for i = 1, NUM_BANKBAGSLOTS do
            self:DebugPrint("BankEvent", 10,
                "Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i))
            table.insert(containersSoulbound, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i)
            table.insert(containersBank, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i)
        end
    end

    if Yoinked:GetConfigReagentBankEnabled() then
        self:DebugPrint("BankEvent", 10, "Adding bank containers " .. REAGENTBANK_CONTAINER)
        table.insert(containersSoulbound, REAGENTBANK_CONTAINER)
        table.insert(containersBank, REAGENTBANK_CONTAINER)
    end

    --initialise standard container var
    if Yoinked:GetConfigWarbankEnabled() then
        for i = 1, 5 do
            self:DebugPrint("BankEvent", 10,
                "Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS + i))
            table.insert(containersBank, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS + i)
        end
    end

    --#TODO: Add support for reagent bags
    for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        self:DebugPrint("BankEvent", 10, "Adding bag container " .. i)
        table.insert(containersBag, i)
    end

    self:UpdateCacheItems(containersBank)
    self:UpdateCacheItems(containersBag)

    local speed = Yoinked:GetConfigSpeed()
    if not speed or type(speed) ~= "number" then speed = 1 end
    extractionResults = {}
    Yoinked:DebugPrint("BankEvent", 6, "Starting Extraction")
    bankTicker = C_Timer.NewTicker(speed, function ()
        Yoinked:UpdateBankFrameState("running", speed)
        self:DebugPrint("BankEvent", 6, "Running move tick")
        if self.bankTickerRunning then bankTicker:Cancel() end
        self.bankTickerRunning = true
        local continue = self:ExtractItems(containersBank, containersBag, containersSoulbound)
        self.bankTickerRunning = false
        if not continue then Yoinked:StopExtraction() end
        Yoinked:DebugPrint("BankEvent", 6, "Move tick complete")
    end)
    
end

function Yoinked:StopExtraction()
    Yoinked:DebugPrint("BankEvent", 6, "Extraction stopped")
    if bankTicker then
        bankTicker:Cancel()
        bankTicker = nil
    end
    Yoinked:UpdateBankFrameState("finished")
end

function Yoinked:OnBankFrameOpened()
    Yoinked:DebugPrint("BankEvent", 6, "Bank frame opened")
    Yoinked:DisplayBankFrame()
    Yoinked:ExtractionInteract(false)
end

function Yoinked:OnBankFrameClosed()
    Yoinked:DebugPrint("BankEvent", 6, "Bank frame closed")
    Yoinked:StopExtraction()
    Yoinked:HideBankFrame()
    extractionResults = nil
    --TODO: update database storing of cache'd bank items
end

---@param containersBank table<number, number>
---@param containersBag table<number, number>
---@param containersSoulbound table<number, number>
function Yoinked:ExtractItems(containersBank, containersBag, containersSoulbound)
    for itemID, rule in pairs(Yoinked:ConstructRuleset()) do
        if rule.enabled then
            self:DebugPrint("BankEvent", 10, "Checking " .. itemID .. ": " .. rule.bagAmount)

            local bagCount = C_Item.GetItemCount(itemID, false, false, false, false) ---@diagnostic disable-line: redundant-parameter

            if bagCount < rule.bagAmount and rule.amountEnabled then
                local needed = rule.bagAmount - bagCount
                local bagAndBankCount = C_Item.GetItemCount(itemID, Yoinked:GetConfigBankEnabled(), false,
                    Yoinked:GetConfigReagentBankEnabled(), Yoinked:GetConfigWarbankEnabled()) ---@diagnostic disable-line: redundant-parameter
                self:DebugPrint("BankEvent", 10,
                    "Verify Bag Count (" ..
                    bagCount ..
                    ") < Bag + Bank Count (" .. bagAndBankCount .. "): " .. tostring(bagAndBankCount > bagCount))
                if bagAndBankCount > bagCount then
                    local success = self:TryMoveContainers(itemID, needed, containersBank, containersBag, nil)
                    if (success == "succeeded") then return true end
                    if (success == "nospace") then return false end
                end
            elseif bagCount > rule.bagCap and rule.capEnabled then
                local overflow = bagCount - rule.bagCap

                if overflow > 0 then
                    local success = self:TryMoveContainers(itemID, overflow, containersBag, containersBank,
                        containersSoulbound)
                    if (success == "succeeded") then return true end
                    if (success == "nospace") then return false end
                end
            end
        end
    end

    return false
end

---@param itemID number
---@param requestedAmount number
---@param containerIDsFrom table<number, number>
---@param containerIDsTo table<number, number>
---@param containerIDsToSoulbound table<number, number>|nil
---@return "succeeded"|"nospace"|"noitems"
function Yoinked:TryMoveContainers(itemID, requestedAmount, containerIDsFrom, containerIDsTo, containerIDsToSoulbound)
    self:DebugPrint("BankEvent", 6, "Withdrawing " .. itemID .. ": " .. requestedAmount)

    for _, containerIDFrom in pairs(containerIDsFrom) do
        for containerSlotFrom = 1, C_Container.GetContainerNumSlots(containerIDFrom) do
            local fromItemID = C_Container.GetContainerItemID(containerIDFrom, containerSlotFrom)
            if (fromItemID) then
                self:DebugPrint("BankEvent", 8,
                    "Checking slot " .. containerSlotFrom .. " vs " .. fromItemID)
            end
            if fromItemID == itemID then
                local foundAmount = C_Container.GetContainerItemInfo(containerIDFrom, containerSlotFrom)["stackCount"]
                local isSoulbound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(containerIDFrom, containerSlotFrom))
                local containerIDsToFiltered = (containerIDsToSoulbound and isSoulbound) and containerIDsToSoulbound or
                    containerIDsTo

                local containerIDTo, containerSlotTo, containerSlotToCapacity = self:FindEmptyOrUnfilledSlot(itemID,
                    containerIDsToFiltered)
                self:DebugPrint("BankEvent", 6, "Found empty slot at " .. containerIDTo .. ", " .. containerSlotTo)
                if not containerIDTo or not containerSlotTo or not containerSlotToCapacity then
                    return "nospace"
                end

                local toWithdraw = math.min(foundAmount, requestedAmount, containerSlotToCapacity)
                self:DebugPrint("BankEvent", 4,
                    "Moving id" ..
                    itemID ..
                    ", #" ..
                    foundAmount ..
                    "<=" ..
                    requestedAmount ..
                    " from " ..
                    containerIDFrom ..
                    "-" .. containerSlotFrom .. " (" .. toWithdraw .. ") to " .. containerIDTo .. "-" .. containerSlotTo)
                --TODO: Verify container still has cache'd item
                C_Container.SplitContainerItem(containerIDFrom, containerSlotFrom, toWithdraw)

                containerCache[containerIDFrom][containerSlotFrom].itemCount = containerCache[containerIDFrom]
                    [containerSlotFrom].itemCount - toWithdraw

                if containerCache[containerIDFrom][containerSlotFrom] == 0 then containerCache[containerIDFrom][containerSlotFrom].itemID = 0 end
                --TODO: Verify container still has open or available space
                C_Container.PickupContainerItem(containerIDTo, containerSlotTo)
                containerCache[containerIDTo][containerSlotTo].itemID = itemID
                containerCache[containerIDTo][containerSlotTo].itemCount = containerCache[containerIDTo]
                    [containerSlotTo].itemCount + toWithdraw
                ClearCursor()
                
                if extractionResults[itemID] then
                    extractionResults[itemID][1] = extractionResults[itemID][1] + toWithdraw
                    extractionResults[itemID][2][containerIDFrom] = true
                    extractionResults[itemID][3][containerIDTo] = true
                else
                    ---@type table<number, boolean>
                    local containerIDFromTable = {[containerIDFrom] = true}
                    local containerIDToTable = {[containerIDTo] = true}
                    extractionResults[itemID] = {toWithdraw, containerIDFromTable, containerIDToTable}
                end
                return "succeeded"
            end
        end
    end

    return "noitems"
end

---@param containersToSearch table<number, number>
---@return number|nil, number|nil, number|nil
function Yoinked:FindEmptySlot(containersToSearch)
    for _, bagIndex in pairs(containersToSearch) do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            if containerCache[bagIndex][slotIndex].itemID == 0 then
                return bagIndex, slotIndex, 1000
            end
        end
    end
    return nil, nil
end

---@param itemToFind number
---@param containersToSearch table<number, number>
function Yoinked:FindEmptyOrUnfilledSlot(itemToFind, containersToSearch)
    local maxStack = select(8, C_Item.GetItemInfo(itemToFind))
    self:DebugPrint("BankEvent", 6, "finding empty or unfilled for " .. itemToFind)
    for _, bagIndex in pairs(containersToSearch) do
        local bag = containerCache[bagIndex]
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local itemID = bag[slotIndex].itemID
            if itemID == itemToFind then
                self:DebugPrint("BankEvent", 8, "Found item in bag " .. bagIndex .. ": " .. itemToFind)
                local countInSlot = bag[slotIndex].itemCount
                if maxStack > countInSlot then
                    self:DebugPrint("BankEvent", 10, "Itemstack has space: " .. countInSlot .. "/" .. maxStack)
                    return bagIndex, slotIndex, maxStack - countInSlot
                end
                self:DebugPrint("BankEvent", 10, "Itemstack doesn't have space: " .. countInSlot .. "/" .. maxStack)
            end
        end
    end
    self:DebugPrint("BankEvent", 6, "Finding empty for " .. itemToFind)
    local bagIndex, slotIndex = self:FindEmptySlot(containersToSearch)
    return bagIndex, slotIndex, maxStack
end

---@param input string arguments to the slash command
function Yoinked:ChatCommand(input)
    self:CreateUIFrame()
end

---@return table options
function Yoinked:GetOptions()
    local options = {
        type = "group",
        args = {
            bankEnable = {
                name = "Bank",
                desc = "Enables searching standard character bank for items",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigBankEnabled(val) end,
                get = function (info) return Yoinked:GetConfigBankEnabled() end
            },
            warbankEnable = {
                name = "Warbank",
                desc = "Enables searching Warbank for items",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigWarbankEnabled(val) end,
                get = function (info) return Yoinked:GetConfigWarbankEnabled() end
            },
            reagentBankEnable = {
                name = "Reagent Bank",
                desc = "Enables searching Reagent Bank for items",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigReagentBankEnabled(val) end,
                get = function (info) return Yoinked:GetConfigReagentBankEnabled() end
            },
            guildBankEnable = {
                name = "Guild Bank (NYI)",
                desc = "Enables searching Guild Bank for items",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigGuildBankEnabled(val) end,
                get = function (info) return Yoinked:GetConfigGuildBankEnabled() end
            },
            reagentBagEnable = {
                name = "Prefer Reagent Bag for reagents (NYI)",
                desc = "Prioritised finding reagent bag slots if item is a reagent",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigReagentBagEnabled(val) end,
                get = function (info) return Yoinked:GetConfigReagentBagEnabled() end
            },
            debugEnable = {
                name = "Debug",
                desc = "Toggles debug messages",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigDebugEnabled(val) end,
                get = function (info) return Yoinked:GetConfigDebugEnabled() end
            },
            warbankPriorityEnable = {
                name = "Warbank Priority (NYI - does by default but will not work for non warbank items)",
                desc = "Prioritises Warbank for items that can go in the Warbank",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigWarbankPreferenceEnabled(val) end,
                get = function (info) return Yoinked:GetConfigWarbankPreferenceEnabled() end
            },
            yoinkSpeed = {
                name = "Yoink delay",
                desc =
                "Time in seconds between each Yoink - WARNING: Setting this too low may cause transfers to fail, especially if you have resource intensive bag or similar addons",
                type = "range",
                width = "full",
                min = 0.1,
                max = 5,
                softMin = 0.3,
                softMax = 2,
                bigStep = 0.05,
                set = function (info, val) Yoinked:SetConfigSpeed(val) end,
                get = function (info) return Yoinked:GetConfigSpeed() end
            },
            autoExtractEnable = {
                name = "Auto Extract",
                desc = "Automatically extract items when you open your bank",
                type = "toggle",
                width = "full",
                set = function (info, val) Yoinked:SetConfigAutoExtractEnabled(val) end,
                get = function (info) return Yoinked:GetConfigAutoExtractEnabled() end
            },
        },
    }
    return options
end

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
        id=1,
        displayString="Global",
        descriptionString = "",
        tooltipString="These rules will be applied to every character on your account",
        contextString="across your account."
    },
    class = {
        id=2,
        displayString="Class",
        descriptionString = WrapTextInColorCode(select(1, UnitClass("player")), C_ClassColor.GetClassColor(select(2, UnitClass("player"))):GenerateHexColor()),
        tooltipString="These rules will be applied to every " .. select(1, UnitClass("player")) .. " on your account",
        contextString="on every " .. select(1, UnitClass("player")) .. "."
    },
    profile = {
        id=3,
        displayString="Profile",
        descriptionString = "",
        tooltipString="",
        contextString=""
    },
    char = {
        id=4,
        displayString="Character",
        descriptionString = UnitName("player"),
        tooltipString="These rules will only be applied to " .. UnitName("player"),
        contextString="on " .. UnitName("player") .. "."
    }
}


Yoinked = LibStub("AceAddon-3.0"):NewAddon("Yoinked", "AceEvent-3.0", "AceConsole-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local bankTicker

---@type table<number, table<number, {itemID: number, itemCount: number}>>
local containerCache = {}

---@param containers table<number, number>
function Yoinked:UpdateCacheItems(containers)

    for _, containerID in pairs(containers) do
        if not containerCache[containerID] then containerCache[containerID] = {} end
        for containerSlot = 1, C_Container.GetContainerNumSlots(containerID) do
            local slot = C_Container.GetContainerItemInfo(containerID, containerSlot)
            if slot then 
                containerCache[containerID][containerSlot] = {itemID = C_Container.GetContainerItemInfo(containerID, containerSlot).itemID, itemCount = C_Container.GetContainerItemInfo(containerID, containerSlot).stackCount}
            else
                containerCache[containerID][containerSlot] = {itemID = 0, itemCount = 0}
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

function Yoinked:OnInitialize()
    --#TODO: Add minimap icon
    Yoinked:InitialiseDatabase()
    AceConfig:RegisterOptionsTable("Yoinked", self:GetOptions())
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("Yoinked", "Yoinked")

    self:RegisterChatCommand("Yoinked", "ChatCommand")
    self:ConstructRuleset()

    YOINKED_CONTEXTS.profile.tooltipString = "These rules will be applied to every character with the " .. Yoinked:GetConfigProfileName() .. " profile"
    YOINKED_CONTEXTS.profile.contextString = "when the " .. Yoinked:GetConfigProfileName() .. " profile is active."
    YOINKED_CONTEXTS.profile.descriptionString = Yoinked:GetConfigProfileName()
end

function Yoinked:OnEnable()
    self:RegisterEvent("BANKFRAME_OPENED", "OnBankFrameOpened")
    self:RegisterEvent("BANKFRAME_CLOSED", "OnBankFrameClosed")
    Yoinked:RegisterEvent("CURSOR_CHANGED", "OnCursorChanged")
end

function Yoinked:OnBankFrameOpened()

    local containersBank = {}
    local containersBag = {}
    local containersSoulbound = {}
    --initialise enabled soulbound only containers for use as soulbound item
    if Yoinked:GetConfigBankEnabled() then
        table.insert(containersSoulbound, BANK_CONTAINER)
        table.insert(containersBank, BANK_CONTAINER)
        for i = 1, NUM_BANKBAGSLOTS do
            self:DebugPrint("BankEvent", 10, "Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i))
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
            self:DebugPrint("BankEvent", 10, "Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS + i))
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
    if not bankTicker then
        bankTicker = C_Timer.NewTicker(speed, function()

            self:DebugPrint("BankEvent", 6, "Running move tick")
            if self.bankTickerRunning then bankTicker:Cancel() end
            self.bankTickerRunning = true
            local continue = self:ExtractItems(containersBank, containersBag, containersSoulbound)
            self.bankTickerRunning = false
            if not continue then bankTicker:Cancel() end

        end)
    end
end

function Yoinked:OnBankFrameClosed()

    if bankTicker then
        bankTicker:Cancel()
        bankTicker = nil
    end

    --TODO: update database storing of cache'd bank items

end

function Yoinked:ExtractItems(containersBank, containersBag, containersSoulbound)

    for itemID, rule in pairs(Yoinked:ConstructRuleset()) do
        if rule.enabled then

            self:DebugPrint("BankEvent", 10, "Checking " .. itemID .. ": " .. rule.bagAmount)
            local bagCount = C_Item.GetItemCount(itemID, false, false, false, false)

            if bagCount < rule.bagAmount and rule.amountEnabled then

                local needed = rule.bagAmount - bagCount
                local bagAndBankCount = C_Item.GetItemCount(itemID, Yoinked:GetConfigBankEnabled(), false, Yoinked:GetConfigReagentBankEnabled(), Yoinked:GetConfigWarbankEnabled())
                self:DebugPrint("BankEvent", 10, "Verify Bag Count (" .. bagCount .. ") < Bag + Bank Count (" .. bagAndBankCount .. "): " .. tostring(bagAndBankCount > bagCount))
                if bagAndBankCount > bagCount then

                    local success = self:TryMoveContainers(itemID, needed, containersBank, containersBag, nil)
                    if (success == "succeeded") then return true end
                    if (success == "nospace") then return false end

                end

            elseif bagCount > rule.bagCap and rule.capEnabled then

                local overflow = bagCount - rule.bagCap

                if overflow > 0 then

                    local success = self:TryMoveContainers(itemID, overflow, containersBag, containersBank, containersSoulbound)
                    if (success == "succeeded") then return true end
                    if (success == "nospace") then return false end

                end

            end

        end
    end

    return false

end

function Yoinked:TryMoveContainers(itemID, requestedAmount, containerIDsFrom, containerIDsTo, containerIDsToSoulbound)

    self:DebugPrint("BankEvent", 6, "Withdrawing " .. itemID .. ": " .. requestedAmount)

    for _, containerIDFrom in pairs(containerIDsFrom) do
        for containerSlotFrom = 1, C_Container.GetContainerNumSlots(containerIDFrom) do
            local fromItemID = C_Container.GetContainerItemID(containerIDFrom, containerSlotFrom)
            if (fromItemID) then self:DebugPrint("BankEvent", 8, "Checking slot " .. containerSlotFrom .. " vs " .. fromItemID) end
            if fromItemID == itemID then

                local foundAmount = C_Container.GetContainerItemInfo(containerIDFrom, containerSlotFrom)["stackCount"]
                local isSoulbound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(containerIDFrom, containerSlotFrom))

                local containerIDsToFiltered = (containerIDsToSoulbound and isSoulbound) and containerIDsToSoulbound or containerIDsTo

                local containerIDTo, containerSlotTo, containerSlotToCapacity = self:FindEmptyOrUnfilledSlot(itemID, containerIDsToFiltered)
                self:DebugPrint("BankEvent", 6, "Found empty slot at " .. containerIDTo .. ", " .. containerSlotTo)
                if not containerIDTo or not containerSlotTo or not containerSlotToCapacity then
                    return "nospace"
                end

                local toWithdraw = math.min(foundAmount, requestedAmount, containerSlotToCapacity)
                self:DebugPrint("BankEvent", 4, "Moving id" .. itemID .. ", #".. foundAmount .. "<=" .. requestedAmount .. " from " .. containerIDFrom .. "-" .. containerSlotFrom .. " (" .. toWithdraw .. ") to " .. containerIDTo .. "-" .. containerSlotTo)
                --TODO: Verify container still has cache'd item
                C_Container.SplitContainerItem(containerIDFrom, containerSlotFrom, toWithdraw)

                containerCache[containerIDFrom][containerSlotFrom].itemCount = containerCache[containerIDFrom][containerSlotFrom].itemCount - toWithdraw

                if containerCache[containerIDFrom][containerSlotFrom] == 0 then containerCache[containerIDFrom][containerSlotFrom].itemID = 0 end
                --TODO: Verify container still has open or available space
                C_Container.PickupContainerItem(containerIDTo, containerSlotTo)
                containerCache[containerIDTo][containerSlotTo].itemID = itemID
                containerCache[containerIDTo][containerSlotTo].itemCount = containerCache[containerIDTo][containerSlotTo].itemCount + toWithdraw
                ClearCursor()
                return "succeeded"
            end
        end
    end

    return "noitems"
end

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

function Yoinked:ChatCommand(input)
    self:CreateUIFrame()
end

function Yoinked:GetOptions()

    local options = {
        type = "group",
        args = {
            bankEnable = {
                name = "Bank",
                desc = "Enables searching standard character bank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigBankEnabled(val) end,
                get = function(info) return Yoinked:GetConfigBankEnabled() end
            },
            warbankEnable = {
                name = "Warbank",
                desc = "Enables searching Warbank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigWarbankEnabled(val) end,
                get = function(info) return Yoinked:GetConfigWarbankEnabled() end
            },
            reagentBankEnable = {
                name = "Reagent Bank",
                desc = "Enables searching Reagent Bank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigReagentBankEnabled(val) end,
                get = function(info) return Yoinked:GetConfigReagentBankEnabled() end
            },
            guildBankEnable = {
                name = "Guild Bank (NYI)",
                desc = "Enables searching Guild Bank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigGuildBankEnabled(val) end,
                get = function(info) return Yoinked:GetConfigGuildBankEnabled() end
            },
            reagentBagEnable = {
                name = "Prefer Reagent Bag for reagents (NYI)",
                desc = "Prioritised finding reagent bag slots if item is a reagent",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigReagentBagEnabled(val) end,
                get = function(info) return Yoinked:GetConfigReagentBagEnabled() end
            },
            debugEnable = {
                name = "Debug",
                desc = "Toggles debug messages",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigDebugEnabled(val) end,
                get = function(info) return Yoinked:GetConfigDebugEnabled() end
            },
            warbankPriorityEnable = {
                name = "Warbank Priority (NYI - does by default but will not work for non warbank items)",
                desc = "Prioritises Warbank for items that can go in the Warbank",
                type = "toggle",
                width = "full",
                set = function(info,val) Yoinked:SetConfigWarbankPreferenceEnabled(val) end,
                get = function(info) return Yoinked:GetConfigWarbankPreferenceEnabled() end
            },
            yoinkSpeed = {
                name = "Yoink delay",
                desc = "Time in seconds between each Yoink - WARNING: Setting this too low may cause transfers to fail, especially if you have resource intensive bag or similar addons",
                type = "range",
                width = "full",
                min = 0.1,
                max = 5,
                softMin = 0.3,
                softMax = 2,
                bigStep = 0.05,
                set = function(info,val) Yoinked:SetConfigSpeed(val) end,
                get = function(info) return Yoinked:GetConfigSpeed() end
            },
        },
    }
    return options
end
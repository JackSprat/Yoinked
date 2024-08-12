---@class Yoink: AceAddon,AceConsole-3.0,AceEvent-3.0
Yoinked = LibStub("AceAddon-3.0"):NewAddon("Yoinked", "AceEvent-3.0", "AceConsole-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local defaults = {
    profile = {
        --#TODO: refactor variables to be safer and more descriptive
        enabled = true,
        debug = false,
        bank = true,
        warbank = true,
        reagentbank = true,
        reagentbag = false,
        guildbank = false,
        --#TODO: Implement settings to ignore banks
        backpack = true,
        bag1 = true,
        bag2 = true,
        bag3 = true,
        bag4 = true,
        --#TODO: Implement setting to prefer depositing warband compatible items into the warbank
        preferWarbank = true,

        --#TODO: Plan whether rules should be per profile, even if global
        rules = {

        }
    },
    global = {
        enabled = true,
        rules = {
            [207023] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false},
            [191383] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false}
        },
        --#TODO: Implement warbank saved data structure
        --#TODO: Implement guild bank saved data structure
        warbankSaved = {
            
        }
    },
    char = {
        addonEnabled = true,
        enabled = true,
        rules = {

        }
        --#TODO: Implement character bank saved data structure
    },
    class = {
        enabled = true,
        rules = {

        }
    }
}

local assembledRules = {}
local containerCache = {}

function Yoinked:DebugPrint(...)
    if self.db.profile.debug then
		local status, res = pcall(format, ...)
		if status then
			if DLAPI then
                DLAPI.DebugLog("Yoinked", ...)
            else
                print(res)
            end
		end
	end
end

function Yoinked:DebugLog()

end

function Yoinked:OnInitialize()
    --#TODO: Add minimap icon
    self.db = LibStub("AceDB-3.0"):New("YYoinkedDB", defaults, true)
    AceConfig:RegisterOptionsTable("Yoinked", self:GetOptions())
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("Yoinked", "Yoinked")

    self:RegisterChatCommand("Yoinked", "ChatCommand")
end

function Yoinked:OnEnable()
    self:RegisterEvent("BANKFRAME_OPENED", "OnBankFrameOpened")

end

function Yoinked:ConstructRules()
    local contexts = {"global", "class", "profile", "char"}
    for _,context in pairs(contexts) do
        if self.db[context] and self.db[context].rules then
            for itemID, rule in pairs(self.db[context].rules) do
                if assembledRules[itemID] then
                    if rule.priority >= assembledRules[itemID].priority then assembledRules[itemID] = rule end
                else
                    assembledRules[itemID] = rule
                end
            end
        end
    end
end

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

function Yoinked:OnBankFrameOpened()

    local containersBank = {}
    local containersBag = {}
    local containersSoulbound = {}
    --initialise enabled soulbound only containers for use as soulbound item
    if self.db.profile.bank then
        table.insert(containersSoulbound, BANK_CONTAINER)
        for i = 1, NUM_BANKBAGSLOTS do
            self:DebugPrint("Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i))
            table.insert(containersSoulbound, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i)
        end
    end

    if self.db.profile.reagentbank then
        self:DebugPrint("Adding bank container " .. REAGENTBANK_CONTAINER)
        table.insert(containersSoulbound, REAGENTBANK_CONTAINER)
    end

    --initialise standard container var
    if self.db.profile.warbank then
        for i = 1, 5 do
            self:DebugPrint("Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS + i))
            table.insert(containersBank, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + NUM_BANKBAGSLOTS + i)
        end
    end
    if self.db.profile.bank then
        table.insert(containersBank, BANK_CONTAINER)
        for i = 1, NUM_BANKBAGSLOTS do
            self:DebugPrint("Adding bank container " .. (BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i))
            table.insert(containersBank, BACKPACK_CONTAINER + ITEM_INVENTORY_BANK_BAG_OFFSET + i)
        end
    end

    

    if self.db.profile.reagentbank then
        self:DebugPrint("Adding bank container " .. REAGENTBANK_CONTAINER)
        table.insert(containersBank, REAGENTBANK_CONTAINER)
    end

    --#TODO: Add support for reagent bags
    for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        self:DebugPrint("Adding bag container " .. i)
        table.insert(containersBag, i)
    end

    self:UpdateCacheItems(containersBank)
    self:UpdateCacheItems(containersBag)

    --#TODO: add dirty flag to save updating rules
    self:ConstructRules()

    if (self.db.profile.debug) then
        for i, container in pairs(containerCache) do
            for j, slot in pairs(container) do
                if slot.itemID > 0 then self:DebugPrint("container " .. i .. ", slot " .. j .. ", item, " .. slot.itemID .. ", count " .. slot.itemCount) end
            end
        end
    end

    BankTicker = C_Timer.NewTicker(0.5, function()

        self:DebugPrint("extracting")
        if self.bankTickerRunning then BankTicker:Cancel() end
        self.bankTickerRunning = true
        local continue = self:ExtractItems(containersBank, containersBag, containersSoulbound)
        self.bankTickerRunning = false
        if not continue then BankTicker:Cancel() end

    end)

end

function Yoinked:ExtractItems(containersBank, containersBag, containersSoulbound)

    for itemID, rule in pairs(assembledRules) do
        if rule.enabled then

            self:DebugPrint("Checking " .. itemID .. ": " .. rule.bagAmount)
            local bagCount = C_Item.GetItemCount(itemID, false, false, false, false)

            if bagCount < rule.bagAmount then

                local needed = rule.bagAmount - bagCount
                local bagAndBankCount = C_Item.GetItemCount(itemID, self.db.profile.bank, false, self.db.profile.reagentbank, self.db.profile.warbank)
                self:DebugPrint("Verify Bag Count (" .. bagCount .. ") < Bag + Bank Count (" .. bagAndBankCount .. "): " .. tostring(bagAndBankCount > bagCount))
                if bagAndBankCount > bagCount then

                    local success = self:TryMoveContainers(itemID, needed, containersBank, containersBag, nil)
                    if (success == "succeeded") then return true end
                    if (success == "nospace") then return false end

                end

            elseif bagCount > rule.bagCap then

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

    self:DebugPrint("Withdrawing " .. itemID .. ": " .. requestedAmount)

    for _, containerIDFrom in pairs(containerIDsFrom) do
        for containerSlotFrom = 1, C_Container.GetContainerNumSlots(containerIDFrom) do
            local fromItemID = C_Container.GetContainerItemID(containerIDFrom, containerSlotFrom)
            if (fromItemID) then self:DebugPrint("checking slot " .. containerSlotFrom .. " vs " .. fromItemID) end
            if fromItemID == itemID then

                self:DebugPrint ("match found")
                local foundAmount = C_Container.GetContainerItemInfo(containerIDFrom, containerSlotFrom)["stackCount"]
                local isSoulbound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(containerIDFrom, containerSlotFrom))

                local containerIDsToFiltered = (containerIDsToSoulbound and isSoulbound) and containerIDsToSoulbound or containerIDsTo

                local containerIDTo, containerSlotTo, containerSlotToCapacity = self:FindEmptyOrUnfilledSlot(itemID, containerIDsToFiltered)
                print(containerIDTo .. "-" .. containerSlotTo)
                self:DebugPrint("Found empty slot at " .. containerIDTo .. ", " .. containerSlotTo)
                if not containerIDTo or not containerSlotTo or not containerSlotToCapacity then
                    return "nospace"
                end

                
                local toWithdraw = math.min(foundAmount, requestedAmount, containerSlotToCapacity)
                self:DebugPrint("Moving id" .. itemID .. ", #".. foundAmount .. "<=" .. requestedAmount .. " from " .. containerIDFrom .. "-" .. containerSlotFrom .. " (" .. toWithdraw .. ") to " .. containerIDTo .. "-" .. containerSlotTo)
                C_Container.SplitContainerItem(containerIDFrom, containerSlotFrom, toWithdraw)
                containerCache[containerIDFrom][containerSlotFrom].itemCount = containerCache[containerIDFrom][containerSlotFrom].itemCount - toWithdraw
                if containerCache[containerIDFrom][containerSlotFrom] == 0 then containerCache[containerIDFrom][containerSlotFrom].itemID = 0 end
                C_Container.PickupContainerItem(containerIDTo, containerSlotTo)
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
    self:DebugPrint("finding empty or unfilled for " .. itemToFind)
    for _, bagIndex in pairs(containersToSearch) do
        local bag = containerCache[bagIndex]
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local itemID = bag[slotIndex].itemID
            if itemID == itemToFind then
                self:DebugPrint("found item in bag " .. bagIndex .. ": " .. itemToFind)
                local countInSlot = bag[slotIndex].itemCount
                if maxStack > countInSlot then
                    self:DebugPrint("Itemstack has space: " .. countInSlot .. "/" .. maxStack)
                    return bagIndex, slotIndex, maxStack - countInSlot
                end
                self:DebugPrint("Itemstack doesn't have space: " .. countInSlot .. "/" .. maxStack)
            end
        end
    end
    self:DebugPrint("Finding empty for " .. itemToFind)
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
                set = function(info,val) self.db.profile.bank = val end,
                get = function(info) return self.db.profile.bank end
            },
            warbankEnable = {
                name = "Warbank",
                desc = "Enables searching Warbank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.warbank = val end,
                get = function(info) return self.db.profile.warbank end
            },
            reagentBankEnable = {
                name = "Reagent Bank",
                desc = "Enables searching Reagent Bank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.reagentbank = val end,
                get = function(info) return self.db.profile.reagentbank end
            },
            guildBankEnable = {
                name = "Guild Bank (NYI)",
                desc = "Enables searching Guild Bank for items",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.guildbank = val end,
                get = function(info) return self.db.profile.guildbank end
            },
            reagentBagEnable = {
                name = "Prefer Reagent Bag for reagents (NYI)",
                desc = "Prioritised finding reagent bag slots if item is a reagent",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.reagentbag = val end,
                get = function(info) return self.db.profile.reagentbag end
            },
            debugEnable = {
                name = "Debug",
                desc = "Toggles debug messages",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.debug = val end,
                get = function(info) return self.db.profile.debug end
            },
            warbankPriorityEnable = {
                name = "Warbank Priority (NYI - does by default but will not work for non warbank items)",
                desc = "Prioritises Warbank for items that can go in the Warbank",
                type = "toggle",
                width = "full",
                set = function(info,val) self.db.profile.preferWarbank = val end,
                get = function(info) return self.db.profile.preferWarbank end
            },
        },
    }
    return options
end
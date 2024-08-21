local db
local assembledRules = {}
local assembledRulesDirtyFlag = true

local defaults = {
    profile = {
        --#TODO: refactor variables to be safer and more descriptive
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
        yoinkSpeed = 0.7,
        configX = 0,
        configY = 0,
        configWidth = 0,
        configHeight = 0,
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = true, amountEnabled = true, capEnabled = false}
        }
    },
    global = {
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = true, amountEnabled = true, capEnabled = false},
            [207023] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false, amountEnabled = false, capEnabled = false},
            [191383] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false, amountEnabled = false, capEnabled = false}
        },
        deletedItems = {

        },
        --#TODO: Implement warbank saved data structure
        --#TODO: Implement guild bank saved data structure
        warbankSaved = {
            
        }
    },
    char = {
        charEnabled = true,
        classEnabled = true,
        globalEnabled = true,
        profileEnabled = true,
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = true, amountEnabled = true, capEnabled = false}
        }
        --#TODO: Implement character bank saved data structure
    },
    class = {
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = true, amountEnabled = true, capEnabled = false}
        }
    }
}

function Yoinked:InitialiseDatabase()
    Yoinked:DebugPrint("Database", 6, "Initialising database")
    db = LibStub("AceDB-3.0"):New("YoinkedDB", defaults, true)
end

---@return string profile
function Yoinked:GetConfigProfileName()
    return db:GetCurrentProfile()
end

---@param context Context
---@param itemID number
---@return number bagAmount
---@return number bagCap
---@return number priority
---@return boolean enabled
---@return boolean amountEnabled
---@return boolean capEnabled
function Yoinked:GetRule(context, itemID)
    if db.global.deletedItems[itemID] then return 0, 0, 1, false, false, false end
    local rule = db[context].rules[itemID]
    return rule.bagAmount, rule.bagCap, rule.priority, rule.enabled, rule.amountEnabled, rule.capEnabled
end

---@param itemID number
---@return boolean exists
function Yoinked:GetRuleExists(itemID)
    return not db.global.deletedItems[itemID] and db.global.rules[itemID] ~= nil
end


---@param context Context
---@param itemID number
---@param bagAmount number
---@param bagCap number
---@param priority number
---@param enabled boolean
---@param amountEnabled boolean
---@param capEnabled boolean
---@return boolean success
function Yoinked:SetRule(context, itemID, bagAmount, bagCap, priority, enabled, amountEnabled, capEnabled)
    if not db[context] then return false end
    if db.global.deletedItems then db.global.deletedItems[itemID] = nil end
    local success = true
    success = success and self:SetRuleBagAmount(context, itemID, bagAmount)
    success = success and self:SetRuleBagCap(context, itemID, bagCap)
    success = success and self:SetRulePriority(context, itemID, priority)
    success = success and self:SetRuleEnabled(context, itemID, enabled)
    success = success and self:SetRuleAmountEnabled(context, itemID, amountEnabled)
    success = success and self:SetRuleCapEnabled(context, itemID, capEnabled)
    assembledRulesDirtyFlag = true
    return success
end

---@param context Context
---@param itemID number
---@param bagAmount number
---@return boolean success
function Yoinked:SetRuleBagAmount(context, itemID, bagAmount)
    local value = tonumber(bagAmount)
    if not db[context] or not value then return false end
    db[context].rules[itemID].bagAmount = value
    assembledRulesDirtyFlag = true
    return true
end

---@param context Context
---@param itemID number
---@param bagCap number
---@return boolean success
function Yoinked:SetRuleBagCap(context, itemID, bagCap)
    local value = tonumber(bagCap)
    if not db[context] or not value then return false end
    db[context].rules[itemID].bagCap = value
    assembledRulesDirtyFlag = true
    return true
end

---@param context Context
---@param itemID number
---@param priority number
---@return boolean success
function Yoinked:SetRulePriority(context, itemID, priority)
    local value = tonumber(priority)
    if not db[context] or not value or value < 1 or value > 10 then return false end
    db[context].rules[itemID].priority = value
    assembledRulesDirtyFlag = true
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean success
function Yoinked:SetRuleEnabled(context, itemID, enabled)
    if not db[context] then return false end
    db[context].rules[itemID].enabled = enabled
    assembledRulesDirtyFlag = true
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean success
function Yoinked:SetRuleAmountEnabled(context, itemID, enabled)
    if not db[context] then return false end
    db[context].rules[itemID].amountEnabled = enabled
    assembledRulesDirtyFlag = true
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean success
function Yoinked:SetRuleCapEnabled(context, itemID, enabled)
    if not db[context] then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = 20, priority = 1, enabled = false, amountEnabled = false, capEnabled = enabled} end
    db[context].rules[itemID].capEnabled = enabled
    assembledRulesDirtyFlag = true
    return true
end

---@param itemID number
function Yoinked:DeleteRule(itemID)
    db.global.rules[itemID] = nil
    db.class.rules[itemID] = nil
    db.profile.rules[itemID] = nil
    db.char.rules[itemID] = nil
    db.global.deletedItems[itemID] = true
    assembledRules[itemID] = nil
    assembledRulesDirtyFlag = true
end


---@return table<number, Rule>
function Yoinked:ConstructRuleset()
    if assembledRulesDirtyFlag then
        for context in pairs(YOINKED_CONTEXTS) do
            if self:GetContextEnabled(context) then 
                for itemID, rule in pairs(db[context].rules) do
                    if not db.global.deletedItems[itemID] then
                    if assembledRules[itemID] then
                        if rule.priority >= assembledRules[itemID].priority then assembledRules[itemID] = rule end
                    else
                        assembledRules[itemID] = rule
                    end
                end
                end
            end
        end
    end
    assembledRulesDirtyFlag = false
    return assembledRules
end

---@param context Context
---@return boolean contextEnabled
function Yoinked:GetContextEnabled(context)
    if (not db.char) or (not db.char[context .. "Enabled"]) then return false end
    return db.char[context .. "Enabled"]
end

---@param context Context
---@param enabled boolean
function Yoinked:SetContextEnabled(context, enabled)
    if not db.char then db.char = {} end
    db.char[context .. "Enabled"] = enabled
    assembledRulesDirtyFlag = true
end

---@return boolean debugEnabled
function Yoinked:GetConfigDebugEnabled()
    return db.profile.debug
end

---@param enabled boolean
function Yoinked:SetConfigDebugEnabled(enabled)
    db.profile.debug = enabled
end

---@return boolean bankEnabled
function Yoinked:GetConfigBankEnabled()
    return db.profile.bank
end

---@param enabled boolean
function Yoinked:SetConfigBankEnabled(enabled)
    db.profile.bank = enabled
end

---@return boolean warbankEnabled
function Yoinked:GetConfigWarbankEnabled()
    return db.profile.warbank
end

---@param enabled boolean
function Yoinked:SetConfigWarbankEnabled(enabled)
    db.profile.warbank = enabled
end

---@return boolean reagentBankEnabled
function Yoinked:GetConfigReagentBankEnabled()
    return db.profile.reagentbank
end

---@param enabled boolean
function Yoinked:SetConfigReagentBankEnabled(enabled)
    db.profile.reagentbank = enabled
end

---@return number speed
function Yoinked:GetConfigSpeed()
    return db.profile.yoinkSpeed
end

---@param speed number
function Yoinked:SetConfigSpeed(speed)
    db.profile.yoinkSpeed = speed
end

---@return boolean guildBankEnabled
function Yoinked:GetConfigGuildBankEnabled()
    --TODO implement guild bank
    return false
end

---@param enabled boolean
function Yoinked:SetConfigGuildBankEnabled(enabled)
    --TODO implement guild bank
end

---@return boolean reagentBagEnabled
function Yoinked:GetConfigReagentBagEnabled()
    return db.profile.reagentbag
end

---@param enabled boolean
function Yoinked:SetConfigReagentBagEnabled(enabled)
    db.profile.reagentbag = enabled
end

---@return boolean warbankPreferenceEnabled
function Yoinked:GetConfigWarbankPreferenceEnabled()
    --TODO implement guild bank
    return false
end

---@param enabled boolean
function Yoinked:SetConfigWarbankPreferenceEnabled(enabled)
    --TODO implement guild bank
end
local db

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
        --#TODO: Plan whether rules should be per profile, even if global
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = false, amountEnabled = false, capEnabled = false}
        }
    },
    global = {
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = false, amountEnabled = false, capEnabled = false},
            [207023] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false, amountEnabled = false, capEnabled = false},
            [191383] = {bagAmount = 20, bagCap = 20, priority = 10, enabled = false, amountEnabled = false, capEnabled = false}
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
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = false, amountEnabled = false, capEnabled = false}
        }
        --#TODO: Implement character bank saved data structure
    },
    class = {
        rules = {
            ['**'] = {bagAmount = 0, bagCap = 0, priority = 1, enabled = false, amountEnabled = false, capEnabled = false}
        }
    }
}

function Yoinked:InitialiseDatabase()
    Yoinked:DebugPrint("Database", 6, "Initialising database")
    db = LibStub("AceDB-3.0"):New("YoinkedDB", defaults, true)
end

---@return string
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
    if (not db[context]) or (not db[context].rules) or (not db[context].rules[itemID]) then return 0, 0, 1, false, false, false end
    local rule = db[context].rules[itemID]
    return rule.bagAmount, rule.bagCap, rule.priority, rule.enabled, rule.amountEnabled, rule.capEnabled
end

---@param itemID number
---@return boolean
function Yoinked:GetRuleExists(itemID)
    return db.global.rules[itemID] ~= nil
end

function Yoinked:GetAllRules(context)
    if (not db[context]) or (not db[context].rules) then return {} end
    return db[context].rules
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
    local success = true
    success = success and self:SetRuleBagAmount(context, itemID, bagAmount)
    success = success and self:SetRuleBagCap(context, itemID, bagCap)
    success = success and self:SetRulePriority(context, itemID, priority)
    success = success and self:SetRuleEnabled(context, itemID, enabled)
    success = success and self:SetRuleAmountEnabled(context, itemID, amountEnabled)
    success = success and self:SetRuleCapEnabled(context, itemID, capEnabled)
    return success
end

---@param context Context
---@param itemID number
---@param bagAmount number
---@return boolean
function Yoinked:SetRuleBagAmount(context, itemID, bagAmount)
    local value = tonumber(bagAmount)
    if not db[context] or not value then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = value, bagCap = 20, priority = 1, enabled = false, amountEnabled = false, capEnabled = false} end
    db[context].rules[itemID].bagAmount = value
    return true
end

---@param context Context
---@param itemID number
---@param bagCap number
---@return boolean
function Yoinked:SetRuleBagCap(context, itemID, bagCap)
    local value = tonumber(bagCap)
    if not db[context] or not value then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = value, priority = 1, enabled = false, amountEnabled = false, capEnabled = false} end
    db[context].rules[itemID].bagCap = value
    return true
end

---@param context Context
---@param itemID number
---@param priority number
---@return boolean
function Yoinked:SetRulePriority(context, itemID, priority)
    local value = tonumber(priority)
    if not db[context] or not value or value < 1 or value > 10 then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = 20, priority = value, enabled = false, amountEnabled = false, capEnabled = false} end
    db[context].rules[itemID].priority = value
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean
function Yoinked:SetRuleEnabled(context, itemID, enabled)
    if not db[context] then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = 20, priority = 1, enabled = enabled, amountEnabled = false, capEnabled = false} end
    db[context].rules[itemID].enabled = enabled
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean
function Yoinked:SetRuleAmountEnabled(context, itemID, enabled)
    if not db[context] then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = 20, priority = 1, enabled = false, amountEnabled = enabled, capEnabled = false} end
    db[context].rules[itemID].amountEnabled = enabled
    return true
end

---@param context Context
---@param itemID number
---@param enabled boolean
---@return boolean
function Yoinked:SetRuleCapEnabled(context, itemID, enabled)
    if not db[context] then return false end
    if not db[context].rules[itemID] then db[context].rules[itemID] = {bagAmount = 20, bagCap = 20, priority = 1, enabled = false, amountEnabled = false, capEnabled = enabled} end
    db[context].rules[itemID].capEnabled = enabled
    return true
end

local assembledRules = {}
---@return table<number, Rule>
function Yoinked:ConstructRuleset()

    for context in pairs(YOINKED_CONTEXTS) do

        if self:GetContextEnabled(context) then
            for itemID, rule in pairs(db[context].rules) do
                if assembledRules[itemID] then
                    if rule.priority >= assembledRules[itemID].priority then assembledRules[itemID] = rule end
                else
                    assembledRules[itemID] = rule
                end
            end
        end
    end
    return assembledRules
end

---@return table<number, Rule>
function Yoinked:GetRuleset()
    if #assembledRules > 0 then return assembledRules else return Yoinked:ConstructRuleset() end
end



---@param context Context
---@return boolean
function Yoinked:GetContextEnabled(context)
    if (not db.char) or (not db.char[context .. "Enabled"]) then return false end
    return db.char[context .. "Enabled"]
end

---@param context Context
---@param enabled boolean
function Yoinked:SetContextEnabled(context, enabled)
    if not db.char then db.char = {} end
    db.char[context .. "Enabled"] = enabled
end

---@return boolean
function Yoinked:GetConfigDebugEnabled()
    if true then return true end
    return db.profile.debug
end

---@param enabled boolean
function Yoinked:SetConfigDebugEnabled(enabled)
    db.profile.debug = enabled
end

---@return boolean
function Yoinked:GetConfigBankEnabled()
    return db.profile.bank
end

---@param enabled boolean
function Yoinked:SetConfigBankEnabled(enabled)
    db.profile.bank = enabled
end

---@return boolean
function Yoinked:GetConfigWarbankEnabled()
    return db.profile.warbank
end

---@param enabled boolean
function Yoinked:SetConfigWarbankEnabled(enabled)
    db.profile.warbank = enabled
end

---@return boolean
function Yoinked:GetConfigReagentBankEnabled()
    return db.profile.reagentbank
end

---@param enabled boolean
function Yoinked:SetConfigReagentBankEnabled(enabled)
    db.profile.reagentbank = enabled
end

---@return number
function Yoinked:GetConfigSpeed()
    return db.profile.yoinkSpeed
end

---@param speed number
function Yoinked:SetConfigSpeed(speed)
    db.profile.yoinkSpeed = speed
end

---@return boolean
function Yoinked:GetConfigGuildBankEnabled()
    --TODO implement guild bank
    return false
end

---@param enabled boolean
function Yoinked:SetConfigGuildBankEnabled(enabled)
    --TODO implement guild bank
end

---@return boolean
function Yoinked:GetConfigReagentBagEnabled()
    return db.profile.reagentbag
end

---@param enabled boolean
function Yoinked:SetConfigReagentBagEnabled(enabled)
    db.profile.reagentbag = enabled
end

---@return boolean
function Yoinked:GetConfigWarbankPreferenceEnabled()
    --TODO implement guild bank
    return false
end

---@param enabled boolean
function Yoinked:SetConfigWarbankPreferenceEnabled(enabled)
    --TODO implement guild bank
end
local internal = {
    lootThreshold = 10,
    isLooting = false,
    lastNumLoot = nil,
    lootTicker = nil,
    initialAutoLootState = nil,
}

local EnumLootSlotItem = Enum.LootSlotType.Item
local EnumLootSlotTypeNone = Enum.LootSlotType.None
local EnumBagIndexKeyring = Enum.BagIndex.Keyring
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC

local function ProcessLootItem(itemLink, itemQuantity)
    local itemStackCount, _, _, _, _, _, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(itemLink))
    local itemFamily = C_Item.GetItemFamily(itemLink)

    if isClassicEra and itemFamily == 256 then
        local freeKeyringSlots = C_Container.GetContainerNumFreeSlots(EnumBagIndexKeyring)
        if freeKeyringSlots > 0 then return true end
    end

    local inventoryItemCount = C_Item.GetItemCount(itemLink)
    if inventoryItemCount > 0 and itemStackCount > 1 then
        if ((itemStackCount - inventoryItemCount) % itemStackCount) >= itemQuantity then
            return true
        end
    end

    for bagSlot = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagSlot)
        if freeSlots > 0 then
            if bagSlot == 5 then
                if isCraftingReagent then return true else return false end
            end
            if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
                return true
            end
        end
    end
    return false
end

local function LootSlot(slot)
    local slotType = GetLootSlotType(slot)
    if slotType == EnumLootSlotTypeNone then return true end

    local itemLink = GetLootSlotLink(slot)
    local lootQuantity, _, lootQuality, lootLocked, isQuestItem = select(3, GetLootSlotInfo(slot))

    if lootLocked or (lootQuality and lootQuality >= internal.lootThreshold) then
        return false
    elseif slotType ~= EnumLootSlotItem or isQuestItem or ProcessLootItem(itemLink, lootQuantity) then
        _G.LootSlot(slot)
        return true
    end
    return false
end

local function CancelLootTicker()
    if internal.lootTicker then
        internal.lootTicker:Cancel()
        internal.lootTicker = nil
    end
end

local function StartLooting(numItems)
    CancelLootTicker()
    local currentLootSlot = numItems

    internal.lootTicker = C_Timer.NewTicker(0.033, function()
        if currentLootSlot >= 1 then
            LootSlot(currentLootSlot)
            currentLootSlot = currentLootSlot - 1
        else
            CancelLootTicker()
        end
    end, numItems + 1)
end

local function OnLootReady(autoLoot)
    internal.isLooting = true

    if not internal.initialAutoLootState then
        internal.initialAutoLootState = autoLoot or (not autoLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE"))
    end

    local numItems = GetNumLootItems()
    if numItems == 0 or internal.lastNumLoot == numItems then return end

    if internal.initialAutoLootState then
        StartLooting(numItems)
    end

    internal.lastNumLoot = numItems
end

local function OnLootClosed()
    internal.isLooting = false
    internal.lastNumLoot = nil
    internal.initialAutoLootState = nil
    CancelLootTicker()
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("LOOT_OPENED")
f:RegisterEvent("LOOT_CLOSED")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        OnLootReady(...)
    elseif event == "LOOT_CLOSED" then
        OnLootClosed()
    end
end)

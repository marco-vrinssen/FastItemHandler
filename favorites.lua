local accountDB, charDB
local itemKeyFields = {"itemID", "itemLevel", "itemSuffix", "battlePetSpeciesID", "itemContext"}
local itemKeyFieldLookup = {}
for _, f in ipairs(itemKeyFields) do itemKeyFieldLookup[f] = true end

local function serializeKey(k)
    local v = {}
    for i, f in ipairs(itemKeyFields) do v[i] = k[f] ~= nil and tostring(k[f]) or "" end
    local extra = {}
    for f in pairs(k) do if not itemKeyFieldLookup[f] then extra[#extra+1] = f end end
    if #extra > 0 then
        table.sort(extra)
        for _, f in ipairs(extra) do v[#v+1] = k[f] ~= nil and tostring(k[f]) or "" end
    end
    return table.concat(v, "-")
end

local function getItemLink(k)
    if k.itemID then
        local name, link = C_Item.GetItemInfo(k.itemID)
        if link then return link end
        if name then return name end
        C_Item.RequestLoadItemDataByID(k.itemID)
        return "|cff9d9d9d[Item:" .. k.itemID .. "]|r"
    end
    return "Unknown"
end

local function notify(prefix, k)
    local msg = "[FastExchange]: " .. prefix .. getItemLink(k)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(msg) else print(msg) end
end

local function syncItem(k)
    local s = serializeKey(k)
    if not accountDB.favorites[s] == not charDB.favorites[s] then return false end
    local fav = accountDB.favorites[s] ~= nil
    C_AuctionHouse.SetFavoriteItem(k, fav)
    notify(fav and "|cff00ff00[+]|r " or "|cffff0000[-]|r ", k)
    return true
end

local function updateFav(k, fav)
    if not accountDB or not charDB then return end
    local s = serializeKey(k)
    local was = accountDB.favorites[s] ~= nil
    accountDB.favorites[s] = fav and k or nil
    charDB.favorites[s] = fav and k or nil
    if was ~= fav then notify(fav and "|cff00ff00[+]|r " or "|cffff0000[-]|r ", k) end
end

local function captureFav(k)
    if k then updateFav(k, C_AuctionHouse.IsFavoriteItem(k)) end
end

hooksecurefunc(C_AuctionHouse, "SetFavoriteItem", updateFav)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")

f:SetScript("OnEvent", function(_, e, ...)
    if e == "ADDON_LOADED" then
        local addon = ...
        if addon == "FastItemHandler" then
            f:UnregisterEvent("ADDON_LOADED")
            FastItemHandlerDB = FastItemHandlerDB or {}
            accountDB = FastItemHandlerDB
            accountDB.favorites = accountDB.favorites or {}
            FastItemHandlerCharDB = FastItemHandlerCharDB or {}
            charDB = FastItemHandlerCharDB
            charDB.favorites = charDB.favorites or {}
            if not charDB.sync then
                f:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
                f:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
                f:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
                f:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
            end
        elseif addon == "Blizzard_AuctionHouseUI" or addon == "Blizzard_ProfessionsCustomerOrders" then
            if AUCTION_HOUSE_DEFAULT_FILTERS then
                AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end
        return
    end

    if e == "AUCTION_HOUSE_SHOW" then
        local refresh = false
        if charDB.sync then
            for _, t in ipairs{accountDB.favorites, charDB.favorites} do
                for _, k in pairs(t) do refresh = syncItem(k) or refresh end
            end
        else
            for s, k in pairs(accountDB.favorites) do charDB.favorites[s] = k end
            for _, k in pairs(accountDB.favorites) do
                C_AuctionHouse.SetFavoriteItem(k, true)
                refresh = true
            end
        end
        if refresh then C_AuctionHouse.SearchForFavorites({}) end
        return
    end

    if e == "AUCTION_HOUSE_CLOSED" then
        charDB.sync = true
        f:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        f:UnregisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        f:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
        f:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
        return
    end

    if e == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        for _, r in ipairs(C_AuctionHouse.GetBrowseResults()) do captureFav(r.itemKey) end
        return
    end

    if e == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        for _, r in ipairs(...) do captureFav(r.itemKey) end
        return
    end

    if e == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        captureFav(C_AuctionHouse.MakeItemKey(...))
        return
    end

    if e == "ITEM_SEARCH_RESULTS_UPDATED" then
        captureFav(...)
        return
    end
end)

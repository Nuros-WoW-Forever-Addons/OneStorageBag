--[[
    OneStorageBag - Hooks.lua
    Coordinates default bag replacement, keybinding integration,
    and automatic opening on vendor, bank, mail, trade, and auction house.
--]]

local addonName, addonTable = ...
local OneStorageBag = _G.OneStorageBag or addonTable

-- Register Keybinding display strings for WoW Keybindings Menu
_G["BINDING_HEADER_ONESTORAGE"] = "OneStorage"
_G["BINDING_NAME_CLICK OneStorageBagToggleButton:LeftButton"] = "Toggle OneBag"

local toggleBtn = CreateFrame("Button", "OneStorageBagToggleButton", UIParent)
toggleBtn:SetScript("OnClick", function()
    if OneStorageBag and OneStorageBag.Toggle then
        OneStorageBag:Toggle()
    end
end)

-------------------------------------------------------------------------------
-- Native Blizzard Container Suppression (Taint-Free)
-------------------------------------------------------------------------------

local nativeSuppressed = false
local function SuppressNativeContainers()
    if nativeSuppressed then return end
    nativeSuppressed = true
    
    local parent = ContainerFrameContainer or UIParent
    local disabled = CreateFrame("Frame", "OneStorage_DisabledContainerFrame", parent)
    disabled:SetAllPoints()
    disabled:Hide()
    
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f then
            f:SetParent(disabled)
            hooksecurefunc(f, "SetID", function(frame)
                frame:SetParent(disabled)
            end)
        end
    end
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:SetParent(disabled)
    end
end

-------------------------------------------------------------------------------
-- Secure Bag Toggling Hooks (Preserves Blizzard execution context)
-------------------------------------------------------------------------------

if ToggleAllBags then
    hooksecurefunc("ToggleAllBags", function()
        OneStorageBag:Toggle()
    end)
end

if ToggleBackpack then
    hooksecurefunc("ToggleBackpack", function()
        local stack = debugstack()
        if not stack:find("ToggleAllBags") then
            OneStorageBag:Toggle()
        end
    end)
end

if ToggleBag then
    hooksecurefunc("ToggleBag", function(bagID)
        local stack = debugstack()
        if not stack:find("OpenBackpack") and not stack:find("ToggleBackpack") and not stack:find("ToggleAllBags") then
            OneStorageBag:Toggle()
        end
    end)
end

if OpenAllBags then
    hooksecurefunc("OpenAllBags", function()
        local stack = debugstack()
        if not stack:find("Toggle") then
            OneStorageBag:Show()
        end
    end)
end

if OpenBackpack then
    hooksecurefunc("OpenBackpack", function()
        local stack = debugstack()
        if not stack:find("Toggle") then
            OneStorageBag:Show()
        end
    end)
end

if CloseAllBags then
    hooksecurefunc("CloseAllBags", function()
        local stack = debugstack()
        if not stack:find("Toggle") then
            OneStorageBag:Hide()
        end
    end)
end

if CloseBackpack then
    hooksecurefunc("CloseBackpack", function()
        local stack = debugstack()
        if not stack:find("Toggle") then
            OneStorageBag:Hide()
        end
    end)
end

-------------------------------------------------------------------------------
-- Interaction Auto-Open Coordination
-------------------------------------------------------------------------------

local autoOpenedFor = {}

local hookFrame = CreateFrame("Frame", "OneStorageBag_HookFrame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("MERCHANT_SHOW")
hookFrame:RegisterEvent("MERCHANT_CLOSED")
hookFrame:RegisterEvent("BANKFRAME_OPENED")
hookFrame:RegisterEvent("BANKFRAME_CLOSED")
hookFrame:RegisterEvent("MAIL_SHOW")
hookFrame:RegisterEvent("MAIL_CLOSED")
hookFrame:RegisterEvent("TRADE_SHOW")
hookFrame:RegisterEvent("TRADE_CLOSED")
hookFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
hookFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

hookFrame:SetScript("OnEvent", function(self, event)
    local db = _G.OneStorageBagDB or {}
    
    if event == "PLAYER_LOGIN" then
        SuppressNativeContainers()
        
    -- 1. Merchant / Vendor
    elseif event == "MERCHANT_SHOW" then
        if db.autoOpenVendor then
            autoOpenedFor["MERCHANT"] = true
            OneStorageBag:Show()
        end
    elseif event == "MERCHANT_CLOSED" then
        if autoOpenedFor["MERCHANT"] then
            autoOpenedFor["MERCHANT"] = nil
            OneStorageBag:Hide()
        end
        
    -- 2. Bank
    elseif event == "BANKFRAME_OPENED" then
        if db.autoOpenBank then
            autoOpenedFor["BANK"] = true
            OneStorageBag:Show()
        end
    elseif event == "BANKFRAME_CLOSED" then
        if autoOpenedFor["BANK"] then
            autoOpenedFor["BANK"] = nil
            OneStorageBag:Hide()
        end
        
    -- 3. Mailbox
    elseif event == "MAIL_SHOW" then
        if db.autoOpenMail then
            autoOpenedFor["MAIL"] = true
            OneStorageBag:Show()
        end
    elseif event == "MAIL_CLOSED" then
        if autoOpenedFor["MAIL"] then
            autoOpenedFor["MAIL"] = nil
            OneStorageBag:Hide()
        end
        
    -- 4. Trade Window
    elseif event == "TRADE_SHOW" then
        if db.autoOpenTrade then
            autoOpenedFor["TRADE"] = true
            OneStorageBag:Show()
        end
    elseif event == "TRADE_CLOSED" then
        if autoOpenedFor["TRADE"] then
            autoOpenedFor["TRADE"] = nil
            OneStorageBag:Hide()
        end
        
    -- 5. Auction House
    elseif event == "AUCTION_HOUSE_SHOW" then
        if db.autoOpenAuction then
            autoOpenedFor["AUCTION"] = true
            OneStorageBag:Show()
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if autoOpenedFor["AUCTION"] then
            autoOpenedFor["AUCTION"] = nil
            OneStorageBag:Hide()
        end
    end
end)

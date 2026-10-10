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
-- Native Blizzard Container Suppression
-------------------------------------------------------------------------------

local function CloseNativeContainerFrames()
    if InCombatLockdown and InCombatLockdown() then return end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
        ContainerFrameCombinedBags:Hide()
    end
end

-- Suppress native container generation if triggered by Blizzard UI
if ContainerFrame_GenerateFrame then
    hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
        if InCombatLockdown and InCombatLockdown() then return end
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end)
end

-------------------------------------------------------------------------------
-- Default Blizzard Bag Functions Replacement
-------------------------------------------------------------------------------

function ToggleAllBags()
    OneStorageBag:Toggle()
    CloseNativeContainerFrames()
end

function ToggleBackpack()
    OneStorageBag:Toggle()
    CloseNativeContainerFrames()
end

function OpenAllBags(forceOpen)
    OneStorageBag:Show()
    CloseNativeContainerFrames()
end

function OpenBackpack()
    OneStorageBag:Show()
    CloseNativeContainerFrames()
end

function CloseAllBags()
    OneStorageBag:Hide()
    CloseNativeContainerFrames()
end

function CloseBackpack()
    OneStorageBag:Hide()
    CloseNativeContainerFrames()
end

function ToggleBag(bagID)
    OneStorageBag:Toggle()
    CloseNativeContainerFrames()
end

function OpenBag(bagID)
    OneStorageBag:Show()
    CloseNativeContainerFrames()
end

function CloseBag(bagID)
    OneStorageBag:Hide()
    CloseNativeContainerFrames()
end

-- Update IsBagOpen query so Blizzard UI buttons (e.g. Backpack bar)
-- reflect the opened/closed state of the player bags.
local orig_IsBagOpen = IsBagOpen
function IsBagOpen(bagID)
    if OneStorageBag and OneStorageBag.frame and OneStorageBag.frame:IsShown() then
        if bagID and bagID >= 0 and bagID <= 4 then
            return true
        end
    end
    if orig_IsBagOpen then
        return orig_IsBagOpen(bagID)
    end
    return false
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
        CloseNativeContainerFrames()
        if ContainerFrame_GenerateFrame then
            pcall(hooksecurefunc, "ContainerFrame_GenerateFrame", function(frame)
                if InCombatLockdown and InCombatLockdown() then return end
                if frame and frame:IsShown() then
                    frame:Hide()
                end
            end)
        end
        
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

--[[
    OneStorageBag - Core.lua
    Master all-in-one inventory window featuring authentic Blizzard Metal styling,
    live search filtering, cleanup sorting, collapsible bag bar, and scrap indicators.
--]]

local addonName, addonTable = ...
_G.OneStorageBag = _G.OneStorageBag or addonTable
local OneStorageBag = _G.OneStorageBag

local Utils = _G.OneStorageUtils
local FrameHelper = Utils and Utils.FrameHelper
local ContainerHelper = Utils and Utils.ContainerHelper

OneStorageBag.buttons = {}
OneStorageBag.bagBarButtons = {}
OneStorageBag.currentSearch = ""
OneStorageBag.isBagBarShown = false

local defaultDB = {
    columns = 10,
    separateBags = true,
    showBagBar = false,
    autoOpenVendor = true,
    autoOpenBank = true,
    autoOpenMail = true,
    autoOpenTrade = true,
    autoOpenAuction = true,
}

-------------------------------------------------------------------------------
-- Window Title & Capacity Badges
-------------------------------------------------------------------------------

function OneStorageBag:UpdateTitle()
    if not self.frame then return end
    
    local free, total = ContainerHelper:GetFreeSlotCount(ContainerHelper.BAG_IDS)
    local titleText = string.format("|cffffffffInventory|r  |cff888888(%d/%d Free)|r", free, total)
    
    local titleTarget = (self.frame.TitleContainer and self.frame.TitleContainer.TitleText) 
        or self.frame.TitleText or self.frame.Title
    if titleTarget then
        titleTarget:SetText(titleText)
    end
end

-------------------------------------------------------------------------------
-- Money Display
-------------------------------------------------------------------------------

function OneStorageBag:UpdateMoney()
    if not self.frame or not self.frame.MoneyText then return end
    local copper = GetMoney() or 0
    self.frame.MoneyText:SetText(ContainerHelper:FormatMoney(copper))
end

-------------------------------------------------------------------------------
-- Item Slot Button Creation & Pooling
-------------------------------------------------------------------------------

function OneStorageBag:GetBagParentFrame(bagID)
    self.bagFrames = self.bagFrames or {}
    if not self.bagFrames[bagID] then
        local f = CreateFrame("Frame", "OneStorageBag_Bag" .. bagID, self.frame.ContentArea)
        f:SetID(bagID)
        f:SetAllPoints(self.frame.ContentArea)
        f:Show()
        self.bagFrames[bagID] = f
    end
    return self.bagFrames[bagID]
end

local function OnItemEnter(self)
    if not self.bagID or not self.slotID then return end
    OneStorageBag:HighlightBagBarButton(self.bagID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(self.bagID, self.slotID)
    else
        local link = ContainerHelper:GetItemLink(self.bagID, self.slotID)
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
    GameTooltip:Show()
    
    if self.hasItem then
        ContainerHelper:ShowItemCursor(self.bagID, self.slotID, self.isReadable)
        self:SetScript("OnUpdate", function(s)
            if GameTooltip:IsOwned(s) then
                ContainerHelper:ShowItemCursor(s.bagID, s.slotID, s.isReadable)
            end
        end)
    else
        ContainerHelper:ResetItemCursor()
    end
end

local function OnItemLeave(self)
    self:SetScript("OnUpdate", nil)
    OneStorageBag:ClearBagBarHighlight()
    GameTooltip:Hide()
    ContainerHelper:ResetItemCursor()
end

function OneStorageBag:CreateItemButton(index)
    local name = "OneStorageBagItem" .. index
    local parent = self.frame.ContentArea
    local ok, btn = pcall(CreateFrame, "ItemButton", name, parent, "ContainerFrameItemButtonTemplate")
    if not ok or not btn then
        btn = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate")
    end
    btn:SetSize(37, 37)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    
    -- Disable Blizzard's automatic template event updates; OneStorageBag manages updates
    btn:SetScript("OnEvent", nil)
    btn:SetScript("OnShow", nil)
    
    -- Ensure OnClick uses Blizzard's native ContainerFrameItemButton_OnClick
    if not btn:GetScript("OnClick") and ContainerFrameItemButton_OnClick then
        btn:SetScript("OnClick", ContainerFrameItemButton_OnClick)
    end
    
    -- Slot Background Texture (Empty Slot art)
    local slotBg = btn:CreateTexture(nil, "BACKGROUND")
    slotBg:SetAllPoints(btn)
    slotBg:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    slotBg:SetVertexColor(0.35, 0.35, 0.35, 0.6)
    btn.SlotBg = slotBg
    
    -- Item Icon
    local icon = _G[name .. "IconTexture"] or btn.icon
    if not icon then
        icon = btn:CreateTexture(nil, "BORDER")
        icon:SetAllPoints(btn)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = icon
    
    -- Item Count Label
    local count = _G[name .. "Count"] or btn.Count
    if not count then
        count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    btn.Count = count
    
    -- Quality Border Ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Common\\WhiteIconFrame")
    border:SetAllPoints(btn)
    border:Hide()
    btn.QualityBorder = border
    
    -- Quest Indicator Border
    local quest = btn:CreateTexture(nil, "OVERLAY")
    quest:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
    quest:SetPoint("CENTER", btn, "CENTER", 0, 0)
    quest:SetSize(42, 42)
    quest:Hide()
    btn.QuestBorder = quest
    
    -- Junk / Scrap Badge
    local scrap = btn:CreateTexture(nil, "OVERLAY")
    scrap:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    scrap:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    scrap:SetSize(12, 12)
    scrap:Hide()
    btn.ScrapBadge = scrap
    
    -- Search Dimming Overlay
    local searchOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    searchOverlay:SetAllPoints(btn)
    searchOverlay:SetColorTexture(0, 0, 0, 0.75)
    searchOverlay:Hide()
    btn.SearchOverlay = searchOverlay
    
    -- Bag Hover Highlight (Gold glow & white/gold border)
    local bagHighlight = btn:CreateTexture(nil, "OVERLAY", nil, 5)
    bagHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    bagHighlight:SetBlendMode("ADD")
    bagHighlight:SetVertexColor(1, 0.85, 0.2, 0.6)
    bagHighlight:SetAllPoints(btn)
    bagHighlight:Hide()
    btn.BagHighlight = bagHighlight
    
    local bagHighlightBorder = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    bagHighlightBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    bagHighlightBorder:SetBlendMode("ADD")
    bagHighlightBorder:SetVertexColor(1, 0.85, 0.2, 1.0)
    bagHighlightBorder:SetAllPoints(btn)
    bagHighlightBorder:Hide()
    btn.BagHighlightBorder = bagHighlightBorder
    
    -- Cooldown Spiral
    local cd = _G[name .. "Cooldown"] or btn.Cooldown
    if not cd then
        local okCd, newCd = pcall(CreateFrame, "Cooldown", name .. "Cooldown", btn, "CooldownFrameTemplate")
        cd = (okCd and newCd) or CreateFrame("Cooldown", name .. "Cooldown", btn)
    end
    cd:SetAllPoints(btn)
    btn.Cooldown = cd
    
    btn:SetScript("OnEnter", OnItemEnter)
    btn:SetScript("OnLeave", OnItemLeave)
    
    return btn
end

-------------------------------------------------------------------------------
-- Bag Hover Highlight System
-------------------------------------------------------------------------------

function OneStorageBag:HighlightBagSlots(bagID)
    self.highlightedBagID = bagID
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn.bagID ~= nil then
            if btn.bagID == bagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.25)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        end
    end
end

function OneStorageBag:ClearBagHighlights()
    self.highlightedBagID = nil
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            self:UpdateButton(btn)
        end
    end
end

function OneStorageBag:HighlightBagBarButton(bagID)
    if not self.bagBarButtons then return end
    for _, btn in ipairs(self.bagBarButtons) do
        if btn:GetID() == bagID then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
end

function OneStorageBag:ClearBagBarHighlight()
    if not self.bagBarButtons then return end
    for _, btn in ipairs(self.bagBarButtons) do
        btn:UnlockHighlight()
    end
end

-------------------------------------------------------------------------------
-- Grid Layout & Refresh
-------------------------------------------------------------------------------

function OneStorageBag:RefreshLayout()
    if InCombatLockdown and InCombatLockdown() then
        self.needsLayoutUpdate = true
        return
    end
    if not self.frame or not self.frame.ContentArea then return end
    
    local cols = (OneStorageBagDB and OneStorageBagDB.columns) or defaultDB.columns
    local separateBags = (OneStorageBagDB and OneStorageBagDB.separateBags ~= nil) and OneStorageBagDB.separateBags or defaultDB.separateBags
    local btnSize = 37
    local spacing = 4
    local bagGap = 8
    
    local slotList = {}
    local contentH = 0
    
    if separateBags then
        -- 1. Gather active player bags (only equipped bags with slots > 0)
        local activeBags = {}
        for _, bagID in ipairs(ContainerHelper:GetPlayerBagIDs()) do
            local numSlots = ContainerHelper:GetNumSlots(bagID)
            if numSlots and numSlots > 0 then
                table.insert(activeBags, { bagID = bagID, numSlots = numSlots })
            end
        end
        
        local currentRow = 0
        local numActiveBags = #activeBags
        
        for bagIdx, bagData in ipairs(activeBags) do
            local bagID = bagData.bagID
            local numSlots = bagData.numSlots
            local bagRows = math.ceil(numSlots / cols)
            
            for slotID = 1, numSlots do
                local col = (slotID - 1) % cols
                local localRow = math.floor((slotID - 1) / cols)
                local row = currentRow + localRow
                local x = col * (btnSize + spacing)
                local y = -(row * (btnSize + spacing) + (bagIdx - 1) * bagGap)
                
                table.insert(slotList, {
                    bagID  = bagID,
                    slotID = slotID,
                    x      = x,
                    y      = y,
                })
            end
            
            currentRow = currentRow + bagRows
        end
        
        local totalRows = math.max(1, currentRow)
        contentH = (totalRows * btnSize) + ((totalRows - 1) * spacing) + (math.max(0, numActiveBags - 1) * bagGap)
    else
        -- Merged continuous grid
        for _, bagID in ipairs(ContainerHelper:GetPlayerBagIDs()) do
            local numSlots = ContainerHelper:GetNumSlots(bagID)
            for slotID = 1, numSlots do
                table.insert(slotList, { bagID = bagID, slotID = slotID })
            end
        end
        
        local totalSlots = #slotList
        local rows = math.max(1, math.ceil(totalSlots / cols))
        contentH = (rows * btnSize) + ((rows - 1) * spacing)
        
        for i, slotData in ipairs(slotList) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            slotData.x = col * (btnSize + spacing)
            slotData.y = -row * (btnSize + spacing)
        end
    end
    
    local totalSlots = #slotList
    local contentW = (cols * btnSize) + ((cols - 1) * spacing)
    local frameW = math.max(340, contentW + 32)
    local headerH = self.isBagBarShown and 90 or 58
    local footerH = 34
    local frameH = contentH + headerH + footerH + 16
    
    self.frame:SetSize(frameW, frameH)
    self.frame.ContentArea:SetSize(contentW, contentH)
    
    self.frame.ContentArea:ClearAllPoints()
    if self.isBagBarShown then
        self.frame.ContentArea:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -92)
    else
        self.frame.ContentArea:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -60)
    end
    
    -- Layout Slots
    for i = 1, math.max(totalSlots, #self.buttons) do
        local btn = self.buttons[i]
        if i <= totalSlots then
            if not btn then
                btn = self:CreateItemButton(i)
                self.buttons[i] = btn
            end
            
            local slotData = slotList[i]
            local bagParent = self:GetBagParentFrame(slotData.bagID)
            if btn:GetParent() ~= bagParent then
                btn:SetParent(bagParent)
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.frame.ContentArea, "TOPLEFT", slotData.x, slotData.y)
            
            btn:SetID(slotData.slotID)
            btn.bagID = slotData.bagID
            btn.slotID = slotData.slotID
            btn.GetBagID = function(s) return s.bagID end
            btn:Show()
            
            self:UpdateButton(btn)
        else
            if btn then
                btn.bagID = nil
                btn.slotID = nil
                btn:Hide()
            end
        end
    end
    
    self:UpdateTitle()
    self:UpdateMoney()
    self:UpdateBagBar()
end

function OneStorageBag:UpdateButton(btn)
    local bagID = btn.bagID
    local slotID = btn.slotID
    if not bagID or not slotID then return end
    
    local info = ContainerHelper:GetItemInfo(bagID, slotID)
    
    if info and info.icon then
        btn.hasItem = true
        btn.isReadable = info.readable
        btn.Icon:SetTexture(info.icon)
        btn.Icon:Show()
        btn.SlotBg:Hide()
        
        -- Stack Count
        if info.count and info.count > 1 then
            btn.Count:SetText(info.count)
            btn.Count:Show()
        else
            btn.Count:Hide()
        end
        
        -- Cooldown
        local start, duration, enable = ContainerHelper:GetItemCooldown(bagID, slotID)
        if start and duration and duration > 0 and enable == 1 then
            btn.Cooldown:SetCooldown(start, duration)
            btn.Cooldown:Show()
        else
            btn.Cooldown:Hide()
        end
        
        -- Quality Border
        if info.quality and info.quality > 1 then
            local r, g, b = ContainerHelper:GetQualityColor(info.quality)
            btn.QualityBorder:SetVertexColor(r, g, b, 1.0)
            btn.QualityBorder:Show()
        else
            btn.QualityBorder:Hide()
        end
        
        -- Junk / Scrap Coin Badge
        if ContainerHelper:IsJunk(bagID, slotID) then
            btn.ScrapBadge:Show()
        else
            btn.ScrapBadge:Hide()
        end
        
        -- Bag Hover Highlight / Search Dimming
        if self.highlightedBagID ~= nil then
            if bagID == self.highlightedBagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.25)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        elseif self.currentSearch and self.currentSearch ~= "" then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            local matches = ContainerHelper:MatchesSearch(bagID, slotID, self.currentSearch)
            if matches then
                btn.SearchOverlay:Hide()
                btn:SetAlpha(1.0)
            else
                btn.SearchOverlay:Show()
                btn:SetAlpha(0.3)
            end
        else
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Hide()
            btn:SetAlpha(1.0)
        end
    else
        btn.hasItem = false
        btn.isReadable = nil
        -- Empty Slot
        btn.Icon:Hide()
        btn.Count:Hide()
        btn.Cooldown:Hide()
        btn.QualityBorder:Hide()
        btn.QuestBorder:Hide()
        btn.ScrapBadge:Hide()
        btn.SlotBg:Show()
        
        if self.highlightedBagID ~= nil then
            if bagID == self.highlightedBagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.2)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        elseif self.currentSearch and self.currentSearch ~= "" then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Show()
            btn:SetAlpha(0.2)
        else
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Hide()
            btn:SetAlpha(1.0)
        end
    end
end

-------------------------------------------------------------------------------
-- Search Handler
-------------------------------------------------------------------------------

function OneStorageBag:OnSearchChanged(text)
    self.currentSearch = text or ""
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            self:UpdateButton(btn)
        end
    end
end

-------------------------------------------------------------------------------
-- Collapsible Bag Bar (Equipped Bag Slots Drawer)
-------------------------------------------------------------------------------

function OneStorageBag:UpdateBagBar()
    if not self.bagBar or not self.bagBarButtons then return end
    
    for _, btn in ipairs(self.bagBarButtons) do
        local bagID = btn:GetID()
        if bagID == 0 then
            btn.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
            btn.icon:SetVertexColor(1, 1, 1, 1)
            if btn.QualityBorder then btn.QualityBorder:Hide() end
        else
            local texture = ContainerHelper:GetBagTexture(bagID)
            if texture then
                btn.icon:SetTexture(texture)
                btn.icon:SetVertexColor(1, 1, 1, 1)
                
                local quality = ContainerHelper:GetBagQuality(bagID)
                if quality and quality > 1 and btn.QualityBorder then
                    local r, g, b = ContainerHelper:GetQualityColor(quality)
                    btn.QualityBorder:SetVertexColor(r, g, b, 1)
                    btn.QualityBorder:Show()
                elseif btn.QualityBorder then
                    btn.QualityBorder:Hide()
                end
            else
                btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                btn.icon:SetVertexColor(0.4, 0.4, 0.4, 0.8)
                if btn.QualityBorder then btn.QualityBorder:Hide() end
            end
        end
    end
end

function OneStorageBag:CreateBagBar()
    if self.bagBar then return self.bagBar end
    
    local bar = CreateFrame("Frame", "OneStorageBagBar", self.frame)
    bar:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -58)
    bar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -16, -58)
    bar:SetHeight(32)
    bar:Hide()
    self.bagBar = bar
    
    local bagSlots = ContainerHelper:GetPlayerBagIDs()
    local xOffset = 0
    for idx, bagID in ipairs(bagSlots) do
        local btn = CreateFrame("Button", "OneStorageBagBarButton" .. bagID, bar)
        btn:SetSize(28, 28)
        btn:SetPoint("LEFT", bar, "LEFT", xOffset, 0)
        btn:SetID(bagID)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")
        
        -- Slot Background Texture
        local slotBg = btn:CreateTexture(nil, "BACKGROUND")
        slotBg:SetAllPoints(btn)
        slotBg:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        slotBg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
        btn.slotBg = slotBg
        
        local icon = btn:CreateTexture(nil, "BORDER")
        icon:SetAllPoints(btn)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = icon
        
        local qualityBorder = btn:CreateTexture(nil, "OVERLAY")
        qualityBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        qualityBorder:SetAllPoints(btn)
        qualityBorder:Hide()
        btn.QualityBorder = qualityBorder
        
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetAllPoints(btn)
        highlight:SetBlendMode("ADD")
        btn.Highlight = highlight
        
        btn:SetScript("OnClick", function(s, button)
            if bagID > 0 then
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                if invID then
                    if CursorHasItem and CursorHasItem() then
                        PutItemInBag(invID)
                    else
                        PickupInventoryItem(invID)
                    end
                end
            end
        end)
        btn:SetScript("OnDragStart", function(s)
            if bagID > 0 then
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                if invID then
                    PickupInventoryItem(invID)
                end
            end
        end)
        btn:SetScript("OnReceiveDrag", function(s)
            if bagID > 0 then
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                if invID then
                    PutItemInBag(invID)
                end
            end
        end)
        
        btn:SetScript("OnEnter", function(s)
            OneStorageBag:HighlightBagSlots(bagID)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            if bagID == 0 then
                GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack", 1, 1, 1)
                local free, total = ContainerHelper:GetFreeSlotCount({ 0 })
                GameTooltip:AddLine(string.format("%d / %d Free Slots", free, total), 0.8, 0.8, 0.8)
            else
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                local hasItem = ContainerHelper:GetBagTexture(bagID)
                if invID and hasItem and GameTooltip.SetInventoryItem then
                    GameTooltip:SetInventoryItem("player", invID)
                else
                    GameTooltip:SetText("Empty Bag Slot", 1, 1, 1)
                    GameTooltip:AddLine("Drag a bag here to equip it.", 0.8, 0.8, 0.8)
                end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            OneStorageBag:ClearBagHighlights()
            GameTooltip:Hide()
        end)
        
        table.insert(self.bagBarButtons, btn)
        xOffset = xOffset + 32
    end
    
    self:UpdateBagBar()
    return bar
end

function OneStorageBag:ToggleBagBar()
    self.isBagBarShown = not self.isBagBarShown
    if not self.bagBar then
        self:CreateBagBar()
    end
    
    if self.isBagBarShown then
        self.bagBar:Show()
    else
        self.bagBar:Hide()
    end
    
    self:RefreshLayout()
end

-------------------------------------------------------------------------------
-- Position Persistence (Save & Restore)
-------------------------------------------------------------------------------

function OneStorageBag:SavePosition()
    if not self.frame then return end
    local point, _, relPoint, xOfs, yOfs = self.frame:GetPoint(1)
    if point then
        _G.OneStorageBagDB = _G.OneStorageBagDB or {}
        _G.OneStorageBagDB.position = {
            point = point,
            relativePoint = relPoint or point,
            x = math.floor(xOfs + 0.5),
            y = math.floor(yOfs + 0.5),
        }
    end
end

function OneStorageBag:RestorePosition()
    if not self.frame then return end
    local pos = _G.OneStorageBagDB and _G.OneStorageBagDB.position
    self.frame:ClearAllPoints()
    if pos and pos.point and pos.x and pos.y then
        self.frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 60)
    end
end

-------------------------------------------------------------------------------
-- Master Window Creation
-------------------------------------------------------------------------------

function OneStorageBag:CreateFrame()
    if self.frame then return self.frame end
    
    local frame = CreateFrame("Frame", "OneStorageBagFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(430, 480)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    local function StartMoving()
        if not InCombatLockdown or not InCombatLockdown() then
            frame:StartMoving()
        end
    end
    local function StopMoving()
        frame:StopMovingOrSizing()
        OneStorageBag:SavePosition()
    end
    
    frame:SetScript("OnDragStart", StartMoving)
    frame:SetScript("OnDragStop", StopMoving)
    frame:Hide()
    
    self.frame = frame
    self:RestorePosition()
    
    -- Esc key close
    if FrameHelper then
        FrameHelper:RegisterEscClose("OneStorageBagFrame")
        FrameHelper:ApplyHiResFrame(frame)
    end
    
    -- Enable dragging on TitleContainer if present
    if frame.TitleContainer then
        frame.TitleContainer:EnableMouse(true)
        frame.TitleContainer:RegisterForDrag("LeftButton")
        frame.TitleContainer:SetScript("OnDragStart", StartMoving)
        frame.TitleContainer:SetScript("OnDragStop", StopMoving)
    end
    
    -- Top-Left Portrait Icon (Backpack)
    local portrait = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait
    if portrait then
        portrait:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
        portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        portrait:Show()
    end
    
    local portraitBtn = CreateFrame("Button", "OneStorageBagPortraitHoverButton", frame)
    portraitBtn:SetSize(60, 60)
    portraitBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    portraitBtn:SetFrameLevel(frame:GetFrameLevel() + 50)
    portraitBtn:EnableMouse(true)
    portraitBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    portraitBtn:RegisterForDrag("LeftButton")
    portraitBtn:SetScript("OnDragStart", StartMoving)
    portraitBtn:SetScript("OnDragStop", StopMoving)
    portraitBtn:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            OneStorageBag:ToggleOptions()
        end
    end)
    portraitBtn:SetScript("OnEnter", function(s)
        OneStorageBag:HighlightBagSlots(0)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack", 1, 1, 1)
        local free, total = ContainerHelper:GetFreeSlotCount({ 0 })
        GameTooltip:AddLine(string.format("%d / %d Free Slots", free, total), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Right-Click|r to open Options", 0.2, 1.0, 0.2)
        GameTooltip:Show()
    end)
    portraitBtn:SetScript("OnLeave", function()
        OneStorageBag:ClearBagHighlights()
        GameTooltip:Hide()
    end)
    
    -- Header Action: Search Box
    local search = FrameHelper:CreateSearchBox(frame, "OneStorageBagSearchBox", function(s, text)
        OneStorageBag:OnSearchChanged(text)
    end)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -36)
    search:SetWidth(150)
    frame.SearchBox = search
    
    -- Header Action: Sort Broom Button
    local sortBtn = CreateFrame("Button", "OneStorageBagSortButton", frame)
    sortBtn:SetSize(20, 20)
    sortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -36)
    
    local sortIcon = sortBtn:CreateTexture(nil, "OVERLAY")
    sortIcon:SetAllPoints(sortBtn)
    sortIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    sortBtn.Icon = sortIcon
    
    sortBtn:SetScript("OnClick", function()
        ContainerHelper:SortBags()
    end)
    sortBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Bags", 1, 1, 1)
        GameTooltip:AddLine("Clean up and consolidate inventory stacks.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.SortButton = sortBtn
    
    -- Header Action: Toggle Bag Bar Drawer Button (Right-click opens Options)
    local bagBarBtn = CreateFrame("Button", "OneStorageBagBarToggleButton", frame)
    bagBarBtn:SetSize(20, 20)
    bagBarBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)
    
    local bagBarIcon = bagBarBtn:CreateTexture(nil, "OVERLAY")
    bagBarIcon:SetAllPoints(bagBarBtn)
    bagBarIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    bagBarBtn.Icon = bagBarIcon
    
    bagBarBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bagBarBtn:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            OneStorageBag:ToggleOptions()
        else
            OneStorageBag:ToggleBagBar()
        end
    end)
    bagBarBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle Bag Bar", 1, 1, 1)
        GameTooltip:AddLine("Show or hide equipped bag containers.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cff00ff00Right-Click|r to open Options", 0.2, 1.0, 0.2)
        GameTooltip:Show()
    end)
    bagBarBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BagBarButton = bagBarBtn
    
    -- Content Area for Item Grid
    local contentArea = CreateFrame("Frame", "OneStorageBagContentArea", frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -60)
    contentArea:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.ContentArea = contentArea
    
    -- Footer Money Text
    local moneyText = frame:CreateFontString("OneStorageBagMoneyText", "OVERLAY", "GameFontHighlightSmall")
    moneyText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 10)
    frame.MoneyText = moneyText
    
    -- Close Button
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            OneStorageBag:Hide()
        end)
    end
    
    -- Sound effects on Open / Close (Native Backpack sounds)
    local function PlayOpenSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN) or 862
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igBackPackOpen")
        end
    end

    local function PlayCloseSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE) or 863
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igBackPackClose")
        end
    end

    local function UpdateBlizzardBagButtons()
        if InCombatLockdown and InCombatLockdown() then return end
        local isShown = frame:IsShown() and true or false
        if MainMenuBarBackpackButton then
            pcall(function()
                if MainMenuBarBackpackButton.SetChecked then
                    MainMenuBarBackpackButton:SetChecked(isShown)
                end
                if MainMenuBarBackpackButton.SetButtonState then
                    MainMenuBarBackpackButton:SetButtonState(isShown and "PUSHED" or "NORMAL")
                end
            end)
        end
        for i = 0, 3 do
            local slot = _G["CharacterBag" .. i .. "Slot"]
            if slot then
                pcall(function()
                    if slot.SetChecked then
                        slot:SetChecked(isShown)
                    end
                    if slot.SetButtonState then
                        slot:SetButtonState(isShown and "PUSHED" or "NORMAL")
                    end
                end)
            end
        end
    end

    local function OnBagShow()
        PlayOpenSound()
        UpdateBlizzardBagButtons()
    end

    local function OnBagHide()
        PlayCloseSound()
        UpdateBlizzardBagButtons()
        if OneStorageBag.optionsFrame and OneStorageBag.optionsFrame:IsShown() then
            OneStorageBag.optionsFrame:Hide()
        end
    end

    if frame.HookScript then
        frame:HookScript("OnShow", OnBagShow)
        frame:HookScript("OnHide", OnBagHide)
    else
        frame:SetScript("OnShow", OnBagShow)
        frame:SetScript("OnHide", OnBagHide)
    end
    
    return frame
end

-------------------------------------------------------------------------------
-- Visibility & Toggle API
-------------------------------------------------------------------------------

function OneStorageBag:Show()
    local f = self:CreateFrame()
    f:Show()
    self:RefreshLayout()
end

function OneStorageBag:Hide()
    if self.optionsFrame and self.optionsFrame:IsShown() then
        self.optionsFrame:Hide()
    end
    if self.frame then
        self.frame:Hide()
    end
end

function OneStorageBag:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-------------------------------------------------------------------------------
-- Options Panel (Docked to Left of Master Window)
-------------------------------------------------------------------------------

function OneStorageBag:DockOptions()
    if not self.optionsFrame or not self.frame then return end
    self.optionsFrame:ClearAllPoints()
    self.optionsFrame:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
    self.optionsFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", 0, 0)
end

function OneStorageBag:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    
    local parent = self.frame or self:CreateFrame()
    local opt = CreateFrame("Frame", "OneStorageBagOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    opt:SetWidth(230)
    opt:SetFrameStrata(parent:GetFrameStrata())
    opt:SetFrameLevel(math.max(1, parent:GetFrameLevel()))
    opt:SetClampedToScreen(true)
    opt:Hide()
    self.optionsFrame = opt
    
    -- Clean simple dialog frame styling without upper-left portrait ring
    if FrameHelper then
        FrameHelper:RegisterEscClose("OneStorageBagOptionsFrame")
        FrameHelper:ApplySimplePanel(opt, "Bag Options")
    end
    
    -- Draggable: Dragging docked options panel moves parent bag window smoothly
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", function()
        if parent:IsMovable() and (not InCombatLockdown or not InCombatLockdown()) then
            parent:StartMoving()
        end
    end)
    opt:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        OneStorageBag:SavePosition()
    end)
    
    -- UI Controls inside Options Panel
    local controls = {}
    local yOffset = -38
    local marginX = 16
    
    -- SECTION 1: Display & Layout
    local s1Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s1Header:SetText("|cffffcc00Display & Layout|r")
    yOffset = yOffset - 24
    
    -- Stepper: Columns
    local colStepper = FrameHelper:CreateStepper(
        opt,
        "OneStorageBagOptions_Columns",
        "Columns",
        6,
        16,
        function() return (OneStorageBagDB and OneStorageBagDB.columns) or defaultDB.columns end,
        function(val)
            OneStorageBagDB = OneStorageBagDB or {}
            OneStorageBagDB.columns = val
            OneStorageBag:RefreshLayout()
        end
    )
    colStepper:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    colStepper:SetWidth(194)
    table.insert(controls, colStepper)
    yOffset = yOffset - 28
    
    -- Checkbox: Separate Bag Rows
    local sepCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_SeparateBags",
        "Separate Bag Rows",
        "Group each equipped bag into its own row(s) instead of one continuous merged grid.",
        function()
            return (OneStorageBagDB and OneStorageBagDB.separateBags ~= nil) and OneStorageBagDB.separateBags or defaultDB.separateBags
        end,
        function(val)
            OneStorageBagDB = OneStorageBagDB or {}
            OneStorageBagDB.separateBags = val
            OneStorageBag:RefreshLayout()
        end
    )
    sepCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, sepCb)
    yOffset = yOffset - 26
    
    -- Checkbox: Show Bag Drawer
    local drawerCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_ShowBagBar",
        "Show Bag Drawer",
        "Show or hide the drawer of equipped bag containers.",
        function()
            return OneStorageBag.isBagBarShown
        end,
        function(val)
            OneStorageBag.isBagBarShown = val
            if not OneStorageBag.bagBar then
                OneStorageBag:CreateBagBar()
            end
            if val then
                OneStorageBag.bagBar:Show()
            else
                OneStorageBag.bagBar:Hide()
            end
            OneStorageBag:RefreshLayout()
        end
    )
    drawerCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, drawerCb)
    yOffset = yOffset - 34
    
    -- SECTION 2: Auto-Open Triggers
    local s2Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s2Header:SetText("|cffffcc00Auto-Open With|r")
    yOffset = yOffset - 24
    
    local function AddAutoCb(propName, labelText, tooltipText)
        local cb = FrameHelper:CreateCheckbox(
            opt,
            "OneStorageBagOptions_" .. propName,
            labelText,
            tooltipText,
            function()
                return (OneStorageBagDB and OneStorageBagDB[propName] ~= nil) and OneStorageBagDB[propName] or defaultDB[propName]
            end,
            function(val)
                OneStorageBagDB = OneStorageBagDB or {}
                OneStorageBagDB[propName] = val
            end
        )
        cb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
        table.insert(controls, cb)
        yOffset = yOffset - 24
    end
    
    AddAutoCb("autoOpenVendor", "Merchant / Vendor", "Automatically open bags when visiting a vendor.")
    AddAutoCb("autoOpenBank", "Bank Window", "Automatically open bags when opening the bank vault.")
    AddAutoCb("autoOpenMail", "Mailbox", "Automatically open bags when opening the mailbox.")
    AddAutoCb("autoOpenTrade", "Trade Window", "Automatically open bags when trading with a player.")
    AddAutoCb("autoOpenAuction", "Auction House", "Automatically open bags when talking to an auctioneer.")
    
    yOffset = yOffset - 10
    
    -- SECTION 3: Window Settings
    local s3Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s3Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s3Header:SetText("|cffffcc00Window Settings|r")
    yOffset = yOffset - 26
    
    local resetBtn = FrameHelper:CreateSilverButton(opt, "OneStorageBagOptions_ResetPosBtn", "Reset Position")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    resetBtn:SetScript("OnClick", function()
        if _G.OneStorageBagDB then _G.OneStorageBagDB.position = nil end
        OneStorageBag:RestorePosition()
    end)
    
    opt.RefreshOptions = function()
        for _, c in ipairs(controls) do
            if c.Refresh then c:Refresh() end
        end
    end
    
    return opt
end

function OneStorageBag:ToggleOptions()
    if not self.frame or not self.frame:IsShown() then
        self:Show()
    end
    local opt = self.optionsFrame or self:CreateOptionsFrame()
    if opt:IsShown() then
        opt:Hide()
    else
        self:DockOptions()
        opt:RefreshOptions()
        opt:Show()
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------

local function SafeRegisterEvent(frame, eventName)
    pcall(function() frame:RegisterEvent(eventName) end)
end

local eventFrame = CreateFrame("Frame", "OneStorageBag_EventFrame")
SafeRegisterEvent(eventFrame, "ADDON_LOADED")
SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")
SafeRegisterEvent(eventFrame, "BAG_UPDATE")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(eventFrame, "BAG_CONTAINER_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(eventFrame, "ITEM_LOCK_CHANGED")
SafeRegisterEvent(eventFrame, "PLAYER_MONEY")
SafeRegisterEvent(eventFrame, "MERCHANT_SHOW")
SafeRegisterEvent(eventFrame, "MERCHANT_CLOSED")
SafeRegisterEvent(eventFrame, "BANKFRAME_OPENED")
SafeRegisterEvent(eventFrame, "BANKFRAME_CLOSED")
SafeRegisterEvent(eventFrame, "MAIL_SHOW")
SafeRegisterEvent(eventFrame, "MAIL_CLOSED")
SafeRegisterEvent(eventFrame, "TRADE_SHOW")
SafeRegisterEvent(eventFrame, "TRADE_CLOSED")
SafeRegisterEvent(eventFrame, "AUCTION_HOUSE_SHOW")
SafeRegisterEvent(eventFrame, "AUCTION_HOUSE_CLOSED")
SafeRegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        _G.OneStorageBagDB = _G.OneStorageBagDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OneStorageBagDB[k] == nil then
                _G.OneStorageBagDB[k] = v
            end
        end
        
    elseif event == "PLAYER_LOGIN" then
        OneStorageBag:CreateFrame()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        if OneStorageBag.needsLayoutUpdate or (OneStorageBag.frame and OneStorageBag.frame:IsShown()) then
            OneStorageBag.needsLayoutUpdate = nil
            OneStorageBag:RefreshLayout()
        end
        
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "BAG_CONTAINER_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "ITEM_LOCK_CHANGED" then
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        
    elseif event == "PLAYER_MONEY" then
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:UpdateMoney()
        end

    elseif event == "MERCHANT_SHOW" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenVendor then OneStorageBag:Show() end
    elseif event == "MERCHANT_CLOSED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenVendor then OneStorageBag:Hide() end
    elseif event == "BANKFRAME_OPENED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenBank then OneStorageBag:Show() end
    elseif event == "BANKFRAME_CLOSED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenBank then OneStorageBag:Hide() end
    elseif event == "MAIL_SHOW" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenMail then OneStorageBag:Show() end
    elseif event == "MAIL_CLOSED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenMail then OneStorageBag:Hide() end
    elseif event == "TRADE_SHOW" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenTrade then OneStorageBag:Show() end
    elseif event == "TRADE_CLOSED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenTrade then OneStorageBag:Hide() end
    elseif event == "AUCTION_HOUSE_SHOW" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenAuction then OneStorageBag:Show() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if OneStorageBagDB and OneStorageBagDB.autoOpenAuction then OneStorageBag:Hide() end
    end
end)

-- Slash Command Registry
SLASH_ONESTORAGEBAG1 = "/onebag"
SLASH_ONESTORAGEBAG2 = "/osbag"
SlashCmdList["ONESTORAGEBAG"] = function(msg)
    local cmd, arg = strsplit(" ", (msg or ""):lower(), 2)
    if cmd == "reset" then
        if _G.OneStorageBagDB then _G.OneStorageBagDB.position = nil end
        if OneStorageBag.frame then
            OneStorageBag.frame:ClearAllPoints()
            OneStorageBag.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 60)
        end
        print("|cff00ccff[OneStorageBag]|r Window position reset to default.")
    elseif cmd == "options" or cmd == "opt" or cmd == "config" then
        OneStorageBag:ToggleOptions()
    elseif cmd == "separate" or cmd == "group" or cmd == "mode" or cmd == "rows" then
        _G.OneStorageBagDB = _G.OneStorageBagDB or {}
        local current = (_G.OneStorageBagDB.separateBags ~= nil) and _G.OneStorageBagDB.separateBags or defaultDB.separateBags
        _G.OneStorageBagDB.separateBags = not current
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        local modeStr = _G.OneStorageBagDB.separateBags and "|cff00ff00Separated bag rows|r" or "|cffffcc00Merged continuous grid|r"
        print("|cff00ccff[OneStorageBag]|r Bag layout mode: " .. modeStr)
    elseif cmd == "cols" and tonumber(arg) then
        local c = math.max(6, math.min(16, tonumber(arg)))
        if OneStorageBagDB then OneStorageBagDB.columns = c end
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        print("|cff00ccff[OneStorageBag]|r Column width set to " .. c)
    else
        OneStorageBag:Toggle()
    end
end

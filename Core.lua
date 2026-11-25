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
    largeMoney = false,
    openScrapOptions = false,
    autoOpenVendor = true,
    autoOpenBank = true,
    autoOpenMail = true,
    autoOpenTrade = true,
    autoOpenAuction = true,
}

function OneStorageBag:GetOption(key)
    if _G.OneStorageBagDB and _G.OneStorageBagDB[key] ~= nil then
        return _G.OneStorageBagDB[key]
    end
    return defaultDB[key]
end

function OneStorageBag:SetOption(key, val)
    _G.OneStorageBagDB = _G.OneStorageBagDB or {}
    _G.OneStorageBagDB[key] = val
end

-------------------------------------------------------------------------------
-- Window Title & Capacity Badges
-------------------------------------------------------------------------------

function OneStorageBag:UpdateTitle()
    if not self.frame then return end
    
    local titleTarget = (self.frame.TitleContainer and self.frame.TitleContainer.TitleText) 
        or self.frame.TitleText or self.frame.Title
    if not titleTarget then return end
    
    if self.viewingAlt then
        local cache = OneStorageUtils and OneStorageUtils.CharacterCache
        local charData = cache and cache:GetCharacter(self.viewingAlt)
        local hex = (cache and charData and cache.GetClassColorHex(charData.class)) or "ffffcc00"
        local bags = (charData and charData.bags) or {}
        local total, used = 0, 0
        for bagID = 0, 5 do
            local b = bags[bagID]
            if b and b.numSlots then
                total = total + b.numSlots
                for slotID = 1, b.numSlots do
                    if b.slots and b.slots[slotID] then
                        used = used + 1
                    end
                end
            end
        end
        local free = total - used
        local displayName = (charData and charData.fullName) or self.viewingAlt
        titleTarget:SetText(string.format("|c%s[%s]|r |cffffcc00(Snapshot)|r |cff888888(%d/%d Free)|r", hex, displayName, free, total))
        return
    end
    
    local free, total = ContainerHelper:GetFreeSlotCount(ContainerHelper.BAG_IDS)
    local titleText = string.format("|cffffffffInventory|r  |cff888888(%d/%d Free)|r", free, total)
    titleTarget:SetText(titleText)
end

-------------------------------------------------------------------------------
-- Money Display
-------------------------------------------------------------------------------

function OneStorageBag:UpdateMoney()
    if not self.frame or not self.frame.MoneyText then return end
    local copper = 0
    if self.viewingAlt then
        local cache = OneStorageUtils and OneStorageUtils.CharacterCache
        local charData = cache and cache:GetCharacter(self.viewingAlt)
        copper = (charData and charData.money) or 0
    else
        copper = GetMoney() or 0
    end
    local isLarge = self:GetOption("largeMoney")
    if isLarge then
        if _G["GameFontHighlightLarge"] then
            self.frame.MoneyText:SetFontObject("GameFontHighlightLarge")
        else
            self.frame.MoneyText:SetFontObject("GameFontHighlight")
        end
        self.frame.MoneyText:ClearAllPoints()
        self.frame.MoneyText:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 16, 9)
        self.frame.MoneyText:SetText(ContainerHelper:FormatMoney(copper, 16))
    else
        self.frame.MoneyText:SetFontObject("GameFontHighlightSmall")
        self.frame.MoneyText:ClearAllPoints()
        self.frame.MoneyText:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 16, 10)
        self.frame.MoneyText:SetText(ContainerHelper:FormatMoney(copper, 12))
    end
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
    local bag = self.bag or (self:GetParent() and self:GetParent():GetID())
    local slot = self.slot or self:GetID()
    if not bag or not slot then return end
    
    -- Clear Blizzard NewItem overlay if present
    if C_NewItems and C_NewItems.RemoveNewItem then
        C_NewItems.RemoveNewItem(bag, slot)
    end
    if self.NewItemTexture then self.NewItemTexture:Hide() end
    if self.BattlepayItemTexture then self.BattlepayItemTexture:Hide() end
    if self.flashAnim and self.flashAnim:IsPlaying() then self.flashAnim:Stop() end
    if self.newitemglowAnim and self.newitemglowAnim:IsPlaying() then self.newitemglowAnim:Stop() end

    if self.isAltSlot then
        OneStorageBag:HighlightBagBarButton(bag)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.altLink then
            GameTooltip:SetHyperlink(self.altLink)
        else
            GameTooltip:SetText("Empty Slot", 1, 1, 1)
        end
        GameTooltip:Show()
        return
    end

    OneStorageBag:HighlightBagBarButton(bag)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(bag, slot)
    else
        local link = ContainerHelper:GetItemLink(bag, slot)
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
    GameTooltip:Show()
    
    if self.hasItem then
        ContainerHelper:ShowItemCursor(bag, slot, self.isReadable)
        self:SetScript("OnUpdate", function(s)
            if GameTooltip:IsOwned(s) then
                ContainerHelper:ShowItemCursor(bag, slot, s.isReadable)
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
    
    -- Suppress Blizzard template default glow / battlepay overlays
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.ExtendedSlot then btn.ExtendedSlot:Hide() end
    if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
    if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
    
    -- Ensure GetBagID method is present from Blizzard's template mixin
    if not btn.GetBagID then
        if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.GetBagID then
            btn.GetBagID = ContainerFrameItemButtonMixin.GetBagID
        else
            btn.GetBagID = function(s)
                return s.bag or (s:GetParent() and s:GetParent():GetID())
            end
        end
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
    
    -- Preserve native ContainerFrameItemButtonTemplate OnClick and OnDragStart handlers
    -- to ensure zero taint when targeting spells (e.g. Disenchant, Milling) or using items.
    
    return btn
end

-------------------------------------------------------------------------------
-- Bag Hover Highlight System
-------------------------------------------------------------------------------

function OneStorageBag:HighlightBagSlots(bagID)
    self.highlightedBagID = bagID
    for _, btn in ipairs(self.buttons) do
        local btnBag = btn.bag or (btn:GetParent() and btn:GetParent():GetID())
        if btn:IsShown() and btnBag ~= nil then
            if btnBag == bagID then
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

function OneStorageBag:RefreshItems()
    if not self.frame or not self.buttons then return end
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn.bag and btn.slot then
            self:UpdateButton(btn)
        end
    end
    self:UpdateTitle()
    self:UpdateMoney()
    self:UpdateBagBar()
end

function OneStorageBag:RefreshLayout()
    if InCombatLockdown and InCombatLockdown() then
        self.needsLayoutUpdate = true
        self:RefreshItems()
        return
    end
    if not self.frame or not self.frame.ContentArea then return end
    
    local cols = self:GetOption("columns")
    local separateBags = self:GetOption("separateBags")
    local btnSize = 37
    local spacing = 4
    local bagGap = 8
    
    local slotList = {}
    local contentH = 0
    
    if self.viewingAlt then
        local cache = OneStorageUtils and OneStorageUtils.CharacterCache
        local charData = cache and cache:GetCharacter(self.viewingAlt)
        local bags = (charData and charData.bags) or {}
        
        if separateBags then
            local activeBags = {}
            for bagID = 0, 5 do
                local bagData = bags[bagID]
                if bagData and bagData.numSlots and bagData.numSlots > 0 then
                    table.insert(activeBags, { bagID = bagID, numSlots = bagData.numSlots })
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
            for bagID = 0, 5 do
                local bagData = bags[bagID]
                local numSlots = (bagData and bagData.numSlots) or 0
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
    elseif separateBags then
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
    local frameW = math.max(390, contentW + 32)
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
            btn.bag = slotData.bagID
            btn.slot = slotData.slotID
            btn.bagID = nil
            btn.slotID = nil
            if not btn.GetBagID then
                if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.GetBagID then
                    btn.GetBagID = ContainerFrameItemButtonMixin.GetBagID
                else
                    btn.GetBagID = function(s)
                        return s.bag or (s:GetParent() and s:GetParent():GetID())
                    end
                end
            end
            btn:Show()
            
            self:UpdateButton(btn)
        else
            if btn then
                btn.bag = nil
                btn.slot = nil
                btn.bagID = nil
                btn.slotID = nil
                btn:Hide()
            end
        end
    end
    
    self:UpdateTitle()
    self:UpdateMoney()
    self:UpdateBagBar()
    if self.optionsFrame and self.optionsFrame:IsShown() then
        self:DockOptions()
    end
end

function OneStorageBag:UpdateButton(btn)
    local bagID = btn.bag or (btn:GetParent() and btn:GetParent():GetID())
    local slotID = btn.slot or btn:GetID()
    if not bagID or not slotID then return end
    
    -- Suppress Blizzard template default glow / battlepay overlays
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.ExtendedSlot then btn.ExtendedSlot:Hide() end
    if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
    if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
    
    local info
    if self.viewingAlt then
        local cache = OneStorageUtils and OneStorageUtils.CharacterCache
        local charData = cache and cache:GetCharacter(self.viewingAlt)
        local bagData = charData and charData.bags and charData.bags[bagID]
        local slotData = bagData and bagData.slots and bagData.slots[slotID]
        if slotData then
            local icon = slotData.icon
            if not icon and slotData.id and C_Item and C_Item.GetItemIconByID then
                icon = C_Item.GetItemIconByID(slotData.id)
                slotData.icon = icon
            end
            local link = slotData.link
            if not link and slotData.id and ContainerHelper and ContainerHelper.GetItemInfoSafe then
                local _, itemLink = ContainerHelper.GetItemInfoSafe(slotData.id)
                if itemLink then
                    link = itemLink
                    slotData.link = link
                end
            end
            info = {
                icon = icon,
                count = slotData.count or 1,
                quality = slotData.quality or 1,
                hyperlink = link,
                itemID = slotData.id,
                readable = false,
            }
        end
        if not btn.isAltSlot then
            btn.isAltSlot = true
            -- Disable clicks and drags on cached alt slots to prevent interaction errors
            if not (InCombatLockdown and InCombatLockdown()) then
                btn:RegisterForClicks()
                btn:RegisterForDrag()
            end
        end
        btn.altLink = (info and info.hyperlink) or (slotData and slotData.link)
    else
        if btn.isAltSlot then
            btn.isAltSlot = false
            -- Restore native clicks and drags for current player's live inventory
            if not (InCombatLockdown and InCombatLockdown()) then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:RegisterForDrag("LeftButton")
            end
        end
        btn.altLink = nil
        info = ContainerHelper:GetItemInfo(bagID, slotID)
    end
    
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
        if not self.viewingAlt then
            local start, duration, enable = ContainerHelper:GetItemCooldown(bagID, slotID)
            if start and duration and duration > 0 and enable == 1 then
                btn.Cooldown:SetCooldown(start, duration)
                btn.Cooldown:Show()
            else
                btn.Cooldown:Hide()
            end
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
        if not self.viewingAlt and ContainerHelper:IsJunk(bagID, slotID) then
            btn.ScrapBadge:Show()
        elseif self.viewingAlt and info and info.quality == 0 then
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
            local matches = false
            if self.viewingAlt then
                if info and info.hyperlink then
                    matches = info.hyperlink:lower():find(self.currentSearch:lower(), 1, true) ~= nil
                end
            else
                matches = ContainerHelper:MatchesSearch(bagID, slotID, self.currentSearch)
            end
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
    
    if self.viewingAlt then
        local cache = OneStorageUtils and OneStorageUtils.CharacterCache
        local charData = cache and cache:GetCharacter(self.viewingAlt)
        local bags = (charData and charData.bags) or {}
        
        for _, btn in ipairs(self.bagBarButtons) do
            local bagID = btn:GetID()
            local bagData = bags[bagID]
            btn.isAltBag = true
            
            if bagID == 0 then
                btn.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
                btn.icon:SetVertexColor(1, 1, 1, 1)
                btn.altLink = nil
                if btn.QualityBorder then btn.QualityBorder:Hide() end
            elseif bagData and bagData.icon then
                btn.icon:SetTexture(bagData.icon)
                btn.icon:SetVertexColor(1, 1, 1, 1)
                btn.altLink = bagData.link
                if bagData.quality and bagData.quality > 1 and btn.QualityBorder then
                    local r, g, b = ContainerHelper:GetQualityColor(bagData.quality)
                    btn.QualityBorder:SetVertexColor(r, g, b, 1)
                    btn.QualityBorder:Show()
                elseif btn.QualityBorder then
                    btn.QualityBorder:Hide()
                end
            else
                btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                btn.icon:SetVertexColor(0.4, 0.4, 0.4, 0.8)
                btn.altLink = nil
                if btn.QualityBorder then btn.QualityBorder:Hide() end
            end
        end
        return
    end
    
    for _, btn in ipairs(self.bagBarButtons) do
        btn.isAltBag = false
        btn.altLink = nil
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
            if s.isAltBag then return end
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
            if s.isAltBag then return end
            if bagID > 0 then
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                if invID then
                    PickupInventoryItem(invID)
                end
            end
        end)
        btn:SetScript("OnReceiveDrag", function(s)
            if s.isAltBag then return end
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
            if s.isAltBag then
                if bagID == 0 then
                    GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack", 1, 1, 1)
                elseif s.altLink then
                    GameTooltip:SetHyperlink(s.altLink)
                else
                    GameTooltip:SetText("Empty Bag Slot", 1, 1, 1)
                end
                GameTooltip:Show()
                return
            end
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
    self.isBagBarShown = not self:GetOption("showBagBar")
    self:SetOption("showBagBar", self.isBagBarShown)
    if not self.bagBar then
        self:CreateBagBar()
    end
    
    if self.isBagBarShown then
        self.bagBar:Show()
    else
        self.bagBar:Hide()
    end
    
    self:RefreshLayout()
    if self.optionsFrame and self.optionsFrame:IsShown() and self.optionsFrame.RefreshOptions then
        self.optionsFrame:RefreshOptions()
    end
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
    
    -- Bottom-Right Character Selector & Return to Self
    if FrameHelper and FrameHelper.CreateCharacterDropdown then
        frame.CharSelect = FrameHelper:CreateCharacterDropdown(frame, "OneStorageBag", function(charName, isCurrent)
            if isCurrent then
                OneStorageBag.viewingAlt = nil
            else
                OneStorageBag.viewingAlt = charName
            end
            OneStorageBag:RefreshLayout()
            OneStorageBag:UpdateTitle()
            OneStorageBag:UpdateMoney()
            OneStorageBag:UpdateBagBar()
        end)
    end
    
    -- Bottom-Right Bank Button (Toggles static read-only bank)
    if FrameHelper and FrameHelper.CreateSilverButton and frame.CharSelect then
        local bankBtn = FrameHelper:CreateSilverButton(frame, "OneStorageBagBankButton", "Bank")
        bankBtn:SetSize(48, 20)
        bankBtn:SetPoint("RIGHT", frame.CharSelect, "LEFT", -6, 0)
        bankBtn:SetScript("OnClick", function()
            OneStorageBag:ToggleBank()
        end)
        bankBtn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText("Toggle Bank", 1, 1, 1)
            GameTooltip:AddLine("Open static read-only bank snapshot.", 0.8, 0.8, 0.8)
            if OneStorageBag.viewingAlt then
                GameTooltip:AddLine("Viewing Alt: |cffffcc00" .. tostring(OneStorageBag.viewingAlt) .. "|r", 0.2, 1.0, 0.2)
            end
            GameTooltip:Show()
        end)
        bankBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.BankButton = bankBtn
    end
    
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
        if OneStorageBag.viewingAlt then
            OneStorageBag.viewingAlt = nil
            if OneStorageBag.frame and OneStorageBag.frame.CharSelect and OneStorageBag.frame.CharSelect.SetSelected then
                OneStorageBag.frame.CharSelect:SetSelected(UnitName("player"))
            end
        end
    end

    if frame.HookScript then
        frame:HookScript("OnShow", OnBagShow)
        frame:HookScript("OnHide", OnBagHide)
    else
        frame:SetScript("OnShow", OnBagShow)
        frame:SetScript("OnHide", OnBagHide)
    end
    
    self.isBagBarShown = self:GetOption("showBagBar") or false
    if self.isBagBarShown then
        if not self.bagBar then
            self:CreateBagBar()
        end
        self.bagBar:Show()
    end
    
    return frame
end

-------------------------------------------------------------------------------
-- Visibility & Toggle API
-------------------------------------------------------------------------------

function OneStorageBag:Show()
    local f = self:CreateFrame()
    self.isBagBarShown = self:GetOption("showBagBar") or false
    if self.isBagBarShown then
        if not self.bagBar then
            self:CreateBagBar()
        end
        self.bagBar:Show()
    else
        if self.bagBar then
            self.bagBar:Hide()
        end
    end
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

function OneStorageBag:IsShown()
    return (self.frame and self.frame:IsShown()) and true or false
end

function OneStorageBag:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function OneStorageBag:ToggleBank()
    local bank = _G.OneStorageBank
    if not bank then
        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("OneStorageBank")
        elseif UIParentLoadAddOn then
            UIParentLoadAddOn("OneStorageBank")
        end
        bank = _G.OneStorageBank
    end
    
    if not bank then
        print("|cff00ccff[OneStorageBag]|r OneStorageBank is not loaded or enabled.")
        return
    end
    
    local isShown = (bank.IsShown and bank:IsShown()) or (bank.frame and bank.frame:IsShown())
    if isShown then
        bank:Hide()
    else
        -- If currently inspecting an alt in bags, sync the bank window to that same alt!
        if self.viewingAlt then
            bank.viewingAlt = self.viewingAlt
            if bank.frame and bank.frame.CharSelect then
                bank.frame.CharSelect:SetSelected(self.viewingAlt)
            end
        else
            bank.viewingAlt = nil
            if bank.frame and bank.frame.CharSelect then
                bank.frame.CharSelect:SetSelected(UnitName("player"))
            end
        end
        bank:Show()
    end
end

-------------------------------------------------------------------------------
-- Options Panel (Docked to Left of Master Window)
-------------------------------------------------------------------------------

function OneStorageBag:DockOptions()
    if not self.optionsFrame or not self.frame then return end
    self.optionsFrame:ClearAllPoints()
    self.optionsFrame:SetSize(230, 475)
    self.optionsFrame:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
    if self.isScrapDocked and OneStorageScrap and OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
        self:DockScrapOptions()
    end
end

function OneStorageBag:DockScrapOptions()
    if not OneStorageScrap or not self.optionsFrame then return end
    local scrapOpt = OneStorageScrap.optionsFrame or OneStorageScrap:CreateOptionsFrame()
    if not scrapOpt then return end
    scrapOpt:ClearAllPoints()
    scrapOpt:SetPoint("TOPRIGHT", self.optionsFrame, "TOPLEFT", 0, 0)
    scrapOpt:SetFrameStrata(self.optionsFrame:GetFrameStrata())
    scrapOpt:SetFrameLevel(math.max(1, self.optionsFrame:GetFrameLevel()))
    self.isScrapDocked = true
end

function OneStorageBag:OpenScrapOptions()
    if not OneStorageScrap then return end
    local scrapOpt = OneStorageScrap.optionsFrame or OneStorageScrap:CreateOptionsFrame()
    if not scrapOpt then return end
    self:DockScrapOptions()
    if scrapOpt.RefreshOptions then
        scrapOpt:RefreshOptions()
    end
    scrapOpt:Show()
    self.isScrapDocked = true
    if self.optionsFrame and self.optionsFrame.RefreshOptions then
        self.optionsFrame:RefreshOptions()
    end
end

function OneStorageBag:CloseScrapOptions()
    if OneStorageScrap and OneStorageScrap.optionsFrame then
        OneStorageScrap.optionsFrame:Hide()
    end
    self.isScrapDocked = false
    if self.optionsFrame and self.optionsFrame.RefreshOptions then
        self.optionsFrame:RefreshOptions()
    end
end

function OneStorageBag:ToggleScrapOptions()
    if not OneStorageScrap then return end
    local scrapOpt = OneStorageScrap.optionsFrame or OneStorageScrap:CreateOptionsFrame()
    if scrapOpt and scrapOpt:IsShown() and self.isScrapDocked then
        self:CloseScrapOptions()
    else
        self:OpenScrapOptions()
    end
end

function OneStorageBag:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    
    local parent = self.frame or self:CreateFrame()
    local opt = CreateFrame("Frame", "OneStorageBagOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    opt:SetSize(230, 475)
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
    
    -- Automatically close docked scrap options if bag options hides
    opt:HookScript("OnHide", function()
        if self.isScrapDocked and OneStorageScrap and OneStorageScrap.optionsFrame and OneStorageScrap.optionsFrame:IsShown() then
            OneStorageScrap.optionsFrame:Hide()
            self.isScrapDocked = false
        end
    end)
    
    -- UI Controls inside Options Panel
    local controls = {}
    local yOffset = -38
    local marginX = 16
    
    -- SECTION 1: Display & Layout
    local s1Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s1Header:SetText("|cffffcc00Display & Layout|r")
    yOffset = yOffset - 22
    
    -- Stepper: Columns
    local colStepper = FrameHelper:CreateStepper(
        opt,
        "OneStorageBagOptions_Columns",
        "Columns",
        6,
        16,
        function() return OneStorageBag:GetOption("columns") end,
        function(val)
            OneStorageBag:SetOption("columns", val)
            OneStorageBag:RefreshLayout()
        end
    )
    colStepper:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    colStepper:SetWidth(194)
    table.insert(controls, colStepper)
    yOffset = yOffset - 26
    
    -- Checkbox: Separate Bag Rows
    local sepCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_SeparateBags",
        "Separate Bag Rows",
        "Group each equipped bag into its own row(s) instead of one continuous merged grid.",
        function()
            return OneStorageBag:GetOption("separateBags")
        end,
        function(val)
            OneStorageBag:SetOption("separateBags", val)
            OneStorageBag:RefreshLayout()
        end
    )
    sepCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, sepCb)
    yOffset = yOffset - 24
    
    -- Checkbox: Show Bag Drawer
    local drawerCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_ShowBagBar",
        "Show Bag Drawer",
        "Show or hide the drawer of equipped bag containers.",
        function()
            return OneStorageBag:GetOption("showBagBar")
        end,
        function(val)
            OneStorageBag.isBagBarShown = val
            OneStorageBag:SetOption("showBagBar", val)
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
    yOffset = yOffset - 24
    
    -- Checkbox: Large Money Text
    local moneyCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_LargeMoney",
        "Large Money Text",
        "Make the money text and coin icons at the bottom of the bag frame larger.",
        function()
            return OneStorageBag:GetOption("largeMoney")
        end,
        function(val)
            OneStorageBag:SetOption("largeMoney", val)
            OneStorageBag:UpdateMoney()
        end
    )
    moneyCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, moneyCb)
    yOffset = yOffset - 24
    
    -- Checkbox: Enhanced Alt Tooltip
    local altTipCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_AltTooltip",
        "Enhanced Alt Tooltip",
        "Display a sub-frame anchored to the bottom of the item tooltip showing item counts across all your characters.",
        function()
            return OneStorageUtilsDB and OneStorageUtilsDB.showAltTooltip ~= false
        end,
        function(val)
            if OneStorageUtilsDB then
                OneStorageUtilsDB.showAltTooltip = val
            end
        end
    )
    altTipCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, altTipCb)
    yOffset = yOffset - 30
    
    -- SECTION 2: Auto-Open Triggers
    local s2Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s2Header:SetText("|cffffcc00Auto-Open With|r")
    yOffset = yOffset - 22
    
    local function AddAutoCb(propName, labelText, tooltipText)
        local cb = FrameHelper:CreateCheckbox(
            opt,
            "OneStorageBagOptions_" .. propName,
            labelText,
            tooltipText,
            function()
                return OneStorageBag:GetOption(propName)
            end,
            function(val)
                OneStorageBag:SetOption(propName, val)
            end
        )
        cb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
        table.insert(controls, cb)
        yOffset = yOffset - 22
    end
    
    AddAutoCb("autoOpenVendor", "Merchant / Vendor", "Automatically open bags when visiting a vendor.")
    AddAutoCb("autoOpenBank", "Bank Window", "Automatically open bags when opening the bank vault.")
    AddAutoCb("autoOpenMail", "Mailbox", "Automatically open bags when opening the mailbox.")
    AddAutoCb("autoOpenTrade", "Trade Window", "Automatically open bags when trading with a player.")
    AddAutoCb("autoOpenAuction", "Auction House", "Automatically open bags when talking to an auctioneer.")
    
    yOffset = yOffset - 8
    
    -- SECTION 3: OneStorage Scrap Integration
    local s3Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s3Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s3Header:SetText("|cffffcc00OneStorage Scrap|r")
    yOffset = yOffset - 22
    
    local scrapCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBagOptions_OpenScrapOptions",
        "Open Scrap Options",
        "Automatically open the OneStorage Scrap options panel docked to the left of the bag options.",
        function()
            return OneStorageBag:GetOption("openScrapOptions")
        end,
        function(val)
            OneStorageBag:SetOption("openScrapOptions", val)
            if val then
                OneStorageBag:OpenScrapOptions()
            else
                OneStorageBag:CloseScrapOptions()
            end
        end
    )
    scrapCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, scrapCb)
    yOffset = yOffset - 24
    
    local openScrapBtn = FrameHelper:CreateSilverButton(opt, "OneStorageBagOptions_OpenScrapBtn", "Scrap Options...")
    openScrapBtn:SetSize(140, 22)
    openScrapBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    openScrapBtn:SetScript("OnClick", function()
        OneStorageBag:ToggleScrapOptions()
    end)
    openScrapBtn:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Scrap & Repair Options", 1, 1, 1)
        if OneStorageScrap then
            GameTooltip:AddLine("Open or close the OneStorage Scrap options panel docked to the left of Bag Options.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("|cffff2020OneStorageScrap is not installed or loaded.|r", 1, 0.2, 0.2, true)
        end
        GameTooltip:Show()
    end)
    openScrapBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    yOffset = yOffset - 30
    
    -- SECTION 4: Window Settings
    local s4Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s4Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s4Header:SetText("|cffffcc00Window Settings|r")
    yOffset = yOffset - 24
    
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
        if openScrapBtn then
            if OneStorageScrap then
                openScrapBtn:Enable()
            else
                openScrapBtn:Disable()
            end
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
        if self:GetOption("openScrapOptions") then
            self:OpenScrapOptions()
        end
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
SafeRegisterEvent(eventFrame, "BAG_UPDATE_COOLDOWN")
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
        OneStorageBag.isBagBarShown = OneStorageBag:GetOption("showBagBar") or false
        
    elseif event == "PLAYER_LOGIN" then
        OneStorageBag:CreateFrame()
        OneStorageBag:RefreshLayout()
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        if OneStorageBag.needsLayoutUpdate or (OneStorageBag.frame and OneStorageBag.frame:IsShown()) then
            OneStorageBag.needsLayoutUpdate = nil
            OneStorageBag:RefreshLayout()
        end
        
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "BAG_CONTAINER_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "ITEM_LOCK_CHANGED" then
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshItems()
        end
        
    elseif event == "PLAYER_MONEY" then
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:UpdateMoney()
        end

    elseif event == "MERCHANT_SHOW" then
        if OneStorageBag:GetOption("autoOpenVendor") then OneStorageBag:Show() end
    elseif event == "MERCHANT_CLOSED" then
        if OneStorageBag:GetOption("autoOpenVendor") then OneStorageBag:Hide() end
    elseif event == "BANKFRAME_OPENED" then
        if OneStorageBag:GetOption("autoOpenBank") then OneStorageBag:Show() end
    elseif event == "BANKFRAME_CLOSED" then
        if OneStorageBag:GetOption("autoOpenBank") then OneStorageBag:Hide() end
    elseif event == "MAIL_SHOW" then
        if OneStorageBag:GetOption("autoOpenMail") then OneStorageBag:Show() end
    elseif event == "MAIL_CLOSED" then
        if OneStorageBag:GetOption("autoOpenMail") then OneStorageBag:Hide() end
    elseif event == "TRADE_SHOW" then
        if OneStorageBag:GetOption("autoOpenTrade") then OneStorageBag:Show() end
    elseif event == "TRADE_CLOSED" then
        if OneStorageBag:GetOption("autoOpenTrade") then OneStorageBag:Hide() end
    elseif event == "AUCTION_HOUSE_SHOW" then
        if OneStorageBag:GetOption("autoOpenAuction") then OneStorageBag:Show() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if OneStorageBag:GetOption("autoOpenAuction") then OneStorageBag:Hide() end
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
    elseif cmd == "bagbar" or cmd == "drawer" or cmd == "bags" then
        OneStorageBag:ToggleBagBar()
    elseif cmd == "separate" or cmd == "group" or cmd == "mode" or cmd == "rows" then
        local current = OneStorageBag:GetOption("separateBags")
        OneStorageBag:SetOption("separateBags", not current)
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        local modeStr = OneStorageBag:GetOption("separateBags") and "|cff00ff00Separated bag rows|r" or "|cffffcc00Merged continuous grid|r"
        print("|cff00ccff[OneStorageBag]|r Bag layout mode: " .. modeStr)
    elseif cmd == "cols" and tonumber(arg) then
        local c = math.max(6, math.min(16, tonumber(arg)))
        OneStorageBag:SetOption("columns", c)
        if OneStorageBag.frame and OneStorageBag.frame:IsShown() then
            OneStorageBag:RefreshLayout()
        end
        print("|cff00ccff[OneStorageBag]|r Column width set to " .. c)
    elseif cmd == "scrap" or cmd == "scrapopt" then
        if not OneStorageBag.frame or not OneStorageBag.frame:IsShown() then
            OneStorageBag:Show()
        end
        if not OneStorageBag.optionsFrame or not OneStorageBag.optionsFrame:IsShown() then
            OneStorageBag:ToggleOptions()
        end
        OneStorageBag:ToggleScrapOptions()
    elseif cmd == "money" or cmd == "largemoney" then
        local current = OneStorageBag:GetOption("largeMoney")
        OneStorageBag:SetOption("largeMoney", not current)
        OneStorageBag:UpdateMoney()
        if OneStorageBag.optionsFrame and OneStorageBag.optionsFrame:IsShown() and OneStorageBag.optionsFrame.RefreshOptions then
            OneStorageBag.optionsFrame:RefreshOptions()
        end
        local stateStr = OneStorageBag:GetOption("largeMoney") and "|cff00ff00Enabled (Large)|r" or "|cffffcc00Disabled (Standard)|r"
        print("|cff00ccff[OneStorageBag]|r Large money text: " .. stateStr)
    else
        OneStorageBag:Toggle()
    end
end

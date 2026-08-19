local addonName, Addon = ...
local Core = Addon.Core

local UI = {
    routeRows = {},
    catalogRows = {},
    savedRouteRows = {},
    routeOffset = 0,
    catalogOffset = 0,
    savedRouteOffset = 0,
    selectedRouteIndex = nil,
    searchText = "",
}
Addon.UI = UI

local COLORS = {
    background = { 0.035, 0.043, 0.055, 0.98 },
    panel = { 0.065, 0.075, 0.095, 0.98 },
    panelLight = { 0.090, 0.102, 0.125, 1 },
    border = { 0.22, 0.25, 0.30, 1 },
    gold = { 0.86, 0.64, 0.25, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    muted = { 0.58, 0.62, 0.68, 1 },
    green = { 0.35, 0.78, 0.48, 1 },
    red = { 0.88, 0.32, 0.30, 1 },
    current = { 0.090, 0.102, 0.125, 1 },
    selected = { 0.090, 0.102, 0.125, 1 },
    normal = { 0.065, 0.075, 0.095, 0.98 },
}

local function setTextureColor(texture, color)
    texture:SetTexture(color[1], color[2], color[3], color[4] or 1)
end

local function setBackdrop(frame, color, border)
    if not frame or not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(color or COLORS.panel))
    frame:SetBackdropBorderColor(unpack(border or COLORS.border))
end

local function makeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    setBackdrop(button, COLORS.panelLight, COLORS.border)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetAllPoints()
    button.label:SetText(text or "")
    button.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() == 1 then
            self:SetBackdropColor(0.14, 0.16, 0.20, 1)
            self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.8)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(COLORS.panelLight[1], COLORS.panelLight[2], COLORS.panelLight[3], COLORS.panelLight[4])
        self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
    end)
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() == 1 then
            self.label:ClearAllPoints()
            self.label:SetPoint("CENTER", 1, -1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        self.label:ClearAllPoints()
        self.label:SetAllPoints()
    end)
    function button:SetButtonEnabled(enabled)
        if enabled then
            self:Enable()
            self.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
        else
            self:Disable()
            self.label:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        end
    end
    return button
end

local function styleSecureButton(button, text)
    button:SetWidth(button:GetWidth())
    setBackdrop(button, COLORS.panelLight, COLORS.border)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetAllPoints()
    button.label:SetText(text or "")
    button.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.16, 0.20, 1)
        self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.8)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(COLORS.panelLight[1], COLORS.panelLight[2], COLORS.panelLight[3], COLORS.panelLight[4])
        self:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
    end)
    button:SetScript("OnMouseDown", function(self)
        self.label:ClearAllPoints()
        self.label:SetPoint("CENTER", 1, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.label:ClearAllPoints()
        self.label:SetAllPoints()
    end)
    return button
end

local function setButtonText(button, text)
    if button and button.label then
        button.label:SetText(text or "")
    end
end

local function makeInput(parent, width, height, maxLetters)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetWidth(width)
    holder:SetHeight(height)
    setBackdrop(holder, { 0.025, 0.030, 0.040, 1 }, COLORS.border)
    local input = CreateFrame("EditBox", nil, holder)
    input:SetPoint("TOPLEFT", 9, -2)
    input:SetPoint("BOTTOMRIGHT", -9, 2)
    input:SetFont("Fonts\\FRIZQT__.TTF", 12)
    input:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    input:SetAutoFocus(false)
    input:SetJustifyH("LEFT")
    input:SetMaxLetters(maxLetters or 80)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    holder.input = input
    return holder, input
end

local function makeCheckbox(parent, label)
    local checkbox = CreateFrame("Button", nil, parent)
    checkbox:SetWidth(18)
    checkbox:SetHeight(18)
    setBackdrop(checkbox, COLORS.panelLight, COLORS.border)
    checkbox.mark = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.mark:SetAllPoints()
    checkbox.mark:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkbox.label:SetText(label)
    checkbox.checked = false
    function checkbox:SetChecked(value)
        self.checked = value and true or false
        self.mark:SetText(self.checked and "X" or "")
        self:SetBackdropBorderColor(
            self.checked and COLORS.gold[1] or COLORS.border[1],
            self.checked and COLORS.gold[2] or COLORS.border[2],
            self.checked and COLORS.gold[3] or COLORS.border[3],
            1
        )
    end
    function checkbox:GetChecked()
        return self.checked
    end
    checkbox:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
    end)
    return checkbox
end

local function makePanel(parent, title, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(width)
    panel:SetHeight(height)
    setBackdrop(panel, COLORS.panel)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    panel.title:SetText(title)
    panel.title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    return panel
end

local function addHeaderBand(frame, height)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    texture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    texture:SetHeight(height or 44)
    setTextureColor(texture, { 0.055, 0.062, 0.078, 1 })
    return texture
end

local function clampOffset(offset, count, visible)
    return math.max(0, math.min(offset or 0, math.max(0, count - visible)))
end

local function getStatusColor(message)
    local lower = string.lower(tostring(message or ""))
    if string.find(lower, "stopped", 1, true)
        or string.find(lower, "could not", 1, true)
        or string.find(lower, "not enough", 1, true)
        or string.find(lower, "repeat-locked", 1, true)
    then
        return COLORS.red
    elseif string.find(lower, "completed", 1, true)
        or string.find(lower, "route complete", 1, true)
        or string.find(lower, "saved", 1, true)
        or string.find(lower, "accepted", 1, true)
    then
        return COLORS.green
    elseif string.find(lower, "running", 1, true)
        or string.find(lower, "waiting", 1, true)
        or string.find(lower, "reroll", 1, true)
        or string.find(lower, "active", 1, true)
    then
        return COLORS.gold
    end
    return COLORS.muted
end

local function createRouteRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(27)
    row:SetPoint("LEFT", parent, "LEFT", 8, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    setBackdrop(row, COLORS.normal, COLORS.border)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.number:SetPoint("LEFT", row, "LEFT", 7, 0)
    row.number:SetWidth(32)
    row.number:SetJustifyH("RIGHT")

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.number, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.label:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(self)
        UI.selectedRouteIndex = self.routeIndex
        UI:Refresh()
    end)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.16, 0.20, 1)
        self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.8)
    end)
    row:SetScript("OnLeave", function(self)
        UI:Refresh()
    end)
    return row
end

local function createCatalogRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(27)
    row:SetPoint("LEFT", parent, "LEFT", 8, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    row:EnableMouse(true)
    setBackdrop(row, COLORS.normal, COLORS.border)

    row.add = makeButton(row, "+", 28, 21)
    row.add:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.add:SetScript("OnClick", function(self)
        if self.questKey then
            Addon:AddRouteQuest(self.questKey)
        end
    end)

    row.info = makeButton(row, "?", 26, 21)
    row.info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.info:SetScript("OnClick", function(self)
        if self.questKey then
            UI:ToggleQuestDetails(self.questKey, row)
        end
    end)
    row.info:HookScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Show quest objective", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    row.info:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.add, "RIGHT", 7, 0)
    row.label:SetPoint("RIGHT", row.info, "LEFT", -5, 0)
    row.label:SetJustifyH("LEFT")
    row:SetScript("OnMouseUp", function(self)
        if self.groupId then
            UI:ToggleCatalogGroup(self.groupId)
        end
    end)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.14, 0.16, 0.20, 1)
        self:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.8)
    end)
    row:SetScript("OnLeave", function(self)
        UI:Refresh()
    end)
    return row
end

function UI:HideQuestDetails()
    if self.detailPopup then
        self.detailPopup.questKey = nil
        self.detailPopup:Hide()
    end
end

function UI:ToggleQuestDetails(key, owner)
    if not self.detailPopup or not key then
        return
    end
    if self.detailPopup:IsShown() and self.detailPopup.questKey == key then
        self:HideQuestDetails()
        return
    end

    local quest = Addon.db and Addon.db.knownQuests[key]
    if not quest then
        return
    end

    local classification = Core.ClassifyCatalogZone(quest)
    local objective = tostring(quest.objectiveText or "")
    if objective == "" then
        objective = "No objective text has been learned yet. Open the Callboard when this quest is offered to refresh its details."
    end

    self.detailPopup.questKey = key
    self.detailPopup.title:SetText(Core.QuestTitle(quest))
    self.detailPopup.meta:SetText(classification.label
        .. (quest.questId and "  |cff888888Quest #" .. tostring(quest.questId) .. "|r" or ""))
    self.detailPopup.objective:SetText(objective)
    self.detailPopup.add.questKey = key
    if Core.RouteContains(Addon.profile and Addon.profile.route, key) then
        setButtonText(self.detailPopup.add, "Already Added")
        self.detailPopup.add:SetButtonEnabled(false)
    else
        setButtonText(self.detailPopup.add, "Add to Route")
        self.detailPopup.add:SetButtonEnabled(true)
    end

    local textHeight = math.max(34, self.detailPopup.objective:GetStringHeight() or 34)
    self.detailPopup:SetHeight(math.min(170, 82 + textHeight))
    self.detailPopup:ClearAllPoints()
    self.detailPopup:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
    self.detailPopup:Show()
    self.detailPopup:Raise()
end

function UI:ToggleCatalogGroup(groupId)
    if not Addon.profile or type(groupId) ~= "string" then
        return
    end
    self:HideQuestDetails()
    Addon.profile.catalogCollapsed = Addon.profile.catalogCollapsed or {}
    if Addon.profile.catalogCollapsed[groupId] then
        Addon.profile.catalogCollapsed[groupId] = nil
    else
        Addon.profile.catalogCollapsed[groupId] = true
    end
    self:Refresh()
end

function UI:SetAllCatalogGroupsCollapsed(collapsed)
    if not Addon.profile then
        return
    end
    self:HideQuestDetails()
    Addon.profile.catalogCollapsed = {}
    if collapsed then
        local ids = Core.CatalogGroupIDs(Addon.db, self.searchText)
        for i = 1, table.getn(ids) do
            Addon.profile.catalogCollapsed[ids[i]] = true
        end
    end
    self.catalogOffset = 0
    self:Refresh()
end

function UI:SavePosition()
    if not self.frame or not Addon.profile then
        return
    end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    Addon.profile.window.point = point or "CENTER"
    Addon.profile.window.relativePoint = relativePoint or point or "CENTER"
    Addon.profile.window.x = x or 0
    Addon.profile.window.y = y or 0
end

function UI:UpdateSummonCooldown()
    if (not self.summon and not self.miniSummon) or not Addon.PE or not Addon.PE.GetSummonCooldownRemaining then
        return
    end
    local remaining = Addon.PE.GetSummonCooldownRemaining()
    local seconds = remaining > 0 and math.max(1, math.ceil(remaining)) or 0
    if self.lastSummonCooldownSecond == seconds then
        return
    end
    self.lastSummonCooldownSecond = seconds
    local label = seconds > 0 and ("Callboard " .. tostring(seconds) .. "s") or "Summon Board"
    if self.summon then
        setButtonText(self.summon, label)
    end
    if self.miniSummon then
        setButtonText(self.miniSummon, label)
    end
end

function UI:UpdateStartAction()
    if not self.start or not Addon.PE or not Addon.PE.IsBoardVisible then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local shouldCast = not Addon.PE.IsBoardVisible()
    if self.startActionCasts == shouldCast then
        return
    end
    self.startActionCasts = shouldCast
    self.start:SetAttribute("macrotext", shouldCast and "/cast Summon Callboard" or "")
end

function UI:SaveMiniLayout()
    if not self.miniFrame or not Addon.profile then
        return
    end
    local point, _, relativePoint, x, y = self.miniFrame:GetPoint(1)
    Addon.profile.miniWindow.point = point or "CENTER"
    Addon.profile.miniWindow.relativePoint = relativePoint or point or "CENTER"
    Addon.profile.miniWindow.x = x or 0
    Addon.profile.miniWindow.y = y or 0
    Addon.profile.miniWindow.width = self.miniFrame:GetWidth()
    Addon.profile.miniWindow.height = self.miniFrame:GetHeight()
end

function UI:RefreshMini()
    if not self.miniFrame or not Addon.profile or not Addon.db then
        return
    end
    local route = Addon.profile.route or {}
    local currentIndex = Addon.profile.currentStep or 1
    local routeCount = table.getn(route)
    local wantedCount = math.max(1, math.min(20, Addon.profile.miniQuestCount or 5))
    local shownCount = math.min(wantedCount, routeCount)
    local lines = {}

    if currentIndex > routeCount or routeCount == 0 then
        table.insert(lines, "|cffaaaaaaRoute complete|r")
        shownCount = 1
    else
        for offset = 0, shownCount - 1 do
            local routeIndex = currentIndex + offset
            if routeIndex > routeCount then
                if Addon.profile.autoLoop then
                    routeIndex = routeIndex - routeCount
                else
                    break
                end
            end

            local key = route[routeIndex]
            local quest = key and Addon.db.knownQuests[key]
            local title = quest and Core.QuestTitle(quest) or tostring(key or "Unknown quest")
            if offset == 0 then
                table.insert(lines, "|cffffcc00> " .. tostring(routeIndex) .. ". " .. title .. "|r")
            else
                table.insert(lines, "  " .. tostring(routeIndex) .. ". |cffffffff" .. title .. "|r")
            end
        end
        shownCount = table.getn(lines)
    end

    self.miniFrame.title:SetText(Addon.profile.activeRouteName
        and ("RavioliCallboard — " .. Addon.profile.activeRouteName)
        or "RavioliCallboard Route")
    self.miniCurrent:SetText(table.concat(lines, "\n"))
    self.miniStatus:SetText(Addon.statusMessage or "")
    local miniStatusColor = getStatusColor(Addon.statusMessage)
    self.miniStatus:SetTextColor(miniStatusColor[1], miniStatusColor[2], miniStatusColor[3])

    local minimumHeight = 134 + (shownCount * 16)
    if self.miniFrame.SetMinResize then
        self.miniFrame:SetMinResize(360, math.max(165, minimumHeight))
    end
    if self.miniFrame:GetWidth() < 360 then
        self.miniFrame:SetWidth(360)
    end
    if self.miniFrame:GetHeight() < minimumHeight then
        self.miniFrame:SetHeight(minimumHeight)
        self:SaveMiniLayout()
    end
    self:UpdateSummonCooldown()
    self:RefreshGroupProgress()
end

function UI:RefreshGroupProgress()
    if not self.miniGroup or not self.groupProgressFrame or not Addon.profile then
        return
    end
    if Addon.profile.showGroupProgress ~= true then
        setButtonText(self.miniGroup, "Group Off")
        self.groupProgressFrame.subtitle:SetText("Live group progress is disabled in Settings.")
        self.groupProgressText:SetText("")
        return
    end

    local group = Addon.Group
    local display = group and group.GetDisplay and group:GetDisplay() or nil
    if not display then
        setButtonText(self.miniGroup, "Group")
        return
    end

    if display.grouped then
        setButtonText(self.miniGroup, "Group " .. tostring(display.completeCount) .. "/" .. tostring(display.memberCount))
    else
        setButtonText(self.miniGroup, "Group")
    end
    self.groupProgressFrame.subtitle:SetText(display.title)

    local lines = {}
    if not display.grouped then
        table.insert(lines, "|cffaaaaaaYou are not currently in a group.|r")
    else
        for index = 1, table.getn(display.rows or {}) do
            local row = display.rows[index]
            local color = "|cffffffff"
            if row.color == "complete" then
                color = "|cff55ff55"
            elseif row.color == "missing" then
                color = "|cffffaa55"
            elseif row.color == "unknown" then
                color = "|cff888888"
            end
            table.insert(lines, color .. tostring(row.name) .. "|r  —  " .. tostring(row.status))
        end
        if display.addonCount < display.memberCount then
            table.insert(lines, "")
            table.insert(lines, "|cff888888No addon data means that player has not responded from RavioliCallboard.|r")
        end
    end

    self.groupProgressText:SetText(table.concat(lines, "\n"))
    local contentHeight = math.max(250, (table.getn(lines) * 18) + 12)
    self.groupProgressChild:SetHeight(contentHeight)
end

function UI:ToggleGroupProgress()
    if not self.groupProgressFrame then
        return
    end
    if self.groupProgressFrame:IsShown() then
        self.groupProgressFrame:Hide()
    else
        self:RefreshGroupProgress()
        self.groupProgressFrame:Show()
        self.groupProgressFrame:Raise()
    end
end

function UI:ShowMini()
    if not self.miniFrame then
        return
    end
    self.frame:Hide()
    self.miniFrame:Show()
    self:RefreshMini()
end

function UI:ShowMain()
    if self.miniFrame then
        self.miniFrame:Hide()
    end
    self.frame:Show()
    self:Refresh()
end

function UI:RefreshSettings()
    if not self.settingsFrame or not Addon.profile then
        return
    end
    self.settingsAutoLoop:SetChecked(Addon.profile.autoLoop == true)
    self.settingsAutoAccept:SetChecked(Addon.profile.autoAccept == true)
    self.settingsAutoShare:SetChecked(Addon.profile.autoShare == true)
    self.settingsGroupProgress:SetChecked(Addon.profile.showGroupProgress == true)
    self.settingsMaxRerolls:SetText(tostring(Addon.profile.maxRerolls or 50))
    self.settingsRerollDelay:SetText(tostring(Addon.profile.rerollDelay or 1.6))
    self.settingsMiniQuestCount:SetText(tostring(Addon.profile.miniQuestCount or 5))
end

function UI:ToggleSettings()
    if not self.settingsFrame then
        return
    end
    self:HideQuestDetails()
    if self.routeManager and self.routeManager:IsShown() then
        self.routeManager:Hide()
    end
    if self.settingsFrame:IsShown() then
        self.settingsFrame:Hide()
    else
        self:RefreshSettings()
        self.settingsFrame:Show()
        self.settingsFrame:Raise()
    end
end

local function sortedSavedRouteNames()
    local names = {}
    local savedRoutes = Addon.profile and Addon.profile.savedRoutes or {}
    for name in pairs(savedRoutes) do
        table.insert(names, name)
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

function UI:UpdateRouteSaveButton()
    if not self.routeManagerSave or not self.routeManagerName then
        return
    end
    local name = self.routeManagerName:GetText() or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    local exists = Addon.profile and Addon.profile.savedRoutes and Addon.profile.savedRoutes[name]
    setButtonText(self.routeManagerSave, exists and "Overwrite" or "Save Current")
end

function UI:RefreshRouteManager()
    if not self.routeManager or not Addon.profile then
        return
    end
    local names = sortedSavedRouteNames()
    self.savedRouteOffset = clampOffset(self.savedRouteOffset, table.getn(names), 8)

    for visibleIndex = 1, 8 do
        local row = self.savedRouteRows[visibleIndex]
        local name = names[self.savedRouteOffset + visibleIndex]
        if name then
            local saved = Addon.profile.savedRoutes[name]
            local activePrefix = Addon.profile.activeRouteName == name and "|cff66ff66*|r " or ""
            local loopSuffix = saved.autoLoop and "  |cffffcc00[Loop]|r" or ""
            row.load.routeName = name
            row.share.routeName = name
            row.delete.routeName = name
            setButtonText(row.load, activePrefix .. name .. loopSuffix)
            setButtonText(row.delete, self.pendingDeleteName == name and "Confirm" or "Delete")
            row:Show()
        else
            row.load.routeName = nil
            row.share.routeName = nil
            row.delete.routeName = nil
            row:Hide()
        end
    end
    self.routeManagerPage:SetText(tostring(table.getn(names)) .. " saved route(s)")
    self:UpdateRouteSaveButton()
end

function UI:ToggleRouteManager()
    if not self.routeManager then
        return
    end
    self:HideQuestDetails()
    if self.settingsFrame and self.settingsFrame:IsShown() then
        self.settingsFrame:Hide()
    end
    if self.routeManager:IsShown() then
        self.routeManager:Hide()
    else
        self.pendingDeleteName = nil
        self.routeManagerName:SetText(Addon.profile.activeRouteName or "")
        self:RefreshRouteManager()
        self.routeManager:Show()
        self.routeManager:Raise()
    end
end

function UI:CaptureShiftClickedPlayer(link)
    if not self.routeManagerShareTarget or not IsShiftKeyDown or not IsShiftKeyDown() then
        return
    end
    local linkType, playerName = string.match(tostring(link or ""), "^([^:]+):([^:]+)")
    if linkType ~= "player" or not playerName or playerName == "" then
        return
    end
    self.routeManagerShareTarget:SetText(playerName)
    self.routeManagerShareTarget:HighlightText(0, 0)
end

function UI:InstallChatNameHook()
    if self.chatNameHooked or not hooksecurefunc or type(SetItemRef) ~= "function" then
        return
    end
    self.chatNameHooked = true
    hooksecurefunc("SetItemRef", function(link)
        UI:CaptureShiftClickedPlayer(link)
    end)
end

function UI:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "RavioliCallboardFrame", UIParent)
    frame:SetWidth(940)
    frame:SetHeight(620)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    setBackdrop(frame, COLORS.background)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)
    frame:SetScript("OnShow", function()
        UI:Refresh()
    end)
    frame:SetScript("OnHide", function()
        UI:HideQuestDetails()
        if UI.settingsFrame then
            UI.settingsFrame:Hide()
        end
        if UI.routeManager then
            UI.routeManager:Hide()
        end
    end)
    frame:Hide()
    self.frame = frame

    local window = Addon.profile and Addon.profile.window or {}
    frame:SetPoint(window.point or "CENTER", UIParent, window.relativePoint or "CENTER", window.x or 0, window.y or 0)

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.header:SetHeight(60)
    frame.header.texture = frame.header:CreateTexture(nil, "BACKGROUND")
    frame.header.texture:SetAllPoints()
    setTextureColor(frame.header.texture, { 0.055, 0.062, 0.078, 1 })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 18, -13)
    frame.title:SetText("RavioliCallboard")
    frame.title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 18, -38)
    frame.subtitle:SetText("Ordered Callboard route builder")
    frame.subtitle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    frame.close = makeButton(frame.header, "X", 28, 28)
    frame.close:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.settingsButton = makeButton(frame.header, "Settings", 76, 28)
    frame.settingsButton:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)
    frame.settingsButton:SetScript("OnClick", function()
        UI:ToggleSettings()
    end)

    frame.routesButton = makeButton(frame.header, "Routes", 76, 28)
    frame.routesButton:SetPoint("RIGHT", frame.settingsButton, "LEFT", -8, 0)
    frame.routesButton:SetScript("OnClick", function()
        UI:ToggleRouteManager()
    end)

    self.navPanel = CreateFrame("Frame", nil, frame)
    self.navPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -61)
    self.navPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    self.navPanel:SetWidth(152)
    setBackdrop(self.navPanel, { 0.045, 0.052, 0.066, 1 }, { 0.10, 0.11, 0.14, 1 })

    self.routePanel = makePanel(frame, "Quest route", 356, 514)
    self.routePanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -61)
    self.routePanel:EnableMouseWheel(true)
    self.routePanel:SetScript("OnMouseWheel", function(_, delta)
        local count = Addon.profile and table.getn(Addon.profile.route) or 0
        UI.routeOffset = clampOffset(UI.routeOffset - delta, count, 13)
        UI:Refresh()
    end)

    self.catalogPanel = makePanel(frame, "Learned Callboard quests", 430, 514)
    self.catalogPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 153, -61)
    self.catalogPanel:EnableMouseWheel(true)
    self.catalogPanel:SetScript("OnMouseWheel", function(_, delta)
        local count = table.getn(UI.catalog or {})
        UI.catalogOffset = clampOffset(UI.catalogOffset - delta, count, 12)
        UI:Refresh()
    end)

    self.searchHolder, self.search = makeInput(self.catalogPanel, 398, 30, 80)
    self.searchHolder:SetPoint("TOPLEFT", self.catalogPanel, "TOPLEFT", 16, -31)
    self.search:SetScript("OnTextChanged", function(self)
        UI:HideQuestDetails()
        UI.searchText = self:GetText() or ""
        UI.catalogOffset = 0
        UI:Refresh()
    end)

    for i = 1, 13 do
        local row = createRouteRow(self.routePanel, i)
        row:SetPoint("TOP", self.routePanel, "TOP", 0, -32 - ((i - 1) * 29))
        self.routeRows[i] = row
    end

    for i = 1, 12 do
        local row = createCatalogRow(self.catalogPanel, i)
        row:SetPoint("TOP", self.catalogPanel, "TOP", 0, -63 - ((i - 1) * 29))
        self.catalogRows[i] = row
    end

    self.routeEmpty = self.routePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.routeEmpty:SetPoint("CENTER", self.routePanel, "CENTER", 0, 8)
    self.routeEmpty:SetWidth(300)
    self.routeEmpty:SetText("No route steps yet.\n\nAdd quests from the catalogue to begin.")
    self.routeEmpty:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.routeEmpty:SetJustifyH("CENTER")

    self.catalogEmpty = self.catalogPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.catalogEmpty:SetPoint("CENTER", self.catalogPanel, "CENTER", 0, 8)
    self.catalogEmpty:SetWidth(340)
    self.catalogEmpty:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.catalogEmpty:SetJustifyH("CENTER")

    self.detailPopup = CreateFrame("Frame", "RavioliCallboardQuestDetailPopup", frame)
    self.detailPopup:SetWidth(390)
    self.detailPopup:SetHeight(125)
    self.detailPopup:SetFrameStrata("TOOLTIP")
    self.detailPopup:SetClampedToScreen(true)
    setBackdrop(self.detailPopup, COLORS.background, COLORS.gold)
    self.detailPopup.headerTexture = addHeaderBand(self.detailPopup, 30)
    self.detailPopup:EnableMouse(true)

    self.detailPopup.title = self.detailPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.detailPopup.title:SetPoint("TOPLEFT", self.detailPopup, "TOPLEFT", 12, -10)
    self.detailPopup.title:SetPoint("RIGHT", self.detailPopup, "RIGHT", -38, 0)
    self.detailPopup.title:SetJustifyH("LEFT")
    self.detailPopup.title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.detailPopup.meta = self.detailPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.detailPopup.meta:SetPoint("TOPLEFT", self.detailPopup.title, "BOTTOMLEFT", 0, -5)
    self.detailPopup.meta:SetPoint("RIGHT", self.detailPopup, "RIGHT", -12, 0)
    self.detailPopup.meta:SetJustifyH("LEFT")
    self.detailPopup.meta:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.detailPopup.objective = self.detailPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.detailPopup.objective:SetPoint("TOPLEFT", self.detailPopup.meta, "BOTTOMLEFT", 0, -8)
    self.detailPopup.objective:SetPoint("RIGHT", self.detailPopup, "RIGHT", -12, 0)
    self.detailPopup.objective:SetJustifyH("LEFT")
    self.detailPopup.objective:SetJustifyV("TOP")

    self.detailPopup.close = makeButton(self.detailPopup, "X", 24, 21)
    self.detailPopup.close:SetPoint("TOPRIGHT", self.detailPopup, "TOPRIGHT", -6, -6)
    self.detailPopup.close:SetScript("OnClick", function()
        UI:HideQuestDetails()
    end)

    self.detailPopup.add = makeButton(self.detailPopup, "Add to Route", 94, 23)
    self.detailPopup.add.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.detailPopup.add:SetPoint("BOTTOMRIGHT", self.detailPopup, "BOTTOMRIGHT", -9, 8)
    self.detailPopup.add:SetScript("OnClick", function(self)
        if self.questKey then
            Addon:AddRouteQuest(self.questKey)
            UI:HideQuestDetails()
        end
    end)
    self.detailPopup:Hide()

    self.settingsFrame = CreateFrame("Frame", "RavioliCallboardSettingsFrame", frame)
    self.settingsFrame:SetWidth(480)
    self.settingsFrame:SetHeight(440)
    self.settingsFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    self.settingsFrame:SetFrameStrata("TOOLTIP")
    self.settingsFrame:SetClampedToScreen(true)
    setBackdrop(self.settingsFrame, COLORS.background, COLORS.gold)
    self.settingsFrame.headerTexture = addHeaderBand(self.settingsFrame, 46)
    self.settingsFrame:EnableMouse(true)

    self.settingsFrame.title = self.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.settingsFrame.title:SetPoint("TOPLEFT", self.settingsFrame, "TOPLEFT", 16, -15)
    self.settingsFrame.title:SetText("RavioliCallboard Settings")
    self.settingsFrame.title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.settingsFrame.close = makeButton(self.settingsFrame, "X", 26, 22)
    self.settingsFrame.close:SetPoint("TOPRIGHT", self.settingsFrame, "TOPRIGHT", -9, -9)
    self.settingsFrame.close:SetScript("OnClick", function()
        UI.settingsFrame:Hide()
    end)

    self.settingsAutoLoop = makeCheckbox(self.settingsFrame, "Automatically loop to step 1 when the route finishes")
    self.settingsAutoLoop:SetPoint("TOPLEFT", self.settingsFrame, "TOPLEFT", 18, -57)
    self.settingsAutoLoop.label:SetWidth(410)
    self.settingsAutoLoop.label:SetJustifyH("LEFT")

    self.settingsAutoAccept = makeCheckbox(self.settingsFrame, "Auto-accept only the exact current route quest")
    self.settingsAutoAccept:SetPoint("TOPLEFT", self.settingsAutoLoop, "BOTTOMLEFT", 0, -14)
    self.settingsAutoAccept.label:SetWidth(410)
    self.settingsAutoAccept.label:SetJustifyH("LEFT")

    self.settingsAutoShare = makeCheckbox(self.settingsFrame, "Automatically share each accepted route quest with the group")
    self.settingsAutoShare:SetPoint("TOPLEFT", self.settingsAutoAccept, "BOTTOMLEFT", 0, -10)
    self.settingsAutoShare.label:SetWidth(410)
    self.settingsAutoShare.label:SetJustifyH("LEFT")

    self.settingsGroupProgress = makeCheckbox(self.settingsFrame, "Exchange live quest progress with other RavioliCallboard users")
    self.settingsGroupProgress:SetPoint("TOPLEFT", self.settingsAutoShare, "BOTTOMLEFT", 0, -10)
    self.settingsGroupProgress.label:SetWidth(410)
    self.settingsGroupProgress.label:SetJustifyH("LEFT")

    self.settingsMaxLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.settingsMaxLabel:SetPoint("TOPLEFT", self.settingsGroupProgress, "BOTTOMLEFT", 2, -24)
    self.settingsMaxLabel:SetWidth(320)
    self.settingsMaxLabel:SetJustifyH("LEFT")
    self.settingsMaxLabel:SetText("Maximum rerolls per route step")
    self.settingsMaxLabel:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.settingsMaxHolder, self.settingsMaxRerolls = makeInput(self.settingsFrame, 70, 24, 3)
    self.settingsMaxRerolls:SetNumeric(true)
    self.settingsMaxHolder:SetPoint("LEFT", self.settingsMaxLabel, "RIGHT", 14, 0)

    self.settingsDelayLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.settingsDelayLabel:SetPoint("TOPLEFT", self.settingsMaxLabel, "BOTTOMLEFT", 0, -26)
    self.settingsDelayLabel:SetWidth(320)
    self.settingsDelayLabel:SetJustifyH("LEFT")
    self.settingsDelayLabel:SetText("Reroll response delay (seconds)")
    self.settingsDelayLabel:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.settingsDelayHolder, self.settingsRerollDelay = makeInput(self.settingsFrame, 70, 24, 5)
    self.settingsDelayHolder:SetPoint("LEFT", self.settingsDelayLabel, "RIGHT", 14, 0)

    self.settingsMiniCountLabel = self.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.settingsMiniCountLabel:SetPoint("TOPLEFT", self.settingsDelayLabel, "BOTTOMLEFT", 0, -26)
    self.settingsMiniCountLabel:SetWidth(320)
    self.settingsMiniCountLabel:SetJustifyH("LEFT")
    self.settingsMiniCountLabel:SetText("Quests shown in mini window (1-20)")
    self.settingsMiniCountLabel:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.settingsMiniHolder, self.settingsMiniQuestCount = makeInput(self.settingsFrame, 70, 24, 2)
    self.settingsMiniQuestCount:SetNumeric(true)
    self.settingsMiniHolder:SetPoint("LEFT", self.settingsMiniCountLabel, "RIGHT", 14, 0)

    self.settingsFrame.note = self.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.settingsFrame.note:SetPoint("TOPLEFT", self.settingsMiniCountLabel, "BOTTOMLEFT", 0, -27)
    self.settingsFrame.note:SetWidth(440)
    self.settingsFrame.note:SetHeight(72)
    self.settingsFrame.note:SetJustifyH("LEFT")
    self.settingsFrame.note:SetJustifyV("TOP")
    if self.settingsFrame.note.SetWordWrap then
        self.settingsFrame.note:SetWordWrap(true)
    end
    self.settingsFrame.note:SetText("Group progress requires RavioliCallboard on each player. Without it, they show as No addon data. Looping is saved per route and requires at least four different quests because the Callboard locks a quest for the next three completions.")
    self.settingsFrame.note:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.settingsFrame.save = makeButton(self.settingsFrame, "Save Settings", 112, 27)
    self.settingsFrame.save.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.settingsFrame.save:SetPoint("BOTTOMRIGHT", self.settingsFrame, "BOTTOMRIGHT", -14, 12)
    self.settingsFrame.save:SetScript("OnClick", function()
        Addon:ApplySettings(
            UI.settingsAutoLoop:GetChecked(),
            UI.settingsAutoAccept:GetChecked(),
            UI.settingsMaxRerolls:GetText(),
            UI.settingsRerollDelay:GetText(),
            UI.settingsMiniQuestCount:GetText(),
            UI.settingsAutoShare:GetChecked(),
            UI.settingsGroupProgress:GetChecked()
        )
    end)
    self.settingsFrame:Hide()

    self.routeManager = CreateFrame("Frame", "RavioliCallboardRouteManager", frame)
    self.routeManager:SetWidth(460)
    self.routeManager:SetHeight(465)
    self.routeManager:SetPoint("CENTER", frame, "CENTER", 0, 0)
    self.routeManager:SetFrameStrata("TOOLTIP")
    setBackdrop(self.routeManager, COLORS.background, COLORS.gold)
    self.routeManager.headerTexture = addHeaderBand(self.routeManager, 46)
    self.routeManager:EnableMouse(true)
    self.routeManager:EnableMouseWheel(true)
    self.routeManager:SetScript("OnMouseWheel", function(_, delta)
        local count = table.getn(sortedSavedRouteNames())
        UI.savedRouteOffset = clampOffset(UI.savedRouteOffset - delta, count, 8)
        UI:RefreshRouteManager()
    end)

    self.routeManager.title = self.routeManager:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.routeManager.title:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -15)
    self.routeManager.title:SetText("Saved Routes")
    self.routeManager.title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.routeManager.close = makeButton(self.routeManager, "X", 26, 22)
    self.routeManager.close:SetPoint("TOPRIGHT", self.routeManager, "TOPRIGHT", -9, -9)
    self.routeManager.close:SetScript("OnClick", function()
        UI.routeManager:Hide()
    end)

    self.routeManager.nameLabel = self.routeManager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.routeManager.nameLabel:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -50)
    self.routeManager.nameLabel:SetText("Route name")
    self.routeManager.nameLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.routeManagerNameHolder, self.routeManagerName = makeInput(self.routeManager, 312, 24, 60)
    self.routeManagerNameHolder:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 16, -66)
    self.routeManagerName:SetScript("OnTextChanged", function()
        UI:UpdateRouteSaveButton()
    end)
    self.routeManagerName:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.routeManagerName:SetScript("OnEnterPressed", function(self)
        Addon:SaveCurrentRoute(self:GetText())
        self:ClearFocus()
    end)

    self.routeManagerSave = makeButton(self.routeManager, "Save Current", 106, 25)
    self.routeManagerSave.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.routeManagerSave:SetPoint("TOPRIGHT", self.routeManager, "TOPRIGHT", -14, -65)
    self.routeManagerSave:SetScript("OnClick", function()
        Addon:SaveCurrentRoute(UI.routeManagerName:GetText())
    end)

    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, self.routeManager)
        row:SetHeight(29)
        row:SetPoint("TOPLEFT", self.routeManager, "TOPLEFT", 14, -105 - ((i - 1) * 31))
        row:SetPoint("RIGHT", self.routeManager, "RIGHT", -14, 0)
        setBackdrop(row, COLORS.normal, COLORS.border)

        row.load = makeButton(row, "", 258, 23)
        row.load:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.load:SetScript("OnClick", function(self)
            if self.routeName then
                UI.pendingDeleteName = nil
                Addon:LoadSavedRoute(self.routeName)
                UI.routeManagerName:SetText(self.routeName)
                UI:RefreshRouteManager()
            end
        end)

        row.share = makeButton(row, "Share", 82, 23)
        row.share:SetPoint("RIGHT", row, "RIGHT", -82, 0)
        row.share:SetScript("OnClick", function(self)
            if self.routeName then
                Addon:ShareSavedRoute(self.routeName, UI.routeManagerShareTarget:GetText())
                UI.routeManagerShareTarget:ClearFocus()
            end
        end)

        row.delete = makeButton(row, "Delete", 72, 23)
        row.delete.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
        row.delete:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.delete:SetScript("OnClick", function(self)
            if not self.routeName then
                return
            end
            if UI.pendingDeleteName == self.routeName then
                local name = self.routeName
                UI.pendingDeleteName = nil
                Addon:DeleteSavedRoute(name)
            else
                UI.pendingDeleteName = self.routeName
                UI:RefreshRouteManager()
            end
        end)

        self.savedRouteRows[i] = row
    end

    self.routeManager.shareLabel = self.routeManager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.routeManager.shareLabel:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 51)
    self.routeManager.shareLabel:SetText("Recipient for Share buttons (addon required)")
    self.routeManager.shareLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.routeManagerShareHolder, self.routeManagerShareTarget = makeInput(self.routeManager, 312, 24, 48)
    self.routeManagerShareHolder:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 17)
    if self.routeManagerShareTarget.SetMaxLetters then
        self.routeManagerShareTarget:SetMaxLetters(48)
    end
    self.routeManagerShareTarget:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    self.routeManagerShareTarget:SetScript("OnEnterPressed", function(self)
        Addon:ShareCurrentRoute(self:GetText(), UI.routeManagerName:GetText())
        self:ClearFocus()
    end)

    self.routeManagerShare = makeButton(self.routeManager, "Share Current", 108, 25)
    self.routeManagerShare.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.routeManagerShare:SetPoint("BOTTOMRIGHT", self.routeManager, "BOTTOMRIGHT", -14, 17)
    self.routeManagerShare:SetScript("OnClick", function()
        Addon:ShareCurrentRoute(UI.routeManagerShareTarget:GetText(), UI.routeManagerName:GetText())
        UI.routeManagerShareTarget:ClearFocus()
    end)

    self.routeManagerPage = self.routeManager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.routeManagerPage:SetPoint("BOTTOMLEFT", self.routeManager, "BOTTOMLEFT", 16, 85)
    self.routeManagerPage:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
    self.routeManager:Hide()
    self:InstallChatNameHook()

    self.routePage = self.routePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.routePage:SetPoint("BOTTOMLEFT", self.routePanel, "BOTTOMLEFT", 12, 10)
    self.routePage:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.catalogPage = self.catalogPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.catalogPage:SetPoint("BOTTOMLEFT", self.catalogPanel, "BOTTOMLEFT", 12, 10)
    self.catalogPage:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.up = makeButton(frame, "Up", 62, 25)
    self.up:SetPoint("TOPLEFT", self.routePanel, "BOTTOMLEFT", 0, -8)
    self.up:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:MoveRouteStep(UI.selectedRouteIndex, UI.selectedRouteIndex - 1)
            UI.selectedRouteIndex = math.max(1, UI.selectedRouteIndex - 1)
        end
    end)

    self.down = makeButton(frame, "Down", 62, 25)
    self.down:SetPoint("LEFT", self.up, "RIGHT", 5, 0)
    self.down:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:MoveRouteStep(UI.selectedRouteIndex, UI.selectedRouteIndex + 1)
            UI.selectedRouteIndex = math.min(table.getn(Addon.profile.route), UI.selectedRouteIndex + 1)
        end
    end)

    self.remove = makeButton(frame, "Remove", 72, 25)
    self.remove.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    self.remove:SetPoint("LEFT", self.down, "RIGHT", 5, 0)
    self.remove:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:RemoveRouteStep(UI.selectedRouteIndex)
            UI.selectedRouteIndex = nil
        end
    end)

    self.setCurrent = makeButton(frame, "Set Current", 94, 25)
    self.setCurrent:SetPoint("LEFT", self.remove, "RIGHT", 5, 0)
    self.setCurrent:SetScript("OnClick", function()
        if UI.selectedRouteIndex then
            Addon:SetCurrentStep(UI.selectedRouteIndex)
        end
    end)

    self.collapseZones = makeButton(frame, "Collapse", 76, 25)
    self.collapseZones:SetPoint("TOPLEFT", self.catalogPanel, "BOTTOMLEFT", 0, -8)
    self.collapseZones:SetScript("OnClick", function()
        UI:SetAllCatalogGroupsCollapsed(true)
    end)

    self.expandZones = makeButton(frame, "Expand", 76, 25)
    self.expandZones:SetPoint("LEFT", self.collapseZones, "RIGHT", 5, 0)
    self.expandZones:SetScript("OnClick", function()
        UI:SetAllCatalogGroupsCollapsed(false)
    end)

    self.import = makeButton(frame, "Import AutoCallboard", 148, 25)
    self.import.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.import:SetPoint("TOPRIGHT", self.catalogPanel, "BOTTOMRIGHT", 0, -8)
    self.import:SetScript("OnClick", function()
        Addon:ImportAutoCallboard()
    end)

    self.navRunLabel = self.navPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.navRunLabel:SetPoint("TOPLEFT", self.navPanel, "TOPLEFT", 14, -18)
    self.navRunLabel:SetText("RUN ROUTE")
    self.navRunLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.navStatusLabel = self.navPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.navStatusLabel:SetPoint("TOPLEFT", self.navPanel, "TOPLEFT", 14, -270)
    self.navStatusLabel:SetText("STATUS")
    self.navStatusLabel:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.status:SetPoint("TOPLEFT", self.navPanel, "TOPLEFT", 14, -292)
    self.status:SetWidth(124)
    self.status:SetHeight(210)
    self.status:SetJustifyH("LEFT")
    self.status:SetJustifyV("TOP")
    self.status:SetText("Ready.")
    self.status:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.start = CreateFrame("Button", "RavioliCallboardStartRouteButton", self.navPanel, "SecureActionButtonTemplate")
    self.start:SetWidth(124)
    self.start:SetHeight(30)
    styleSecureButton(self.start, "Start Route")
    self.start:SetPoint("TOPLEFT", self.navPanel, "TOPLEFT", 14, -40)
    self.start.label:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    self.start:SetAttribute("type", "macro")
    self.start:SetAttribute("macrotext", "/cast Summon Callboard")
    self.start:SetScript("PostClick", function()
        Addon:BeginStartFlow()
    end)
    self.startActionCasts = true
    self:UpdateStartAction()

    self.summon = CreateFrame("Button", "RavioliCallboardSummonButton", self.navPanel, "SecureActionButtonTemplate")
    self.summon:SetWidth(124)
    self.summon:SetHeight(30)
    styleSecureButton(self.summon, "Summon Board")
    self.summon:SetPoint("TOPLEFT", self.start, "BOTTOMLEFT", 0, -8)
    self.summon:SetAttribute("type", "macro")
    self.summon:SetAttribute("macrotext", "/cast Summon Callboard")
    self.summon:SetScript("PostClick", function()
        Addon:BeginBoardOpenFlow(false)
    end)
    self:UpdateSummonCooldown()

    self.advance = makeButton(self.navPanel, "Complete Step", 124, 30)
    self.advance:SetPoint("TOPLEFT", self.summon, "BOTTOMLEFT", 0, -8)
    self.advance.label:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3])
    self.advance:SetScript("OnClick", function()
        Addon:AdvanceRoute("Marked complete by user")
    end)

    self.reset = makeButton(self.navPanel, "Reset to Step 1", 124, 30)
    self.reset:SetPoint("TOPLEFT", self.advance, "BOTTOMLEFT", 0, -8)
    self.reset:SetScript("OnClick", function()
        Addon:ResetRoute()
    end)

    self.clear = makeButton(self.navPanel, "Clear Route", 124, 30)
    self.clear:SetPoint("TOPLEFT", self.reset, "BOTTOMLEFT", 0, -8)
    self.clear.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])
    self.clear:SetScript("OnClick", function()
        Addon:ClearRoute()
        UI.selectedRouteIndex = nil
    end)

    local miniLayout = Addon.profile.miniWindow
    self.miniFrame = CreateFrame("Frame", "RavioliCallboardMiniFrame", UIParent)
    self.miniFrame:SetWidth(math.max(360, miniLayout.width or 390))
    self.miniFrame:SetHeight(miniLayout.height or 190)
    self.miniFrame:SetPoint(
        miniLayout.point or "CENTER",
        UIParent,
        miniLayout.relativePoint or "CENTER",
        miniLayout.x or 0,
        miniLayout.y or 180
    )
    self.miniFrame:SetFrameStrata("DIALOG")
    self.miniFrame:SetClampedToScreen(true)
    self.miniFrame:SetMovable(true)
    self.miniFrame:SetResizable(true)
    if self.miniFrame.SetMinResize then
        self.miniFrame:SetMinResize(360, 165)
    end
    if self.miniFrame.SetMaxResize then
        self.miniFrame:SetMaxResize(700, 600)
    end
    self.miniFrame:EnableMouse(true)
    self.miniFrame:RegisterForDrag("LeftButton")
    setBackdrop(self.miniFrame, COLORS.background)
    self.miniFrame.headerTexture = addHeaderBand(self.miniFrame, 32)
    self.miniFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    self.miniFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SaveMiniLayout()
    end)

    self.miniFrame.title = self.miniFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.miniFrame.title:SetPoint("TOPLEFT", self.miniFrame, "TOPLEFT", 14, -12)
    self.miniFrame.title:SetPoint("RIGHT", self.miniFrame, "RIGHT", -14, 0)
    self.miniFrame.title:SetJustifyH("LEFT")
    self.miniFrame.title:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])

    self.miniCurrent = self.miniFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.miniCurrent:SetPoint("TOPLEFT", self.miniFrame, "TOPLEFT", 14, -40)
    self.miniCurrent:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -14, 88)
    self.miniCurrent:SetJustifyH("LEFT")
    self.miniCurrent:SetJustifyV("TOP")

    self.miniNext = self.miniFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.miniNext:Hide()

    self.miniStatus = self.miniFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.miniStatus:SetPoint("BOTTOMLEFT", self.miniFrame, "BOTTOMLEFT", 14, 52)
    self.miniStatus:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -14, 52)
    self.miniStatus:SetJustifyH("LEFT")
    self.miniStatus:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.miniSummon = CreateFrame("Button", "RavioliCallboardMiniSummonButton", self.miniFrame, "SecureActionButtonTemplate")
    self.miniSummon:SetWidth(122)
    self.miniSummon:SetHeight(28)
    self.miniSummon:SetPoint("BOTTOMLEFT", self.miniFrame, "BOTTOMLEFT", 14, 14)
    styleSecureButton(self.miniSummon, "Summon Board")
    self.miniSummon:SetAttribute("type", "macro")
    self.miniSummon:SetAttribute("macrotext", "/cast Summon Callboard")
    self.miniSummon:SetScript("PostClick", function()
        Addon:BeginBoardOpenFlow(false)
    end)

    self.miniStop = makeButton(self.miniFrame, "STOP", 90, 28)
    self.miniStop:SetPoint("LEFT", self.miniSummon, "RIGHT", 8, 0)
    self.miniStop:SetScript("OnClick", function()
        Addon:StopRouteAndReturn()
    end)
    self.miniStop.label:SetTextColor(COLORS.red[1], COLORS.red[2], COLORS.red[3])

    self.miniGroup = makeButton(self.miniFrame, "Group", 88, 28)
    self.miniGroup:SetPoint("LEFT", self.miniStop, "RIGHT", 8, 0)
    self.miniGroup:SetScript("OnClick", function()
        UI:ToggleGroupProgress()
    end)

    self.groupProgressFrame = CreateFrame("Frame", "RavioliCallboardGroupProgressFrame", self.miniFrame)
    self.groupProgressFrame:SetWidth(360)
    self.groupProgressFrame:SetHeight(390)
    self.groupProgressFrame:SetPoint("TOPLEFT", self.miniFrame, "TOPRIGHT", 8, 0)
    self.groupProgressFrame:SetFrameStrata("TOOLTIP")
    self.groupProgressFrame:SetClampedToScreen(true)
    self.groupProgressFrame:EnableMouse(true)
    setBackdrop(self.groupProgressFrame, COLORS.background, COLORS.gold)
    self.groupProgressFrame.headerTexture = addHeaderBand(self.groupProgressFrame, 48)

    self.groupProgressFrame.title = self.groupProgressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.groupProgressFrame.title:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 14, -13)
    self.groupProgressFrame.title:SetText("Group Progress")
    self.groupProgressFrame.title:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])

    self.groupProgressFrame.close = makeButton(self.groupProgressFrame, "X", 26, 22)
    self.groupProgressFrame.close:SetPoint("TOPRIGHT", self.groupProgressFrame, "TOPRIGHT", -9, -9)
    self.groupProgressFrame.close:SetScript("OnClick", function()
        UI.groupProgressFrame:Hide()
    end)

    self.groupProgressFrame.subtitle = self.groupProgressFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.groupProgressFrame.subtitle:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 14, -42)
    self.groupProgressFrame.subtitle:SetPoint("RIGHT", self.groupProgressFrame, "RIGHT", -14, 0)
    self.groupProgressFrame.subtitle:SetJustifyH("LEFT")
    self.groupProgressFrame.subtitle:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])

    self.groupProgressScroll = CreateFrame("ScrollFrame", "RavioliCallboardGroupProgressScroll", self.groupProgressFrame, "UIPanelScrollFrameTemplate")
    self.groupProgressScroll:SetPoint("TOPLEFT", self.groupProgressFrame, "TOPLEFT", 12, -68)
    self.groupProgressScroll:SetPoint("BOTTOMRIGHT", self.groupProgressFrame, "BOTTOMRIGHT", -31, 13)

    self.groupProgressChild = CreateFrame("Frame", nil, self.groupProgressScroll)
    self.groupProgressChild:SetWidth(305)
    self.groupProgressChild:SetHeight(250)
    self.groupProgressScroll:SetScrollChild(self.groupProgressChild)

    self.groupProgressText = self.groupProgressChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.groupProgressText:SetPoint("TOPLEFT", self.groupProgressChild, "TOPLEFT", 3, -3)
    self.groupProgressText:SetPoint("RIGHT", self.groupProgressChild, "RIGHT", -3, 0)
    self.groupProgressText:SetJustifyH("LEFT")
    self.groupProgressText:SetJustifyV("TOP")
    self.groupProgressFrame:Hide()

    self.miniResize = CreateFrame("Button", nil, self.miniFrame)
    self.miniResize:SetWidth(18)
    self.miniResize:SetHeight(18)
    self.miniResize:SetPoint("BOTTOMRIGHT", self.miniFrame, "BOTTOMRIGHT", -2, 2)
    self.miniResize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    self.miniResize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    self.miniResize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    self.miniResize:SetScript("OnMouseDown", function()
        UI.miniFrame:StartSizing("BOTTOMRIGHT")
    end)
    self.miniResize:SetScript("OnMouseUp", function()
        UI.miniFrame:StopMovingOrSizing()
        UI:SaveMiniLayout()
    end)
    self.miniFrame:Hide()
    self.lastSummonCooldownSecond = nil
    self:UpdateSummonCooldown()

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "RavioliCallboardFrame")
    end
    return frame
end

function UI:SetStatus(message)
    if self.status then
        self.status:SetText(message or "")
        local color = getStatusColor(message)
        self.status:SetTextColor(color[1], color[2], color[3])
    end
end

function UI:Refresh()
    if not self.frame or not Addon.profile or not Addon.db then
        return
    end

    local route = Addon.profile.route
    local routeCount = table.getn(route)
    local activeRouteName = Addon.profile.activeRouteName
    local loopSuffix = Addon.profile.autoLoop and "  |cffffcc00[Loop]|r" or ""
    self.routePanel.title:SetText(activeRouteName and ("Quest route — " .. activeRouteName .. loopSuffix) or ("Quest route" .. loopSuffix))
    self.routeOffset = clampOffset(self.routeOffset, routeCount, 13)

    for visibleIndex = 1, 13 do
        local row = self.routeRows[visibleIndex]
        local routeIndex = self.routeOffset + visibleIndex
        local key = route[routeIndex]
        if key then
            local quest = Addon.db.knownQuests[key]
            local title = quest and Core.QuestTitle(quest) or key
            row.routeIndex = routeIndex
            row.number:SetText(tostring(routeIndex) .. ".")
            row.label:SetText(title)
            if routeIndex == Addon.profile.currentStep then
                row:SetBackdropColor(unpack(COLORS.current))
                row:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
            elseif routeIndex == self.selectedRouteIndex then
                row:SetBackdropColor(unpack(COLORS.selected))
                row:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)
            else
                row:SetBackdropColor(unpack(COLORS.normal))
                row:SetBackdropBorderColor(unpack(COLORS.border))
            end
            row:Show()
        else
            row.routeIndex = nil
            row:Hide()
        end
    end
    self.routePage:SetText(tostring(routeCount) .. " route step(s)")
    if routeCount == 0 then
        self.routeEmpty:Show()
    else
        self.routeEmpty:Hide()
    end

    local zoneCount
    local learnedCount
    self.catalog, zoneCount, learnedCount = Core.BuildGroupedCatalog(
        Addon.db,
        self.searchText,
        Addon.profile.catalogCollapsed
    )
    local catalogCount = table.getn(self.catalog)
    if catalogCount == 0 then
        self.catalogEmpty:SetText((self.searchText or "") ~= ""
            and "No learned quests match this search."
            or "No quests learned yet.\n\nOpen the Callboard or import AutoCallboard data.")
        self.catalogEmpty:Show()
    else
        self.catalogEmpty:Hide()
    end
    self.catalogOffset = clampOffset(self.catalogOffset, catalogCount, 12)
    for visibleIndex = 1, 12 do
        local row = self.catalogRows[visibleIndex]
        local catalogIndex = self.catalogOffset + visibleIndex
        local entry = self.catalog[catalogIndex]
        if entry then
            if entry.kind == "header" then
                row.groupId = entry.groupId
                row.add.questKey = nil
                row.info.questKey = nil
                row.add:Hide()
                row.info:Hide()
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.label:SetText((entry.collapsed and "|cffffcc00[+]|r " or "|cffffcc00[-]|r ")
                    .. entry.label .. "  |cff888888(" .. tostring(entry.count) .. ")|r")
                row:SetBackdropColor(unpack(COLORS.panelLight))
                row:SetBackdropBorderColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.65)
            else
                local quest = entry.quest
                local inRoute = Core.RouteContains(route, quest.key)
                row.groupId = nil
                row.add.questKey = quest.key
                row.info.questKey = quest.key
                setButtonText(row.add, inRoute and "=" or "+")
                row.add:Show()
                row.info:Show()
                if inRoute then
                    row.add:SetButtonEnabled(false)
                else
                    row.add:SetButtonEnabled(true)
                end
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row.add, "RIGHT", 7, 0)
                row.label:SetPoint("RIGHT", row.info, "LEFT", -5, 0)
                local idSuffix = quest.questId and "  |cff777777#" .. tostring(quest.questId) .. "|r" or ""
                row.label:SetText(Core.QuestTitle(quest) .. idSuffix)
                row:SetBackdropColor(unpack(COLORS.normal))
                row:SetBackdropBorderColor(unpack(COLORS.border))
            end
            row:Show()
        else
            row.groupId = nil
            row.add.questKey = nil
            row.info.questKey = nil
            row:Hide()
        end
    end
    self.catalogPage:SetText(tostring(learnedCount or 0) .. " learned quest(s) in " .. tostring(zoneCount or 0) .. " zone group(s)")

    setButtonText(self.start, "Start Route")
    self:SetStatus(Addon.statusMessage or "Ready.")
    self:RefreshMini()
end

function UI:Toggle()
    if Addon.uiInitError then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555RavioliCallboard UI error:|r " .. tostring(Addon.uiInitError))
        end
        return
    end
    self:Create()
    if self.miniFrame and self.miniFrame:IsShown() then
        self:ShowMain()
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end

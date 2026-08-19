local addonName, Addon = ...

Addon = Addon or {}
_G.RavioliCallboard = Addon

local Core = {}
Addon.Core = Core

Core.VERSION = 3

Core.REPEAT_LOCKOUT_COUNT = 3

-- Project Ebonhold's objective payload uses zoneOrSort for both outdoor zones
-- and instances. These names mirror the currently known Callboard catalogue.
Core.ZONE_NAMES = {
    [90] = "Storm Peaks",
    [206] = "Utgarde Keep",
    [210] = "Icecrown",
    [618] = "Wintergrasp",
    [1196] = "Utgarde Pinnacle",
    [2817] = "Crystalsong Forest",
    [3456] = "Naxxramas",
    [4196] = "Drak'Tharon Keep",
    [4228] = "The Oculus",
    [4265] = "The Nexus",
    [4272] = "Halls of Lightning",
    [4273] = "Ulduar",
    [4277] = "Azjol-Nerub",
    [4416] = "Gundrak",
    [4493] = "Obsidian Sanctum",
    [4494] = "Ahn'kahet",
    [4500] = "Eye of Eternity",
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shallowCopy(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end
    return copy
end

function Core.NormalizeTitle(value)
    return string.lower(trim(value))
end

function Core.QuestTitle(quest)
    if type(quest) ~= "table" then
        return ""
    end
    return trim(quest.title or quest.name or quest.questTitle or quest.objectiveTitle)
end

function Core.QuestID(quest)
    if type(quest) ~= "table" then
        return nil
    end
    local id = tonumber(quest.questId or quest.questID or quest.id)
    if id and id > 0 then
        return math.floor(id)
    end
    return nil
end

function Core.QuestKey(quest)
    local id = Core.QuestID(quest)
    if id then
        return "id:" .. tostring(id)
    end

    local title = Core.NormalizeTitle(Core.QuestTitle(quest))
    if title ~= "" then
        return "title:" .. title
    end
    return nil
end

function Core.NormalizeQuest(quest)
    if type(quest) ~= "table" then
        return nil
    end

    local key = Core.QuestKey(quest)
    if not key then
        return nil
    end

    return {
        key = key,
        questId = Core.QuestID(quest),
        title = Core.QuestTitle(quest),
        objectiveText = trim(quest.objectiveText or quest.description or quest.text),
        questType = tonumber(quest.questType or quest.type),
        zoneOrSort = tonumber(quest.zoneOrSort or quest.zoneId or quest.zoneID),
    }
end

function Core.CopyQuest(quest)
    local normalized = Core.NormalizeQuest(quest)
    if not normalized then
        return nil
    end
    return shallowCopy(normalized)
end

function Core.DefaultProfile()
    return {
        route = {},
        currentStep = 1,
        recentCompletedQuests = {},
        maxRerolls = 50,
        rerollDelay = 1.6,
        autoAccept = true,
        autoLoop = false,
        autoShare = true,
        showGroupProgress = true,
        miniQuestCount = 5,
        savedRoutes = {},
        activeRouteName = nil,
        catalogCollapsed = {},
        window = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        miniWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 180,
            width = 390,
            height = 190,
        },
    }
end

local function copyRoute(route)
    local result = {}
    if type(route) ~= "table" then
        return result
    end

    for i = 1, table.getn(route) do
        local key = route[i]
        if type(key) == "string" and key ~= "" then
            table.insert(result, key)
        end
    end
    return result
end

Core.CopyRoute = copyRoute

function Core.RecordCompletedQuest(history, key)
    local result = {}
    if type(history) == "table" then
        for i = 1, table.getn(history) do
            local previousKey = history[i]
            if type(previousKey) == "string" and previousKey ~= "" and previousKey ~= key then
                local alreadyAdded = false
                for j = 1, table.getn(result) do
                    if result[j] == previousKey then
                        alreadyAdded = true
                        break
                    end
                end
                if not alreadyAdded then
                    table.insert(result, previousKey)
                end
            end
        end
    end

    if type(key) == "string" and key ~= "" then
        table.insert(result, key)
    end
    while table.getn(result) > Core.REPEAT_LOCKOUT_COUNT do
        table.remove(result, 1)
    end
    return result
end

function Core.IsQuestRepeatLocked(history, key)
    if type(history) ~= "table" or type(key) ~= "string" then
        return false
    end
    for i = 1, table.getn(history) do
        if history[i] == key then
            return true
        end
    end
    return false
end

function Core.ValidateRouteRepeatSpacing(route, autoLoop)
    if type(route) ~= "table" then
        return true
    end

    local count = table.getn(route)
    for startIndex = 1, count do
        local key = route[startIndex]
        local seen = {}
        local differentCount = 0
        local maxDistance = autoLoop and count or (count - startIndex)

        for distance = 1, maxDistance do
            local nextIndex = math.mod(startIndex + distance - 1, count) + 1
            local nextKey = route[nextIndex]
            if nextKey == key then
                if differentCount < Core.REPEAT_LOCKOUT_COUNT then
                    return false, key, startIndex, nextIndex, differentCount
                end
                break
            elseif type(nextKey) == "string" and nextKey ~= "" and not seen[nextKey] then
                seen[nextKey] = true
                differentCount = differentCount + 1
            end
        end
    end
    return true
end

function Core.MergeProfile(saved)
    local profile = Core.DefaultProfile()
    if type(saved) ~= "table" then
        return profile
    end

    profile.route = copyRoute(saved.route)

    if type(saved.recentCompletedQuests) == "table" then
        for i = 1, table.getn(saved.recentCompletedQuests) do
            profile.recentCompletedQuests = Core.RecordCompletedQuest(
                profile.recentCompletedQuests,
                saved.recentCompletedQuests[i]
            )
        end
    end

    if type(saved.currentStep) == "number" then
        profile.currentStep = math.max(1, math.floor(saved.currentStep))
    end
    if type(saved.maxRerolls) == "number" then
        profile.maxRerolls = math.max(1, math.min(500, math.floor(saved.maxRerolls)))
    end
    if type(saved.rerollDelay) == "number" then
        profile.rerollDelay = math.max(0.5, math.min(10, saved.rerollDelay))
    end
    if type(saved.autoAccept) == "boolean" then
        profile.autoAccept = saved.autoAccept
    end
    if type(saved.autoLoop) == "boolean" then
        profile.autoLoop = saved.autoLoop
    end
    if type(saved.autoShare) == "boolean" then
        profile.autoShare = saved.autoShare
    end
    if type(saved.showGroupProgress) == "boolean" then
        profile.showGroupProgress = saved.showGroupProgress
    end
    if type(saved.miniQuestCount) == "number" then
        profile.miniQuestCount = math.max(1, math.min(20, math.floor(saved.miniQuestCount)))
    end
    if type(saved.savedRoutes) == "table" then
        for name, savedRoute in pairs(saved.savedRoutes) do
            if type(name) == "string" and trim(name) ~= "" and type(savedRoute) == "table" then
                local routeData = savedRoute.route or savedRoute
                local route = copyRoute(routeData)
                if table.getn(route) > 0 then
                    profile.savedRoutes[trim(name)] = {
                        route = route,
                        autoLoop = savedRoute.autoLoop == true,
                    }
                end
            end
        end
    end
    if type(saved.activeRouteName) == "string" and profile.savedRoutes[trim(saved.activeRouteName)] then
        profile.activeRouteName = trim(saved.activeRouteName)
    end
    if type(saved.catalogCollapsed) == "table" then
        for groupId, collapsed in pairs(saved.catalogCollapsed) do
            if type(groupId) == "string" and collapsed == true then
                profile.catalogCollapsed[groupId] = true
            end
        end
    end

    if type(saved.window) == "table" then
        local window = saved.window
        if type(window.point) == "string" and window.point ~= "" then
            profile.window.point = window.point
        end
        if type(window.relativePoint) == "string" and window.relativePoint ~= "" then
            profile.window.relativePoint = window.relativePoint
        end
        if type(window.x) == "number" then
            profile.window.x = window.x
        end
        if type(window.y) == "number" then
            profile.window.y = window.y
        end
    end

    if type(saved.miniWindow) == "table" then
        local mini = saved.miniWindow
        if type(mini.point) == "string" and mini.point ~= "" then
            profile.miniWindow.point = mini.point
        end
        if type(mini.relativePoint) == "string" and mini.relativePoint ~= "" then
            profile.miniWindow.relativePoint = mini.relativePoint
        end
        if type(mini.x) == "number" then
            profile.miniWindow.x = mini.x
        end
        if type(mini.y) == "number" then
            profile.miniWindow.y = mini.y
        end
        if type(mini.width) == "number" then
            profile.miniWindow.width = math.max(330, math.min(650, mini.width))
        end
        if type(mini.height) == "number" then
            profile.miniWindow.height = math.max(165, math.min(320, mini.height))
        end
    end

    if profile.currentStep > table.getn(profile.route) + 1 then
        profile.currentStep = table.getn(profile.route) + 1
    end
    return profile
end

function Core.MergeDatabase(saved)
    local db = {
        version = Core.VERSION,
        knownQuests = {},
        profiles = {},
    }

    if type(saved) ~= "table" then
        return db
    end

    if type(saved.knownQuests) == "table" then
        for key, quest in pairs(saved.knownQuests) do
            local normalized = Core.NormalizeQuest(quest)
            if normalized then
                db.knownQuests[normalized.key] = normalized
            elseif type(key) == "string" and type(quest) == "table" then
                local fallback = shallowCopy(quest)
                fallback.key = key
                fallback.title = Core.QuestTitle(fallback)
                db.knownQuests[key] = fallback
            end
        end

        -- Accept older array-shaped catalogues as well.
        for i = 1, table.getn(saved.knownQuests) do
            local normalized = Core.NormalizeQuest(saved.knownQuests[i])
            if normalized then
                db.knownQuests[normalized.key] = normalized
            end
        end
    end

    if type(saved.profiles) == "table" then
        for profileKey, profile in pairs(saved.profiles) do
            if type(profileKey) == "string" then
                db.profiles[profileKey] = Core.MergeProfile(profile)
            end
        end
    end

    return db
end

function Core.ProfileKey()
    local player = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    player = trim(player)
    realm = trim(realm)
    if player == "" then
        player = "Unknown"
    end
    if realm == "" then
        realm = "UnknownRealm"
    end
    return realm .. "/" .. player
end

function Core.LearnQuest(db, quest)
    if type(db) ~= "table" then
        return false
    end
    db.knownQuests = db.knownQuests or {}

    local normalized = Core.NormalizeQuest(quest)
    if not normalized then
        return false
    end

    local previous = db.knownQuests[normalized.key]
    if previous then
        normalized.objectiveText = normalized.objectiveText ~= "" and normalized.objectiveText or previous.objectiveText
        normalized.questType = normalized.questType or previous.questType
        normalized.zoneOrSort = normalized.zoneOrSort or previous.zoneOrSort
    end
    db.knownQuests[normalized.key] = normalized
    return previous == nil
end

function Core.ImportQuestList(db, quests)
    local added = 0
    if type(quests) ~= "table" then
        return added
    end

    for _, quest in pairs(quests) do
        if Core.LearnQuest(db, quest) then
            added = added + 1
        end
    end
    return added
end

function Core.FindObjective(objectives, wantedKey)
    if type(objectives) ~= "table" or type(wantedKey) ~= "string" then
        return nil
    end

    for i = 1, table.getn(objectives) do
        local quest = Core.NormalizeQuest(objectives[i])
        if quest and quest.key == wantedKey then
            return i, quest
        end
    end
    return nil
end

function Core.ObjectiveSignature(objectives)
    local keys = {}
    if type(objectives) == "table" then
        for i = 1, table.getn(objectives) do
            keys[i] = Core.QuestKey(objectives[i]) or tostring(i)
        end
    end
    return table.concat(keys, "|")
end

function Core.BuildCatalog(db, search)
    local result = {}
    local query = Core.NormalizeTitle(search)
    local known = db and db.knownQuests or {}

    for _, quest in pairs(known) do
        local title = Core.QuestTitle(quest)
        local blob = Core.NormalizeTitle(title .. " " .. tostring(quest.objectiveText or "") .. " " .. tostring(quest.questId or ""))
        if query == "" or string.find(blob, query, 1, true) then
            table.insert(result, quest)
        end
    end

    table.sort(result, function(left, right)
        local leftTitle = Core.NormalizeTitle(Core.QuestTitle(left))
        local rightTitle = Core.NormalizeTitle(Core.QuestTitle(right))
        if leftTitle == rightTitle then
            return tostring(left.key) < tostring(right.key)
        end
        return leftTitle < rightTitle
    end)
    return result
end

local function containsPlain(haystack, needle)
    return string.find(Core.NormalizeTitle(haystack), needle, 1, true) ~= nil
end

function Core.ClassifyCatalogZone(quest)
    local zone = tonumber(quest and quest.zoneOrSort) or 0
    local questType = tonumber(quest and quest.questType) or 1
    local title = Core.QuestTitle(quest)
    local objective = tostring(quest and quest.objectiveText or "")

    if questType == 4 then
        return {
            id = "supplies",
            label = "Supplies",
            sort = 90000,
        }
    end

    if zone > 0 then
        zone = math.floor(zone)
        return {
            id = "zone:" .. tostring(zone),
            label = Core.ZONE_NAMES[zone] or ("Zone " .. tostring(zone)),
            sort = Core.ZONE_NAMES[zone] and 1000 or (10000 + zone),
        }
    end

    local normalizedObjective = Core.NormalizeTitle(objective)
    if containsPlain(normalizedObjective, "wintergrasp") then
        return { id = "zone:618", label = "Wintergrasp", sort = 1000 }
    elseif containsPlain(normalizedObjective, "icecrown") then
        return { id = "zone:210", label = "Icecrown", sort = 1000 }
    elseif containsPlain(normalizedObjective, "crystalsong") then
        return { id = "zone:2817", label = "Crystalsong Forest", sort = 1000 }
    elseif containsPlain(normalizedObjective, "storm peaks") then
        return { id = "zone:90", label = "Storm Peaks", sort = 1000 }
    elseif containsPlain(title, "trophy") then
        return { id = "trophy", label = "Trophy Hunts", sort = 80000 }
    elseif questType == 2 then
        return { id = "unknown_dungeon", label = "Other Dungeons", sort = 91000 }
    elseif questType == 3 then
        return { id = "unknown_raid", label = "Other Raids", sort = 92000 }
    end

    return { id = "other", label = "Other Zones", sort = 99000 }
end

function Core.BuildGroupedCatalog(db, search, collapsed)
    local quests = Core.BuildCatalog(db, search)
    local groups = {}
    local groupOrder = {}
    local queryActive = Core.NormalizeTitle(search) ~= ""

    for i = 1, table.getn(quests) do
        local quest = quests[i]
        local classification = Core.ClassifyCatalogZone(quest)
        local group = groups[classification.id]
        if not group then
            group = {
                id = classification.id,
                label = classification.label,
                sort = classification.sort,
                quests = {},
            }
            groups[classification.id] = group
            table.insert(groupOrder, classification.id)
        end
        table.insert(group.quests, quest)
    end

    table.sort(groupOrder, function(leftId, rightId)
        local left = groups[leftId]
        local right = groups[rightId]
        local leftKnown = left.sort < 10000
        local rightKnown = right.sort < 10000
        if leftKnown ~= rightKnown then
            return leftKnown
        end
        if left.sort ~= right.sort and (left.sort >= 80000 or right.sort >= 80000) then
            return left.sort < right.sort
        end
        return Core.NormalizeTitle(left.label) < Core.NormalizeTitle(right.label)
    end)

    local display = {}
    for i = 1, table.getn(groupOrder) do
        local group = groups[groupOrder[i]]
        local isCollapsed = not queryActive and collapsed and collapsed[group.id] == true
        table.insert(display, {
            kind = "header",
            groupId = group.id,
            label = group.label,
            count = table.getn(group.quests),
            collapsed = isCollapsed,
        })
        if not isCollapsed then
            for j = 1, table.getn(group.quests) do
                table.insert(display, {
                    kind = "quest",
                    groupId = group.id,
                    quest = group.quests[j],
                })
            end
        end
    end

    return display, table.getn(groupOrder), table.getn(quests)
end

function Core.CatalogGroupIDs(db, search)
    local display = Core.BuildGroupedCatalog(db, search, {})
    local ids = {}
    for i = 1, table.getn(display) do
        if display[i].kind == "header" then
            table.insert(ids, display[i].groupId)
        end
    end
    return ids
end

function Core.RouteContains(route, key)
    if type(route) ~= "table" then
        return false
    end
    for i = 1, table.getn(route) do
        if route[i] == key then
            return true, i
        end
    end
    return false
end

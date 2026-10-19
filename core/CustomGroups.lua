-- User-created frame groups with a manually picked list of members.
-- Each group is backed by its own custom unit type (like Focus), so it requires SuperWoW.

local util = PTUtil

util.SetEnvironment(Puppeteer)
local _G = getfenv(0)
local colorize = util.Colorize

CUSTOM_GROUP_MAX_MEMBERS = 15

-- Key: Group name | Value: Map of member name to the last known GUID, for members outside of your party/raid
local sessionGuids = {}

local function getSavedGroups()
    if not PTOptions.CustomGroups then
        PTOptions.CustomGroups = {}
    end
    return PTOptions.CustomGroups
end

local function getUnitType(saved)
    return "ptgroup"..saved.Id.."_"
end

function GetCustomGroupData(name)
    for _, saved in ipairs(getSavedGroups()) do
        if saved.Name == name then
            return saved
        end
    end
end

function GetCustomGroupNames()
    local names = {}
    for _, saved in ipairs(getSavedGroups()) do
        table.insert(names, saved.Name)
    end
    return names
end

function IsCustomGroup(name)
    return GetCustomGroupData(name) ~= nil
end

local function createGroupFrames(saved)
    local unitType = getUnitType(saved)
    if not PTUnitProxy.CustomUnitsMap[unitType] then
        PTUnitProxy.RegisterCustomUnits(unitType, CUSTOM_GROUP_MAX_MEMBERS)
    end
    local group = CreateUnitFrameGroup(saved.Name, saved.Environment or "all", PTUnitProxy.CustomUnitsMap[unitType], 
        false, PuppeteerSettings.GetSelectedProfile(saved.Name), false)
    group.customGroup = true
    return group
end

function InitCustomGroups()
    if not util.IsSuperWowPresent() then
        return
    end
    for _, saved in ipairs(getSavedGroups()) do
        if not UnitFrameGroups[saved.Name] then
            createGroupFrames(saved)
        end
    end
end

-- Units checked when looking up a member by name
local function getRosterUnits()
    if GetNumRaidMembers() > 0 then
        return util.RaidUnits, util.RaidPetUnits
    end
    return util.PartyUnits, util.PetUnits
end

local function findGuidByName(name)
    local players, pets = getRosterUnits()
    for _, units in ipairs({players, pets}) do
        for _, unit in ipairs(units) do
            if UnitName(unit) == name then
                local _, guid = UnitExists(unit)
                return guid
            end
        end
    end
end

-- Assigns the members of the group to its units, in the order they were added
function RefreshCustomGroup(saved)
    local units = PTUnitProxy.CustomUnitsMap[getUnitType(saved)]
    if not units then
        return
    end
    local known = sessionGuids[saved.Name] or {}
    local desired = {}
    for _, name in ipairs(saved.Members) do
        local guid = findGuidByName(name) or known[name]
        if guid and not util.ArrayContains(desired, guid) then
            table.insert(desired, guid)
        end
    end

    local changed = false
    for i, unit in ipairs(units) do
        if PTUnitProxy.CustomUnitGUIDMap[unit] ~= desired[i] then
            changed = true
            break
        end
    end
    if not changed then
        return
    end

    for _, unit in ipairs(units) do
        PTUnitProxy.SetCustomUnitGuid(unit, nil, true)
    end
    for i, guid in ipairs(desired) do
        if units[i] then
            PTUnitProxy.SetCustomUnitGuid(units[i], guid, true)
        end
    end
    PTUnitProxy.UpdateUnitTypeFrames(getUnitType(saved))
    local group = UnitFrameGroups[saved.Name]
    if group then
        group:UpdateUIPositions()
    end
end

function RefreshCustomGroups()
    if not util.IsSuperWowPresent() or not PTOptions then
        return
    end
    for _, saved in ipairs(getSavedGroups()) do
        RefreshCustomGroup(saved)
    end
end

local function requireSuperWow()
    if not util.IsSuperWowPresent() then
        Info("Custom groups require SuperWoW.")
        return false
    end
    return true
end

-- Returns the group if created, or nil and a reason
function CreateCustomGroup(name)
    if not requireSuperWow() then
        return
    end
    if not name or name == "" then
        return nil, "Please give the group a name."
    end
    if UnitFrameGroups[name] or IsCustomGroup(name) then
        return nil, "A frame group named \""..name.."\" already exists."
    end
    PTOptions.CustomGroupsNextId = (PTOptions.CustomGroupsNextId or 0) + 1
    local saved = {
        Id = PTOptions.CustomGroupsNextId,
        Name = name,
        Environment = "all",
        Members = {}
    }
    table.insert(getSavedGroups(), saved)
    local group = createGroupFrames(saved)
    group:EvaluateShown()
    return group
end

function DeleteCustomGroup(name)
    local saved = GetCustomGroupData(name)
    if not saved then
        return false
    end
    local units = PTUnitProxy.CustomUnitsMap[getUnitType(saved)]
    for _, unit in ipairs(units or {}) do
        PTUnitProxy.SetCustomUnitGuid(unit, nil, true)
        for ui in UnitFrames(unit) do
            ui:Hide()
        end
    end
    util.RemoveElement(getSavedGroups(), saved)
    local group = UnitFrameGroups[name]
    if group then
        group:Hide()
        UnitFrameGroups[name] = nil
    end
    PTOptions.FrameOptions[name] = nil
    PTOptions.ChosenProfiles[name] = nil
    sessionGuids[name] = nil
    return true
end

function RenameCustomGroup(oldName, newName)
    local saved = GetCustomGroupData(oldName)
    if not saved then
        return nil, "There is no custom group named \""..oldName.."\"."
    end
    if not newName or newName == "" then
        return nil, "Please give the group a new name."
    end
    if UnitFrameGroups[newName] or IsCustomGroup(newName) then
        return nil, "A frame group named \""..newName.."\" already exists."
    end
    saved.Name = newName
    PTOptions.FrameOptions[newName] = PTOptions.FrameOptions[oldName]
    PTOptions.FrameOptions[oldName] = nil
    PTOptions.ChosenProfiles[newName] = PTOptions.ChosenProfiles[oldName]
    PTOptions.ChosenProfiles[oldName] = nil
    sessionGuids[newName] = sessionGuids[oldName]
    sessionGuids[oldName] = nil
    local group = UnitFrameGroups[oldName]
    if group then
        UnitFrameGroups[oldName] = nil
        UnitFrameGroups[newName] = group
        group.name = newName
        group.label:SetText(newName)
    end
    return true
end

function IsUnitInCustomGroup(groupName, unit)
    local saved = GetCustomGroupData(groupName)
    local name = UnitName(unit)
    return saved ~= nil and name ~= nil and util.ArrayContains(saved.Members, name)
end

-- Returns true if the unit was added
function AddUnitToCustomGroup(groupName, unit)
    local saved = GetCustomGroupData(groupName)
    if not saved or not UnitExists(unit) then
        return false
    end
    local name = UnitName(unit)
    if util.ArrayContains(saved.Members, name) then
        return false
    end
    if table.getn(saved.Members) >= CUSTOM_GROUP_MAX_MEMBERS then
        Info("\""..groupName.."\" is full ("..CUSTOM_GROUP_MAX_MEMBERS.." members).")
        return false
    end
    table.insert(saved.Members, name)
    local guid = PTGuidRoster.ResolveUnitGuid(unit)
    if guid then
        sessionGuids[groupName] = sessionGuids[groupName] or {}
        sessionGuids[groupName][name] = guid
    end
    RefreshCustomGroup(saved)
    return true
end

function RemoveNameFromCustomGroup(groupName, name)
    local saved = GetCustomGroupData(groupName)
    if not saved or not util.ArrayContains(saved.Members, name) then
        return false
    end
    util.RemoveElement(saved.Members, name)
    if sessionGuids[groupName] then
        sessionGuids[groupName][name] = nil
    end
    RefreshCustomGroup(saved)
    return true
end

function RemoveUnitFromCustomGroup(groupName, unit)
    local name = UnitName(unit)
    return name ~= nil and RemoveNameFromCustomGroup(groupName, name)
end

function ToggleUnitInCustomGroup(groupName, unit)
    if IsUnitInCustomGroup(groupName, unit) then
        RemoveUnitFromCustomGroup(groupName, unit)
    else
        AddUnitToCustomGroup(groupName, unit)
    end
end

-- If the unit is one of a custom group's units, moves that member to the top of the group and returns true
function PromoteCustomGroupUnit(unit)
    local unitType = PTUnitProxy and PTUnitProxy.CustomUnitsTypeMap[unit]
    if not unitType then
        return false
    end
    for _, saved in ipairs(getSavedGroups()) do
        if getUnitType(saved) == unitType then
            local name = UnitName(unit)
            if name and util.ArrayContains(saved.Members, name) then
                util.RemoveElement(saved.Members, name)
                table.insert(saved.Members, 1, name)
                RefreshCustomGroup(saved)
            end
            return true
        end
    end
    return false
end

function ClearCustomGroup(groupName)
    local saved = GetCustomGroupData(groupName)
    if not saved then
        return
    end
    saved.Members = {}
    sessionGuids[groupName] = nil
    RefreshCustomGroup(saved)
end

-- Menu opened at the cursor to toggle a unit's membership in each custom group
CustomGroupMenu = PTGuiLib.Get("dropdown", UIParent)
CustomGroupMenu:SetDynamicOptions(function(addOption, level, args)
    local unit = CustomGroupMenu.Unit
    addOption("text", UnitName(unit) or "Custom Groups",
        "isTitle", true,
        "notCheckable", true)
    local names = GetCustomGroupNames()
    if table.getn(names) == 0 then
        addOption("text", "No custom groups yet",
            "disabled", true,
            "notCheckable", true)
        addOption("text", "Create one with /pt group create <name>",
            "disabled", true,
            "notCheckable", true)
        return
    end
    for _, groupName in ipairs(names) do
        addOption("text", groupName,
            "groupName", groupName,
            "keepShownOnClick", true,
            "func", function(self)
                ToggleUnitInCustomGroup(self.groupName, CustomGroupMenu.Unit)
            end,
            "initFunc", function(self)
                self.checked = IsUnitInCustomGroup(self.groupName, CustomGroupMenu.Unit)
            end)
    end
end)

function OpenCustomGroupMenu(unit)
    if not requireSuperWow() then
        return
    end
    CustomGroupMenu:SetToggleState(false)
    CustomGroupMenu.Unit = unit
    ToggleDropDownMenu(1, nil, CustomGroupMenu:GetHandle(), "cursor")
    PlaySound("igMainMenuOpen")
end

RegisterActionBind({
    Name = "Custom Groups",
    Description = "Opens a menu to add/remove the unit from your custom groups",
    Script = function(unit, unitFrame)
        if UnitExists(unit) then
            OpenCustomGroupMenu(unit)
        end
    end
})

local function trim(s)
    local _, _, trimmed = string.find(s or "", "^%s*(.-)%s*$")
    return trimmed
end

local function printUsage()
    local cmd = function(text) return colorize(text, 0, 0.8, 0) end
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group").." -- Lists your custom groups")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group create <name>").." -- Creates a custom group")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group delete <name>").." -- Deletes a custom group")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group rename <old> > <new>").." -- Renames a custom group")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group add <name>").." -- Adds your target to the group")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group remove <name>").." -- Removes your target from the group")
    DEFAULT_CHAT_FRAME:AddMessage(cmd("/pt group clear <name>").." -- Removes everyone from the group")
end

-- Handles "/pt group ..." with the text after "group"
function HandleCustomGroupCommand(args)
    if not requireSuperWow() then
        return
    end
    args = trim(args)
    local _, _, sub, rest = string.find(args, "^(%S*)%s*(.*)$")
    sub = string.lower(sub or "")
    rest = trim(rest)

    if sub == "" or sub == "list" then
        local groups = getSavedGroups()
        if table.getn(groups) == 0 then
            Info("You have no custom groups. Create one with /pt group create <name>")
            return
        end
        for _, saved in ipairs(groups) do
            local members = table.getn(saved.Members) > 0 and table.concat(saved.Members, ", ") or "(empty)"
            Info(saved.Name..": "..members)
        end
    elseif sub == "create" then
        local group, err = CreateCustomGroup(rest)
        if group then
            Info("Created \""..rest.."\". Target someone and use /pt group add "..rest..", or bind the "..
                "\"Custom Groups\" action to your frames.")
        elseif err then
            Info(err)
        end
    elseif sub == "delete" then
        if DeleteCustomGroup(rest) then
            Info("Deleted \""..rest.."\".")
        else
            Info("There is no custom group named \""..rest.."\".")
        end
    elseif sub == "rename" then
        local _, _, oldName, newName = string.find(rest, "^(.-)%s*>%s*(.-)$")
        if not oldName then
            Info("Usage: /pt group rename <old> > <new>")
            return
        end
        local ok, err = RenameCustomGroup(oldName, newName)
        if ok then
            Info("Renamed \""..oldName.."\" to \""..newName.."\".")
        else
            Info(err)
        end
    elseif sub == "add" or sub == "remove" then
        if not IsCustomGroup(rest) then
            Info("There is no custom group named \""..rest.."\".")
            return
        end
        if not UnitExists("target") then
            Info("You need a target to "..sub..".")
            return
        end
        if sub == "add" then
            if AddUnitToCustomGroup(rest, "target") then
                Info("Added "..UnitName("target").." to \""..rest.."\".")
            end
        else
            if RemoveUnitFromCustomGroup(rest, "target") then
                Info("Removed "..UnitName("target").." from \""..rest.."\".")
            end
        end
    elseif sub == "clear" then
        if not IsCustomGroup(rest) then
            Info("There is no custom group named \""..rest.."\".")
            return
        end
        ClearCustomGroup(rest)
        Info("Cleared \""..rest.."\".")
    else
        printUsage()
    end
end

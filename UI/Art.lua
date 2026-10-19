local _, ns = ...

-- Every path is referenced by FrameXML 3.3.5; sources are listed in
-- knowledge_base/verification/keystone-ui-assets-2026-10-18.md.
local Art = {
    Window = {
        background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        border = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        header = "Interface\\DialogFrame\\UI-DialogBox-Header",
    },
    Close = {
        up = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        down = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down",
        highlight = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
    },
    PortraitRing = "Interface\\Minimap\\MiniMap-TrackingBorder",
    ClassCircles = "Interface\\TargetingFrame\\UI-Classes-Circles",
    -- Same values as CLASS_ICON_TCOORDS in FrameXML 3.3.5 Constants.lua.
    ClassCoords = {
        WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
        ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
        HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
        PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
        PALADIN = { 0, 0.25, 0.5, 0.75 }, DEATHKNIGHT = { 0.25, 0.5, 0.5, 0.75 },
    },
    Dropdown = {
        frame = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame",
        arrowUp = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
        arrowDown = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down",
        highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
        expand = "Interface\\ChatFrame\\ChatFrameExpandArrow",
        menuBackground = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        menuBorder = "Interface\\DialogFrame\\UI-DialogBox-Border",
    },
    Tab = {
        active = "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab",
        inactive = "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab",
        highlight = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight",
    },
    EmptyCell = "Interface\\Buttons\\UI-EmptySlot-Disabled",
    CellBorder = "Interface\\Buttons\\UI-ActionButton-Border",
    RowHighlight = "Interface\\Buttons\\UI-Listbox-Highlight2",
    Question = "Interface\\Icons\\INV_Misc_QuestionMark",
    Relic = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic",
    Background = {
        dungeon = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON",
        heroic = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-HEROIC",
        raid = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL",
    },
    InventorySlot = {
        HEAD = "HeadSlot", NECK = "NeckSlot", SHOULDER = "ShoulderSlot", CLOAK = "BackSlot",
        CHEST = "ChestSlot", WRIST = "WristSlot", HANDS = "HandsSlot", WAIST = "WaistSlot",
        LEGS = "LegsSlot", FEET = "FeetSlot", FINGER = "Finger0Slot", TRINKET = "Trinket0Slot",
        ONEHANDED = "MainHandSlot", TWOHANDED = "MainHandSlot", OFFHAND = "SecondaryHandSlot",
        RANGED = "RangedSlot", BAG = "Bag0Slot", SHIRT = "ShirtSlot",
    },
}
ns.Art = Art

-- The client resolves empty-slot art itself; RangedSlot has no relic variant there.
function Art.SlotTexture(slot)
    if slot == "RELIC" then return Art.Relic end
    local inventorySlot = Art.InventorySlot[slot]
    if inventorySlot and GetInventorySlotInfo then
        local ok, _, texture = pcall(GetInventorySlotInfo, inventorySlot)
        if ok and type(texture) == "string" then return texture end
    end
    return Art.Question
end

function Art.ForStage(stageKey)
    if type(stageKey) ~= "string" or not (stageKey:find("^bis_") or stageKey:find("^classic_")
        or stageKey:find("^tbc_") or stageKey:find("^wrath_")) then return nil end
    if stageKey:find("heroic") then return Art.Background.heroic end
    if stageKey:find("_pr$") or stageKey:find("_PR$") or stageKey:find("_prebis$")
        or stageKey:find("pre_raid") or stageKey:find("dungeons") then return Art.Background.dungeon end
    return Art.Background.raid
end

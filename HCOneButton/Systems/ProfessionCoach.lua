-- HCOneButton Profession Coach v1.17.0
-- Event-driven profession leveling advisor for WoW Classic Era.
-- No automatic crafting/gathering: it only recommends the most efficient next action.

local HCOB = HCOneButton
local P = HCOB.Systems.ProfessionCoach

local floor, min, max = math.floor, math.min, math.max
local lower = string.lower

local PROF = {
    ALCHEMY       = {spell=2259,  kind="craft"},
    BLACKSMITHING = {spell=2018,  kind="craft"},
    COOKING       = {spell=2550,  kind="craft", secondary=true},
    ENCHANTING    = {spell=7411,  kind="craft"},
    ENGINEERING   = {spell=4036,  kind="craft"},
    FIRSTAID      = {spell=3273,  kind="firstaid", secondary=true},
    FISHING       = {spell=7620,  kind="fishing", secondary=true},
    HERBALISM     = {spell=2366,  kind="gather"},
    LEATHERWORKING= {spell=2108,  kind="craft"},
    MINING        = {spell=2575,  kind="gather"},
    SKINNING      = {spell=8613,  kind="gather"},
    TAILORING     = {spell=3908,  kind="craft"},
}

local FALLBACK_NAMES = {
    ALCHEMY="Alchemy", BLACKSMITHING="Blacksmithing", COOKING="Cooking", ENCHANTING="Enchanting",
    ENGINEERING="Engineering", FIRSTAID="First Aid", FISHING="Fishing", HERBALISM="Herbalism",
    LEATHERWORKING="Leatherworking", MINING="Mining", SKINNING="Skinning", TAILORING="Tailoring",
}


local function SpellName(id, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and info and info.name then return info.name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and name then return name end
    end
    return fallback
end

local function Norm(s)
    if not s then return "" end
    return lower((s:gsub("^%s+", ""):gsub("%s+$", "")))
end

local aliases = nil
local function BuildAliases()
    aliases = {}
    for key, data in pairs(PROF) do
        aliases[Norm(FALLBACK_NAMES[key])] = key
        aliases[Norm(SpellName(data.spell, FALLBACK_NAMES[key]))] = key
    end
end

local function ClassifySkillName(name)
    if not aliases then BuildAliases() end
    local n = Norm(name)
    if aliases[n] then return aliases[n] end
    -- Some localized clients append rank wording; prefix matching is safer than hardcoding every locale.
    for alias, key in pairs(aliases) do
        if #alias >= 4 and (n:find(alias, 1, true) == 1 or alias:find(n, 1, true) == 1) then return key end
    end
end

local state = {
    skills={},
    openRecipe=nil,
    lastRecipes={},
    dirty=true,
    lastUpdate=0,
}

local function ScanSkills()
    wipe(state.skills)
    if not GetNumSkillLines or not GetSkillLineInfo then return end
    local ok, count = pcall(GetNumSkillLines)
    if not ok or not count then return end
    for i=1,count do
        local ok2, name, header, _, rank, temp, modifier, maxRank, abandonable, stepCost, rankCost, minLevel, costType, desc = pcall(GetSkillLineInfo, i)
        if ok2 and name and not header and (tonumber(maxRank) or 0) > 1 then
            local key = ClassifySkillName(name)
            if key then
                state.skills[key] = {
                    key=key, name=name, skill=tonumber(rank) or 0, max=tonumber(maxRank) or 0,
                    temp=tonumber(temp) or 0, modifier=tonumber(modifier) or 0,
                    abandonable=abandonable, minLevel=minLevel,
                }
            end
        end
    end
end

local function PlayerLevel()
    local safe = HCOB and HCOB.Internal and HCOB.Internal.SafeUnitLevel
    if safe then return safe("player", 1) or 1 end
    if not UnitLevel then return 1 end
    local ok, value = pcall(UnitLevel, "player")
    if not ok then return 1 end
    if canaccessvalue then
        local okAccess, allowed = pcall(canaccessvalue, value)
        if okAccess and not allowed then return 1 end
    end
    local okNum, number = pcall(tonumber, value)
    return okNum and number or 1
end

local function Faction()
    return (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
end

local function ItemCount(id)
    if GetItemCount then
        local ok, n = pcall(GetItemCount, id, false, false)
        if ok and n then return n end
    end
    return 0
end

local function ItemName(id, fallback)
    if C_Item and C_Item.GetItemNameByID then
        local ok, n = pcall(C_Item.GetItemNameByID, id)
        if ok and n then return n end
    end
    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, id)
        if ok and n then return n end
    end
    return fallback
end

-- ---------- Training gates ----------
local function GenericRankHint(s)
    if not s then return nil end
    local lvl = PlayerLevel()
    if s.max <= 75 and s.skill >= 50 and lvl >= 10 then return "TRAINER: learn Journeyman now" end
    if s.max <= 150 and s.skill >= 125 and lvl >= 20 then return "TRAINER: learn Expert now" end
    if s.max <= 225 and s.skill >= 200 and lvl >= 35 then return "TRAINER: learn Artisan now" end
    return nil
end

local function FirstAidRankHint(s)
    if not s then return nil end
    local lvl = PlayerLevel()
    if s.max <= 75 and s.skill >= 50 and lvl >= 10 then return "FIRST AID: train Journeyman" end
    if s.max <= 150 and s.skill >= 125 then
        local loc = Faction()=="Horde" and "Balai Lok'Wein, Brackenwall (Dustwallow)" or "Deneb Walker, Stromgarde (Arathi)"
        return "FIRST AID: buy Expert + 2 manuals from "..loc
    end
    if s.max <= 225 and s.skill >= 225 then
        if lvl < 35 then return "FIRST AID 225: reach character level 35 for Artisan/Triage" end
        local loc = Faction()=="Horde" and "Doctor Gregory Victor, Hammerfall" or "Doctor Gustaf VanHowzen, Theramore"
        return "FIRST AID: complete Triage / Artisan with "..loc
    end
    return nil
end

local function FishingRankHint(s)
    if not s then return nil end
    local lvl = PlayerLevel()
    if s.max <= 75 and s.skill >= 50 and lvl >= 10 then return "FISHING: train Journeyman" end
    if s.max <= 150 and s.skill >= 125 then return "FISHING: buy Expert Fishing - The Bass and You" end
    if s.max <= 225 and s.skill >= 225 then return "FISHING: Artisan through Nat Pagle quest (L35+)" end
end

local function CookingRankHint(s)
    if not s then return nil end
    local lvl = PlayerLevel()
    if s.max <= 75 and s.skill >= 50 and lvl >= 10 then return "COOKING: train Journeyman" end
    if s.max <= 150 and s.skill >= 125 then return "COOKING: buy the Expert Cookbook from your faction vendor" end
    if s.max <= 225 and s.skill >= 225 and lvl >= 35 then return "COOKING: quest Artisan / Clamlette Surprise" end
end

-- ---------- First Aid exact route ----------
local FA = {
    {lo=1,   hi=40,  item=1251,  fallback="Linen Bandage",          cloth=2589,  clothFallback="Linen Cloth",     per=1, learn="Train Linen Bandage"},
    {lo=40,  hi=80,  item=2581,  fallback="Heavy Linen Bandage",    cloth=2589,  clothFallback="Linen Cloth",     per=2, learn="Train Heavy Linen Bandage"},
    {lo=80,  hi=115, item=3530,  fallback="Wool Bandage",           cloth=2592,  clothFallback="Wool Cloth",      per=1, learn="Train Wool Bandage"},
    {lo=115, hi=150, item=3531,  fallback="Heavy Wool Bandage",     cloth=2592,  clothFallback="Wool Cloth",      per=2, learn="Train Heavy Wool Bandage"},
    {lo=150, hi=180, item=6450,  fallback="Silk Bandage",           cloth=4306,  clothFallback="Silk Cloth",      per=1, learn="Train Silk Bandage"},
    {lo=180, hi=210, item=6451,  fallback="Heavy Silk Bandage",     cloth=4306,  clothFallback="Silk Cloth",      per=2, learn="Learn Manual: Heavy Silk Bandage"},
    {lo=210, hi=240, item=8544,  fallback="Mageweave Bandage",      cloth=4338,  clothFallback="Mageweave Cloth", per=1, learn="Learn Manual: Mageweave Bandage"},
    {lo=240, hi=260, item=8545,  fallback="Heavy Mageweave Bandage",cloth=4338,  clothFallback="Mageweave Cloth", per=2, learn="Train Heavy Mageweave Bandage from the trauma surgeon"},
    {lo=260, hi=290, item=14529, fallback="Runecloth Bandage",      cloth=14047, clothFallback="Runecloth",       per=1, learn="Train Runecloth Bandage from the trauma surgeon"},
    {lo=290, hi=301, item=14530, fallback="Heavy Runecloth Bandage",cloth=14047, clothFallback="Runecloth",       per=2, learn="Train Heavy Runecloth Bandage from the trauma surgeon"},
}

local function FirstAidPlan(s)
    if not s then return nil end
    local gate = FirstAidRankHint(s)
    if gate then return {priority=1000, title="FIRST AID", text=gate, detail=s.skill.."/"..s.max} end
    if s.skill >= 300 then return {priority=10, title="FIRST AID 300", text="Maxed", detail="300/300"} end
    for _,r in ipairs(FA) do
        if s.skill >= r.lo and s.skill < r.hi then
            local have = ItemCount(r.cloth)
            local recipe = ItemName(r.item, r.fallback)
            local cloth = ItemName(r.cloth, r.clothFallback)
            local remaining = r.hi - s.skill
            local minNeed = remaining * r.per
            local buffered = math.ceil(minNeed * 1.30)
            local can = floor(have / r.per)
            local target = min(300, PlayerLevel()*5 + 25)
            local prio = s.skill < target and 930 or 520
            local action = "Craft "..recipe.." until "..r.hi
            if r.learn and s.skill <= (r.lo + 1) then action = r.learn.."; then "..action end
            return {
                priority=prio, title="FIRST AID "..s.skill.."/"..s.max,
                text=action,
                detail=cloth.." "..have.." | theoretical minimum "..minNeed.." / buffer ~"..buffered.." | craft now "..can,
            }
        end
    end
end

-- ---------- Gathering routes ----------
local GATHER_ROUTES = {
    HERBALISM = {
        {1,70,  "Peacebloom / Silverleaf / Earthroot / Mageroyal", "starter zone; Darkshore/Loch Modan/Barrens"},
        {70,115,"Mageroyal / Briarthorn / Stranglekelp / Bruiseweed", "Darkshore, Loch Modan, Silverpine"},
        {115,170,"Bruiseweed / Wild Steelbloom / Kingsblood / Liferoot", "Wetlands, Hillsbrad, Stonetalon"},
        {170,205,"Fadeleaf / Goldthorn / Khadgar's Whisker", "Arathi, STV, Swamp of Sorrows"},
        {205,230,"Goldthorn / Firebloom / Purple Lotus", "Tanaris, Feralas, Hinterlands"},
        {230,270,"Sungrass / Blindweed / Ghost Mushroom / Gromsblood", "Feralas, Hinterlands, Searing Gorge"},
        {270,301,"Dreamfoil / Mountain Silversage / Plaguebloom / Icecap", "Felwood, W/E Plaguelands, Winterspring"},
    },
    MINING = {
        {1,65,  "Copper Vein", "starter/secondary zones; buy and carry a Mining Pick"},
        {65,125,"Tin + Silver", "Darkshore/Wetlands/Ashenvale/Barrens/Thousand Needles"},
        {125,175,"Iron + Gold", "Arathi, Badlands, STV, Thousand Needles"},
        {175,245,"Mithril + Truesilver", "Badlands, Tanaris, Hinterlands, Feralas"},
        {245,301,"Small/Rich Thorium", "Un'Goro, Burning Steppes, Silithus, Winterspring"},
    },
    SKINNING = {
        {1,60,   "skin everything", "starter zone"},
        {60,110, "mob skinnable ~12-22", "Loch Modan / Barrens"},
        {110,185,"mob skinnable ~22-37", "Duskwood / Ashenvale"},
        {185,225,"mob skinnable ~37-45", "STV / Dustwallow"},
        {225,265,"mob skinnable ~45-53", "Tanaris / Feralas"},
        {265,301,"mob skinnable ~53-60", "Un'Goro / Burning Steppes"},
    },
}

local function GatherPlan(key, s)
    if not s then return nil end
    local gate = GenericRankHint(s)
    if gate then return {priority=850,title=s.name,text=gate,detail=s.skill.."/"..s.max} end
    if s.skill >= 300 then return {priority=5,title=s.name.." 300",text="Maxed",detail="300/300"} end
    local rows = GATHER_ROUTES[key]
    if not rows then return nil end
    for _,r in ipairs(rows) do
        if s.skill >= r[1] and s.skill < r[2] then
            local lvl = PlayerLevel()
            local lagTarget = min(300, lvl*5)
            local prio = s.skill < lagTarget and 700 or 300
            return {priority=prio,title=s.name.." "..s.skill.."/"..s.max,text="Cerca: "..r[3],detail=r[4]}
        end
    end
end

local function FishingPlan(s)
    if not s then return nil end
    local gate = FishingRankHint(s)
    if gate then return {priority=800,title="FISHING",text=gate,detail=s.skill.."/"..s.max} end
    if s.skill >= 300 then return {priority=5,title="FISHING 300",text="Maxed",detail="300/300"} end
    local skill = s.skill
    local where
    if skill < 75 then where="starter zone: use a lure if many fish get away"
    elseif skill < 150 then where="faction capital: safe area, also excellent for Cooking"
    elseif skill < 225 then where="Wetlands/Hillsbrad/Desolace: fish while leveling Cooking"
    else where="Tanaris/Feralas/Azshara: useful fishing + Cooking/Alchemy" end
    local desired = min(300, PlayerLevel()*5 + 50)
    local prio = skill < desired and 500 or 180
    return {priority=prio,title="FISHING "..skill.."/"..s.max,text=where,detail="Comfort target: ~"..desired.." skill (reduces 'fish got away')"}
end

-- ---------- Open crafting-window optimizer ----------
local DIFF = {difficult=110, optimal=100, medium=68, easy=24, trivial=0}
local DIFF_LABEL = {difficult="ORANGE", optimal="ORANGE", medium="YELLOW", easy="GREEN", trivial="GREY"}

local function ItemMetaFromLink(link)
    if not link or not GetItemInfo then return 0,0 end
    local ok, _, _, quality, _, _, _, _, _, _, sell = pcall(GetItemInfo, link)
    if not ok then return 0,0 end
    return tonumber(quality) or 0, tonumber(sell) or 0
end

local function ReagentPenalty(required, have, quality, sell)
    required = tonumber(required) or 0
    have = tonumber(have) or 0
    local scarcity = have > 0 and (required / max(required, have)) or 3.0
    local rarity = 1 + (tonumber(quality) or 0) * 0.75
    local vendor = min(8, (tonumber(sell) or 0) / 5000)
    return required * (1.5 + scarcity*2.2 + rarity + vendor)
end

local function ScanTradeSkills()
    if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then return nil end
    local ok, tradeName, current, cap = pcall(GetTradeSkillLine)
    if not ok or not tradeName or tradeName=="UNKNOWN" or (tonumber(cap) or 0)<=0 then return nil end
    local best, blocked
    local n = GetNumTradeSkills() or 0
    for i=1,n do
        local ok2, name, typ, available, expanded, altVerb, numUps = pcall(GetTradeSkillInfo, i)
        if ok2 and name and typ and typ~="header" and typ~="subheader" and typ~="trivial" then
            local diff = DIFF[typ] or 10
            local nreg = (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)) or 0
            local penalty, missing, missText = 0,0,nil
            for r=1,nreg do
                local rn, _, req, have = GetTradeSkillReagentInfo(i,r)
                local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i,r)
                local q,sell = ItemMetaFromLink(link)
                penalty = penalty + ReagentPenalty(req,have,q,sell)
                if (tonumber(have) or 0) < (tonumber(req) or 0) then
                    missing = missing + ((tonumber(req) or 0)-(tonumber(have) or 0))
                    if not missText then missText=(rn or "reagent").." "..tostring(have or 0).."/"..tostring(req or 0) end
                end
            end
            local avail = tonumber(available) or 0
            local skillUps = max(1, tonumber(numUps) or 1)
            local score = diff*skillUps - penalty + min(20, avail*2)
            local rec = {name=name, typ=typ, available=avail, score=score, missing=missing, missingText=missText, index=i, tradeName=tradeName, current=current, cap=cap}
            if avail > 0 then
                if not best or rec.score > best.score then best=rec end
            elseif missing > 0 then
                rec.score = diff - penalty - missing*3
                if not blocked or rec.score > blocked.score then blocked=rec end
            end
        end
    end
    local chosen = best or blocked
    if chosen then
        local key = ClassifySkillName(tradeName)
        if key then state.lastRecipes[key]=chosen end
    end
    return chosen
end

local function ScanCraftWindow()
    if not GetCraftSkillLine or not GetNumCrafts or not GetCraftInfo then return nil end
    local ok, craftName = pcall(GetCraftSkillLine, 1)
    if not ok or not craftName or craftName=="UNKNOWN" then return nil end
    local best, blocked
    local n = GetNumCrafts() or 0
    for i=1,n do
        local ok2, name, subName, typ, available = pcall(GetCraftInfo, i)
        if ok2 and name and typ and typ~="header" and typ~="trivial" then
            local diff = DIFF[typ] or 10
            local nreg = (GetCraftNumReagents and GetCraftNumReagents(i)) or 0
            local penalty, missing, missText = 0,0,nil
            for r=1,nreg do
                local rn, _, req, have = GetCraftReagentInfo(i,r)
                local link = GetCraftReagentItemLink and GetCraftReagentItemLink(i,r)
                local q,sell = ItemMetaFromLink(link)
                penalty = penalty + ReagentPenalty(req,have,q,sell)
                if (tonumber(have) or 0) < (tonumber(req) or 0) then
                    missing=missing+((tonumber(req) or 0)-(tonumber(have) or 0))
                    if not missText then missText=(rn or "reagent").." "..tostring(have or 0).."/"..tostring(req or 0) end
                end
            end
            local avail = tonumber(available) or 0
            local score = diff - penalty + min(20,avail*2)
            local rec={name=name,typ=typ,available=avail,score=score,missing=missing,missingText=missText,index=i,tradeName=craftName}
            if avail>0 then if not best or score>best.score then best=rec end
            elseif missing>0 then rec.score=score-missing*3; if not blocked or rec.score>blocked.score then blocked=rec end end
        end
    end
    local chosen=best or blocked
    if chosen then
        local key=ClassifySkillName(craftName) or "ENCHANTING"
        state.lastRecipes[key]=chosen
    end
    return chosen
end

local function OpenCraftPlan()
    local rec = ScanTradeSkills() or ScanCraftWindow()
    state.openRecipe=rec
    if not rec then return nil end
    local label=DIFF_LABEL[rec.typ] or string.upper(rec.typ or "?")
    if (rec.available or 0) > 0 then
        local batch = rec.typ=="easy" and 1 or rec.typ=="medium" and 2 or 3
        batch=min(batch, rec.available)
        return {priority=760,title=(rec.tradeName or "PROFESSION").." | "..label,text="Craft "..rec.name,detail="Available "..rec.available.." | recommended batch "..batch.." then re-check recipe color"}
    end
    return {priority=620,title=(rec.tradeName or "PROFESSION").." | "..label,text="Next efficient craft: "..rec.name,detail="Missing: "..tostring(rec.missingText or "reagents")}
end

local function CraftSkillPlan(key,s)
    if not s then return nil end
    local gate
    if key=="COOKING" then gate=CookingRankHint(s) else gate=GenericRankHint(s) end
    if gate then return {priority=820,title=s.name,text=gate,detail=s.skill.."/"..s.max} end
    if s.skill>=300 then return {priority=5,title=s.name.." 300",text="Maxed",detail="300/300"} end
    local last=state.lastRecipes[key]
    if last then
        local label=DIFF_LABEL[last.typ] or string.upper(last.typ or "?")
        if (last.available or 0)>0 then
            return {priority=340,title=s.name.." "..s.skill.."/"..s.max,text="Last best: "..last.name.." ("..label..")",detail="Open the profession to recalculate materials/color"}
        end
    end
    return {priority=220,title=s.name.." "..s.skill.."/"..s.max,text="Open the profession window: analyze recipes + reagents",detail="Preference: Orange > Yellow > Green; never Grey"}
end

local function BuildPlans()
    ScanSkills()
    local plans={}
    local open=OpenCraftPlan(); if open then plans[#plans+1]=open end
    for key,s in pairs(state.skills) do
        local kind=PROF[key] and PROF[key].kind
        local p
        if kind=="firstaid" then p=FirstAidPlan(s)
        elseif kind=="gather" then p=GatherPlan(key,s)
        elseif kind=="fishing" then p=FishingPlan(s)
        elseif kind=="craft" then p=CraftSkillPlan(key,s) end
        if p then p.key=key; plans[#plans+1]=p end
    end
    table.sort(plans,function(a,b) return (a.priority or 0)>(b.priority or 0) end)
    state.plans=plans
    state.dirty=false
    state.lastUpdate=GetTime and GetTime() or 0
    return plans
end

-- ---------- UI ----------
local frame, titleFS, mainFS, detailFS
local refreshPending=false
local function CreatePanel()
    if frame then return end
    frame=CreateFrame("Frame","HCOneButtonProfessionCoach",UIParent)
    local actionAnchor=_G.HCOneButtonAdvisorActions
    local coachWidth=282
    if actionAnchor and actionAnchor.GetWidth then coachWidth=math.max(282,actionAnchor:GetWidth() or 282) end
    frame:SetSize(coachWidth,62)
    frame:SetFrameStrata("HIGH")
    local anchor=_G.HCOneButtonFrame
    if actionAnchor then frame:SetPoint("TOPLEFT",actionAnchor,"BOTTOMLEFT",0,-6)
    elseif anchor then frame:SetPoint("TOPLEFT",anchor,"TOPRIGHT",10,-198)
    else frame:SetPoint("CENTER",UIParent,"CENTER",160,-80) end
    frame:EnableMouse(false)
    local bg=frame:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.018,0.018,0.022,0.94)
    if HCOB_MakeRectBorder then HCOB_MakeRectBorder(frame,0.25,0.55,0.80,0.90) end
    titleFS=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); titleFS:SetPoint("TOPLEFT",8,-7); titleFS:SetPoint("RIGHT",-8,0); titleFS:SetJustifyH("LEFT")
    mainFS=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mainFS:SetPoint("TOPLEFT",titleFS,"BOTTOMLEFT",0,-5); mainFS:SetPoint("RIGHT",-8,0); mainFS:SetJustifyH("LEFT")
    detailFS=frame:CreateFontString(nil,"OVERLAY","GameFontNormalTiny"); detailFS:SetPoint("TOPLEFT",mainFS,"BOTTOMLEFT",0,-4); detailFS:SetPoint("RIGHT",-8,0); detailFS:SetJustifyH("LEFT")
end

local function UpdatePanel()
    CreatePanel()
    if HCOB_DB and HCOB_DB.profCoach==false then frame:Hide(); return end
    if UnitAffectingCombat and UnitAffectingCombat("player") then frame:Hide(); return end
    local plans=BuildPlans()
    if #plans==0 then frame:Hide(); return end
    local p=plans[1]
    titleFS:SetText("PROF COACH | "..tostring(p.title or "PROFESSIONS"))
    mainFS:SetText(tostring(p.text or ""))
    detailFS:SetText(tostring(p.detail or ""))
    frame:Show()
end

function P.Refresh()
    state.dirty=true
    if refreshPending then return end
    refreshPending=true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.20,function() refreshPending=false; UpdatePanel() end)
    else
        refreshPending=false
        UpdatePanel()
    end
end

local function SkillColor(s)
    if not s then return "" end
    if s.skill>=s.max then return "|cffaaaaaa" end
    return "|cffffffff"
end

function P.PrintStatus()
    local plans=BuildPlans()
    local nskills=0; for _ in pairs(state.skills) do nskills=nskills+1 end
    print("|cff55c8ffHCOB PROF COACH:|r detected professions="..tostring(nskills).." (sorted priorities)")
    if next(state.skills)==nil then print("  No professions detected: open the Skills/Professions panel and retry /hcob prof") return end
    for key,s in pairs(state.skills) do
        print("  "..SkillColor(s)..s.name.."|r "..s.skill.."/"..s.max)
    end
    for i,p in ipairs(plans) do
        if i<=8 then print(string.format("  #%d %s -> %s | %s",i,tostring(p.title),tostring(p.text),tostring(p.detail or ""))) end
    end
end

function P.HandleSlash(arg)
    arg=Norm(arg)
    HCOB_DB=HCOB_DB or {}
    if arg=="off" then HCOB_DB.profCoach=false; if frame then frame:Hide() end; print("|cff55c8ffHCOB PROF:|r OFF")
    elseif arg=="on" then HCOB_DB.profCoach=true; P.Refresh(); print("|cff55c8ffHCOB PROF:|r ON")
    elseif arg=="refresh" then P.Refresh(); print("|cff55c8ffHCOB PROF:|r refresh")
    else P.PrintStatus() end
end

-- Event-driven only; no per-frame scans.
local ef=CreateFrame("Frame")
local events={"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_LEVEL_UP","SKILL_LINES_CHANGED","SPELLS_CHANGED","BAG_UPDATE_DELAYED","TRADE_SKILL_SHOW","TRADE_SKILL_UPDATE","TRADE_SKILL_CLOSE","CRAFT_SHOW","CRAFT_UPDATE","CRAFT_CLOSE"}
for _,e in ipairs(events) do pcall(ef.RegisterEvent,ef,e) end
ef:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        HCOB_DB=HCOB_DB or {}; if HCOB_DB.profCoach==nil then HCOB_DB.profCoach=true end
        if C_Timer and C_Timer.After then C_Timer.After(1.0,UpdatePanel) else UpdatePanel() end
    elseif event=="PLAYER_REGEN_DISABLED" then if frame then frame:Hide() end
    else P.Refresh() end
end)

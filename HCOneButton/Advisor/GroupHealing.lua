-- Read-only group triage. Secure mouseover actions live in UI/GroupHealing.lua.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local G = {roles={"quick","direct","hot","shield"}, labels={"Quick heal","Direct heal","Heal over time","Shield"}}
HCOB.Advisor.GroupHealing = G

local function call(fn,...)
    if type(fn) ~= "function" then return nil end
    local ok,a,b,c,d = pcall(fn,...)
    if ok then return a,b,c,d end
end
local function number(v)
    return type(v)=="number" and v==v and math.abs(v)<math.huge and v or nil
end
local function yes(v) return v==true or v==1 end

function G.Spells()
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    local choices = class and class.GetGroupHealingSpells and class:GetGroupHealingSpells() or {}
    local result = {}
    for slot,role in ipairs(G.roles) do
        for _,id in ipairs(choices[role] or {}) do
            if IsKnown(id) then result[slot]=id; break end
        end
    end
    return result
end

function G.BindingCommand(slot) return "CLICK HCOneButtonGroupHeal"..slot..":LeftButton" end
function G.Binding(slot) return call(GetBindingKey,G.BindingCommand(slot)) end

local function castSeconds(id)
    local name=SpellName(id)
    local _,_,_,ms=call(GetSpellInfo,name)
    if not number(ms) then
        local info=call(C_Spell and C_Spell.GetSpellInfo,name)
        ms=type(info)=="table" and number(info.castTime) or nil
    end
    if number(ms) and ms>=0 then return ms/1000 end
    if id==S.RENEW or id==S.REJUVENATION or id==S.POWER_WORD_SHIELD then return 0 end
    return number(call(SpellCastSeconds,id)) or 3
end

-- No target/player fallback, no health-based secure decision and no /target.
-- The Druid's form is cancelled only after a valid friendly mouseover exists.
function G.Macro(id,unit)
    unit=unit or "mouseover"
    if type(unit)~="string" or (unit~="mouseover" and unit~="player" and not unit:match("^party[1-4]$")) then return "/stopmacro" end
    local name = id and IsKnown(id) and SpellName(id)
    if not name then return "/stopmacro" end
    return "/stopmacro [@"..unit..",noexists][@"..unit..",nohelp][@"..unit..",dead][channeling]\n"
        .. (PLAYER_CLASS=="DRUID" and "/cancelform\n" or "")
        .. "/cast [@"..unit..",help,nodead] "..name
end

local function valid(unit)
    return yes(call(UnitExists,unit)) and yes(call(UnitCanAssist,"player",unit))
        and not yes(call(UnitIsUnit,unit,"player")) and yes(call(UnitIsConnected,unit))
        and not yes(call(UnitIsDeadOrGhost,unit)) and not yes(call(UnitIsCharmed,unit))
end

local function manaAllows(id, urgent)
    local mana = number(call(UnitPower,"player",0))
    local maximum = number(call(UnitPowerMax,"player",0))
    if not mana or not maximum or maximum<=0 then return false end
    local name = SpellName(id)
    local costs = call(GetSpellPowerCost,name)
    if type(costs)~="table" then costs=call(C_Spell and C_Spell.GetSpellPowerCost,name) end
    local cost
    if type(costs)=="table" then
        for _,entry in pairs(costs) do
            if type(entry)=="table" and entry.type==0 then
                local value=number(entry.cost)
                if value and value>=0 then cost=math.max(cost or 0,value) end
            end
        end
    end
    -- Preserve recovery mana; live rank/talent cost data wins over a percent
    -- fallback. Unknown cost is never treated as a free cast.
    if cost then return mana-cost >= maximum*(urgent and .10 or .15) end
    return mana/maximum >= (urgent and .25 or .35)
end

local function aura(unit,id,filter,mine)
    local name=id and SpellName(id)
    if not name then return false,0 end
    return AuraByName(unit,name,filter or "HELPFUL",mine)
end

local function usable(id,unit,urgent)
    if not id or not IsKnown(id) or not IsUsable(id) or not CooldownReady(id) then return false end
    if HCOB.Advisor.Engine.SpellRange(id,unit)~=true then return false end
    if not manaAllows(id,urgent) then return false end
    local duration = castSeconds(id)
    if duration>0 and (number(call(GetUnitSpeed,"player")) or 0)>0 then return false end
    return true
end

-- A confirmed instant HoT/shield may precede UNIT_AURA. The cache is bounded,
-- keyed by GUID (never party position), transient and never written to logs.
local recent, inputs = {}, {}
function G.NoteInput(id,unit)
    unit=unit or "mouseover"
    if not id or not valid(unit) or call(UnitCastingInfo,"player") or call(UnitChannelInfo,"player") then return end
    local guid=call(UnitGUID,unit)
    local name=SpellName(id)
    if not guid or not name then return end
    local duration=castSeconds(id)
    inputs[name]={guid=guid,expires=GetTime()+math.min(15,math.max(1,duration+1))}
    -- A group heal is not evidence for a self-survival tuning choice.
    if ClearTuningPending then ClearTuningPending() end
end

function G.IsOtherUnitCast(id)
    local input=inputs[SpellName(id)]
    return input and GetTime()<=input.expires or false
end

function G.HandleCast(event,unit,castGUID,id)
    if unit~="player" or not id then return end
    local name=SpellName(id)
    local input=name and inputs[name]
    if not input or GetTime()>input.expires then return end
    if event=="UNIT_SPELLCAST_START" then
        input.castGUID=castGUID
        input.expires=GetTime()+15 -- live cast holds, including pushback
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        if input.castGUID and input.castGUID~=castGUID then return end
        for key,state in pairs(recent) do if GetTime()>state then recent[key]=nil end end
        if name==SpellName(S.RENEW) or name==SpellName(S.REJUVENATION)
            or name==SpellName(S.POWER_WORD_SHIELD) or name==SpellName(S.REGROWTH) then
            recent[input.guid..":"..name]=GetTime()+1
        end
        input.expires=GetTime()+.25 -- keep self-aura grace isolated on this event
    elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED" then
        if not input.castGUID or input.castGUID==castGUID then inputs[name]=nil end
    end
end

function G.Recommend(playerHP)
    G.current=nil
    local ui=HCOB.UI.GroupHealing
    if not ui or HCOB_DB.groupHealing==false or HCOB_DB.secureActions==false then return end
    if not number(playerHP) or playerHP>100 or playerHP<=math.max(60,HCOB_DB.dangerHP or 35) then return end
    if yes(call(UnitIsDeadOrGhost,"player")) or yes(call(IsMounted)) or yes(call(IsFlying)) then return end
    if PLAYER_CLASS=="PRIEST" and aura("player",15473) then return end -- Shadowform: never silently cancel it
    local raid=yes(call(IsInRaid))
    local count=number(call(raid and GetNumGroupMembers or GetNumSubgroupMembers)) or 0
    count=math.min(raid and 40 or 4,math.max(0,math.floor(count)))
    if count==0 then return end
    local best
    for index=1,count do
        local unit=(raid and "raid" or "party")..index
        if valid(unit) then
            local hp,known=UnitHealthPct(unit)
            local maximum=number(call(UnitHealthMax,unit))
            if known and number(hp) and hp>0 and hp<=80 and maximum and maximum>0 then
                local incoming=number(call(UnitGetIncomingHeals,unit)) or 0
                local effective=math.min(100,hp+math.max(0,incoming)/maximum*100)
                local guid=call(UnitGUID,unit)
                for slot,role in ipairs(G.roles) do
                    local id=ui.spells and ui.spells[slot]
                    local key=id and G.Binding(slot)
                    local panel=HCOB.UI.GroupHealingPanel
                    local click=id and panel and panel.ActionFor(id,unit)
                    if not key then key=click end
                    local urgent=effective<=40
                    if key and usable(id,unit,urgent) then
                        local active,remaining=aura(unit,id,"HELPFUL",role~="shield")
                        local grace=guid and recent[guid..":"..SpellName(id)]
                        local eligible,bonus=false,0
                        if role=="quick" then
                            -- A bound quick heal can also cover a moderate
                            -- deficit when the preferred direct heal is absent.
                            eligible=effective<=65; bonus=urgent and 8 or -1
                        elseif role=="direct" then eligible=effective<=65
                        elseif role=="hot" then eligible=effective<=80 and not (active and remaining>3); bonus=-3
                        elseif role=="shield" then
                            local weakened=aura(unit,S.WEAKENED_SOUL,"HARMFUL",false)
                            eligible=effective<=30 and not active and not weakened; bonus=12
                        end
                        -- Regrowth is a quick direct heal with a HoT: do not
                        -- refresh that HoT for moderate damage if HT can work.
                        if id==S.REGROWTH and active and remaining>3 and effective>25 then eligible=false end
                        if grace and GetTime()<grace then eligible=false end
                        if eligible then
                            local score=(100-effective)*10+bonus
                            if not best or score>best.score then
                                best={unit=unit,guid=guid,id=id,slot=slot,key=key,click=click,
                                    panel=not G.Binding(slot) and click~=nil,hp=hp,score=score,
                                    name=call(UnitName,unit) or unit}
                            end
                        end
                    end
                end
            end
        end
    end
    G.current=best
    if best then
        -- Identity is rendered only in the live UI. Generic title/reason keep
        -- names and GUIDs out of combat exports, feedback and tuning buckets.
        return nil,"GROUP HEAL",best.panel and "GROUP CLICK" or "GROUP MOUSEOVER",
            best.panel and "Click the indicated ally's party bar with the displayed mouse binding"
                or "Mouseover the indicated ally and press the dedicated group-heal binding","groupheal"
    end
end

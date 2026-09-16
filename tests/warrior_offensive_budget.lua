local rt = assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local e, I, S, W = rt.env, rt.internal, rt.S, rt.Warrior
local checks, state = 0, rt.reset()
local function expect(actual, expected, label)
    checks=checks+1
    assert(actual==expected,label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function reset()
    state=rt.reset()
    e.GetSpellPowerCost, e.C_Spell = nil, nil
end
local function recommend() return I.Recommend() end

-- Cost queries use the localized learned name, accept client talent discounts,
-- reject malformed data, and conservatively fall back to undiscounted costs.
reset()
expect(W:RageCost(S.HEROIC_STRIKE),15,"HS fallback")
expect(W:RageCost(S.CLEAVE),20,"Cleave fallback")
expect(W:RageCost(nil),nil,"no phantom nil-ID cost")
expect(W:RageCost(999),nil,"unknown cost is not free")
e.GetSpellPowerCost=function(name)
    expect(name,rt.names[S.HEROIC_STRIKE],"localized name used")
    return {{type=0,cost=999},{type=1,cost=12}}
end
expect(W:RageCost(S.HEROIC_STRIKE),12,"learned/talented HS cost")
e.GetSpellPowerCost=function() error("unavailable") end
e.C_Spell={GetSpellPowerCost=function() return {{type=1,cost=17}} end}
expect(W:RageCost(S.CLEAVE),17,"structured cost fallback")
for _, invalid in ipairs({-1,0/0,math.huge,-math.huge,"invalid"}) do
    e.C_Spell.GetSpellPowerCost=function() return {{type=1,cost=invalid}} end
    expect(W:RageCost(S.CLEAVE),20,"malformed native cost")
end
e.GetSpellPowerCost=function() return {{type=1,cost=0}} end
expect(W:RageCost(S.HEROIC_STRIKE),0,"real zero cost is honored")

-- Maintenance may spend only the uncommitted Rage. Test both queue occupants,
-- every guarded action, exact budget boundaries and release after the swing.
local maintenance={
    {S.BATTLE_SHOUT,10}, {S.REND,10}, {S.DEMO_SHOUT,10},
    {S.THUNDER_CLAP,20}, {S.SUNDER_ARMOR,15},
}
for _, queued in ipairs({{S.HEROIC_STRIKE,15},{S.CLEAVE,20}}) do
    for _, action in ipairs(maintenance) do
        reset(); state.queued=queued[1]
        expect(W:CanFundMaintenance(action[1],queued[2]+action[2]-1),false,"preserve queued strike budget")
        expect(W:CanFundMaintenance(action[1],queued[2]+action[2]),true,"fully funded maintenance allowed")
        state.queued=nil
        expect(W:CanFundMaintenance(action[1],action[2]),true,"reservation ends with queue")
    end
end
reset(); state.queued=S.HEROIC_STRIKE
e.GetSpellPowerCost=function(name)
    return {{type=1,cost=name==rt.names[S.HEROIC_STRIKE] and 12 or 10}}
end
expect(W:CanFundMaintenance(S.BATTLE_SHOUT,22),true,"talent savings available to maintenance")
expect(W:CanFundMaintenance(S.BATTLE_SHOUT,21),false,"discounted queue budget still protected")

-- Real scorer regressions: the next-swing attack must not be starved by a buff,
-- bleed or mitigation suggestion. Maintenance resumes with sufficient Rage.
reset(); state.queued=S.HEROIC_STRIKE; state.rage=23; state.shout=false
expect(recommend(),nil,"23 Rage cannot fund queued HS plus Shout")
state.rage=25
expect(recommend(),S.BATTLE_SHOUT,"missing Shout allowed when both spells funded")
state.rage=23;state.queued=nil
expect(recommend(),S.BATTLE_SHOUT,"queue clears; normal Shout maintenance resumes")
reset(); state.queued=S.HEROIC_STRIKE; state.rage=24
state.debuffs[S.REND]=nil; I.currentFight.startClock=state.now
expect(recommend(),nil,"Rend cannot consume pending HS budget")
state.rage=25
expect(recommend(),S.REND,"funded Rend is not delayed")
reset(); state.queued=S.CLEAVE; state.rage=30; state.enemies=2
state.debuffs[S.THUNDER_CLAP]=nil
expect(recommend(),nil,"Clap cannot cancel a funded Cleave")
state.rage=40
expect(recommend(),S.THUNDER_CLAP,"funded multi-target Clap remains available")
reset(); state.queued=S.HEROIC_STRIKE; state.rage=24
state.known[S.DEMO_SHOUT]=true
expect(recommend(),nil,"Demo cannot consume pending HS budget")
state.rage=25
expect(recommend(),S.DEMO_SHOUT,"fully funded Demo remains eligible")
reset(); state.queued=S.HEROIC_STRIKE; state.rage=29; state.targetHP=80
state.known[S.SUNDER_ARMOR]=true
expect(recommend(),nil,"Sunder cannot consume pending HS budget")
state.rage=30
expect(recommend(),S.SUNDER_ARMOR,"fully funded Sunder remains eligible")

-- This is offensive resource accounting, not a new blanket hold. Actual core
-- attacks/procs, critical HP and interrupts retain their existing priorities.
for _, spell in ipairs({S.OVERPOWER,S.MORTAL_STRIKE,S.BLOODTHIRST}) do
    reset();state.queued=S.HEROIC_STRIKE;state.rage=30;state.known[spell]=true
    expect(recommend(),spell,"priority attack can still preempt a dump")
end
reset();state.queued=S.HEROIC_STRIKE;state.rage=20;state.hp=20;state.known[S.HAMSTRING]=true
expect(recommend(),S.HAMSTRING,"critical defense not delayed by queue")
reset();state.queued=S.HEROIC_STRIKE;state.rage=20;state.targetCast={name="Cast"};state.known[S.PUMMEL]=true
expect(recommend(),S.PUMMEL,"interrupt not delayed by queue")

-- A previously displayed buff must be withdrawn immediately when the player
-- queues an attack and no longer has the budget for both (no 200ms stale hold).
reset();state.rage=23;state.shout=false
expect(rt.Engine.Stabilize(recommend()),S.BATTLE_SHOUT,"Shout displayed before queue")
state.queued=S.HEROIC_STRIKE;state.now=state.now+.01
expect(rt.Engine.Stabilize(recommend()),nil,"unfunded displayed buff clears immediately")

-- Exercise real secure attribute generation: all eight modifier states have
-- identical BASE text; rebuild replaces stale spell branches out of combat.
reset();e.MACRO_LIMIT=255
local locked=false
e.InCombatLockdown=function() return locked end
local macros=assert(loadfile("HCOneButton/Core/Macros.lua"));setfenv(macros,e);macros()
local attrs, writes={},0
local target={SetAttribute=function(_,key,value) attrs[key]=value;writes=writes+1 end,
    GetAttribute=function(_,key) return attrs[key] end}
local prefixes={"","shift-","ctrl-","alt-","ctrl-shift-","alt-shift-","alt-ctrl-","alt-ctrl-shift-"}
local legacy={shift="/cast BATTLE_SHOUT",ctrl="/cast THUNDER_CLAP",alt="/cast HAMSTRING",
    ctrlshift="/cast PUMMEL",altshift="/cast !HEROIC_STRIKE",altctrl="/cast BLOODRAGE",all="/cast RETALIATION"}
for _, knownRend in ipairs({false,true}) do
    state.known[S.REND]=knownRend
    for _, prefix in ipairs(prefixes) do attrs[prefix.."macrotext1"]="/cast BATTLE_SHOUT" end
    local main=W:BuildMainMacro()
    expect(I.ApplyAttributes(target,main,legacy),true,"secure rebuild allowed")
    for _, prefix in ipairs(prefixes) do
        expect(attrs[prefix.."type1"],"macro","every modifier uses macro type")
        expect(attrs[prefix.."macrotext1"],main,"every modifier has identical BASE")
        expect(attrs[prefix.."macrotext1"]:find("BATTLE_SHOUT",1,true),nil,"no hidden Shout on BASE")
    end
end
local before=writes;locked=true
expect(I.ApplyAttributes(target,"/different",legacy),false,"no protected mutation during combat")
expect(writes,before,"combat rebuild made zero writes")
locked=false
for _, class in ipairs({"PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID","SHAMAN"}) do
    I.PLAYER_CLASS=class;e.HCOneButton.Classes[class]={}
    I.ApplyAttributes(target,"/base",legacy)
    expect(attrs['shift-macrotext1'],legacy.shift,class.." keeps existing modifier behavior")
    expect(attrs['alt-ctrl-shift-macrotext1'],legacy.all,class.." keeps combined modifier behavior")
end
I.PLAYER_CLASS="WARRIOR"
expect(next(W:BuildModifierMacros().desc),nil,"no misleading modifier tooltip")
local output={}
e.UnitClass=function() return "Warrior" end
e.print=function(message) output[#output+1]=message end
I.btn=target;I.currentMods=W:BuildModifierMacros();I.PrintPlan()
expect(table.concat(output,"\n"):find("BASE ignores SHIFT/CTRL/ALT",1,true)~=nil,true,"plan explains isolated BASE")
expect(table.concat(output,"\n"):find("SHIFT=nil",1,true),nil,"plan does not show removed shortcuts")
print(string.format("Warrior offensive Rage budget and isolated BASE: %d checks PASS",checks))

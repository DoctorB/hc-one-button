local rt=assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local e,W,S,Engine=rt.env,rt.Warrior,rt.S,rt.Engine
local state,checks
checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": expected "..tostring(wanted)..", got "..tostring(actual))
end
local function near(a,b,label) expect(math.abs(a-b)<0.00001,true,label) end
local function reset()
    state=rt.reset()
    state.level,state.targetLevel,state.rage=16,16,30
    state.known[S.SUNDER_ARMOR]=true
    state.health,state.maximum,state.low,state.high,state.crit=350,350,60,90,10
    rt.internal.currentFight.startClock=state.now
    state.armor,state.multiplier,state.talents=754,1,{}
    state.exact={[285]=true,[6546]=true,[7386]=true}
    for id in pairs(state.known) do rt.internal.knownSpellNames[rt.names[id]]=true end
    e.IsPlayerSpell=function(id)
        return state.exact[id] or (id~=S.HEROIC_STRIKE and id~=S.REND and id~=S.SUNDER_ARMOR and state.known[id]) or false
    end
    e.UnitAttackSpeed=function() return state.speed,state.offSpeed end
    e.UnitDamage=function() return state.low,state.high,0,0,0,0,state.multiplier end
    e.UnitHealth=function() return state.health end
    e.UnitHealthMax=function() return state.maximum end
    e.GetCritChance=function() return state.crit end
    e.UnitArmor=function() return state.armor,state.armor end
    e.UnitIsPlayer=function() return state.pvp or false end
    Engine.PlayerIsGrouped=function() return state.grouped or false end
    e.GetNumTalents=function(tab) return tab==1 and 2 or 0 end
    local talentIds={12286,16493}
    e.GetSpellInfo=function(id)
        if id==12286 then return "Improved Rend" end
        if id==16493 then return "Impale" end
        return rt.names[id]
    end
    e.GetTalentInfo=function(tab,index)
        return e.GetSpellInfo(talentIds[index]),nil,nil,nil,state.talents[talentIds[index]] or 0
    end
    e.GetSpellPowerCost=function(name)
        return {{type=1,cost=name==rt.names[S.REND] and 10 or state.hsCost or 15}}
    end
    return state
end
reset()
local m=W:DamageEfficiency(12)
expect(m.heroicRank,285,"actual learned rank, not level-based rank")
near(m.weapon,75,"client damage includes AP once")
near(m.mitigation,1760/2514,"reported armor")
near(m.lostRage,7.5*75*(1760/2514)*1.1/(.0091107836*256+3.225598133*16+4.2652911),"foregone white Rage")
near(m[S.HEROIC_STRIKE].cost,15+m.lostRage,"HS effective cost includes lost Rage")
near(m[S.HEROIC_STRIKE].damage,32*1.1*m.mitigation,"incremental HS damage, not full weapon hit")
near(m[S.REND].damage,28,"four actual rank-2 ticks")
near(m[S.SUNDER_ARMOR].damage,350*90/2514,"sheet armor benefit in damage units")
expect(m.estimatedArmor,false,"reported armor labeled")
state.armor=0
expect(W:DamageEfficiency(12).estimatedArmor,true,"unreadable armor is an explicit estimate")
state.armor=754
state.talents[12286]=3
W:HandleEvent("PLAYER_TALENT_UPDATE")
near(W:DamageEfficiency(12)[S.REND].damage,28*1.35,"invested Rend talent")
state.talents[16493]=2
W:HandleEvent("PLAYER_TALENT_UPDATE")
expect(W:DamageEfficiency(12)[S.HEROIC_STRIKE].damage>m[S.HEROIC_STRIKE].damage,true,"invested Impale boosts yellow crit only")
state.hsCost=12
near(W:DamageEfficiency(12)[S.HEROIC_STRIKE].cost,12+m.lostRage,"native talent discount applied once")
state.exact[285]=nil; state.exact[284]=true
W:HandleEvent("SPELLS_CHANGED")
expect(W:DamageEfficiency(12).heroicRank,284,"not buying next rank keeps learned lower rank")
state.exact[285]=true
W:HandleEvent("SPELLS_CHANGED")
expect(W:DamageEfficiency(12).heroicRank,285,"training updates rank cache")
state.level=20
W:HandleEvent("PLAYER_LEVEL_UP")
expect(W:DamageEfficiency(12).heroicRank,285,"level up does not train spells")
expect(W:DamageEfficiency(12).lostRage<m.lostRage,true,"level changes Rage conversion and armor model")

reset()
local full=W:DamageEfficiency(12)
local short=W:DamageEfficiency(5)
expect(short[S.REND].ticks,1,"truncate Rend to realistic remaining ticks")
expect(W:DPRSetupWorth(short,S.REND),false,"do not buy a one-tick DoT")
expect(W:DPRSetupWorth(short,S.SUNDER_ARMOR),false,"Sunder requires future swings")
state.health=175
near(W:DamageEfficiency(12)[S.SUNDER_ARMOR].damage,full[S.SUNDER_ARMOR].damage/2,"remaining absolute health scales Sunder")
state.health=350
near(W:DamageEfficiency(60)[S.SUNDER_ARMOR].damage,full[S.SUNDER_ARMOR].damage/2,"Sunder duration limits payoff")
state.low,state.high=120,180
expect(W:DamageEfficiency(12).lostRage>full.lostRage,true,"better weapon increases foregone Rage")
state.low,state.high=60,90
state.health=20
expect(W:DamageEfficiency(12).finishing,true,"low absolute health favors immediate finish")
expect(W:DPRSetupWorth(W:DamageEfficiency(12),S.SUNDER_ARMOR),false,"no setup before a likely finishing swing")

for _,case in ipairs({"grouped","pvp","offSpeed","multi","damage","health","crit","noRank"}) do
    reset()
    if case=="grouped" then state.grouped=true
    elseif case=="pvp" then state.pvp=true
    elseif case=="offSpeed" then state.offSpeed=2
    elseif case=="multi" then state.enemies=2
    elseif case=="damage" then state.low=0/0
    elseif case=="health" then state.health=nil
    elseif case=="crit" then state.crit=math.huge
    else state.exact={} end
    expect(W:DamageEfficiency(12),nil,"fallback for "..case)
end

reset()
state.level,state.targetLevel=22,22
state.exact[7405]=true
state.health,state.maximum=700,700
state.targetHP=100
state.debuffs[S.REND]=12
state.dynamics={ttk=20,confidence=1}
state.debuffs[S.SUNDER_ARMOR]=nil
local id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.SUNDER_ARMOR,"real policy chooses efficient Sunder over HS")
state.health=120; state.maximum=700; state.targetHP=17
state.dynamics={ttk=6,confidence=1}
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.HEROIC_STRIKE,"same rank/talents choose HS as remaining payoff falls")
state.health=40; state.targetHP=6; state.rage=15
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.HEROIC_STRIKE,"affordable likely finish needs no arbitrary Rage reserve")
state.health=700; state.targetHP=100; state.rage=90
state.dynamics={ttk=20,confidence=1}
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.HEROIC_STRIKE,"near cap prioritize immediate dumping")
state.known[S.OVERPOWER]=true
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.OVERPOWER,"reactive proc remains above DPR")
state.known[S.OVERPOWER]=nil
state.known[S.MORTAL_STRIKE]=true
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.MORTAL_STRIKE,"core remains above DPR")
state.known[S.MORTAL_STRIKE]=nil
state.rage=30; state.queued=S.HEROIC_STRIKE
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.SUNDER_ARMOR,"funded queued maintenance stays possible")
state.rage=20
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,nil,"DPR cannot steal committed queue budget")
state.queued=nil; state.rage=30; state.debuffs[S.SUNDER_ARMOR]=25
id=W:GetRecommendation(true,true,state.targetHP,1)
expect(id,S.HEROIC_STRIKE,"existing Sunder is not stacked/spammed")

reset()
state.debuffs[S.REND]=nil
state.currentWarriorAutoRend=false
state.dynamics={ttk=12,confidence=1}
id=W:GetRecommendation(true,true,70,1)
expect(id,S.REND,"Rend wins when sufficient efficient ticks remain")
expect(Engine.lastCandidates[1].reason:find("est. DPR",1,true)~=nil,true,"explain modeled candidate")
state.dynamics={ttk=2,confidence=1}
id=W:GetRecommendation(true,true,70,1)
expect(id,S.HEROIC_STRIKE,"Rend no longer wins without time to tick")
reset()
state.health,state.maximum,state.targetHP=700,2800,25
state.level,state.targetLevel=22,22; state.exact[7405]=true
state.known[S.EXECUTE]=true; state.debuffs[S.REND]=nil
state.dynamics={ttk=20,confidence=1}
id=W:GetRecommendation(true,true,25,1)
expect(id,nil,"DPR setup does not drain Execute pooling")
reset()
state.debuffs[S.REND]=nil
rt.internal.currentFight.startClock=state.now-8
W:GetRecommendation(true,true,70,1)
local hasRend=false
for _,c in ipairs(Engine.lastCandidates) do if c.id==S.REND then hasRend=true end end
expect(hasRend,false,"keep bounded Rend opener on aura-less/immune targets")

-- The ranking must react to inputs across the leveling range, not just to the
-- exact example used while implementing the spreadsheet formula.
for _,level in ipairs({6,10,16,22,30,40,50,60}) do
    for _,health in ipairs({40,300,800}) do
        reset(); state.level=level; state.health=health; state.maximum=health
        local base=W:DamageEfficiency(12)
        expect(base~=nil,true,"model available at level "..level)
        expect(base[S.HEROIC_STRIKE].cost>15,true,"white Rage included at every level")
        expect(base[S.SUNDER_ARMOR].cost>=1,true,"no division through negative net cost")
        state.talents[12286]=1; W:HandleEvent("PLAYER_TALENT_UPDATE")
        near(W:DamageEfficiency(12)[S.REND].damage,base[S.REND].damage*1.15,"first talent point affects damage")
        state.talents[12286]=0; W:HandleEvent("PLAYER_TALENT_UPDATE")
        near(W:DamageEfficiency(12)[S.REND].damage,base[S.REND].damage,"respec clears cached talent")
    end
end
reset()
e.GetTalentInfo=function() return 1,"Improved Rend",nil,nil,nil,2 end
W:HandleEvent("PLAYER_TALENT_UPDATE")
near(W:DamageEfficiency(12)[S.REND].damage,35,"alternate talent tuple")
reset()
e.IsPlayerSpell=nil
e.C_SpellBook={IsSpellKnown=function(id) return state.exact[id] or false end}
expect(W:DamageEfficiency(12).heroicRank,285,"modern exact-rank API")
e.C_SpellBook=nil
reset()
e.GetSpellPowerCost=nil
e.C_Spell={GetSpellPowerCost=function(name) return {{type=1,cost=name==rt.names[S.REND] and 10 or 12}} end}
near(W:DamageEfficiency(12)[S.HEROIC_STRIKE].cost,12+W:DamageEfficiency(12).lostRage,"modern client cost API")
e.C_Spell=nil
reset()
state.hsCost=0
expect(W:DamageEfficiency(12)[S.HEROIC_STRIKE].dpr<math.huge,true,"free cast still loses white Rage")
reset()
state.exact[6546]=nil
expect(W:DamageEfficiency(12),nil,"unknown learned Rend rank falls back, never guessed")
reset()
e.UnitDamage=function() error("client temporarily unavailable") end
expect(W:DamageEfficiency(12),nil,"API failure is a safe fallback")
print("warrior DPR: "..checks.." checks passed")

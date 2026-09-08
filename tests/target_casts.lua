-- Real target-cast reader: modern/Classic signatures, event races and safe fallback.
local env = setmetatable({}, {__index=_G})
env.HCOneButton = {Internal=env, Classes={}, Advisor={Engine={}}}
local function load(path) local f=assert(loadfile(path)); setfenv(f,env); f() end
env.HCOneButton.Data = {}
load("HCOneButton/Data/Spells.lua")
env.S = env.HCOneButton.Data.Spells
local now, guid, payload, channel = 100, "mob1", nil, nil
env.GetTime = function() return now end
env.SafeUnitGUID = function() return guid end
env.SafeNumber = function(v, fallback)
    v=tonumber(v); return v and v==v and math.abs(v)<math.huge and v or fallback
end
env.CanAccessValue = function(v) return v ~= "secret" end
env.UnitCastingInfo = function() if payload then return unpack(payload,1,9) end end
env.UnitChannelInfo = function() if channel then return unpack(channel,1,8) end end
local castingAPI, channelAPI = env.UnitCastingInfo, env.UnitChannelInfo
load("HCOneButton/Advisor/Threat.lua")
local checks=0
local function eq(a,b,label) checks=checks+1; assert(a==b,label..": got "..tostring(a)..", wanted "..tostring(b)) end
local function clear()
    env.HandleTargetCastEvent("PLAYER_TARGET_CHANGED")
    now,guid,payload,channel=100,"mob1",nil,nil
    env.UnitCastingInfo,env.UnitChannelInfo=castingAPI,channelAPI
end
local function normal(flag) return {"Heal","Heal",1,99000,102000,false,"cast-a",flag,123} end
clear()
eq(env.ActiveTargetCast(),nil,"idle")
payload=normal(false)
local cast=env.ActiveTargetCast()
eq(cast.name,"Heal","live name")
eq(cast.spellId,123,"modern cast spell id")
eq(cast.interruptible,true,"explicit interruptible")
eq(cast.remaining,2,"live remaining seconds")
eq(cast.source,"unit","live source")
eq(cast.channel,false,"cast not channel")
payload[8]=true
eq(env.ActiveTargetCast().interruptible,false,"known non-interruptible cast")
payload[8],payload[9]=123,nil
eq(env.ActiveTargetCast().spellId,123,"Classic shifted spell id")
eq(env.ActiveTargetCast().interruptible,nil,"Classic numeric id is not immunity")
payload[8],payload[9]="secret",123
eq(env.ActiveTargetCast().interruptible,nil,"unreadable immunity is unknown")
payload=nil
channel={"Drain",nil,1,99000,104000,false,false,234}
eq(env.ActiveTargetCast().channel,true,"live channel")
eq(env.ActiveTargetCast().spellId,234,"channel modern id")
channel[7],channel[8]=234,nil
eq(env.ActiveTargetCast().spellId,234,"channel Classic shifted id")
eq(env.ActiveTargetCast().interruptible,nil,"channel unknown immunity")
channel[5]=105000
eq(env.ActiveTargetCast().remaining,5,"channel update refreshes duration")
channel=nil
env.activeTargetCast={guid=guid,spellId=234,expires=110}
eq(env.ActiveTargetCast(),nil,"ended live cast cannot resurrect CLEU estimate")
clear()
env.activeTargetCast={guid=guid,spellId=123,expires=102}
eq(env.ActiveTargetCast().source,"combat_event","Era nil APIs retain bounded event fallback")
eq(env.ActiveTargetCast().interruptible,nil,"event fallback cannot assert interruptibility")
now=102
eq(env.ActiveTargetCast(),nil,"fallback expires at actual estimate, without extra grace")
clear()
env.UnitCastingInfo=function() error("unsupported") end
env.UnitChannelInfo=nil
env.activeTargetCast={guid=guid,spellId=123,expires=102}
eq(env.ActiveTargetCast().remaining,2,"missing/failed API keeps safe fallback")
guid="mob2"
eq(env.ActiveTargetCast(),nil,"old target estimate discarded")
clear()
payload=normal(false)
env.HandleTargetCastEvent("UNIT_SPELLCAST_START","target","cast-a",123)
eq(env.ActiveTargetCast().castGUID,"cast-a","polls preserve exact cast identity")
env.HandleTargetCastEvent("UNIT_SPELLCAST_STOP","target","cast-old",123)
eq(env.ActiveTargetCast().spellId,123,"late stop for earlier same-spell cast ignored")
env.HandleTargetCastEvent("UNIT_SPELLCAST_FAILED","target","cast-a",123)
eq(env.ActiveTargetCast(),nil,"stop overrides stale positive API result")
payload[4]=100050; now=100.1
eq(env.ActiveTargetCast().spellId,123,"new same-spell cast starts normally")
env.HandleTargetCastEvent("UNIT_SPELLCAST_STOP","player","cast-a",123)
eq(env.ActiveTargetCast().spellId,123,"player event cannot cancel target cast")
payload[5]=100100
eq(env.ActiveTargetCast(),nil,"expired positive API data ignored")
clear()
payload=normal(false); payload[5]=0/0
eq(env.ActiveTargetCast(),nil,"NaN timing rejected")
payload=normal(false); payload[4]=200000; payload[5]=202000
eq(env.ActiveTargetCast(),nil,"future cast data rejected")
guid=nil
eq(env.ActiveTargetCast(),nil,"no target")
clear()
channel={"Drain",nil,1,99000,104000,false,false,234}
env.HandleTargetCastEvent("UNIT_SPELLCAST_CHANNEL_START","target","channel-a",234)
eq(env.ActiveTargetCast().castGUID,"channel-a","channel identity persists")
env.HandleTargetCastEvent("UNIT_SPELLCAST_CHANNEL_STOP","target","channel-a",234)
eq(env.ActiveTargetCast(),nil,"channel stop overrides stale channel API")
clear()
payload=normal(false)
env.ActiveTargetCast()
payload[5]=104000
eq(env.ActiveTargetCast().remaining,4,"cast delay refreshes live end time")
payload[8]=true
eq(env.ActiveTargetCast().interruptible,false,"changed interruptibility is immediately visible")
env.HandleTargetCastEvent("PLAYER_REGEN_ENABLED")
payload=nil
eq(env.ActiveTargetCast(),nil,"combat end clears target-cast state")

-- All class contracts keep context and distinguish control from direct interrupt.
local S=env.S
local choices={WARRIOR=S.PUMMEL,MAGE=S.COUNTERSPELL,ROGUE=S.KICK,PRIEST=S.SILENCE,
    WARLOCK=S.SPELL_LOCK,SHAMAN=S.EARTH_SHOCK,PALADIN=S.HAMMER_JUSTICE,
    HUNTER=S.SCATTER_SHOT,DRUID=S.BASH}
for token,id in pairs(choices) do
    env.PLAYER_CLASS=token
    local context={remaining=2,interruptible=true}
    env.HCOneButton.Classes[token]={GetInterruptRecommendation=function(_, received)
        eq(received,context,token.." receives live cast context")
        return id,"STOP","KEY","reason"
    end}
    eq(env.InterruptRecommendation(context),id,token.." normal interrupt")
    context.interruptible=false
    local control=token=="PALADIN" or token=="HUNTER" or token=="DRUID"
    eq(env.InterruptRecommendation(context),control and id or nil,token.." immune cast handling")
    context.remaining=0.15
    eq(env.InterruptRecommendation(context),nil,token.." expired reaction window")
end
print("Target cast/interrupt regression: "..checks.." checks PASS")

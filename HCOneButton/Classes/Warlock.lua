local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.WARLOCK or {}
HCOB.Classes.WARLOCK = Class
Class.classToken = "WARLOCK"
Class.fallbackSpec = 1

local Engine = HCOB.Advisor.Engine
local API = HCOB.Core.ClassAPI
local S = HCOB.Data.Spells
local SOUL_SHARD_ITEM = 6265
-- Drain Soul farms up to the cap. Shadowburn keeps the reserve for a
-- Voidwalker resummon/Healthstone unless the fight itself is the danger.
local SHARD_CAP = 5
local SHARD_RESERVE = 2

local function SoulShardCount()
    if not GetItemCount then return 0 end
    local ok, n = pcall(GetItemCount, SOUL_SHARD_ITEM)
    return ok and (SafeNumber(n, 0) or 0) or 0
end
Class.SoulShardCount = SoulShardCount

local function PetHasSpell(id)
    local wanted = API.SpellName(id)
    if not wanted or not UnitExists("pet") or not GetPetActionInfo then return false end
    for i = 1, 10 do
        local ok, name = pcall(GetPetActionInfo, i)
        name = ok and SafeString(name, nil) or nil
        if name and name == wanted then
            -- A Spell Lock on cooldown is not an interrupt; let the caller
            -- fall through instead of advertising a dead button.
            if not GetPetActionCooldown then return true end
            local cdOk, start, duration = pcall(GetPetActionCooldown, i)
            start, duration = cdOk and SafeNumber(start, 0) or 0, cdOk and SafeNumber(duration, 0) or 0
            return not (start > 0 and duration > 1.5 and start + duration > GetTime())
        end
    end
    return false
end

local function PetOffTarget()
    if not UnitExists("pettarget") then return true end
    if not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, "pettarget", "target")
    return ok and not SafeBoolean(same, false)
end

-- Targeting alone never pulls: the opener is an Action Panel slot, which the
-- pixel reader presses as soon as it shows. A BASE press on this target, or
-- the pet already attacking it, is the decision to engage.
local function Engaged()
    if UnitExists("pet") and not PetOffTarget() then return true end
    local guid = SafeUnitGUID("target")
    return guid ~= nil and guid == Class.engagedGUID
end

function Class:OnBaseInput()
    if HostileLiveTarget() then Class.engagedGUID = SafeUnitGUID("target") end
end

local function ContextText(ctx)
    local text = string.format(
        "HP %.0f%% | mana %.0f%% | reserve %.0f %s",
        ctx.player.hp, ctx.player.mana, ctx.combat.reserve, ctx.combat.reserveLabel or "?"
    )
    local ttk = ctx.combat.ttk
    if ttk and ttk < math.huge then text = text .. string.format(" | TTK ~%.0fs", ttk) end
    if ctx.pet.alive then
        text = text .. string.format(" | pet %.0f%%%s", ctx.pet.hp or 0, ctx.pet.tanking and " tanking" or "")
    else
        text = text .. " | no pet"
    end
    return text
end

function Class:GetCandidates(ctx)
    local candidates = {}
    if not ctx.inCombat then
        Class.petOffSince = nil
        if not ctx.hostile then return candidates end
        if ctx.player.mana <= 45 and ctx.player.hp >= 82 and API.IsKnown(S.LIFE_TAP) and API.IsUsable(S.LIFE_TAP) then
            Engine.AddCandidate(candidates, S.LIFE_TAP, "LIFE TAP", "ALT+CTRL", "Pre-pull resource conversion while HP is safely high", 72, "resource")
        elseif not Engaged() then
            return candidates
        elseif ctx.player.mana >= 35 and API.IsKnown(S.SHADOW_BOLT) and API.IsUsable(S.SHADOW_BOLT) then
            -- A wand tick alone is a weak opener; BASE already sent the pet.
            Engine.AddCandidate(candidates, S.SHADOW_BOLT, "SHADOW BOLT OPENER", "CAST MANUALLY",
                "The pet is engaging: open from maximum range", 70, "opener")
        elseif API.IsKnown(S.CORRUPTION) and API.IsUsable(S.CORRUPTION) then
            Engine.AddCandidate(candidates, S.CORRUPTION, "CORRUPTION OPENER", "CAST MANUALLY",
                "The pet is engaging: low-cost DoT opener", 66, "opener")
        end
        return candidates
    end
    -- The engagement mark only gates the out-of-combat opener; the next
    -- pull needs a new BASE press.
    Class.engagedGUID = nil
    if not ctx.hostile then return candidates end

    local hp = ctx.player.hp
    local mana = ctx.player.mana
    local targetHP = ctx.target.hp
    local reserve = ctx.combat.reserve
    local dyn = ctx.combat.dynamics
    local ttk = ctx.combat.ttk
    local close = ctx.target.close
    local playerTanking = ctx.target.onPlayer
    local petTanking = ctx.pet.tanking
    local petHP = ctx.pet.hp or 0
    -- Standing within ~10 yards of a mob the pet holds is safe casting
    -- range. Only a mob on the player (or one the pet does not hold) makes
    -- proximity a reason to skip cast-time damage.
    local exposed = close and (playerTanking or not petTanking)
    local hasWand = API.HasWandEquipped() and API.IsKnown(S.SHOOT)
    local context = ContextText(ctx)

    -- A target switch in combat leaves the pet on its old mob until the next
    -- BASE press. With several mobs
    -- the pet may tank one while the warlock DoTs another: no notice then.
    -- The one-second wait keeps a quick tab-target check silent.
    if ctx.pet.alive and not petTanking and CountActiveEnemies() <= 1 and PetOffTarget() then
        Class.petOffSince = Class.petOffSince or GetTime()
        if GetTime() - Class.petOffSince >= 1 then
            Engine.AddCandidate(candidates, nil, "PET NOT ATTACKING", "PRESS BASE ONCE",
                "Your pet is not on your target: one BASE press sends it in | " .. context, 96, "pet", "caution")
        end
    else
        Class.petOffSince = nil
    end

    local armor =API.IsKnown(S.DEMON_ARMOR) and S.DEMON_ARMOR or S.DEMON_SKIN
    if armor and API.IsKnown(armor) and API.IsUsable(armor) then
        local hasArmor, armorRemaining = API.StablePlayerBuff(armor)
        if not hasArmor or armorRemaining <= 10 then
            local reason = hasArmor and ("Refresh before expiry (" .. math.floor(armorRemaining) .. "s)") or (API.SpellName(armor) .. " missing in combat")
            Engine.AddCandidate(candidates, armor, "DEMON ARMOR", "SHIFT", reason .. " | " .. context, hasArmor and 64 or 84, "buff")
        end
    end

    -- Nightfall is a short proc window. Consume Shadow Trance before a normal
    -- filler or wand recommendation can hide the instant Shadow Bolt.
    local shadowTrance = API.HasPlayerBuff(S.SHADOW_TRANCE)
    if shadowTrance and API.IsKnown(S.SHADOW_BOLT) and API.IsUsable(S.SHADOW_BOLT) then
        Engine.AddCandidate(candidates, S.SHADOW_BOLT, "NIGHTFALL - SHADOW BOLT", "CAST MANUALLY",
            "Shadow Trance is active: use the instant Shadow Bolt | " .. context, 118, "proc")
    end

    if close and (hp <= 68 or reserve <= 50) and API.IsKnown(S.DEATH_COIL)
       and API.CooldownReady(S.DEATH_COIL) and API.IsUsable(S.DEATH_COIL) then
        local score = 111 + math.max(0, 55 - reserve) * 0.18
        Engine.AddCandidate(candidates, S.DEATH_COIL, "DEATH COIL", "ALL MODS",
            "Instant control + healing: regain casting distance | " .. context, score, "survival")
    end

    -- Curse of Weakness is deliberately a defensive curse here. It can replace
    -- Agony when the player, rather than the pet, is absorbing melee pressure.
    local weakness = API.HasMyTargetDebuff(S.CURSE_WEAKNESS)
    if close and playerTanking and targetHP >= 38 and reserve <= 58
       and API.IsKnown(S.CURSE_WEAKNESS) and API.IsUsable(S.CURSE_WEAKNESS) and not weakness then
        Engine.AddCandidate(candidates, S.CURSE_WEAKNESS, "CURSE OF WEAKNESS", "CAST MANUALLY",
            "You are tanking the mob: trade curse damage for lower melee pressure | " .. context,
            reserve <= 42 and 96 or 86, "survival")
    end

    if close and targetHP > 28 and reserve <= 42 and API.IsKnown(S.FEAR)
       and API.IsUsable(S.FEAR) and not API.HasMyTargetDebuff(S.FEAR) then
        Engine.AddCandidate(candidates, S.FEAR, "FEAR + DISTANCE", "CTRL",
            "Pressure is high: Fear only toward a verified clear escape path | " .. context, 103, "survival")
    end

    -- Losing the tanking pet turns the fight onto the player. While the
    -- warlock's own HP can pay for it, feed the pet instead of Drain Life,
    -- which heals only the player.
    local funnel = petTanking and petHP <= 40 and hp >= 55 and not playerTanking and targetHP > 20
        and reserve >= 45 and API.IsKnown(S.HEALTH_FUNNEL) and API.IsUsable(S.HEALTH_FUNNEL)
    if funnel then
        Engine.AddCandidate(candidates, S.HEALTH_FUNNEL, "HEALTH FUNNEL", "CAST MANUALLY",
            "Keep the tanking pet alive with your spare HP | " .. context,
            88 + math.max(0, 40 - petHP) * 0.4, "sustain")
    end

    local petCritical = ctx.pet.alive and petHP <= 24 and not funnel
    if (hp <= 66 or petCritical or (playerTanking and reserve <= 55))
       and targetHP > 16 and mana >= 18 and API.IsKnown(S.DRAIN_LIFE) and API.IsUsable(S.DRAIN_LIFE) then
        local score = 80 + math.max(0, 66 - hp) * 0.48
        if playerTanking then score = score + 7 end
        if reserve < 45 then score = score + 8 end
        if petCritical then score = score + 4 end
        Engine.AddCandidate(candidates, S.DRAIN_LIFE, "DRAIN LIFE", "ALT",
            "Turn mana into HP while maintaining damage | " .. context, score, "sustain")
    end

    local shards = SoulShardCount()
    if targetHP <= 24 and (shards > SHARD_RESERVE or reserve < 45) and API.IsKnown(S.SHADOWBURN)
       and API.CooldownReady(S.SHADOWBURN) and API.IsUsable(S.SHADOWBURN) then
        local score = 91 + (targetHP <= 14 and 8 or 0) - (reserve < 38 and 8 or 0)
        Engine.AddCandidate(candidates, S.SHADOWBURN, "SHADOWBURN", "ALT+SHIFT",
            "Fast finisher with spare Soul Shards (" .. shards .. ") | " .. context, score, "finisher")
    end

    local corruption = API.HasMyTargetDebuff(S.CORRUPTION)
    if API.IsKnown(S.CORRUPTION) and API.IsUsable(S.CORRUPTION) and not corruption
       and mana >= 26 and targetHP >= 38 and reserve >= 38 then
        local longEnough = not ttk or ttk >= 8
        if longEnough then
            local score = ctx.spec == 1 and 78 or 73
            Engine.AddCandidate(candidates, S.CORRUPTION, "CORRUPTION", "CAST MANUALLY",
                "Primary efficient DoT: target should live long enough for useful ticks | " .. context,
                score, "dot")
        end
    end

    local agony = API.HasMyTargetDebuff(S.CURSE_AGONY)
    if API.IsKnown(S.CURSE_AGONY) and API.IsUsable(S.CURSE_AGONY) and not agony and not weakness
       and mana >= 34 and targetHP >= 58 and reserve >= 48 and not playerTanking then
        local longEnough = not ttk or ttk >= 18
        if longEnough then
            Engine.AddCandidate(candidates, S.CURSE_AGONY, "CURSE OF AGONY", "CAST MANUALLY",
                "Damage curse only when the fight is long and pet/control state is stable | " .. context,
                ctx.spec == 1 and 69 or 64, "dot")
        end
    end

    local immolate = API.HasMyTargetDebuff(S.IMMOLATE)
    if API.IsKnown(S.IMMOLATE) and API.IsUsable(S.IMMOLATE) and not immolate
       and mana >= 46 and targetHP >= 55 and reserve >= 48 and not exposed then
        local longEnough = not ttk or ttk >= 11
        if longEnough then
            Engine.AddCandidate(candidates, S.IMMOLATE, "IMMOLATE", "CAST MANUALLY",
                "Add Immolate only when cast time, mana and remaining fight length justify it | " .. context,
                ctx.spec == 3 and 72 or 62, "dot")
        end
    end

    if mana <= 27 and hp >= 74 and reserve >= 60 and API.IsKnown(S.LIFE_TAP) and API.IsUsable(S.LIFE_TAP)
       and not playerTanking and (petTanking or not close) then
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= 14
        if ttdSafe and (not ctx.pet.alive or petHP >= 32) then
            Engine.AddCandidate(candidates, S.LIFE_TAP, "LIFE TAP", "ALT+CTRL",
                "Low mana with safe HP and threat geometry: convert health before resources stall | " .. context,
                mana <= 15 and 75 or 68, "resource")
        end
    end

    if hasWand and not exposed then
        if targetHP <= 38 or mana <= 34 or (petTanking and mana <= 55) then
            local score = 73 + (targetHP <= 22 and 11 or 0) + (mana <= 22 and 5 or 0) + (petTanking and 4 or 0)
            Engine.AddCandidate(candidates, S.SHOOT, "WAND / CONSERVE", "CAST MANUALLY",
                "Let DoTs and pet finish while mana regenerates and pet threat stabilizes | " .. context, score, "efficiency")
        end
    end

    -- The shard is granted only if the target dies during the channel, so
    -- this must outrank the finishing wand (up to 93) to ever be used.
    if API.IsKnown(S.DRAIN_SOUL) and API.IsUsable(S.DRAIN_SOUL) and targetHP <= 12
       and reserve >= 50 and not exposed and shards < SHARD_CAP then
        Engine.AddCandidate(candidates, S.DRAIN_SOUL, "DRAIN SOUL", "CAST MANUALLY",
            "Finish with Drain Soul to gain a Soul Shard (" .. shards .. "/" .. SHARD_CAP .. ") | " .. context, 95, "resource")
    end

    -- Without a wand Shadow Bolt is the only filler: keep it through the
    -- low-HP tail and on less mana, since Life Tap refills it.
    if API.IsKnown(S.SHADOW_BOLT) and API.IsUsable(S.SHADOW_BOLT) and mana >= (hasWand and 42 or 30)
       and reserve >= 52 and (targetHP >= 28 or not hasWand) and not exposed and not shadowTrance then
        local score = ctx.spec == 3 and 72 or 58
        if petTanking and mana >= 65 then score = score + 3 end
        if ttk and ttk < 5 then score = score - 12 end
        Engine.AddCandidate(candidates, S.SHADOW_BOLT, "SHADOW BOLT", "CAST MANUALLY",
            ctx.spec == 3 and ("Destruction core filler with safe distance | " .. context) or ("Optional filler only when DoTs/resources are already stable | " .. context), score, "damage")
    end

    return candidates
end

function Class:GetIdleRecommendation(inCombat, hostile)
    if not hostile then return end
    -- No spell before the pull, so the pixel stays black (a wand PULL READY
    -- would show Shoot) until the player presses BASE.
    if not inCombat and not Engaged() then
        local readiness = Engine.lastPrePullReadiness
        local summary = readiness and readiness.ready and readiness.summary
        return nil, "PULL READY", "PRESS BASE",
            "BASE sends the pet and starts the rotation" .. (summary and (" | " .. summary) or ""), "idle"
    end
    -- Without a wand BASE only commands the pet and deals no damage itself.
    -- Never fall through to a generic BASE request.
    if API.HasWandEquipped() and API.IsKnown(S.SHOOT) then return end
    if inCombat then
        return nil, "LET DOTS AND PET WORK", "WAIT / RECOVER",
            "Wait for mana, Life Tap health or a safe casting window", "idle"
    end
    return nil, "NO OPENER READY", "WAIT / RECOVER",
        "The pet is engaging; recover mana for the Shadow Bolt opener", "idle"
end

-- Pre-pull readiness asks the class which spell fixes a missing or hurt pet.
function Class:GetPetRecoverySpell(issue)
    if issue == "missing" then
        if SoulShardCount() > 0 and API.IsKnown(S.SUMMON_VOIDWALKER) then return S.SUMMON_VOIDWALKER end
        if API.IsKnown(S.SUMMON_IMP) then return S.SUMMON_IMP end
    elseif issue == "hurt" and API.IsKnown(S.HEALTH_FUNNEL) then
        return S.HEALTH_FUNNEL
    end
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local ctx = Engine.BuildClassContext(inCombat, hostile, targetHP, spec)
    return Engine.SelectCandidate(self:GetCandidates(ctx))
end


-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetCautionRecommendation(ctx)
    if Engine.TargetIsClose() and API.IsKnown(S.DEATH_COIL) and API.CooldownReady(S.DEATH_COIL) and API.IsUsable(S.DEATH_COIL) then
        return S.DEATH_COIL, "UNFAVORABLE FIGHT", "ALL MODS", ctx.text .. ": Death Coil and recreate distance", "caution"
    end
    if ctx.hp <= 62 and API.IsKnown(S.DRAIN_LIFE) and API.IsUsable(S.DRAIN_LIFE) then
        return S.DRAIN_LIFE, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": recover HP while continuing the fight", "caution"
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        local petAlive = HCOB.Advisor.Engine.PetAlive()
        local petHP = HCOB.Advisor.Engine.PetHP()
        local petTanking = HCOB.Advisor.Engine.TargetOnPet()
        local playerTanking = HCOB.Advisor.Engine.TargetOnPlayer()
        score = hp * 0.47 + mana * 0.15 + petHP * 0.10 + 8
        if petAlive then score = score + 5 else score = score - 8 end
        if petTanking then score = score + 8 end
        if playerTanking then score = score - 8 end
        if petAlive and petHP <= 25 then score = score - 7 end
        if IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then score = score + 12 end
        if IsKnown(S.FEAR) and IsUsable(S.FEAR) then score = score + 7 end
        if IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) and mana >= 18 then score = score + 4 end
        if HCOB.Advisor.Engine.TargetIsClose() then score = score - 10 end
        if hp < 45 and mana < 20 then score = score - 5 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then return S.DEATH_COIL, "DEATH COIL", "ALL MODS", "Instant fear + healing: create distance" end
        if IsKnown(S.FEAR) and IsUsable(S.FEAR) then return S.FEAR, "FEAR + RUN", "CTRL", "Create distance only with a clear escape route" end
        if IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) then return S.DRAIN_LIFE, "DRAIN LIFE", "ALT", "No CC ready: recover HP while dealing damage" end
        return nil, "RUN!", "PREPARE ESCAPE", "Death Coil/Fear unavailable"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        local petHP = HCOB.Advisor.Engine.PetHP()
        if enemies >= 3 or hp <= 46 or (petHP > 0 and petHP <= 25) then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - GET OUT" or "MULTI - RESET", key or "ALL MODS", reason or "Control and create distance", "danger"
        end
        if HCOB.Advisor.Engine.TargetIsClose() and IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then
            return S.DEATH_COIL, "MULTI x2 - DEATH COIL", "ALL MODS", "Get one mob off you and recover HP", "caution"
        end
        return nil, "MULTI x2", "PET / DOT / EXIT", "Let the pet tank; do not Fear toward other packs", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if PetHasSpell(S.SPELL_LOCK) then return S.SPELL_LOCK, "SPELL LOCK!", "CTRL+SHIFT", "Felhunter" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        -- BASE is the decision to pull: like the Hunter, the pet attacks at
        -- once, in or out of combat. Targeting alone sends nothing.
        AddLine(lines, "/petattack [harm]", 1)
        -- BASE is a single press: pet plus auto-repeat wand. Every cast-time
        -- spell, Shadow Bolt included, comes from the Advisor's fixed slots
        -- so repeated BASE input can never override its choice.
        if HasWandEquipped() and IsKnown(S.SHOOT) then
            AddLine(lines, "/cast [harm] !" .. SpellName(S.SHOOT), 1)
        end
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        local armor = IsKnown(S.DEMON_ARMOR) and S.DEMON_ARMOR or S.DEMON_SKIN
        local burst = IsKnown(S.SHADOWBURN) and S.SHADOWBURN or S.DRAIN_LIFE
        local panic = IsKnown(S.DEATH_COIL) and BuildSpellMacro(S.DEATH_COIL, "harm") or BuildSpellMacro(S.FEAR, "harm")
        return {
            shift=BuildSpellMacro(armor), ctrl=BuildSpellMacro(S.FEAR, "harm"),
            alt=BuildSpellMacro(S.DRAIN_LIFE, "harm"), ctrlshift=BuildSpellMacro(S.SPELL_LOCK, "harm", false, true),
            altshift=BuildSpellMacro(burst, "harm"), altctrl=BuildSpellMacro(S.LIFE_TAP), all=panic,
            desc={shift="Demon Armor / Skin",ctrl="Fear",alt="Drain Life",ctrlshift="Spell Lock",altshift="Shadowburn / Drain Life",altctrl="Life Tap",all="Death Coil / Fear"}
        }
end

function Class:GetBaseActionInfo(spec)
    if HasWandEquipped() and IsKnown(S.SHOOT) then return S.SHOOT, "PET + WAND" end
    return nil, "PET ATTACK"
end

function Class:GetBaseLabel()
    return "BASE"
end

function Class:GetBaseIcon()
    return "Interface\\Icons\\Ability_GhoulFrenzy"
end

function Class:IsRangedBaseAction(id)
    local baseId = self:GetBaseActionInfo(TalentSpec())
    return baseId ~= nil and id == baseId
end


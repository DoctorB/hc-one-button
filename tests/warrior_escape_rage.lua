-- Risk warnings now accompany normal scoring rather than using a separate
-- excess-Rage escape branch. Exercise the real router at both sides of the
-- former forty-Rage gate and the configured critical-health boundary.
local rt = assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local s, S, W = rt.reset(), rt.S, rt.Warrior
local function expect(actual, wanted, label)
    assert(actual == wanted, label .. ": expected " .. tostring(wanted) .. ", got " .. tostring(actual))
end
for _, rage in ipairs({25,35,39,40,50,85,100}) do
    for _, enemies in ipairs({1,2,3}) do
        s=rt.reset(); s.rage=rage; s.enemies=enemies; s.hp=60; s.trend="caution"
        s.known[S.HAMSTRING]=true
        local id=rt.internal.Recommend()
        expect(id,S.HEROIC_STRIKE,"risk must not hoard affordable Rage")
        expect(W:GetCautionRecommendation({hp=60}),nil,"no separate escape gate")
        expect(W:GetMultiPullRecommendation(enemies,60,70),nil,"no forced multi-pull exit")
        s.hp=20
        expect(rt.internal.Recommend(),S.HAMSTRING,"critical HP retains defensive priority")
    end
end
print("warrior escape/Rage warning regression: PASS")

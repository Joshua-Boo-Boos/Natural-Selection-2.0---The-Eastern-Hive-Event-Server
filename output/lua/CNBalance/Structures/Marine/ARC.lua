
Script.Load("lua/BiomassHealthMixin.lua")
local baseOnCreate = ARC.OnCreate
function ARC:OnCreate()
    baseOnCreate(self)
    InitMixin(self, BiomassHealthMixin)
end

function ARC:GetExtraHealth(techLevel,extraPlayers,recentWins)
    return kARCHealthPerPlayerAdd * extraPlayers
end

-- Killfeed / kill credit (ported from NS2.0-TEH-Beta).
--
-- TeamDeathMessageMixin:GetDeathMessage and Player:OnKill resolve a non-player killer via `killer:GetOwner()` - if
-- that returns a Player the kill is credited to them ("<Commander> killed X with ARC", "X was killed by <Commander>" in
-- the server log), otherwise the ARC itself is shown and the server log only says "X died".
--
-- ARC already has an owner (OwnerMixin; RoboticsFactory:ManufactureEntity sets it to whoever ordered it), but that
-- Commander entity is replaced whenever they leave the chair, so the owner is often gone. This EXTENDS it, never
-- replaces it: the genuine owner if it is still a valid Player, then whoever is (or, where the team tracks it, was last)
-- in the command chair, then nil so the ARC itself is shown.
local baseARCGetOwner = ARC.GetOwner

function ARC:GetOwner()

    local owner = baseARCGetOwner and baseARCGetOwner(self)
    if owner and owner.isa and owner:isa("Player") then
        return owner
    end

    local team = self:GetTeam()
    if not team then
        return nil
    end

    local commander = team.GetCommander and team:GetCommander()
    if commander then
        return commander
    end

    if team.GetLastCommander then
        return team:GetLastCommander()
    end

    return nil
end

local baseValidateTargetPosition = ARC.ValidateTargetPosition
function ARC:ValidateTargetPosition(position)
    -- The base (vanilla ARC:ValidateTargetPosition) ALREADY returns false when any
    -- ShadeInk cloud is within kShadeInkDisorientRadius of the target - so an existing
    -- cloud already blocks the ARC (and cancels a charging shot, since UpdateTargetingPosition
    -- re-runs this every update). This override only ADDS the auto-ink parry: if no cloud
    -- exists yet, a READY nearby shade inks on this shot ("oh no, quickly Ink!") and the
    -- fresh cloud then blocks the ARC via the base check on subsequent updates.
    local successful = baseValidateTargetPosition(self,position)
    if successful then
        successful = not AlienDetectionParry(GetEnemyTeamNumber(self:GetTeamNumber()),position,ShadeInk.kShadeInkDisorientRadius)
    end
    return successful
end

function ARC:GetCanFireAtTargetActual(target, targetPoint, manuallyTargeted)

    if not target.GetReceivesStructuralDamage or not target:GetReceivesStructuralDamage() then
        return false
    end

    -- don't target eggs (they take only splash damage)
    -- Hydra exclusion has to due with people using them to prevent ARC shooting Hive. 
    if target:isa("Egg") or target:isa("Cyst") then -- or target:isa("Contamination") then
        return false
    end

    if not manuallyTargeted and (target:isa("Hydra") or target:isa("SporeMine"))then
        return false
    end

    if target.GetIsSighted then
        if not target:GetIsSighted() and not GetIsTargetDetected(target) then
            return false
        end
    end

    local distToTarget = (target:GetOrigin() - self:GetOrigin()):GetLengthXZ()
    if (distToTarget > ARC.kFireRange) or (distToTarget < ARC.kMinFireRange) then
        return false
    end
    
    return true

end

if Server then
    local basePerformAttack = ARC.PerformAttack
    function ARC:PerformAttack()
        basePerformAttack(self)


        local team = self:GetTeam()
        if team then
            team:OnDeadlockExtend(kTechId.ARCDeploy)
        end
    end
    
end 
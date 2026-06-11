if not CLIENT then return end

local frozenAngle = nil

net.Receive("zcity_adminfreezer_freeze", function()
    frozenAngle = net.ReadAngle()
end)

net.Receive("zcity_adminfreezer_unfreeze", function()
    frozenAngle = nil
end)

-- Блокируем взгляд: CalcView возвращает зафиксированный угол
hook.Add("CalcView", "zcity_adminfreezer_lockview", function(ply, origin, angles, fov)
    if ply ~= LocalPlayer() then return end
    if not frozenAngle then return end
    return { origin = origin, angles = frozenAngle, fov = fov }
end)

-- Блокируем угол в UserCmd чтобы сервер тоже получал зафиксированный угол
hook.Add("CreateMove", "zcity_adminfreezer_lockcmd", function(cmd)
    if not frozenAngle then return end
    cmd:SetViewAngles(frozenAngle)
end)

-- Текст на экране у замороженного
hook.Add("HUDPaint", "zcity_adminfreezer_hud", function()
    if not frozenAngle then return end
    draw.SimpleText(
        "Вы заморожены администратором",
        "DermaLarge",
        ScrW() / 2, ScrH() - 80,
        Color(100, 180, 255, 220),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end)

-- ─── HUD-подсказка для админа с физганом, направленным на игрока ─────────────
local ALLOWED_GROUPS = {
    dmoderator  = true,
    moderator   = true,
    dadmin      = true,
    admin       = true,
    superadmin  = true,
    dsuperadmin = true,
}

hook.Add("HUDPaint", "zcity_adminfreezer_hint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not ALLOWED_GROUPS[ply:GetUserGroup()] and not ply:IsSuperAdmin() then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_physgun" then return end
    if not ply:KeyDown(IN_ATTACK) then return end -- удерживается ЛКМ физгана

    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return end
    if ply:GetPos():DistToSqr(tr.Entity:GetPos()) > 4096 * 4096 then return end
    local target = tr.Entity
    local frozen = target:GetNWBool("admin_frozen", false)
    local txt = frozen
        and ("ПКМ — разморозить " .. target:Nick())
        or  ("ПКМ — заморозить " .. target:Nick())
    local col = frozen and Color(100, 180, 255, 255) or Color(255, 220, 80, 255)
    draw.SimpleTextOutlined(txt, "DermaDefault",
        ScrW() / 2, ScrH() / 2 + 30,
        col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
        1, Color(0, 0, 0, 200))
end)

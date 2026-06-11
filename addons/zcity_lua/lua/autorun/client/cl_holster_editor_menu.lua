-- Меню для редактирования позиций оружия на поясе с 3D превью
-- Автор: Kiro AI Assistant

if SERVER then return end

local editMode = false
local HolsterOffsetsCache = nil

local function GetHolsterOffsets()
	if HolsterOffsetsCache then return HolsterOffsetsCache end
	
	if file.Exists("holster_offsets.txt", "DATA") then
		local content = file.Read("holster_offsets.txt", "DATA")
		if content then
			HolsterOffsetsCache = util.JSONToTable(content) or {}
			return HolsterOffsetsCache
		end
	end
	
	HolsterOffsetsCache = {}
	return HolsterOffsetsCache
end
local currentWeapon = nil
local tempPos = Vector(0, 0, 0)
local tempAng = Angle(0, 0, 0)
local tempClip = 0
local previewModel = nil
local previewWeapon = nil
local camAngle = Angle(0, 0, 0)
local camDistance = 80
local mouseDown = false
local lastMouseX, lastMouseY = 0, 0

-- Создаём превью модель
local function CreatePreviewModel()
	if IsValid(previewModel) then
		previewModel:Remove()
	end
	if IsValid(previewWeapon) then
		previewWeapon:Remove()
	end
	
	-- Создаём модель игрока
	previewModel = ClientsideModel("models/player/group01/male_02.mdl", RENDERGROUP_OPAQUE)
	if IsValid(previewModel) then
		previewModel:SetNoDraw(true)
		previewModel:SetPos(Vector(0, 0, 0))
		previewModel:SetAngles(Angle(0, 0, 0))
		
		-- Устанавливаем анимацию
		local seq = previewModel:LookupSequence("idle_all_01")
		if seq > 0 then
			previewModel:SetSequence(seq)
			previewModel:SetPlaybackRate(1)
		end
		
		-- Обновляем анимацию
		previewModel:SetCycle(0)
		previewModel:InvalidateBoneCache()
		previewModel:SetupBones()
	end
	
	-- Создаём модель оружия
	if IsValid(currentWeapon) then
		local wepModel = currentWeapon.WorldModelFake or currentWeapon.WorldModel
		previewWeapon = ClientsideModel(wepModel, RENDERGROUP_OPAQUE)
		if IsValid(previewWeapon) then
			previewWeapon:SetNoDraw(true)
			
			-- Копируем настройки оружия
			if currentWeapon.WorldModelFake and currentWeapon.FakeScale then
				previewWeapon:SetModelScale(currentWeapon.FakeScale, 0)
			end
			
			if currentWeapon.FakeBodyGroups then
				previewWeapon:SetBodyGroups(currentWeapon.FakeBodyGroups)
			end
			
			-- Копируем скин и бодигруппы если есть
			for i = 0, 6 do
				if currentWeapon.GetBodygroup then
					local bg = currentWeapon:GetBodygroup(i)
					if bg then
						previewWeapon:SetBodygroup(i, bg)
					end
				end
			end
			
			if currentWeapon.GetSkin then
				local skin = currentWeapon:GetSkin()
				if skin then
					previewWeapon:SetSkin(skin)
				end
			end
		end
	end
end

-- Обновляем позицию оружия на превью
local function UpdateWeaponPosition()
	if not IsValid(previewModel) or not IsValid(previewWeapon) or not IsValid(currentWeapon) then return end
	
	local bone = currentWeapon.holsteredBone or "ValveBiped.Bip01_Pelvis"
	local boneId = previewModel:LookupBone(bone)
	if not boneId then return end
	
	local matrix = previewModel:GetBoneMatrix(boneId)
	if not matrix then return end
	
	local basePos, baseAng = matrix:GetTranslation(), matrix:GetAngles()
	
	-- Применяем локальные координаты
	local desiredPos, desiredAng = LocalToWorld(tempPos, tempAng, basePos, baseAng)
	
	currentWeapon.holsterAnchorPos = desiredPos
	currentWeapon.holsterAnchorAng = desiredAng
	
	-- Применяем WorldPos и WorldAng
	local worldPos = currentWeapon.WorldPos or Vector(0, 0, 0)
	local worldAng = currentWeapon.WorldAng or Angle(0, 0, 0)
	local newPos, newAng = LocalToWorld(worldPos, worldAng, desiredPos, desiredAng)
	
	-- Применяем FakePos и FakeAng если есть
	if currentWeapon.WorldModelFake and (currentWeapon.FakePos or currentWeapon.FakeAng) then
		local fakePos = currentWeapon.FakePos or Vector(0, 0, 0)
		local fakeAng = currentWeapon.FakeAng or Angle(0, 0, 0)
		newPos, newAng = LocalToWorld(fakePos, fakeAng, newPos, newAng)
	end
	
	previewWeapon:SetPos(newPos)
	previewWeapon:SetAngles(newAng)
end

-- Создаём меню
local function OpenHolsterEditor()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	-- Проверка на супер-админа
	if not ply:IsSuperAdmin() then
		chat.AddText(Color(255, 100, 100), "[Holster Editor] ", Color(255, 255, 255), "Доступ запрещён! Только для супер-админов.")
		surface.PlaySound("buttons/button10.wav")
		return
	end
	
	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and ishgweapon(wep)) then
		chat.AddText(Color(255, 100, 100), "[Holster Editor] ", Color(255, 255, 255), "Возьмите оружие в руки!")
		return
	end
	
	currentWeapon = wep
	tempPos = Vector(wep.holsteredPos.x, wep.holsteredPos.y, wep.holsteredPos.z)
	tempAng = Angle(wep.holsteredAng.p, wep.holsteredAng.y, wep.holsteredAng.r)
	tempClip = wep.holsteredClip or 0
	editMode = true
	camAngle = Angle(0, 45, 0)
	
	-- Создаём превью модели
	CreatePreviewModel()
	
	local frame = vgui.Create("DFrame")
	frame:SetSize(900, 600)
	frame:Center()
	frame:SetTitle("Редактор позиций оружия - " .. wep:GetClass())
	frame:MakePopup()
	
	-- Левая панель - 3D превью
	local previewPanel = vgui.Create("DPanel", frame)
	previewPanel:SetPos(5, 30)
	previewPanel:SetSize(500, 565)
	previewPanel.Paint = function(self, w, h)
		-- Фон с градиентом
		surface.SetDrawColor(40, 45, 50)
		surface.DrawRect(0, 0, w, h)
		
		-- Рисуем сетку
		surface.SetDrawColor(60, 65, 70)
		local gridSize = 20
		for i = 0, w, gridSize do
			surface.DrawLine(i, 0, i, h)
		end
		for i = 0, h, gridSize do
			surface.DrawLine(0, i, w, i)
		end
		
		-- Рамка
		draw.RoundedBox(4, 0, 0, w, h, Color(80, 85, 90))
		draw.RoundedBox(4, 2, 2, w - 4, h - 4, Color(40, 45, 50))
		
		-- Рисуем 3D модель
		if IsValid(previewModel) and IsValid(previewWeapon) then
			local x, y = self:LocalToScreen(0, 0)
			
			-- Обновляем позицию оружия
			UpdateWeaponPosition()
			
			-- Настраиваем камеру
			local ang = Angle(camAngle.p, camAngle.y, camAngle.r)
			local pos = Vector(0, 0, 40) + ang:Forward() * -camDistance + ang:Right() * 0 + ang:Up() * 0
			
			cam.Start3D(pos, ang, 70, x, y, w, h, 5, 4000)
				cam.IgnoreZ(true)
				
				-- Включаем освещение
				render.SuppressEngineLighting(true)
				render.SetLightingOrigin(Vector(0, 0, 40))
				render.ResetModelLighting(0.5, 0.5, 0.5)
				render.SetColorModulation(1, 1, 1)
				render.SetBlend(1)
				
				-- Настраиваем освещение со всех сторон
				local lightColor = Vector(1, 1, 1)
				render.SetModelLighting(BOX_TOP, lightColor.x, lightColor.y, lightColor.z)
				render.SetModelLighting(BOX_FRONT, lightColor.x * 0.8, lightColor.y * 0.8, lightColor.z * 0.8)
				render.SetModelLighting(BOX_RIGHT, lightColor.x * 0.6, lightColor.y * 0.6, lightColor.z * 0.6)
				render.SetModelLighting(BOX_LEFT, lightColor.x * 0.6, lightColor.y * 0.6, lightColor.z * 0.6)
				render.SetModelLighting(BOX_BACK, lightColor.x * 0.4, lightColor.y * 0.4, lightColor.z * 0.4)
				render.SetModelLighting(BOX_BOTTOM, lightColor.x * 0.3, lightColor.y * 0.3, lightColor.z * 0.3)
				
				-- Рисуем модель игрока
				previewModel:SetupBones()
				previewModel:DrawModel()
				
				-- Рисуем оружие
				if tempClip > 0 and currentWeapon.holsterAnchorPos then
					local clipNormal = currentWeapon.holsterAnchorAng:Forward() * -1
					local clipPos = currentWeapon.holsterAnchorPos + currentWeapon.holsterAnchorAng:Forward() * tempClip
					local oldClip = render.EnableClipping(true)
					render.PushCustomClipPlane(clipNormal, clipNormal:Dot(clipPos))
					previewWeapon:SetupBones()
					previewWeapon:DrawModel()
					render.PopCustomClipPlane()
					render.EnableClipping(oldClip)
				else
					previewWeapon:SetupBones()
					previewWeapon:DrawModel()
				end
				
				-- Восстанавливаем освещение
				render.SuppressEngineLighting(false)
				
				cam.IgnoreZ(false)
			cam.End3D()
		else
			-- Если модели не загружены
			draw.SimpleText("Загрузка моделей...", "DermaLarge", w/2, h/2, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		
		-- Инструкция с фоном
		local instrY = h - 50
		surface.SetDrawColor(0, 0, 0, 180)
		surface.DrawRect(0, instrY, w, 50)
		
		draw.SimpleText("🖱️ ЛКМ + перетаскивание = вращение камеры", "DermaDefault", w/2, h - 40, Color(220, 220, 220), TEXT_ALIGN_CENTER)
		draw.SimpleText("🖱️ Колесо мыши = приближение/отдаление", "DermaDefault", w/2, h - 25, Color(220, 220, 220), TEXT_ALIGN_CENTER)
		draw.SimpleText("🎚️ Используйте ползунки справа →", "DermaDefault", w/2, h - 10, Color(100, 255, 100), TEXT_ALIGN_CENTER)
	end
	
	-- Обработка мыши для вращения камеры
	previewPanel.OnMousePressed = function(self, keyCode)
		if keyCode == MOUSE_LEFT then
			mouseDown = true
			lastMouseX, lastMouseY = gui.MouseX(), gui.MouseY()
		end
	end
	
	previewPanel.OnMouseReleased = function(self, keyCode)
		if keyCode == MOUSE_LEFT then
			mouseDown = false
		end
	end
	
	previewPanel.Think = function(self)
		if mouseDown and self:IsHovered() then
			local mx, my = gui.MouseX(), gui.MouseY()
			local dx = mx - lastMouseX
			local dy = my - lastMouseY
			
			camAngle.y = camAngle.y + dx * 0.5
			camAngle.p = math.Clamp(camAngle.p + dy * 0.5, -89, 89)
			
			lastMouseX, lastMouseY = mx, my
		end
	end
	
	previewPanel.OnMouseWheeled = function(self, delta)
		camDistance = math.Clamp(camDistance - delta * 5, 40, 200)
	end
	
	-- Правая панель - контролы
	local controlPanel = vgui.Create("DPanel", frame)
	controlPanel:SetPos(510, 30)
	controlPanel:SetSize(385, 565)
	controlPanel.Paint = function(self, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40))
	end
	
	local scroll = vgui.Create("DScrollPanel", controlPanel)
	scroll:Dock(FILL)
	
	local y = 10
	
	-- Заголовок
	local title = vgui.Create("DLabel", scroll)
	title:SetPos(10, y)
	title:SetSize(365, 20)
	title:SetText("Настройки позиции оружия")
	title:SetFont("DermaLarge")
	title:SetTextColor(Color(255, 255, 255))
	y = y + 30
	
	-- Выбор кости
	local labelBone = vgui.Create("DLabel", scroll)
	labelBone:SetPos(10, y)
	labelBone:SetText("Кость привязки:")
	labelBone:SetTextColor(Color(200, 200, 200))
	labelBone:SizeToContents()
	
	local comboBone = vgui.Create("DComboBox", scroll)
	comboBone:SetPos(150, y - 5)
	comboBone:SetSize(225, 25)
	comboBone:SetValue(currentWeapon.holsteredBone or "ValveBiped.Bip01_Pelvis")
	comboBone:AddChoice("Таз (Pelvis)", "ValveBiped.Bip01_Pelvis")
	comboBone:AddChoice("Правое бедро (R Thigh)", "ValveBiped.Bip01_R_Thigh")
	comboBone:AddChoice("Левое бедро (L Thigh)", "ValveBiped.Bip01_L_Thigh")
	comboBone:AddChoice("Спина (Spine)", "ValveBiped.Bip01_Spine")
	comboBone:AddChoice("Грудь (Spine2)", "ValveBiped.Bip01_Spine2")
	comboBone.OnSelect = function(self, index, text, data)
		currentWeapon.holsteredBone = data
	end
	
	y = y + 30
	
	-- Выбор анимации для теста
	local labelAnim = vgui.Create("DLabel", scroll)
	labelAnim:SetPos(10, y)
	labelAnim:SetText("Тест анимации:")
	labelAnim:SetTextColor(Color(200, 200, 200))
	labelAnim:SizeToContents()
	
	local comboAnim = vgui.Create("DComboBox", scroll)
	comboAnim:SetPos(150, y - 5)
	comboAnim:SetSize(225, 25)
	comboAnim:SetValue("Бездействие (Idle)")
	comboAnim:AddChoice("Бездействие (Idle)", "idle_all_01")
	comboAnim:AddChoice("Бег (Run)", "run_all_01")
	comboAnim:AddChoice("Ходьба (Walk)", "walk_all_01")
	comboAnim:AddChoice("Присед (Crouch)", "crouch_idle_all_01")
	comboAnim.OnSelect = function(self, index, text, data)
		if IsValid(previewModel) then
			local seq = previewModel:LookupSequence(data)
			if seq > 0 then
				previewModel:SetSequence(seq)
				previewModel:SetCycle(sliderCycle and sliderCycle:GetValue() or 0)
				previewModel:SetPoseParameter("move_x", 1)
				previewModel:InvalidateBoneCache()
			end
		end
	end
	
	y = y + 30
	
	-- Ползунок кадра анимации (Заморозка)
	local labelCycle = vgui.Create("DLabel", scroll)
	labelCycle:SetPos(10, y)
	labelCycle:SetText("Заморозка кадра:")
	labelCycle:SetTextColor(Color(200, 200, 200))
	labelCycle:SizeToContents()
	
	sliderCycle = vgui.Create("DNumSlider", scroll)
	sliderCycle:SetPos(10, y + 20)
	sliderCycle:SetSize(365, 30)
	sliderCycle:SetMin(0)
	sliderCycle:SetMax(1)
	sliderCycle:SetDecimals(2)
	sliderCycle:SetValue(0)
	sliderCycle:SetDark(true)
	sliderCycle.OnValueChanged = function(self, value)
		if IsValid(previewModel) then
			previewModel:SetCycle(value)
			previewModel:SetPoseParameter("move_x", 1)
			previewModel:InvalidateBoneCache()
		end
	end
	
	y = y + 60
	
	-- Разделитель
	local div3 = vgui.Create("DPanel", scroll)
	div3:SetPos(10, y)
	div3:SetSize(365, 2)
	div3.Paint = function(self, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100)) end
	y = y + 10
	
	-- Позиция X
	local labelX = vgui.Create("DLabel", scroll)
	labelX:SetPos(10, y)
	labelX:SetText("Позиция X (вперёд/назад):")
	labelX:SetTextColor(Color(200, 200, 200))
	labelX:SizeToContents()
	
	local sliderX = vgui.Create("DNumSlider", scroll)
	sliderX:SetPos(10, y + 20)
	sliderX:SetSize(365, 30)
	sliderX:SetMin(-20)
	sliderX:SetMax(20)
	sliderX:SetDecimals(2)
	sliderX:SetValue(tempPos.x)
	sliderX:SetDark(true)
	sliderX.OnValueChanged = function(self, value)
		tempPos.x = value
	end
	
	y = y + 60
	
	-- Позиция Y
	local labelY = vgui.Create("DLabel", scroll)
	labelY:SetPos(10, y)
	labelY:SetText("Позиция Y (влево/вправо):")
	labelY:SetTextColor(Color(200, 200, 200))
	labelY:SizeToContents()
	
	local sliderY = vgui.Create("DNumSlider", scroll)
	sliderY:SetPos(10, y + 20)
	sliderY:SetSize(365, 30)
	sliderY:SetMin(-20)
	sliderY:SetMax(20)
	sliderY:SetDecimals(2)
	sliderY:SetValue(tempPos.y)
	sliderY:SetDark(true)
	sliderY.OnValueChanged = function(self, value)
		tempPos.y = value
	end
	
	y = y + 60
	
	-- Позиция Z
	local labelZ = vgui.Create("DLabel", scroll)
	labelZ:SetPos(10, y)
	labelZ:SetText("Позиция Z (вверх/вниз):")
	labelZ:SetTextColor(Color(200, 200, 200))
	labelZ:SizeToContents()
	
	local sliderZ = vgui.Create("DNumSlider", scroll)
	sliderZ:SetPos(10, y + 20)
	sliderZ:SetSize(365, 30)
	sliderZ:SetMin(-20)
	sliderZ:SetMax(20)
	sliderZ:SetDecimals(2)
	sliderZ:SetValue(tempPos.z)
	sliderZ:SetDark(true)
	sliderZ.OnValueChanged = function(self, value)
		tempPos.z = value
	end
	
	y = y + 70
	
	-- Ползунок среза оружия (Clip)
	local labelClip = vgui.Create("DLabel", scroll)
	labelClip:SetPos(10, y)
	labelClip:SetText("Скрытие ствола (Clipping):")
	labelClip:SetTextColor(Color(200, 200, 200))
	labelClip:SizeToContents()
	
	local sliderClip = vgui.Create("DNumSlider", scroll)
	sliderClip:SetPos(10, y + 20)
	sliderClip:SetSize(365, 30)
	sliderClip:SetMin(0)
	sliderClip:SetMax(50)
	sliderClip:SetDecimals(1)
	sliderClip:SetValue(tempClip)
	sliderClip:SetDark(true)
	sliderClip.OnValueChanged = function(self, value)
		tempClip = value
	end
	
	y = y + 60
	
	-- Разделитель
	local divider1 = vgui.Create("DPanel", scroll)
	divider1:SetPos(10, y)
	divider1:SetSize(365, 2)
	divider1.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
	end
	
	y = y + 10
	
	-- Угол Pitch
	local labelP = vgui.Create("DLabel", scroll)
	labelP:SetPos(10, y)
	labelP:SetText("Угол Pitch (наклон):")
	labelP:SetTextColor(Color(200, 200, 200))
	labelP:SizeToContents()
	
	local sliderP = vgui.Create("DNumSlider", scroll)
	sliderP:SetPos(10, y + 20)
	sliderP:SetSize(365, 30)
	sliderP:SetMin(-180)
	sliderP:SetMax(180)
	sliderP:SetDecimals(1)
	sliderP:SetValue(tempAng.p)
	sliderP:SetDark(true)
	sliderP.OnValueChanged = function(self, value)
		tempAng.p = value
	end
	
	y = y + 60
	
	-- Угол Yaw
	local labelYaw = vgui.Create("DLabel", scroll)
	labelYaw:SetPos(10, y)
	labelYaw:SetText("Угол Yaw (поворот):")
	labelYaw:SetTextColor(Color(200, 200, 200))
	labelYaw:SizeToContents()
	
	local sliderYaw = vgui.Create("DNumSlider", scroll)
	sliderYaw:SetPos(10, y + 20)
	sliderYaw:SetSize(365, 30)
	sliderYaw:SetMin(-180)
	sliderYaw:SetMax(180)
	sliderYaw:SetDecimals(1)
	sliderYaw:SetValue(tempAng.y)
	sliderYaw:SetDark(true)
	sliderYaw.OnValueChanged = function(self, value)
		tempAng.y = value
	end
	
	y = y + 60
	
	-- Угол Roll
	local labelR = vgui.Create("DLabel", scroll)
	labelR:SetPos(10, y)
	labelR:SetText("Угол Roll (крен):")
	labelR:SetTextColor(Color(200, 200, 200))
	labelR:SizeToContents()
	
	local sliderR = vgui.Create("DNumSlider", scroll)
	sliderR:SetPos(10, y + 20)
	sliderR:SetSize(365, 30)
	sliderR:SetMin(-180)
	sliderR:SetMax(180)
	sliderR:SetDecimals(1)
	sliderR:SetValue(tempAng.r)
	sliderR:SetDark(true)
	sliderR.OnValueChanged = function(self, value)
		tempAng.r = value
	end
	
	y = y + 70
	
	-- Разделитель
	local divider2 = vgui.Create("DPanel", scroll)
	divider2:SetPos(10, y)
	divider2:SetSize(365, 2)
	divider2.Paint = function(self, w, h)
		draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
	end
	
	y = y + 10
	
	-- Информация
	local infoLabel = vgui.Create("DLabel", scroll)
	infoLabel:SetPos(10, y)
	infoLabel:SetSize(365, 60)
	infoLabel:SetText("Кость: " .. (currentWeapon.holsteredBone or "ValveBiped.Bip01_Pelvis") .. "\n\nДвигайте ползунки и смотрите изменения\nна 3D модели слева в реальном времени!")
	infoLabel:SetTextColor(Color(150, 150, 150))
	infoLabel:SetWrap(true)
	infoLabel:SetAutoStretchVertical(true)
	
	y = y + 80
	
	-- Кнопки
	local btnPanel = vgui.Create("DPanel", scroll)
	btnPanel:SetPos(10, y)
	btnPanel:SetSize(365, 80)
	btnPanel.Paint = nil
	
	-- Кнопка сохранения
	local btnSave = vgui.Create("DButton", btnPanel)
	btnSave:SetPos(0, 0)
	btnSave:SetSize(365, 35)
	btnSave:SetText("💾 Сохранить настройки")
	btnSave:SetFont("DermaLarge")
	btnSave.DoClick = function()
		local wepClass = currentWeapon:GetClass()
		local bone = currentWeapon.holsteredBone or "ValveBiped.Bip01_Pelvis"
		
		-- Применяем изменения к текущему оружию в руках
		currentWeapon.holsteredBone = bone
		currentWeapon.holsteredPos = Vector(tempPos.x, tempPos.y, tempPos.z)
		currentWeapon.holsteredAng = Angle(tempAng.p, tempAng.y, tempAng.r)
		currentWeapon.holsteredClip = tempClip
		currentWeapon.shouldntDrawHolstered = false
		
		-- Применяем изменения к классу оружия (чтобы применялось для всех таких пушек)
		local wepTable = weapons.GetStored(wepClass)
		if wepTable then
			wepTable.holsteredBone = bone
			wepTable.holsteredPos = Vector(tempPos.x, tempPos.y, tempPos.z)
			wepTable.holsteredAng = Angle(tempAng.p, tempAng.y, tempAng.r)
			wepTable.holsteredClip = tempClip
			wepTable.shouldntDrawHolstered = false
		end
		
		-- Сохраняем в файл, чтобы загружалось автоматически при перезаходе
		local savedData = GetHolsterOffsets()
		savedData[wepClass] = {
			bone = bone,
			pos = {x = tempPos.x, y = tempPos.y, z = tempPos.z},
			ang = {p = tempAng.p, y = tempAng.y, r = tempAng.r},
			clip = tempClip
		}
		
		file.Write("holster_offsets.txt", util.TableToJSON(savedData, true))
		HolsterOffsetsCache = savedData
		
		-- Выводим код для копирования (на всякий случай)
		local code = string.format([[
SWEP.holsteredBone = "%s"
SWEP.holsteredPos = Vector(%.2f, %.2f, %.2f)
SWEP.holsteredAng = Angle(%.1f, %.1f, %.1f)
SWEP.holsteredClip = %.1f
SWEP.shouldntDrawHolstered = false
]], 
			bone, tempPos.x, tempPos.y, tempPos.z, tempAng.p, tempAng.y, tempAng.r, tempClip
		)
		SetClipboardText(code)
		
		chat.AddText(Color(100, 255, 100), "[Holster Editor] ", Color(255, 255, 255), "Настройки автоматически применены и сохранены!")
		chat.AddText(Color(255, 200, 100), "Код также скопирован в буфер обмена на всякий случай.")
		
		print("=== СОХРАНЕНЫ НАСТРОЙКИ ДЛЯ " .. wepClass .. " ===")
		print(code)
		print("========================================")
		
		frame:Close()
		editMode = false
		
		if IsValid(previewModel) then previewModel:Remove() end
		if IsValid(previewWeapon) then previewWeapon:Remove() end
	end
	
	-- Кнопка отмены
	local btnCancel = vgui.Create("DButton", btnPanel)
	btnCancel:SetPos(0, 40)
	btnCancel:SetSize(365, 35)
	btnCancel:SetText("❌ Отмена")
	btnCancel.DoClick = function()
		frame:Close()
		editMode = false
		
		if IsValid(previewModel) then previewModel:Remove() end
		if IsValid(previewWeapon) then previewWeapon:Remove() end
	end
	
	-- При закрытии окна
	frame.OnClose = function()
		editMode = false
		if IsValid(previewModel) then previewModel:Remove() end
		if IsValid(previewWeapon) then previewWeapon:Remove() end
	end
end

-- Команда для открытия меню
concommand.Add("hg_holster_menu", OpenHolsterEditor)

-- Добавляем в меню спавна (если есть)
hook.Add("PopulateToolMenu", "HolsterEditorMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "User", "HolsterEditor", "Holster Editor", "", "", function(panel)
		panel:ClearControls()
		
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:IsSuperAdmin() then
			panel:Help("⛔ Доступ запрещён!")
			panel:Help("Только для супер-админов")
			return
		end
		
		panel:Help("Редактор позиций оружия на поясе")
		panel:Help("Возьмите оружие в руки и нажмите кнопку ниже")
		
		panel:Button("Открыть редактор", "hg_holster_menu")
		
		panel:Help("")
		panel:Help("Или используйте консольную команду:")
		panel:Help("hg_holster_menu")
	end)
end)

-- Загрузка сохраненных позиций из файла
local function LoadHolsterOffsets()
	local savedData = GetHolsterOffsets()
	for class, data in pairs(savedData) do
		local wepTable = weapons.GetStored(class)
		if wepTable then
			wepTable.holsteredBone = data.bone
			wepTable.holsteredPos = Vector(data.pos.x, data.pos.y, data.pos.z)
			wepTable.holsteredAng = Angle(data.ang.p, data.ang.y, data.ang.r)
			wepTable.holsteredClip = data.clip or 0
			wepTable.shouldntDrawHolstered = false
		end
	end
end

-- Применяем сохраненные настройки после инициализации энтити
hook.Add("InitPostEntity", "LoadHolsterOffsets", LoadHolsterOffsets)

-- Дополнительно проверяем при создании энтити (на случай если оружие заспавнилось до инициализации)
hook.Add("OnEntityCreated", "ApplyHolsterOffsets", function(ent)
	if ent:IsWeapon() then
		timer.Simple(0.1, function()
			if IsValid(ent) then
				local class = ent:GetClass()
				local savedData = GetHolsterOffsets()
				local data = savedData[class]
				if data then
					ent.holsteredBone = data.bone
					ent.holsteredPos = Vector(data.pos.x, data.pos.y, data.pos.z)
					ent.holsteredAng = Angle(data.ang.p, data.ang.y, data.ang.r)
					ent.holsteredClip = data.clip or 0
					ent.shouldntDrawHolstered = false
				end
			end
		end)
	end
end)

-- Сообщение при загрузке
hook.Add("Initialize", "HolsterEditorInit", function()
	timer.Simple(5, function()
		local ply = LocalPlayer()
		if IsValid(ply) and ply:IsSuperAdmin() then
			chat.AddText(Color(100, 255, 100), "[Holster Editor] ", Color(255, 255, 255), "Загружен! Команда: ", Color(100, 200, 255), "hg_holster_menu")
		end
		LoadHolsterOffsets() -- Загружаем настройки если аддон был перезагружен во время игры
	end)
end)

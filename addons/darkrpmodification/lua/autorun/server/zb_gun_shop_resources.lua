-- Принудительная загрузка кастомных материалов автомата с оружием клиентам.
-- Без этого новые игроки увидят дефолтную текстуру (или фиолетовый клетчатый
-- "missing material") вместо нашей AK-47 текстуры.

if not SERVER then return end

resource.AddFile("materials/zb_weapons/dispenser_ak47.vmt")
resource.AddFile("materials/zb_weapons/dispenser_ak47.vtf")

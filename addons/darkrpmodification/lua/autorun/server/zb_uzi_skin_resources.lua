-- Принудительная загрузка кастомного скина IMI Uzi клиентам.
-- Без resource.AddFile новые игроки увидят дефолтную текстуру вместо скина.

if not SERVER then return end

resource.AddFile("materials/models/weapons/tfa_ins2/imi_uzi/uzidiffuse.vmt")
resource.AddFile("materials/models/weapons/tfa_ins2/imi_uzi/uzidiffuse.vtf")

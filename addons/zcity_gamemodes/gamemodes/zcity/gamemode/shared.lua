--[[---------------------------------------------------------------------------
ZCity gamemode (derived от DarkRP)
-----------------------------------------------------------------------------
Тонкая обёртка вокруг DarkRP. Всё что отличает ZCity от стокового DarkRP —
лежит в addons/darkrpmodification/lua/. Этот файл нужен только чтобы:
  • в Steam-списках сервер показывался как "ZCity"
  • category отображалась "rp" (как у DarkRP)
  • вся логика DarkRP наследовалась через DeriveGamemode
---------------------------------------------------------------------------]]

DeriveGamemode("darkrp")

GM.Name     = "ZCity"
GM.Author   = "uzelezz, sadsalat, Mr. Point, Zac90, Deka, Mannytko"
GM.Email    = "N/A"
GM.Website  = "N/A"

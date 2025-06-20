if SERVER then
    AddCSLuaFile("autorun/client/cl_chaos_raid_hud.lua")
else
    include("autorun/client/cl_chaos_raid_hud.lua")
end

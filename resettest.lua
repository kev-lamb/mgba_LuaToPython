console:log("going to load")
local i = emu:loadStateFile("/Users/kevlamb/penncode/cis400/luascripts/battle_anim_off.ss0",2)
if i then
    console:log("true")
else
    console:log("false")
end
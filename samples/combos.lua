local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "audio player")
local win = igwin:GLFW(800,400, "audio devices")
local ig = win.ig
local rt = require"rtaudio_ffi"

local auinf = rt.GetAllInfo()
local ocombos = auinf.out_combos(ig)
local icombos = auinf.input_combos(ig)

local oAPI,odevice = auinf.first_out()
local function set_odev(API,dev)
    oAPI, odevice = API,dev
    print(oAPI,odevice)
end
local iAPI,idevice = auinf.first_input()
local function set_idev(API,dev)
    iAPI, idevice = API,dev
    print(iAPI,idevice)
end
function win:draw(ig)

    if ig.Button("set out") then
        ocombos.OpenPopup(oAPI, odevice)
    end
    ocombos.DrawPopup(set_odev)
    ig.Separator()
    if ig.Button("set in") then
        icombos.OpenPopup(iAPI, idevice)
    end
    icombos.DrawPopup(set_idev)
    
end

win:start()
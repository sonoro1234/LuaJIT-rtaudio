local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "audio sine")
local win = igwin:GLFW(800,400, "audio sine",{vsync=2})
local ig = win.ig
local igLOG = ig.Log()
local function printLOG(...)
	igLOG:Add(table.concat({...},", ").."\n")
end
local ffi = require"ffi"
local rt = require"rtaudio_ffi"

-------------------------------------
local function AudioInit(udatacode)
	local ffi = require"ffi"
	local sin = math.sin
	ffi.cdef(udatacode)
	return function(out, inp, nFrames,stream_time,status,ud)
		local buf = ffi.cast("float*",out)
		local udc = ffi.cast("MyUdata*",ud)
		for i=0,(2*nFrames)-2,2 do
			local sample = sin(udc.Phase)*0.01
			udc.Phase = udc.Phase + udc.dPhase
			buf[i] = sample
			buf[i+1] = sample
		end
		return 0
	end
end

local udatacode = [[typedef struct {double Phase;double dPhase;} MyUdata]]
ffi.cdef(udatacode)
local ud = ffi.new"MyUdata"
local sampleHz = 44100
local function setFreq(ff)
    ud.dPhase = 2 * math.pi * ff / sampleHz
end

local thecallback = rt.MakeAudioCallback(AudioInit,udatacode)

local auinf = rt.GetAllInfo()
local ocombos = auinf.out_combos(ig)
local oAPI,odevice = auinf.first_out()
local dac
local SRcombo, BScombo
local function set_odev(API,dev)
	sampleHz = tonumber(SRcombo:get_name())
	local wantedBsiz = tonumber(BScombo:get_name())
	if API == oAPI and dev == odevice then
		local keepdac = true
	end
    oAPI, odevice = API,dev
    printLOG(oAPI,odevice, sampleHz, wantedBsiz)
	--if dac close it
	if dac then 
		dac:stop_stream(); 
		dac:close_stream(); 
		if not keepdac then dac = nil end
	end
	if odevice == 0 then return end --bad device
	if not keepdac then
		dac = rt.rtaudio(rt.compiled_api_by_name(oAPI))
		dac:show_warnings(true)
		if dac:error_type()~=rt.ERROR_NONE then printLOG(ffi.string(dac:error())) end
	end
	local outpar = ffi.new("rtaudio_stream_parameters_t[1]",{{odevice, 2, 0}})
	local bufferFrames = ffi.new("unsigned int[1]", wantedBsiz)
	local ret = dac:open_stream(outpar, nil, rt.FORMAT_FLOAT32, sampleHz, bufferFrames, thecallback, ud)
	if ret ~= rt.ERROR_NONE then
       local err = dac:error()
       printLOG(err~=nil and ffi.string(err) or "unknown error opening device")
    end
	if bufferFrames[0]~=wantedBsiz then printLOG("WARNING: bufferSize is: %d",bufferFrames[0]) end
	if dac:start_stream()~= rt.ERROR_NONE then
		printLOG("error in start_stream",ffi.string(dac:error()))
	end
end

local function scandevices()
	auinf = rt.GetAllInfo()
	ocombos = auinf.out_combos(ig)
	oAPI,odevice = auinf.first_out()
	if dac then dac:stop_stream(); dac:close_stream(); dac = nil end
end

SRcombo = ig.LuaCombo("SampleRate##in",{"44100","48000"})

local bufsizes = {}
for i= 6,11 do table.insert(bufsizes, tostring(2^i)) end
BScombo = ig.LuaCombo("buffer size##in",bufsizes)
BScombo:set_name"512"

local counter = 0
function win:draw(ig)

	igLOG:Draw("log window")
	if ig.Button"scan devices" then
		scandevices()
	end
    if ig.Button("set out device") then
        ocombos.OpenPopup(oAPI, odevice)
    end
    ocombos.DrawPopup(set_odev)
	ig.SameLine()
	ig.Text("%s, %s %s",oAPI, tostring(odevice), auinf.dev_name_byID(oAPI,odevice))
	
	SRcombo:draw()
	BScombo:draw()
	if ig.Button"reset device" then
		set_odev(oAPI, odevice)
	end
	
    if counter==10 then
		setFreq(math.random()*500 + 100)
		counter = 0
	else counter = counter + 1 end
end

win:start()
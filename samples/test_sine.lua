local igwin = require"imgui.window"
--local win = igwin:SDL(800,400, "audio sine")
local win = igwin:GLFW(800,400, "audio sine",{vsync=2})
local ig = win.ig
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
local function set_odev(API,dev)
    oAPI, odevice = API,dev
    print(oAPI,odevice)
	--if dac close it
	if dac then dac:stop_stream(); dac:close_stream(); dac = nil end
	if odevice == 0 then return end --bad device
	dac = rt.rtaudio(rt.compiled_api_by_name(oAPI))
	local outpar = ffi.new("rtaudio_stream_parameters_t[1]",{{odevice, 2, 0}})
	local bufferFrames = ffi.new("unsigned int[1]", 512)
	local ret = dac:open_stream(outpar, nil, rt.FORMAT_FLOAT32, sampleHz, bufferFrames, thecallback, ud)
	if ret < 0 then
       local err = dac:error()
       print(err~=nil and ffi.string(err) or "unknown error opening device")
    end
	dac:start_stream()
end

local function scandevices()
	auinf = rt.GetAllInfo()
	ocombos = auinf.out_combos(ig)
	oAPI,odevice = auinf.first_out()
	if dac then dac:stop_stream(); dac:close_stream(); dac = nil end
end

local counter = 0
function win:draw(ig)
	if ig.Button"scan" then
		scandevices()
	end
    if ig.Button("set out") then
        ocombos.OpenPopup(oAPI, odevice)
    end
    ocombos.DrawPopup(set_odev)
    if counter==10 then
		setFreq(math.random()*500 + 100)
		counter = 0
	else counter = counter + 1 end
end

win:start()
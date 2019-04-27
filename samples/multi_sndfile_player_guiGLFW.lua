

local ffi = require 'ffi'
--https://github.com/sonoro1234/LuaJIT-libsndfile
local sndf = require"sndfile_ffi"

local rt = require 'rtaudio_ffi'
local AudioPlayer = require"rtAudioPlayer"
--to show pointer values
ffi.cdef[[int snprintf ( char * s, size_t n, const char * format, ... );
int sprintf ( char * str, const char * format, ... );
]]
--------------------------will run in audio thread after playing files
local delaycdef = [[typedef struct delay{double feedback[1];double delay[1];double maxdelay;} delay]]
ffi.cdef(delaycdef)
local fxdata = ffi.new("delay",{ffi.new("double[1]",0.0),ffi.new("double[1]",1),2})

local function delayfunc(data,code,typebuffer,nchannels,samplerate)
    ffi.cdef(code)
    data = ffi.cast("delay*",data)
    local index = 0
    local lenb = math.floor(samplerate*nchannels*data.maxdelay)
    local buffer = ffi.new(typebuffer.."[?]",lenb)

    return function(streamf,lenf,streamTime)
        local lenbe = math.floor(samplerate*nchannels*data.delay[0])
        local j
        for i=0,(lenf*nchannels)-1 do
            j = index + i
            if j > lenbe-1 then j = j - lenbe end
            streamf[i] = streamf[i] + buffer[j]
            buffer[j] = streamf[i] *data.feedback[0]
        end
        index = index + lenf*nchannels
        if index > lenbe-1 then index = index - lenbe end
    end
end

local function ffi_string(cd)
    if not cd then
        return nil
    else
        return ffi.string(cd)
    end
end
------------------------------------------------------------------------
-----------------------main--------------------------------------


local filename = "african_roomS.wav";
--local filename = "arugh.wav" --"sample.wav";



local apis = rt.compiled_api()
local api, dac, device
local numcompiledapis = rt.get_num_compiled_apis()
for i=0,numcompiledapis-1 do
	api = apis[i]
	dac = rt.create(api)
	if rt.device_count(dac) > 0 then --to avoid a dac without devices
		device = rt.get_default_output_device(dac)
		break
	end
end
print("using",ffi.string(rt.api_name(api)),"device",device)
--copy specs from file
local info = sndf.get_info(filename)
local audioplayer,err = AudioPlayer({
    dac = dac,
    device = device,
    freq = info.samplerate, 
    format = rt.FORMAT_FLOAT32,
    channels = info.channels, 
    samples = 1024},
    delayfunc,fxdata,delaycdef)

if not audioplayer then print(err);error"not audioplayer" end


print("---------------opened device",device)
local info = rt.get_device_info(dac,device)
        print("\tprobed",info.probed>0)
        print("\tname",ffi.string(info.name))
        print("\toutput_channels",info.output_channels)
        print("\tinput_channels",info.input_channels)
        print("\tduplex_channels",info.duplex_channels)
        print("\tpreferred_sample_rate",info.preferred_sample_rate)
        print("\tis_default_output",info.is_default_output>0)
        print("\tis_default_input",info.is_default_input>0)
        print("\tnative_formats",info.native_formats)
print("---------------")
----------------------------------------------------

--insert 3 files
--level 0.1, timeoffset 0
if not audioplayer:insert(filename,1,0) then error"failed insert" end
--will not load, diferent channels
local node2 = audioplayer:insert("arughSt.wav",0.1,0.75)
--assert(not node2)
audioplayer:insert(filename,0.7,1.5)

for node in audioplayer:nodes() do
    print("node",node.sf)
end


--audioplayer:record("recording.wav",sndf.SF_FORMAT_WAV+sndf.SF_FORMAT_FLOAT)
print("audioplayer.recordfile",audioplayer.recordfile)

print"--------------------------------------"
--------------------------------------------------

local lj_glfw = require"glfw"
local gllib = require"gl"
gllib.set_loader(lj_glfw)
local gl, glc, glu, glext = gllib.libraries()
local ig = require"imgui.glfw"

lj_glfw.setErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 

--choose implementation
--local ig_impl = ig.ImplGlfwGL3() --multicontext
--local ig_impl = ig.Imgui_Impl_glfw_opengl3() --standard imgui opengl3 example
local ig_impl = ig.Imgui_Impl_glfw_opengl2() --standard imgui opengl2 example

local igio = ig.GetIO()
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags


ig_impl:Init(window, true)


local streamtime = ffi.new("float[1]")


while not window:shouldClose() do

    lj_glfw.pollEvents()
    
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
    
    ig_impl:NewFrame()
        -------audio gui
    if ig.Button("start") then
        audioplayer:start()
    end
    if ig.Button("stop") then
        audioplayer:stop()
    end

    streamtime[0] = audioplayer:get_stream_time()
    --print(streamtime[0], audioplayer:get_stream_time())
    if ig.SliderFloat("time",streamtime,0,15) then
        audioplayer:set_stream_time(streamtime[0])
    end

    ig.SliderScalar("delay",ig.lib.ImGuiDataType_Double,fxdata.delay,ffi.new("double[1]",0),ffi.new("double[1]",fxdata.maxdelay))

    ig.SliderScalar("feedback",ig.lib.ImGuiDataType_Double,fxdata.feedback,ffi.new("double[1]",0),ffi.new("double[1]",1))

    if ig.Button("nodes") then
        print"----------nodes---------------"
        print(audioplayer.root.next[0])
        for node in audioplayer:nodes() do
            print(node,node.next[0],node.level,node.timeoffset)
            print(node.sf,node.sf:samplerate(),node.sf:channels(),node.sf:format())
        end
    end

    if ig.Button("insert") then
        audioplayer:insert(filename,1,streamtime[0])
    end
	ig.SameLine()
    if ig.Button("insert arugh") then
        audioplayer:insert("arughSt.wav",0.5,streamtime[0])
    end
	if audioplayer.recordfile~=nil then
	if ig.Button("close record") then
        audioplayer.recordfile:close()
    end
	end
---[[

	local format = string.format
	local cbuf = ffi.new"char[201]"
	local level = ffi.new("float[1]")
	ig.PushItemWidth(80)
    for node in audioplayer:nodes() do
		ig.PushIDPtr(node)
		ffi.C.sprintf(cbuf,"%p",node)
		ig.Text(cbuf);ig.SameLine()
		level[0] = node.level
		if ig.SliderFloat("level",level,0,1) then
			node.level = level[0]
		end
		ig.SameLine();ig.Text(format("time:%4.2f",node.timeoffset))
		ig.SameLine();ig.Text(format("srate:%4.0f",node.sf:samplerate()));ig.SameLine();

		if ig.SmallButton("delete") then
			audioplayer:erase(node)
		end
		ig.PopID()
    end
	ig.PopItemWidth()

--]]
    -- end audio gui
   
    
    ig_impl:Render()
    
    window:swapBuffers()                    
end

audioplayer:close()
ig_impl:destroy()
window:destroy()
lj_glfw.terminate()


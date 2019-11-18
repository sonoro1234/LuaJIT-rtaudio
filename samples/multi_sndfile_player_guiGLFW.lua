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
    local ffi = require"ffi"
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

RtAudioInfo = rt.GetAllInfo()

---get output devices
local out_devices = {}
for i,API in ipairs(RtAudioInfo.APIS) do
    out_devices[API] = out_devices[API] or {names={},ids={}}
    for j=0,RtAudioInfo.API[API].device_count-1 do
        local dev = RtAudioInfo.API[API].devices[j]
        if dev.output_channels > 0 then
            table.insert(out_devices[API].names , dev.name)
            table.insert(out_devices[API].ids , j)
        end
    end
end

------------------

local API = RtAudioInfo.APIS[1]
device = RtAudioInfo.API[API].default_output

local function setDEV(API,device)
    print("using",API,"device",device)
    local api = rt.compiled_api_by_name(API)
    local dac = rt.create(api)
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

    local devinf = RtAudioInfo.API[API].devices[device]
    print("---------------opened device",device)
    for k,v in pairs(devinf) do print("\t",k,v) end
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
    return audioplayer
end

local audioplayer = setDEV(API,device)


local lj_glfw = require"glfw"
local gllib = require"gl"
gllib.set_loader(lj_glfw)
local gl, glc, glu, glext = gllib.libraries()
local ig = require"imgui.glfw"

------------------- LuaCombo
local function LuaCombo(label,strs,action)
    action = action or function() end
    strs = strs or {"none"}
    local combo = {}
    local strings 
    combo.currItem = ffi.new("int[1]",0)
    local Items 
    function combo:set(strs, ini)
        strings = strs
        self.currItem[0] = ini or 0
        Items = ffi.new("const char*["..(#strs).."]")
        for i = 0,#strs-1  do
            Items[i] = ffi.new("const char*",strs[i+1])
        end
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    function combo:set_index(ind)
        self.currItem[0] = ind or 0
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    combo:set(strs)
    function combo:draw()
        if ig.Combo(label,self.currItem,Items,#strings,-1) then
            action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
        end
    end
    function combo:get()
        return ffi.string(Items[self.currItem[0]]),self.currItem[0]
    end
    return combo
end


DEVCombo = LuaCombo("DEV")
APICombo = LuaCombo("APIS",RtAudioInfo.APIS,function(val,nit) 
    DEVCombo:set(out_devices[val].names) 
end)
APICombo:set_index(RtAudioInfo.APIbyNAME[API])

local function REsetDEV()
    audioplayer:close()
    local API,apiid = APICombo:get()
    local devs,devid = DEVCombo:get()
    audioplayer = setDEV(API,out_devices[API].ids[devid+1])
end


lj_glfw.setErrorCallback(function(error,description)
    print("GLFW error:",error,ffi.string(description or ""));
end)

lj_glfw.init()
local window = lj_glfw.Window(700,500)
window:makeContextCurrent() 
lj_glfw.glfw.glfwSwapInterval(1)

--choose implementation
--local ig_impl = ig.ImplGlfwGL3() --multicontext
--local ig_impl = ig.Imgui_Impl_glfw_opengl3() --standard imgui opengl3 example
local ig_impl = ig.Imgui_Impl_glfw_opengl2() --standard imgui opengl2 example

local igio = ig.GetIO()
igio.ConfigFlags = ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags


ig_impl:Init(window, true)


local streamtime = ffi.new("float[1]")
local play_text, stop_text = "  > "," || "
while not window:shouldClose() do

    lj_glfw.pollEvents()
    
    gl.glClear(glc.GL_COLOR_BUFFER_BIT)
    
    ig_impl:NewFrame()
    
    -- device PopUp
    if ig.Button"device" then ig.OpenPopup"dev_set" end
    ig.SetNextWindowContentSize(ig.ImVec2(400,0))
    if ig.BeginPopupModal"dev_set" then
        
        APICombo:draw()
        DEVCombo:draw()
        if ig.Button("OK") then
            REsetDEV()
            ig.CloseCurrentPopup(); 
        end
        ig.SameLine()
        if ig.Button("cancel") then
            ig.CloseCurrentPopup(); 
        end
        
        ig.EndPopup()
    end

        -------audio gui
    ig.Separator()
    local play_lab
    if audioplayer:is_playing() then play_lab = stop_text else play_lab = play_text end
    if ig.Button(play_lab) then
        if audioplayer:is_playing() then
            audioplayer:stop()
        else
            audioplayer:start()
        end
    end

    streamtime[0] = audioplayer:get_stream_time()
    --print(streamtime[0], audioplayer:get_stream_time())
    if ig.SliderFloat("time",streamtime,0,15) then
        audioplayer:set_stream_time(streamtime[0])
    end

    ig.SliderScalar("delay",ig.lib.ImGuiDataType_Double,fxdata.delay,ffi.new("double[1]",0),ffi.new("double[1]",fxdata.maxdelay))

    ig.SliderScalar("feedback",ig.lib.ImGuiDataType_Double,fxdata.feedback,ffi.new("double[1]",0),ffi.new("double[1]",1))
    
    ig.Separator()
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
local ffi = require"ffi"
--uncomment to debug cdef calls
---[[
local ffi_cdef = function(code)
    local ret,err = pcall(ffi.cdef,code)
    if not ret then
        local lineN = 1
        for line in code:gmatch("([^\n\r]*)\r?\n") do
            print(lineN, line)
            lineN = lineN + 1
        end
        print(err)
        error"bad cdef"
    end
end
--]]

ffi.cdef[[CDEFS]]

ffi.cdef[[DEFINES]]

local lib = ffi.load"rtaudio"

local M = {C=lib}
local rtaudio_t = {}
rtaudio_t.__index = rtaudio_t

function rtaudio_t:__new(api)
    local ret = lib.rtaudio_create(api)
    ffi.gc(ret,lib.rtaudio_destroy)
    return ret
end
function rtaudio_t:destroy()
    ffi.gc(self,nil)
    return lib.rtaudio_destroy(self)
end

LUAFUNCS

ffi.cdef[[typedef struct rtaudio rtaudio_type]]
M.rtaudio = ffi.metatype("rtaudio_type",rtaudio_t)

local callback_t
local callbacks_anchor = {}
function M.MakeAudioCallback(func, ...)
    if not callback_t then
        local CallbackFactory = require "lj-async.callback"
        callback_t = CallbackFactory("int(*)(void*,void*,unsigned int,double,unsigned int,void*)") --"RtAudioCallback"
    end
    local cb = callback_t(func, ...)
    table.insert(callbacks_anchor,cb)
    return cb:funcptr() , cb
end

function M.GetAllInfo()
    local formats = {
        FORMAT_SINT8 = 0x01,
        FORMAT_SINT16 = 0x02,
        FORMAT_SINT24 = 0x04,
        FORMAT_SINT32 = 0x08,
        FORMAT_FLOAT32 = 0x10,
        FORMAT_FLOAT64 = 0x20,
    }

    local function formats_tbl(ff)
        local str = {}
        for k,v in pairs(formats) do
            if bit.band(ff,v)~=0 then
                table.insert(str,k)
            end
        end
        table.sort(str)
        return str
    end
    
    local numcompiledapis = M.get_num_compiled_apis()
    local compiledapis = M.compiled_api()
    local I = {APIS={},API={},APIbyNAME={}}
    local RtAudioInfo = I
    for i=1,numcompiledapis do
        I.APIS[i] = ffi.string(M.api_name(compiledapis[i-1]))
        I.APIbyNAME[I.APIS[i]] = i
    end
    for i=1,numcompiledapis do
        local api = compiledapis[i-1]
        local dac = M.create(api)
        local apikey = ffi.string(M.api_name(api))
        I.API[apikey] = {}
        I.API[apikey].default_output = M.get_default_output_device(dac)
        I.API[apikey].default_input = M.get_default_input_device(dac)
        I.API[apikey].device_count = M.device_count(dac)
        I.API[apikey].devices = {}
        I.API[apikey].devices_by_ID = {}
        for j=1,M.device_count(dac) do
            local ID = dac:get_device_id(j-1)
            I.API[apikey].devices_by_ID[ID] = j
            local info = M.get_device_info(dac,ID)
            I.API[apikey].devices[j] = {}
            I.API[apikey].devices[j].id = info.id
            I.API[apikey].devices[j].name = ffi.string(info.name)
            I.API[apikey].devices[j].output_channels = info.output_channels
            I.API[apikey].devices[j].input_channels = info.input_channels
            I.API[apikey].devices[j].duplex_channels = info.duplex_channels
            I.API[apikey].devices[j].preferred_sample_rate = info.preferred_sample_rate
            I.API[apikey].devices[j].is_default_output = info.is_default_output>0
            I.API[apikey].devices[j].is_default_input = info.is_default_input>0
            I.API[apikey].devices[j].native_formats = formats_tbl(info.native_formats)
            I.API[apikey].devices[j].sample_rates = {}
            --sample rates
            for k=0,15 do
                if info.sample_rates[k]==0 then break end
                I.API[apikey].devices[j].sample_rates[k+1] = info.sample_rates[k]
            end
        end
        M.destroy(dac)
    end
    ---get output devices
    local out_devices = {}
    for i,API in ipairs(RtAudioInfo.APIS) do
        out_devices[API] = out_devices[API] or {names={},devID={}}
        for j=1,RtAudioInfo.API[API].device_count do
            local dev = RtAudioInfo.API[API].devices[j]
            if dev.output_channels > 0 then
                table.insert(out_devices[API].names , dev.name)
                table.insert(out_devices[API].devID , dev.id)
            end
        end
        --no device
        if #out_devices[API].names == 0 then
                table.insert(out_devices[API].names , "none")
                table.insert(out_devices[API].devID , 0)
        end
    end
        ---get input devices
    local input_devices = {}
    for i,API in ipairs(RtAudioInfo.APIS) do
        input_devices[API] = input_devices[API] or {names={},devID={}}
        for j=1,RtAudioInfo.API[API].device_count do
            local dev = RtAudioInfo.API[API].devices[j]
            if dev.input_channels > 0 then
                table.insert(input_devices[API].names , dev.name)
                table.insert(input_devices[API].devID , dev.id)
            end
        end
        --no device
        if #input_devices[API].names == 0 then
                table.insert(input_devices[API].names , "none")
                table.insert(input_devices[API].devID , 0)
        end
    end
    I.out_devices = out_devices
    I.input_devices = input_devices
    --check first good api-default device
    function I.first_out()
        local API, device
        for i=1,#RtAudioInfo.APIS do
            API = RtAudioInfo.APIS[i]
            device = RtAudioInfo.API[API].default_output
            if device~=0 then
                break
            end
        end
        return API, device
    end
    function I.first_input()
        local API, device
        for i=1,#RtAudioInfo.APIS do
            API = RtAudioInfo.APIS[i]
            device = RtAudioInfo.API[API].default_input
            if device~=0 then
                break
            end
        end
        return API, device
    end
    function I.out_combos(ig)
        local DEVCombo = ig.LuaCombo("DEV")
        local APICombo = ig.LuaCombo("APIS",RtAudioInfo.APIS,function(val,nit)
            DEVCombo:set(out_devices[val].names) 
        end)
        local function Set(API, device)
            APICombo:set_index(RtAudioInfo.APIbyNAME[API]-1)
            local device_i = RtAudioInfo.API[API].devices_by_ID[device]
            DEVCombo:set_index(device_i and device_i-1 or 0)
        end
        local function Get()
            local API,apiid = APICombo:get()
            local devs,devid = DEVCombo:get()
            local device = out_devices[API].devID[devid+1]
            return API, device
        end
        local function draw()
            APICombo:draw()
            DEVCombo:draw()
        end
        local function info()
            local API,device = Get()
            if device~=0 then --bad device
                local devi = I.API[API].devices_by_ID[device]
                for k,v in pairs(I.API[API].devices[devi]) do
                    if type(v)=="table" then v = table.concat(v,",") end
                    ig.Text(" %s: %s",tostring(k),tostring(v))
                end
            end
        end
        local function OpenPopup(API, device)
            Set(API, device)
            ig.OpenPopup"out_dev_set" 
        end
        local function DrawPopup(funOK)
            ig.SetNextWindowContentSize(ig.ImVec2(400,0))
            if ig.BeginPopupModal"out_dev_set" then
                draw()
                info()
                if ig.Button("OK") then
                    funOK(Get())
                    ig.CloseCurrentPopup(); 
                end
                ig.SameLine()
                if ig.Button("cancel") then
                    ig.CloseCurrentPopup(); 
                end
                ig.EndPopup()
            end
        end
        return {DEVCombo=DEVCombo,APICombo=APICombo,Set=Set,Get=Get,draw=draw, info=info, OpenPopup=OpenPopup, DrawPopup=DrawPopup}
    end
    function I.input_combos(ig)
        local DEVCombo = ig.LuaCombo("DEV##in")
        local APICombo = ig.LuaCombo("APIS##in",RtAudioInfo.APIS,function(val,nit)
            DEVCombo:set(input_devices[val].names) 
        end)
        local function Set(API, device)
            APICombo:set_index(RtAudioInfo.APIbyNAME[API]-1)
            local device_i = RtAudioInfo.API[API].devices_by_ID[device]
            DEVCombo:set_index(device_i and device_i-1 or 0)
        end
        local function Get()
            local API,apiid = APICombo:get()
            local devs,devid = DEVCombo:get()
            local device = input_devices[API].devID[devid+1]
            return API, device
        end
        local function draw()
            APICombo:draw()
            DEVCombo:draw()
        end
        local function info()
            local API,device = Get()
            if device~=0 then --bad device
                local devi = I.API[API].devices_by_ID[device]
                for k,v in pairs(I.API[API].devices[devi]) do
                    if type(v)=="table" then v = table.concat(v,",") end
                    ig.Text(" %s: %s",tostring(k),tostring(v))
                end
            end
        end
        local function OpenPopup(API, device)
            Set(API, device)
            ig.OpenPopup"input_dev_set" 
        end
        local function DrawPopup(funOK)
            ig.SetNextWindowContentSize(ig.ImVec2(400,0))
            if ig.BeginPopupModal"input_dev_set" then
                draw()
                info()
                if ig.Button("OK") then
                    funOK(Get())
                    ig.CloseCurrentPopup(); 
                end
                ig.SameLine()
                if ig.Button("cancel") then
                    ig.CloseCurrentPopup(); 
                end
                ig.EndPopup()
            end
        end
        return {DEVCombo=DEVCombo,APICombo=APICombo,Set=Set,Get=Get,draw=draw, info=info, OpenPopup=OpenPopup, DrawPopup=DrawPopup}
    end
    return I
end

setmetatable(M,{
__index = function(t,k)
    local ok,ptr = pcall(function(str) return lib["rtaudio_"..str] end,k)
    if not ok then ok,ptr = pcall(function(str) return lib["RTAUDIO_"..str] end,k) end 
    if not ok then error(k.." not found") end
    rawset(M, k, ptr)
    return ptr
end
})


return M





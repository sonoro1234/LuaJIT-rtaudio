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
    local I = {}
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
    I = {APIS={},API={},APIbyNAME={}}
    for i=0,numcompiledapis-1 do
        I.APIS[i+1] = ffi.string(M.api_name(compiledapis[i]))
        I.APIbyNAME[I.APIS[i+1]] = i
    end
    for i=0,numcompiledapis-1 do
        local api = compiledapis[i]
        local dac = M.create(api)
        local apikey = ffi.string(M.api_name(api))
        I.API[apikey] = {}
        I.API[apikey].default_output = M.get_default_output_device(dac)
        I.API[apikey].default_input = M.get_default_input_device(dac)
        I.API[apikey].device_count = M.device_count(dac)
        I.API[apikey].devices = {}
        I.API[apikey].devices_by_ID = {}
        for i=0,M.device_count(dac)-1 do
            local ID = dac:get_device_id(i)
            I.API[apikey].devices_by_ID[ID] = i
            local info = M.get_device_info(dac,ID)
            I.API[apikey].devices[i] = {}
            I.API[apikey].devices[i].id = info.id
            I.API[apikey].devices[i].name = ffi.string(info.name)
            I.API[apikey].devices[i].output_channels = info.output_channels
            I.API[apikey].devices[i].input_channels = info.input_channels
            I.API[apikey].devices[i].duplex_channels = info.duplex_channels
            I.API[apikey].devices[i].preferred_sample_rate = info.preferred_sample_rate
            I.API[apikey].devices[i].is_default_output = info.is_default_output>0
            I.API[apikey].devices[i].is_default_input = info.is_default_input>0
            I.API[apikey].devices[i].native_formats = formats_tbl(info.native_formats)
            I.API[apikey].devices[i].sample_rates = {}
            --sample rates
            for k=0,15 do
                if info.sample_rates[k]==0 then break end
                I.API[apikey].devices[i].sample_rates[k+1] = info.sample_rates[k]
            end
        end
        M.destroy(dac)
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

-- require"anima.utils"
-- prtable(M.GetAllInfo())

return M





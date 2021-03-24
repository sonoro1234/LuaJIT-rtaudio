
local cp2c = require"cpp2ffi"
local parser = cp2c.Parser()
--local cdefs = {}
local defines = {}

cp2c.save_data("./outheader.h",[[#include <rtaudio_c.h>]])
local pipe,err = io.popen([[gcc -E -dD -I ../rtaudio/ -I ../rtaudio/include/ ./outheader.h]],"r")
if not pipe then
    error("could not execute gcc "..err)
end

for line in cp2c.location(pipe,{[[rtaudio.-]]},defines) do
	--table.insert(cdefs,line)
	parser:insert(line)
end
pipe:close()
os.remove"./outheader.h"
---------------------------
parser:do_parse()


--parseItems
--local itemarr,items = cp2c.parseItems(txt)
local cdefs = {}
for i,it in ipairs(parser.itemsarr) do
	table.insert(cdefs,it.item)
end

--require"anima.utils"
--prtable(parser.itemsarr)

local deftab = {}
---[[
local ffi = require"ffi"
ffi.cdef(table.concat(cdefs,""))
local wanted_strings = {"."}--"^SDL","^AUDIO_","^KMOD_","^RW_"}
for i,v in ipairs(defines) do
	local wanted = false
	for _,wan in ipairs(wanted_strings) do
		if (v[1]):match(wan) then wanted=true; break end
	end
	if wanted then
		local lin = "static const int "..v[1].." = " .. v[2] .. ";"
		local ok,msg = pcall(function() return ffi.cdef(lin) end)
		if not ok then
			print("skipping def",lin)
			print(msg)
		else
			table.insert(deftab,lin)
		end
	end
end
--]]


local rtaudio_t_code = [[

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

]]
cp2c.table_do_sorted(parser.defsT, function(k,v)
--for k,v in pairs(parser.defsT) do
	if v[1].argsT[1] then
		if v[1].argsT[1].type  =="rtaudio_t"  and v[1].funcname~="rtaudio_destroy" then 
			--print(v[1].funcname,v[1].signature) 
			local cname = v[1].funcname:gsub("rtaudio_","")
			local code = "\nfunction rtaudio_t:"..cname.."("
			local codeargs = ""
			for i=2,#v[1].argsT do
				codeargs = codeargs..v[1].argsT[i].name..", "
			end
			codeargs = codeargs:gsub(", $","") --delete last comma
			code = code..codeargs..")\n"
			local retcode = "lib."..v[1].funcname.."(self"
			if #codeargs==0 then
				retcode = retcode ..")"
			else
				retcode = retcode..","..codeargs..")"
			end
			if v[1].ret:match("char") then
				retcode = "    local ret = "..retcode
				retcode = retcode.."\n    if ret==nil then return nil else return ffi.string(ret) end"
			else
				retcode = "    return "..retcode
			end
			code = code .. retcode.. "\nend"
			rtaudio_t_code = rtaudio_t_code..code
		end
	end
--end
end)
rtaudio_t_code = rtaudio_t_code..[[

ffi.cdef"typedef struct rtaudio rtaudio_type"
M.rtaudio = ffi.metatype("rtaudio_type",rtaudio_t)

]]

--require"anima.utils"
--prtable(parser.defsT)
--output sdl2_ffi
local sdlstr = [[
local ffi = require"ffi"

--uncomment to debug cdef calls]]..
"\n---[["..[[

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
]].."--]]"..[[

ffi_cdef]].."[["..table.concat(cdefs,"").."]]"..[[

ffi_cdef]].."[["..table.concat(deftab,"\n").."]]"..[[

local lib = ffi.load"rtaudio"

local M = {C=lib}]]..rtaudio_t_code..[=[

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
        for i=0,M.device_count(dac)-1 do
            local info = M.get_device_info(dac,i)
            I.API[apikey].devices[i] = {}
            I.API[apikey].devices[i].probed = info.probed>0
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


return M
]=]

cp2c.save_data("./rtaudio_ffi.lua",sdlstr)
cp2c.copyfile("./rtaudio_ffi.lua","../rtaudio_ffi.lua")


--use it from anima or require cpp2ffi1
package.path = package.path..";../../LuaJIT-ImGui/cimgui/generator/?.lua"
local cp2c = require"cpp2ffi"

local parser = cp2c.Parser()
cp2c.save_data("./outheader.h",[[#include <rtaudio_c.h>]])
local cmd = [[gcc -E -dD -I ../rtaudio/ -I ../rtaudio/include/ ./outheader.h]]
local names = {[[rtaudio.-]]}
local defines = parser:take_lines(cmd, names)
os.remove"./outheader.h"
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

local ffi = require"ffi"
--ffi.cdef(table.concat(cdefs,""))
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



local LUAFUNCS = ""

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
			LUAFUNCS = LUAFUNCS..code
		end
	end
--end
end)

local template = cp2c.read_data("./template.lua")
local CDEFS = table.concat(cdefs,"")
local DEFINES = "\n"..table.concat(deftab,"\n")

template = template:gsub("CDEFS",CDEFS)
template = template:gsub("DEFINES",DEFINES)
template = template:gsub("LUAFUNCS",LUAFUNCS)


cp2c.save_data("./rtaudio_ffi.lua",template)
cp2c.copyfile("./rtaudio_ffi.lua","../rtaudio_ffi.lua")


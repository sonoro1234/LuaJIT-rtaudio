local ffi = require"ffi"
local rt = require"rtaudio_ffi"

local formats = {
FORMAT_SINT8 = 0x01,
FORMAT_SINT16 = 0x02,
FORMAT_SINT24 = 0x04,
FORMAT_SINT32 = 0x08,
FORMAT_FLOAT32 = 0x10,
FORMAT_FLOAT64 = 0x20,
}

local function formats_str(ff)
    local str = {}
    for k,v in pairs(formats) do
        if bit.band(ff,v)~=0 then
            table.insert(str,k)
        end
    end
    table.sort(str)
    return table.concat(str,", ")
end

print("VERSION",ffi.string(rt.version()))

local numcompiledapis = rt.get_num_compiled_apis()
local compiledapis = rt.compiled_api()
for i=0,numcompiledapis-1 do-- in pairs(compiledapis) do
    print("API",i,ffi.string(rt.api_name(compiledapis[i])),ffi.string(rt.api_display_name(compiledapis[i])))
end

for i=0,numcompiledapis-1 do --k,api in pairs(compiledapis) do
    local api = compiledapis[i]
    dac = rt.create(api)
    print"-------------------------------------"
    print("current api",ffi.string(rt.api_display_name(api)))
    print("device count ",rt.device_count(dac))
    print("getdefaultoutput",rt.get_default_output_device(dac))
    print("getdefaultinput",rt.get_default_input_device(dac))
    
    print"list devices:"
    for i=0,rt.device_count(dac)-1 do
        local ID = dac:get_device_id(i)
        print("\nDevice ",i,ID)
        local info = rt.get_device_info(dac,ID)
        print("\tname",ffi.string(info.name))
        print("\toutput_channels",info.output_channels)
        print("\tinput_channels",info.input_channels)
        print("\tduplex_channels",info.duplex_channels)
        print("\tpreferred_sample_rate",info.preferred_sample_rate)
        print("\tis_default_output",info.is_default_output>0)
        print("\tis_default_input",info.is_default_input>0)
        print("\tnative_formats",info.native_formats)
        print("\t",formats_str(info.native_formats))
        --sample rates
        print"\tsample rates"
        for k=0,15 do
            if info.sample_rates[k]==0 then break end
            print("\t",k,info.sample_rates[k])
        end
    end
end


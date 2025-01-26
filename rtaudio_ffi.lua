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

ffi.cdef[[
typedef unsigned long rtaudio_format_t;
typedef unsigned int rtaudio_stream_flags_t;
typedef unsigned int rtaudio_stream_status_t;
typedef int (*rtaudio_cb_t)(void *out, void *in, unsigned int nFrames,
                            double stream_time, rtaudio_stream_status_t status,
                            void *userdata);
enum rtaudio_error {
  RTAUDIO_ERROR_NONE = 0,
  RTAUDIO_ERROR_WARNING,
  RTAUDIO_ERROR_UNKNOWN,
  RTAUDIO_ERROR_NO_DEVICES_FOUND,
  RTAUDIO_ERROR_INVALID_DEVICE,
  RTAUDIO_ERROR_DEVICE_DISCONNECT,
  RTAUDIO_ERROR_MEMORY_ERROR,
  RTAUDIO_ERROR_INVALID_PARAMETER,
  RTAUDIO_ERROR_INVALID_USE,
  RTAUDIO_ERROR_DRIVER_ERROR,
  RTAUDIO_ERROR_SYSTEM_ERROR,
  RTAUDIO_ERROR_THREAD_ERROR,
};
typedef int rtaudio_error_t;
typedef void (*rtaudio_error_cb_t)(rtaudio_error_t err, const char *msg);
enum rtaudio_api {
  RTAUDIO_API_UNSPECIFIED,
  RTAUDIO_API_MACOSX_CORE,
  RTAUDIO_API_LINUX_ALSA,
  RTAUDIO_API_UNIX_JACK,
  RTAUDIO_API_LINUX_PULSE,
  RTAUDIO_API_LINUX_OSS,
  RTAUDIO_API_WINDOWS_ASIO,
  RTAUDIO_API_WINDOWS_WASAPI,
  RTAUDIO_API_WINDOWS_DS,
  RTAUDIO_API_DUMMY,
  RTAUDIO_API_NUM,
};
typedef int rtaudio_api_t;
typedef struct rtaudio_device_info {
  unsigned int id;
  unsigned int output_channels;
  unsigned int input_channels;
  unsigned int duplex_channels;
  int is_default_output;
  int is_default_input;
  rtaudio_format_t native_formats;
  unsigned int preferred_sample_rate;
  unsigned int sample_rates[16];
  char name[512];
} rtaudio_device_info_t;
typedef struct rtaudio_stream_parameters {
  unsigned int device_id;
  unsigned int num_channels;
  unsigned int first_channel;
} rtaudio_stream_parameters_t;
typedef struct rtaudio_stream_options {
  rtaudio_stream_flags_t flags;
  unsigned int num_buffers;
  int priority;
  char name[512];
} rtaudio_stream_options_t;
typedef struct rtaudio *rtaudio_t;
 const char *rtaudio_version(void);
 unsigned int rtaudio_get_num_compiled_apis(void);
 const rtaudio_api_t *rtaudio_compiled_api(void);
 const char *rtaudio_api_name(rtaudio_api_t api);
 const char *rtaudio_api_display_name(rtaudio_api_t api);
 rtaudio_api_t rtaudio_compiled_api_by_name(const char *name);
 const char *rtaudio_error(rtaudio_t audio);
 rtaudio_error_t rtaudio_error_type(rtaudio_t audio);
 rtaudio_t rtaudio_create(rtaudio_api_t api);
 void rtaudio_destroy(rtaudio_t audio);
 rtaudio_api_t rtaudio_current_api(rtaudio_t audio);
 int rtaudio_device_count(rtaudio_t audio);
 unsigned int rtaudio_get_device_id(rtaudio_t audio, int i);
 rtaudio_device_info_t rtaudio_get_device_info(rtaudio_t audio,
                                                         unsigned int id);
 unsigned int rtaudio_get_default_output_device(rtaudio_t audio);
 unsigned int rtaudio_get_default_input_device(rtaudio_t audio);
 rtaudio_error_t
rtaudio_open_stream(rtaudio_t audio, rtaudio_stream_parameters_t *output_params,
                    rtaudio_stream_parameters_t *input_params,
                    rtaudio_format_t format, unsigned int sample_rate,
                    unsigned int *buffer_frames, rtaudio_cb_t cb,
                    void *userdata, rtaudio_stream_options_t *options,
                    rtaudio_error_cb_t errcb);
 void rtaudio_close_stream(rtaudio_t audio);
 rtaudio_error_t rtaudio_start_stream(rtaudio_t audio);
 rtaudio_error_t rtaudio_stop_stream(rtaudio_t audio);
 rtaudio_error_t rtaudio_abort_stream(rtaudio_t audio);
 int rtaudio_is_stream_open(rtaudio_t audio);
 int rtaudio_is_stream_running(rtaudio_t audio);
 double rtaudio_get_stream_time(rtaudio_t audio);
 void rtaudio_set_stream_time(rtaudio_t audio, double time);
 long rtaudio_get_stream_latency(rtaudio_t audio);
 unsigned int rtaudio_get_stream_sample_rate(rtaudio_t audio);
 void rtaudio_show_warnings(rtaudio_t audio, int show);]]

ffi.cdef[[
static const int RTAUDIO_FORMAT_SINT8 = 0x01;
static const int RTAUDIO_FORMAT_SINT16 = 0x02;
static const int RTAUDIO_FORMAT_SINT24 = 0x04;
static const int RTAUDIO_FORMAT_SINT32 = 0x08;
static const int RTAUDIO_FORMAT_FLOAT32 = 0x10;
static const int RTAUDIO_FORMAT_FLOAT64 = 0x20;
static const int RTAUDIO_FLAGS_NONINTERLEAVED = 0x1;
static const int RTAUDIO_FLAGS_MINIMIZE_LATENCY = 0x2;
static const int RTAUDIO_FLAGS_HOG_DEVICE = 0x4;
static const int RTAUDIO_FLAGS_SCHEDULE_REALTIME = 0x8;
static const int RTAUDIO_FLAGS_ALSA_USE_DEFAULT = 0x10;
static const int RTAUDIO_FLAGS_JACK_DONT_CONNECT = 0x20;
static const int RTAUDIO_STATUS_INPUT_OVERFLOW = 0x1;
static const int RTAUDIO_STATUS_OUTPUT_UNDERFLOW = 0x2;
static const int NUM_SAMPLE_RATES = 16;
static const int MAX_NAME_LENGTH = 512;]]

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


function rtaudio_t:abort_stream()
    return lib.rtaudio_abort_stream(self)
end
function rtaudio_t:close_stream()
    return lib.rtaudio_close_stream(self)
end
function rtaudio_t:current_api()
    return lib.rtaudio_current_api(self)
end
function rtaudio_t:device_count()
    return lib.rtaudio_device_count(self)
end
function rtaudio_t:error()
    local ret = lib.rtaudio_error(self)
    if ret==nil then return nil else return ffi.string(ret) end
end
function rtaudio_t:error_type()
    return lib.rtaudio_error_type(self)
end
function rtaudio_t:get_default_input_device()
    return lib.rtaudio_get_default_input_device(self)
end
function rtaudio_t:get_default_output_device()
    return lib.rtaudio_get_default_output_device(self)
end
function rtaudio_t:get_device_id(i)
    return lib.rtaudio_get_device_id(self,i)
end
function rtaudio_t:get_device_info(id)
    return lib.rtaudio_get_device_info(self,id)
end
function rtaudio_t:get_stream_latency()
    return lib.rtaudio_get_stream_latency(self)
end
function rtaudio_t:get_stream_sample_rate()
    return lib.rtaudio_get_stream_sample_rate(self)
end
function rtaudio_t:get_stream_time()
    return lib.rtaudio_get_stream_time(self)
end
function rtaudio_t:is_stream_open()
    return lib.rtaudio_is_stream_open(self)
end
function rtaudio_t:is_stream_running()
    return lib.rtaudio_is_stream_running(self)
end
function rtaudio_t:open_stream(output_params, input_params, format, sample_rate, buffer_frames, cb, userdata, options, errcb)
    return lib.rtaudio_open_stream(self,output_params, input_params, format, sample_rate, buffer_frames, cb, userdata, options, errcb)
end
function rtaudio_t:set_stream_time(time)
    return lib.rtaudio_set_stream_time(self,time)
end
function rtaudio_t:show_warnings(show)
    return lib.rtaudio_show_warnings(self,show)
end
function rtaudio_t:start_stream()
    return lib.rtaudio_start_stream(self)
end
function rtaudio_t:stop_stream()
    return lib.rtaudio_stop_stream(self)
end

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
			DEVCombo:set_index(device_i-1)
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
			local devi = I.API[API].devices_by_ID[device]
			for k,v in pairs(I.API[API].devices[devi]) do
				if type(v)=="table" then v = table.concat(v,",") end
				ig.Text(" %s: %s",tostring(k),tostring(v))
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
			DEVCombo:set_index(device_i-1)
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
			local devi = I.API[API].devices_by_ID[device]
			for k,v in pairs(I.API[API].devices[devi]) do
				if type(v)=="table" then v = table.concat(v,",") end
				ig.Text(" %s: %s",tostring(k),tostring(v))
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





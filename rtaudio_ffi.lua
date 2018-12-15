local ffi = require"ffi"

--uncomment to debug cdef calls
---[[
local ffi_cdef = ffi.cdef
ffi.cdef = function(code)
    local ret,err = pcall(ffi_cdef,code)
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
typedef enum rtaudio_error {
  RTAUDIO_ERROR_WARNING,
  RTAUDIO_ERROR_DEBUG_WARNING,
  RTAUDIO_ERROR_UNSPECIFIED,
  RTAUDIO_ERROR_NO_DEVICES_FOUND,
  RTAUDIO_ERROR_INVALID_DEVICE,
  RTAUDIO_ERROR_MEMORY_ERROR,
  RTAUDIO_ERROR_INVALID_PARAMETER,
  RTAUDIO_ERROR_INVALID_USE,
  RTAUDIO_ERROR_DRIVER_ERROR,
  RTAUDIO_ERROR_SYSTEM_ERROR,
  RTAUDIO_ERROR_THREAD_ERROR,
} rtaudio_error_t;
typedef void (*rtaudio_error_cb_t)(rtaudio_error_t err, const char *msg);
typedef enum rtaudio_api {
  RTAUDIO_API_UNSPECIFIED,
  RTAUDIO_API_LINUX_ALSA,
  RTAUDIO_API_LINUX_PULSE,
  RTAUDIO_API_LINUX_OSS,
  RTAUDIO_API_UNIX_JACK,
  RTAUDIO_API_MACOSX_CORE,
  RTAUDIO_API_WINDOWS_WASAPI,
  RTAUDIO_API_WINDOWS_ASIO,
  RTAUDIO_API_WINDOWS_DS,
  RTAUDIO_API_DUMMY,
  RTAUDIO_API_NUM,
} rtaudio_api_t;
typedef struct rtaudio_device_info {
  int probed;
  unsigned int output_channels;
  unsigned int input_channels;
  unsigned int duplex_channels;
  int is_default_output;
  int is_default_input;
  rtaudio_format_t native_formats;
  unsigned int preferred_sample_rate;
  int sample_rates[16];
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
 rtaudio_t rtaudio_create(rtaudio_api_t api);
 void rtaudio_destroy(rtaudio_t audio);
 rtaudio_api_t rtaudio_current_api(rtaudio_t audio);
 int rtaudio_device_count(rtaudio_t audio);
 rtaudio_device_info_t rtaudio_get_device_info(rtaudio_t audio,
                                                         int i);
 unsigned int rtaudio_get_default_output_device(rtaudio_t audio);
 unsigned int rtaudio_get_default_input_device(rtaudio_t audio);
 int
rtaudio_open_stream(rtaudio_t audio, rtaudio_stream_parameters_t *output_params,
                    rtaudio_stream_parameters_t *input_params,
                    rtaudio_format_t format, unsigned int sample_rate,
                    unsigned int *buffer_frames, rtaudio_cb_t cb,
                    void *userdata, rtaudio_stream_options_t *options,
                    rtaudio_error_cb_t errcb);
 void rtaudio_close_stream(rtaudio_t audio);
 int rtaudio_start_stream(rtaudio_t audio);
 int rtaudio_stop_stream(rtaudio_t audio);
 int rtaudio_abort_stream(rtaudio_t audio);
 int rtaudio_is_stream_open(rtaudio_t audio);
 int rtaudio_is_stream_running(rtaudio_t audio);
 double rtaudio_get_stream_time(rtaudio_t audio);
 void rtaudio_set_stream_time(rtaudio_t audio, double time);
 int rtaudio_get_stream_latency(rtaudio_t audio);
 unsigned int rtaudio_get_stream_sample_rate(rtaudio_t audio);
 void rtaudio_show_warnings(rtaudio_t audio, int show);]]
ffi.cdef[[static const int RTAUDIO_FORMAT_SINT8 = 0x01;
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


function rtaudio_t:get_default_output_device()
    return lib.rtaudio_get_default_output_device(self)
end
function rtaudio_t:current_api()
    return lib.rtaudio_current_api(self)
end
function rtaudio_t:get_device_info(i)
    return lib.rtaudio_get_device_info(self,i)
end
function rtaudio_t:abort_stream()
    return lib.rtaudio_abort_stream(self)
end
function rtaudio_t:get_default_input_device()
    return lib.rtaudio_get_default_input_device(self)
end
function rtaudio_t:is_stream_open()
    return lib.rtaudio_is_stream_open(self)
end
function rtaudio_t:device_count()
    return lib.rtaudio_device_count(self)
end
function rtaudio_t:error()
    local ret = lib.rtaudio_error(self)
    if ret==nil then return nil else return ffi.string(ret) end
end
function rtaudio_t:show_warnings(show)
    return lib.rtaudio_show_warnings(self,show)
end
function rtaudio_t:get_stream_sample_rate()
    return lib.rtaudio_get_stream_sample_rate(self)
end
function rtaudio_t:get_stream_latency()
    return lib.rtaudio_get_stream_latency(self)
end
function rtaudio_t:start_stream()
    return lib.rtaudio_start_stream(self)
end
function rtaudio_t:set_stream_time(time)
    return lib.rtaudio_set_stream_time(self,time)
end
function rtaudio_t:stop_stream()
    return lib.rtaudio_stop_stream(self)
end
function rtaudio_t:open_stream(output_params, input_params, format, sample_rate, buffer_frames, cb, userdata, options, errcb)
    return lib.rtaudio_open_stream(self,output_params, input_params, format, sample_rate, buffer_frames, cb, userdata, options, errcb)
end
function rtaudio_t:get_stream_time()
    return lib.rtaudio_get_stream_time(self)
end
function rtaudio_t:is_stream_running()
    return lib.rtaudio_is_stream_running(self)
end
function rtaudio_t:close_stream()
    return lib.rtaudio_close_stream(self)
end
ffi.cdef"typedef struct rtaudio_t rtaudio_type"
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
	return cb:funcptr()
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

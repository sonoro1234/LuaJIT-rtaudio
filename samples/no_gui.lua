------sleep function
local ffi = require("ffi")
ffi.cdef[[
void Sleep(int ms);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

local sleep
if ffi.os == "Windows" then
  function sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end
------------ get devices
local rt = require"rtaudio_ffi"
local RtAudioInfo = rt.GetAllInfo()
local API, device = RtAudioInfo.first_out()

print("using",API,"device",device)
local api = rt.compiled_api_by_name(API)
local dac = rt.create(api)

--copy specs from file
local sndf = require"sndfile_ffi"
local AudioPlayer = require"rtAudioPlayer"
local filename = "african_roomS.wav";
local info = sndf.get_info(filename)
local audioplayer,err = AudioPlayer({
    dac = dac,
    device = dac:get_default_output_device(),
    freq = info.samplerate, 
    format = rt.FORMAT_FLOAT32,
    channels = info.channels, 
    samples = 1024})

assert(audioplayer,err)
--insert several files
for i=1,10 do
    --filename, level, timeoffset
    audioplayer:insert(filename,(11-i)*0.1,i*0.6)
end
--show them
for node in audioplayer:nodes() do
    print("node",node.sf)
end
print"return to start"
io.read"*l"
--play them 7 secs
audioplayer:start()
local err = rt.error(dac)
print("start error",ffi.string(err~=nil and err or "no error"))
sleep(7);
--close
audioplayer:close()
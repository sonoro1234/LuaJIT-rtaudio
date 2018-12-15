# LuaJIT-rtaudio
ffi binding to the C interface of RtAudio

The C interface function are accesed removing the rtaudio prefix.

To use rtaudio C interface:

Define your callback

```lua
--callback
local function AudioInit(udatacode)
    local ffi = require"ffi"
    local sin = math.sin
    ffi.cdef(udatacode)
    return function(out, inp, nFrames,stream_time,status,userdata)
        print(nFrames,out,stream_time,status)

        local buf = ffi.cast("float*",out)
        local udc = ffi.cast("MyUdata*",userdata)
        local lenf = nFrames*2
    
        for i=0,lenf-2,2 do
            local sample = sin(udc.Phase)--*32767--*0.01
            udc.Phase = udc.Phase + udc.dPhase
            buf[i] = sample
            buf[i+1] = sample
        end

        --if stream_time > 3 then return 1 end
        return 0
    end
end
-- userdata
local udatacode = [[typedef struct {double Phase;double dPhase;} MyUdata]]
ffi.cdef(udatacode)
local ud = ffi.new"MyUdata"
```

And use it from RtAudio C interface as:

```lua
local rt = require"rtaudio_ffi"
local dac = rt.create(0)
--options
local options = ffi.new("rtaudio_stream_options_t[1]")
options[0].flags = bit.bor(options[0].flags,rt.FLAGS_HOG_DEVICE,rt.FLAGS_SCHEDULE_REALTIME)
--output parameters
local outpar = ffi.new"rtaudio_stream_parameters_t[1]"
outpar[0].device_id = rt.get_default_output_device(dac)
outpar[0].num_channels = 2

local bufferFrames = ffi.new("unsigned int[1]",2048)
local callback = rt.MakeAudioCallback(AudioInit,udatacode) --defined elsewhere
--open it
local ret = rt.open_stream(dac,outpar,nil,rt.FORMAT_FLOAT32,44100,bufferFrames, callback,ud,options,errcb)
if(ret<0) then print(ret,"open_stream",ffi.string(rt.error(dac))) end
--start it
rtaudio.start_stream(dac)
...
rt.stop_stream(dac)
rt.close_stream(dac)
rt.destroy(dac)

```

# rtAudioPlayer

Gives a simplified interface for playing libsndfile files.

```lua
local sndf = require"sndfile_ffi"
local rt = require"rtaudio_ffi"
local AudioPlayer = require"rtAudioPlayer"
local dac = rt.rtaudio(0)

--copy specs from file
local info = sndf.get_info(filename)
local audioplayer,err = AudioPlayer({
    dac = dac,
    device = dac:get_default_output_device(),
    freq = info.samplerate, 
    format = rt.FORMAT_SINT32,
    channels = info.channels, 
    samples = 1024})

assert(audioplayer)
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
print("start error",ffi.string(rt.error(dac)))
sleep(7); -- this can be found in http://luajit.org/ext_ffi_tutorial.html
--close
audioplayer:close()

```

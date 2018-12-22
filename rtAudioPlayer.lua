local ffi = require"ffi"
local rt = require"rtaudio_ffi"
local sndf = require"sndfile_ffi"


--------------will run in a same thread and different lua state and return the callback
local function AudioInit(audioplayer,audioplayercdef,postfunc,postdata,postcode)
    local ffi = require"ffi"
    local rt = require"rtaudio_ffi"
    local sndf = require"sndfile_ffi"
    local function audio_buffer_type(ap)
        local typebuffer
        if ap.format == rt.FORMAT_SINT16 then
            typebuffer = "short"
        elseif ap.format == rt.FORMAT_SINT32 then
            typebuffer = "int"
        elseif ap.format == rt.FORMAT_FLOAT32 then
            typebuffer = "float"
        elseif ap.format == rt.FORMAT_FLOAT64 then
            typebuffer = "double"
        else
            error("unknown buffer type :"..tostring(ap.format))
        end
        return typebuffer
    end
    --postfunc will get upvalues from AudioInit (ffi,spec)
    local function setupvalues(func)
        for i=1,math.huge do
            local name,val =debug.getupvalue(func,i)
            if not name then break end
            if not val then
                --print("searching",name)
                local found = false
                for j=1,math.huge do
                    local name2,val2 = debug.getlocal(2,j)
                    if not name2 then break end
                    --print("found",name2)
                    if name == name2 then
                        debug.setupvalue(func,i,val2)
                        found = true
                        break
                    end
                end
                if not found then error("value for upvalue "..name.." not found") end
            end
        end
    end

    
    ffi.cdef(audioplayercdef)
    audioplayer = ffi.cast("rt_audioplayer*",audioplayer)
    local root = audioplayer.root
    
    local typebuffer = audio_buffer_type(audioplayer)
    local nchannels = audioplayer.outpar[0].num_channels
    local timefac = 1/audioplayer.sample_rate
    local bufpointer = typebuffer.."*"
    local readfunc,writefunc = "readf_"..typebuffer,"writef_"..typebuffer
    setupvalues(postfunc)
    postfunc = setfenv(postfunc,setmetatable({ffi=ffi,rt=rt},{__index=_G}))
    local postfuncS = postfunc(postdata,postcode,typebuffer,nchannels,audioplayer.sample_rate)
    
    local floor = math.floor
    -- this is the real callback
    return function(out, inp, nFrames,stream_time,status,userdata)
        --print(out, inp, nFrames,stream_time,status,userdata)
        
        local streamTime = stream_time
        local lenf = nFrames
        local windowsize = lenf * timefac
        ffi.fill(out,nFrames*ffi.sizeof(typebuffer)*nchannels)
        local streamf = ffi.cast(bufpointer,out)
        local readbuffer = ffi.new(typebuffer.."[?]",lenf*nchannels)
        local sf_node = root
        while true do
            if sf_node.next~=nil then
                sf_node = sf_node.next[0]
                local sf = sf_node.sf
                if sf.resampler~=nil then
                    sf = sf.resampler
                end

                if sf_node.timeoffset <= streamTime then --already setted 
                    local readen = tonumber(sf[readfunc](sf,readbuffer,lenf))
                    for i=0,(readen*nchannels)-1 do
                        streamf[i] = streamf[i] + readbuffer[i]*sf_node.level
                    end
                elseif sf_node.timeoffset < streamTime + windowsize then --set it here

                    local frames = floor(streamTime + windowsize - sf_node.timeoffset) * audioplayer.sample_rate
                    local res = sf:seek( 0, sndf.SEEK_SET)
                    local readen = tonumber(sf[readfunc](sf,readbuffer,frames))
                    local j=0
                    for i=(lenf - frames)*nchannels,((readen+lenf-frames)*nchannels)-1 do
                        streamf[i] = streamf[i] + readbuffer[j]*sf_node.level
                        j = j + 1
                    end
                end
            else break end
        end
        postfuncS(streamf,lenf,streamTime)
        if audioplayer.recordfile~= nil then
            audioplayer.recordfile[writefunc](audioplayer.recordfile,streamf,lenf)
        end
        --audioplayer.streamTime = streamTime + lenf*timefac
        return 0
    end
end
---------------------------------------------------
---------------------------------------------audioplayer interface
local audioplayercdef = [[
typedef struct sf_node sf_node;
struct sf_node
{
    SNDFILE_ref *sf;
    double level;
    double timeoffset;
    sf_node *next;
} sf_node;

typedef struct rt_audioplayer
{
    rtaudio_stream_parameters_t outpar[1];
    sf_node root;
    SNDFILE_ref *recordfile;
    rtaudio_t dac;
    rtaudio_format_t format;
    unsigned int bufferFrames[1];
    unsigned int sample_rate;
    src_callback_t resampler_input_cb;
} rt_audioplayer;
]]

ffi.cdef(audioplayercdef)

local AudioPlayer_mt = {}
AudioPlayer_mt.__index = AudioPlayer_mt
function AudioPlayer_mt:__new(t,postfunc,postdata,postcode)
    local postfunc = postfunc or function() return function() end end
    local ap = ffi.new("rt_audioplayer")
    assert(ap.root.next == nil)
    
    ap.dac = t.dac
    ap.bufferFrames[0] = t.samples
    ap.sample_rate = t.freq
    ap.outpar[0].device_id = t.device
    ap.outpar[0].num_channels = t.channels
    ap.format = t.format
    --print("--------------------------format",ap.format ,t.format)
    local options
    local thecallback, cbmaker = rt.MakeAudioCallback(AudioInit,ap,audioplayercdef,postfunc,postdata,postcode)
    ap.resampler_input_cb = cbmaker:additional_cb(function()
        local sndf = require"sndfile_ffi"
        return sndf.resampler_input_cb
    end,"src_callback_t")
    local ret = rt.open_stream(ap.dac,ap.outpar,nil,ap.format,ap.sample_rate,ap.bufferFrames, thecallback,nil,options,nil)

    if ret < 0 then
        local err = rt.error(dac)
        return nil, err~=nil and ffi.string(err) or "unknown error opening device"
    end
    ffi.gc(ap,self.close)
    return ap
end
function AudioPlayer_mt:close()
    for node in self:nodes() do
        node.sf:close()
    end
    if self.recordfile ~=nil then
        self.recordfile:close()
    end
    rt.close_stream(self.dac)
    ffi.gc(self,nil)
end
function AudioPlayer_mt:get_stream_time()
    return rt.get_stream_time(self.dac)
end
function AudioPlayer_mt:set_stream_time(time)
    rt.set_stream_time(self.dac,time)

    local sf_node = self.root
    while true do
        sf_node = sf_node.next[0]
        if sf_node == nil then break end
        local sf = sf_node.sf
        if sf.resampler~=nil then
            sf = sf.resampler
        end
        if sf_node.timeoffset <= time then
            local frames = math.floor((time - sf_node.timeoffset) * sf_node.sf:samplerate())
            local res = sf:seek( frames, sndf.SEEK_SET) ;
            --if res==-1 then print("bad seeking in ",sf_node.sf) end
        end
    end

end
function AudioPlayer_mt:lock()
    --sdl.LockAudioDevice(self.device)
end
function AudioPlayer_mt:unlock()
    --sdl.UnlockAudioDevice(self.device)
end
function AudioPlayer_mt:start()
    rt.start_stream(self.dac)
end
function AudioPlayer_mt:stop()
    rt.stop_stream(self.dac)
end
local ancla_nodes = {}
local ancla_resam = {}
function AudioPlayer_mt:insert(filename,level,timeoffset)
    level = level or 1
    timeoffset = timeoffset or 0
    local sf = sndf.Sndfile(filename)
    --check channels and samplerate
    if sf:channels() ~= self.outpar[0].num_channels then
        print(filename,"has wrong number of channels",sf:channels())
        sf:close()
        return nil
    end
    local selfkey = tostring(self)
    if sf:samplerate() ~= self.sample_rate then
        local resamp = sf:resampler_create(nil, nil,self.resampler_input_cb)
        resamp:set_ratio(self.sample_rate/sf:samplerate())
        local anchor = ancla_resam[selfkey] or {}
        ancla_resam[selfkey] = anchor
        table.insert(anchor,resamp)
    end
    local node = ffi.new"sf_node[1]"
    local anchor = ancla_nodes[selfkey] or {}
    ancla_nodes[selfkey] = anchor
    table.insert(anchor,node)
    node[0].sf = sf
    node[0].level = level
    node[0].timeoffset = timeoffset
    
    node[0].next = self.root.next
    self:lock()
    self.root.next = node
    self:unlock()
    return node[0]
end
local recordfile_anchor
function AudioPlayer_mt:record(filename,format)
    assert(self.recordfile==nil,"AudioPlayer already has recording file.")
    local sf = sndf.Sndfile(filename,"w",self.sample_rate,self.outpar[0].num_channels,format)
    recordfile_anchor = sf
    self.recordfile = sf
    return sf
end
function AudioPlayer_mt:erase(node)
    self:lock()
    local sf_node = self.root
    while true do
        local prev = sf_node
        sf_node = sf_node.next[0]
        if sf_node == nil then break end
        if sf_node == node then
            --remove from ancla_nodes
            for i,nodeptr in ipairs(ancla_nodes) do
                if nodeptr[0]==node then
                    table.remove(ancla_nodes,i)
                    break
                end
            end
            prev.next = sf_node.next
            node.sf:close()
            break
        end
    end
    self:unlock()
end
function AudioPlayer_mt:nodes()
    local cur_node = self.root
    return function()
        local nextnode = cur_node.next[0]
        if nextnode == nil then return nil end
        cur_node = nextnode
        return nextnode
    end
end

local AudioPlayer = ffi.metatype("rt_audioplayer",AudioPlayer_mt)
return AudioPlayer
local filename = assert(arg[1], "\n\nERROR: filename is empty\n")
local bitdepth = tonumber(arg[2]) or 10   -- Illum mode
local save_to_pgm = arg[3] or false
local sep = "\n-------1-------2-------3-------4-------5-------6-------7-------8-------9-------!"
--

local function parse_raw(mem)
    local r = io.open(arg[1], "rb")
    local content = r:read("a")
    local size = r:seek()
    r:close()

    -- try to allocate
    local last = size * 8 // bitdepth
    mem[last] = 1 >> 0
    mem.to8bit = bitdepth - 8

    local pos = 1
    local step = size // 80 -- width of console window
    local next_step = step
    local mem_ptr = 1

    while pos < size do
        if     bitdepth == 16 then
            -- as is
            mem[mem_ptr], pos = string.unpack("H", content, pos)
            mem_ptr = mem_ptr + 1
        elseif bitdepth == 12 then
            -- 3 8-bit -> 2 12-bit, big endian
            local i1, i2, i3, o1, o2
            i1, pos = string.unpack("B", content, pos)
            i2, pos = string.unpack("B", content, pos)
            i3, pos = string.unpack("B", content, pos)
            --
            o1 = (i1 << 4) + (i2 >> 4)
            o2 = ((i2 & 0x0f) << 8) + i3
            --
            mem[mem_ptr+0] = o1
            mem[mem_ptr+1] = o2
            mem_ptr = mem_ptr + 2
        elseif bitdepth == 10 then
            -- 5 8-bit -> 4 10-bit, little endian
            local i1, i2, i3, i4, lsb, o1, o2, o3, o4
            i1,  pos = string.unpack("B", content, pos)
            i2,  pos = string.unpack("B", content, pos)
            i3,  pos = string.unpack("B", content, pos)
            i4,  pos = string.unpack("B", content, pos)
            lsb, pos = string.unpack("B", content, pos)
            --
            o1 = (i1 << 2) + ((lsb & 0x03) >> 0)
            o2 = (i2 << 2) + ((lsb & 0x0c) >> 2)
            o3 = (i3 << 2) + ((lsb & 0x30) >> 4)
            o4 = (i4 << 2) + ((lsb & 0xc0) >> 6)
            --
            mem[mem_ptr+0] = o1
            mem[mem_ptr+1] = o2
            mem[mem_ptr+2] = o3
            mem[mem_ptr+3] = o4
            mem_ptr = mem_ptr + 4
        elseif bitdepth == 8 then
            -- as is
            mem[mem_ptr], pos = string.unpack("B", content, pos)
            mem_ptr = mem_ptr + 1
        else
            assert(false, "\n\nERROR: unsupported bitdepth - " .. bitdepth .. "\n")
        end

        -- percentage
        if pos >= next_step then
            io.write(".")
            next_step = next_step + step
        end
    end
    content = nil
    io.write("\n")
end
--
local function convert_to_8bit(mem, pgm)
    local name = string.sub(filename, 1, -5)
    local head = ""

    if pgm then
        name = name .. ".pgm"
        head = "P5\n%d\n%d\n255\n"
        if     bitdepth == 10 then
            head = head:format(7728, 5368)
        elseif bitdepth == 12 then
            head = head:format(3280, 3280)
        else
            head = head:format(1, 1)
        end
    else
        name = name .. ".raw"
    end

    local w = assert(io.open(name, "w+b"))
    local count = #mem
    local shift = mem.to8bit
    local step = count // 80 -- width of console window
    local next_step = step

    w:write(head)
    for j = 1, count do
        local i = mem[j] >> shift -- fast divide
        w:write(string.char(i))

        -- percentage
        if j >= next_step then
            io.write(".")
            next_step = next_step + step
        end
    end

    w:close()
    io.write("\n")
end
--
local function demosaic(mem)
    -- TODO
end
--
--[[
local function save_mem(mem, color)
    local size = #mem
    local m = io.open("mem.raw", "w+b")
    local step = size // 80 -- width of console window
    local next_step = step

    if color and bitdepth == 10 then
        for y = 0, 5367 do
            for x = 1, 7728, 2 do
                local p1 = mem[y*7728+x+0] >> 2
                local p2 = mem[y*7728+x+1] >> 2 << 8
                if y & 1 == 0 then
                    -- GR
                    p1 = p1 << 8
                    p2 = p2 << 8
                end
                m:write(string.pack("I3", p1))
                m:write(string.pack("I3", p2))
            end
        end
    else
        for i = 1, size do
            m:write(string.pack("H", mem[i]))

            -- percentage
            if i >= next_step then
                io.write(".")
                next_step = next_step + step
            end
        end
    end

    m:close()
    io.write("\n")
end
--
local function load_mem(m)
    local size = m:seek("end") // 2
    m:seek("set")

    local mem = {}
    mem[size] = 0
    local step = size // 80 -- width of console window
    local next_step = step

    for i = 1, size, 8 do
        mem[i+0], mem[i+1] = string.unpack("H", m:read(4))
        mem[i+2], mem[i+3] = string.unpack("H", m:read(4))
        mem[i+4], mem[i+5] = string.unpack("H", m:read(4))
        mem[i+6], mem[i+7] = string.unpack("H", m:read(4))

        -- percentage
        if i >= next_step then
            io.write(".")
            next_step = next_step + step
        end
    end
    io.write("\n")
    return mem
end
--]]
--
local function timed_run(func, ...)
    local time = os.clock()
    local res, err = pcall(func, ...)
    print(os.clock() - time .. " sec\n")
    assert(res, err)
end

-------------------------------------------------------------------------------

local mem = {}
print(sep)

print("parse...")
timed_run(parse_raw, mem)

--print("save raw...")
--timed_run(save_mem, mem, color)

print("convert to 8 bit...")
timed_run(convert_to_8bit, mem, save_to_pgm)

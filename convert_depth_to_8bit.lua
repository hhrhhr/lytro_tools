local filename = assert(arg[1])
local ascii = arg[2] or false

local r

local function read_float(big_endian)
    local f
    if big_endian then
        f = string.unpack(">f", r:read(4))
    else
        f = string.unpack("<f", r:read(4))
    end
    return f
end

local width, height
for w, h in string.gmatch(filename, "_(%d+)x(%d+)") do
    width = w
    height = h
end
--print(width, height)

r = assert(io.open(filename, "rb"))
local count = r:seek("end") / 4
r:seek("set")
assert(width * height == count)


-- find minimax
local min, max, d = math.huge, 0.0, 0.0
for i = 1, count do
    local f = read_float()
    if min > f then min = f end
    if max < f then max = f end
end
--print("minimax: ", min, max)
local scale = 255.0 / (max - min)
r:seek("set")


-- prepare
local head = "P"
local name = filename:sub(1, -5)
if ascii then
    head = head .. "2\n"
    name = name .. "_ascii"
else
    head = head .. "5\n"
end
head = head .. "%d\n%d\n255\n"
name = name .. ".pgm"


-- convert
local w = assert(io.open(name, "w+b"))
w:write(head:format(width, height))

for i = 1, count do
    local f = (read_float() - min) * scale
    local b = math.modf(f)
    
    if ascii then
        w:write(string.format("%3d", b))
        if (i % 20) > 0 then
            w:write(" ")
        else
            w:write("\n")
        end
    else
        w:write(string.char(b))
    end
end

w:close()

r:close()

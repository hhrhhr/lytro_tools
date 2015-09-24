assert(_VERSION == "Lua 5.3")

local filename = assert(arg[1], "\n\nERROR: filename is empty\n")

local width, height
for w, h in string.gmatch(filename, "_(%d+)x(%d+)") do
    width = w
    height = h
end
--print(width, height)

local r = assert(io.open(filename, "rb"))
local count = r:seek("end") / 4
r:seek("set")
assert(width * height == count)


print("find minimax...")
local min, max, d = math.huge, 0.0, 0.0
for i = 1, count do
    local f = string.unpack("<f", r:read(4))
    if min > f then min = f end
    if max < f then max = f end
end
print(min .. " ... " .. max)
local scale = 255.0 / (max - min)
r:seek("set")


print("convert...")
local name = filename:gsub(".map", ".pgm")

local w = assert(io.open(name, "w+b"))
w:write(("P5\n%d\n%d\n255\n"):format(width, height))

for i = 1, count do
    local f = (string.unpack("<f", r:read(4)) - min) * scale
    local b = math.modf(f)
    w:write(string.char(b))
end

w:close()

r:close()

print("done.")

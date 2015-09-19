local OBJDEF = {}

---------------------------------------------------------------------------

local isArray  = { __tostring = function() return "JSON array"  end }    isArray.__index  = isArray
local isObject = { __tostring = function() return "JSON object" end }    isObject.__index = isObject

function OBJDEF:newArray(tbl)
    return setmetatable(tbl or {}, isArray)
end

function OBJDEF:newObject(tbl)
    return setmetatable(tbl or {}, isObject)
end

local function unicode_codepoint_as_utf8(codepoint)
    if codepoint <= 127 then
        return string.char(codepoint)

    elseif codepoint <= 2047 then
        local highpart = math.floor(codepoint / 0x40)
        local lowpart  = codepoint - (0x40 * highpart)
        return string.char(0xC0 + highpart,
            0x80 + lowpart)

    elseif codepoint <= 65535 then
        local highpart  = math.floor(codepoint / 0x1000)
        local remainder = codepoint - 0x1000 * highpart
        local midpart   = math.floor(remainder / 0x40)
        local lowpart   = remainder - 0x40 * midpart

        highpart = 0xE0 + highpart
        midpart  = 0x80 + midpart
        lowpart  = 0x80 + lowpart

        if ( highpart == 0xE0 and midpart < 0xA0 ) or
        ( highpart == 0xED and midpart > 0x9F ) or
        ( highpart == 0xF0 and midpart < 0x90 ) or
        ( highpart == 0xF4 and midpart > 0x8F )
        then
            return "?"
        else
            return string.char(highpart,
                midpart,
                lowpart)
        end

    else
        local highpart  = math.floor(codepoint / 0x40000)
        local remainder = codepoint - 0x40000 * highpart
        local midA      = math.floor(remainder / 0x1000)
        remainder       = remainder - 0x1000 * midA
        local midB      = math.floor(remainder / 0x40)
        local lowpart   = remainder - 0x40 * midB

        return string.char(0xF0 + highpart,
            0x80 + midA,
            0x80 + midB,
            0x80 + lowpart)
    end
end

function OBJDEF:onDecodeError(message, text, location, etc)
    if text then
        if location then
            message = string.format("%s at char %d of: %s", message, location, text)
        else
            message = string.format("%s: %s", message, text)
        end
    end

    if etc ~= nil then
        message = message .. " (" .. OBJDEF:encode(etc) .. ")"
    end

    if self.assert then
        self.assert(false, message)
    else
        assert(false, message)
    end
end

OBJDEF.onDecodeOfNilError  = OBJDEF.onDecodeError
OBJDEF.onDecodeOfHTMLError = OBJDEF.onDecodeError

local function grok_number(self, text, start, etc)
    local integer_part = text:match('^-?[1-9]%d*', start)
    or text:match("^-?0",        start)

    if not integer_part then
        self:onDecodeError("expected number", text, start, etc)
    end

    local i = start + integer_part:len()

    local decimal_part = text:match('^%.%d+', i) or ""

    i = i + decimal_part:len()

    local exponent_part = text:match('^[eE][-+]?%d+', i) or ""

    i = i + exponent_part:len()

    local full_number_text = integer_part .. decimal_part .. exponent_part
    local as_number = tonumber(full_number_text)

    if not as_number then
        self:onDecodeError("bad number", text, start, etc)
    end

    return as_number, i
end

local function grok_string(self, text, start, etc)

    if text:sub(start,start) ~= '"' then
        self:onDecodeError("expected string's opening quote", text, start, etc)
    end

    local i = start + 1 -- +1 to bypass the initial quote
    local text_len = text:len()
    local VALUE = ""
    while i <= text_len do
        local c = text:sub(i,i)
        if c == '"' then
            return VALUE, i + 1
        end
        if c ~= '\\' then
            VALUE = VALUE .. c
            i = i + 1
        elseif text:match('^\\b', i) then
            VALUE = VALUE .. "\b"
            i = i + 2
        elseif text:match('^\\f', i) then
            VALUE = VALUE .. "\f"
            i = i + 2
        elseif text:match('^\\n', i) then
            VALUE = VALUE .. "\n"
            i = i + 2
        elseif text:match('^\\r', i) then
            VALUE = VALUE .. "\r"
            i = i + 2
        elseif text:match('^\\t', i) then
            VALUE = VALUE .. "\t"
            i = i + 2
        else
            local hex = text:match('^\\u([0123456789aAbBcCdDeEfF][0123456789aAbBcCdDeEfF][0123456789aAbBcCdDeEfF][0123456789aAbBcCdDeEfF])', i)
            if hex then
                i = i + 6 -- bypass what we just read

                local codepoint = tonumber(hex, 16)
                if codepoint >= 0xD800 and codepoint <= 0xDBFF then
                    -- it's a hi surrogate... see whether we have a following low
                    local lo_surrogate = text:match('^\\u([dD][cdefCDEF][0123456789aAbBcCdDeEfF][0123456789aAbBcCdDeEfF])', i)
                    if lo_surrogate then
                        i = i + 6 -- bypass the low surrogate we just read
                        codepoint = 0x2400 + (codepoint - 0xD800) * 0x400 + tonumber(lo_surrogate, 16)
                    else
                        --
                    end
                end
                VALUE = VALUE .. unicode_codepoint_as_utf8(codepoint)

            else

                VALUE = VALUE .. text:match('^\\(.)', i)
                i = i + 2
            end
        end
    end

    self:onDecodeError("unclosed string", text, start, etc)
end

local function skip_whitespace(text, start)

    local _, match_end = text:find("^[ \n\r\t]+", start)
    if match_end then
        return match_end + 1
    else
        return start
    end
end

local grok_one -- assigned later

local function grok_object(self, text, start, etc)
    if text:sub(start,start) ~= '{' then
        self:onDecodeError("expected '{'", text, start, etc)
    end

    local i = skip_whitespace(text, start + 1) -- +1 to skip the '{'

    local VALUE = self.strictTypes and self:newObject { } or { }

    if text:sub(i,i) == '}' then
        return VALUE, i + 1
    end
    local text_len = text:len()
    while i <= text_len do
        local key, new_i
        key, new_i = grok_string(self, text, i, etc)

        i = skip_whitespace(text, new_i)

        if text:sub(i, i) ~= ':' then
            self:onDecodeError("expected colon", text, i, etc)
        end

        i = skip_whitespace(text, i + 1)

        local new_val
        new_val, new_i = grok_one(self, text, i)

        VALUE[key] = new_val

        i = skip_whitespace(text, new_i)

        local c = text:sub(i,i)

        if c == '}' then
            return VALUE, i + 1
        end

        if text:sub(i, i) ~= ',' then
            self:onDecodeError("expected comma or '}'", text, i, etc)
        end

        i = skip_whitespace(text, i + 1)
    end

    self:onDecodeError("unclosed '{'", text, start, etc)
end

local function grok_array(self, text, start, etc)
    if text:sub(start,start) ~= '[' then
        self:onDecodeError("expected '['", text, start, etc)
    end

    local i = skip_whitespace(text, start + 1) -- +1 to skip the '['
    local VALUE = self.strictTypes and self:newArray { } or { }
    if text:sub(i,i) == ']' then
        return VALUE, i + 1
    end

    local VALUE_INDEX = 1

    local text_len = text:len()
    while i <= text_len do
        local val, new_i = grok_one(self, text, i)

        VALUE[VALUE_INDEX] = val
        VALUE_INDEX = VALUE_INDEX + 1

        i = skip_whitespace(text, new_i)

        local c = text:sub(i,i)
        if c == ']' then
            return VALUE, i + 1
        end
        if text:sub(i, i) ~= ',' then
            self:onDecodeError("expected comma or '['", text, i, etc)
        end
        i = skip_whitespace(text, i + 1)
    end
    self:onDecodeError("unclosed '['", text, start, etc)
end

grok_one = function(self, text, start, etc)
    start = skip_whitespace(text, start)

    if start > text:len() then
        self:onDecodeError("unexpected end of string", text, nil, etc)
    end

    if text:find('^"', start) then
        return grok_string(self, text, start, etc)

    elseif text:find('^[-0123456789 ]', start) then
        return grok_number(self, text, start, etc)

    elseif text:find('^%{', start) then
        return grok_object(self, text, start, etc)

    elseif text:find('^%[', start) then
        return grok_array(self, text, start, etc)

    elseif text:find('^true', start) then
        return true, start + 4

    elseif text:find('^false', start) then
        return false, start + 5

    elseif text:find('^null', start) then
        return nil, start + 4

    else
        self:onDecodeError("can't parse JSON", text, start, etc)
    end
end


function OBJDEF:decode(text, etc)
    if type(self) ~= 'table' or self.__index ~= OBJDEF then
        OBJDEF:onDecodeError("JSON:decode must be called in method format", nil, nil, etc)
    end

    if text == nil then
        self:onDecodeOfNilError(string.format("nil passed to JSON:decode()"), nil, nil, etc)
    elseif type(text) ~= 'string' then
        self:onDecodeError(string.format("expected string argument to JSON:decode(), got %s", type(text)), nil, nil, etc)
    end

    if text:match('^%s*$') then
        return nil
    end

    if text:match('^%s*<') then
        -- Can't be JSON... we'll assume it's HTML
        self:onDecodeOfHTMLError(string.format("html passed to JSON:decode()"), text, nil, etc)
    end

    if text:sub(1,1):byte() == 0 or (text:len() >= 2 and text:sub(2,2):byte() == 0) then
        self:onDecodeError("JSON package groks only UTF-8, sorry", text, nil, etc)
    end

    local success, value = pcall(grok_one, self, text, 1, etc)

    if success then
        return value
    else
        if self.assert then
            self.assert(false, value)
        else
            assert(false, value)
        end
        return nil, value
    end
end

function OBJDEF.__tostring()
    return "JSON encode/decode package"
end

OBJDEF.__index = OBJDEF

function OBJDEF:new(args)
    local new = { }

    if args then
        for key, val in pairs(args) do
            new[key] = val
        end
    end

    return setmetatable(new, OBJDEF)
end

return OBJDEF:new()

local mp = require("mp")
local assdraw = require("mp.assdraw")
local mpopts = require("mp.options")

local options = {
    keybind = "M",
    message_duration = 1
}

local positions = {}
local ab = {}
looping = false

-- Start MIT licensed code
local write, writeIndent, writers, refCount;
persistence =
{
	store = function (path, ...)
		local file, e = io.open(path, "w");
		if not file then
			return error(e);
		end
		local n = select("#", ...);
		-- Count references
		local objRefCount = {}; -- Stores reference that will be exported
		for i = 1, n do
			refCount(objRefCount, (select(i,...)));
		end;
		-- Export Objects with more than one ref and assign name
		-- First, create empty tables for each
		local objRefNames = {};
		local objRefIdx = 0;
		file:write("-- Persistent Data\n");
		file:write("local multiRefObjects = {\n");
		for obj, count in pairs(objRefCount) do
			if count > 1 then
				objRefIdx = objRefIdx + 1;
				objRefNames[obj] = objRefIdx;
				file:write("{};"); -- table objRefIdx
			end;
		end;
		file:write("\n} -- multiRefObjects\n");
		-- Then fill them (this requires all empty multiRefObjects to exist)
		for obj, idx in pairs(objRefNames) do
			for k, v in pairs(obj) do
				file:write("multiRefObjects["..idx.."][");
				write(file, k, 0, objRefNames);
				file:write("] = ");
				write(file, v, 0, objRefNames);
				file:write(";\n");
			end;
		end;
		-- Create the remaining objects
		for i = 1, n do
			file:write("local ".."obj"..i.." = ");
			write(file, (select(i,...)), 0, objRefNames);
			file:write("\n");
		end
		-- Return them
		if n > 0 then
			file:write("return obj1");
			for i = 2, n do
				file:write(" ,obj"..i);
			end;
			file:write("\n");
		else
			file:write("return\n");
		end;
		if type(path) == "string" then
			file:close();
		end;
	end;

	load = function (path)
		local f, e;
		if type(path) == "string" then
			f, e = loadfile(path);
		else
			f, e = path:read('*a')
		end
		if f then
			return f();
		else
			return nil, e;
		end;
	end;
}

-- Private methods

-- write thing (dispatcher)
write = function (file, item, level, objRefNames)
	writers[type(item)](file, item, level, objRefNames);
end;

-- write indent
writeIndent = function (file, level)
	for i = 1, level do
		file:write("\t");
	end;
end;

-- recursively count references
refCount = function (objRefCount, item)
	-- only count reference types (tables)
	if type(item) == "table" then
		-- Increase ref count
		if objRefCount[item] then
			objRefCount[item] = objRefCount[item] + 1;
		else
			objRefCount[item] = 1;
			-- If first encounter, traverse
			for k, v in pairs(item) do
				refCount(objRefCount, k);
				refCount(objRefCount, v);
			end;
		end;
	end;
end;

-- Format items for the purpose of restoring
writers = {
	["nil"] = function (file, item)
			file:write("nil");
		end;
	["number"] = function (file, item)
			file:write(tostring(item));
		end;
	["string"] = function (file, item)
			file:write(string.format("%q", item));
		end;
	["boolean"] = function (file, item)
			if item then
				file:write("true");
			else
				file:write("false");
			end
		end;
	["table"] = function (file, item, level, objRefNames)
			local refIdx = objRefNames[item];
			if refIdx then
				-- Table with multiple references
				file:write("multiRefObjects["..refIdx.."]");
			else
				-- Single use table
				file:write("{\n");
				for k, v in pairs(item) do
					writeIndent(file, level+1);
					file:write("[");
					write(file, k, level+1, objRefNames);
					file:write("] = ");
					write(file, v, level+1, objRefNames);
					file:write(";\n");
				end
				writeIndent(file, level);
				file:write("}");
			end;
		end;
	["function"] = function (file, item)
			-- Does only work for "normal" functions, not those
			-- with upvalues or c functions
			local dInfo = debug.getinfo(item, "uS");
			if dInfo.nups > 0 then
				file:write("nil --[[functions with upvalue not supported]]");
			elseif dInfo.what ~= "Lua" then
				file:write("nil --[[non-lua function not supported]]");
			else
				local r, s = pcall(string.dump,item);
				if r then
					file:write(string.format("loadstring(%q)", s));
				else
					file:write("nil --[[function could not be dumped]]");
				end
			end
		end;
	["thread"] = function (file, item)
			file:write("nil --[[thread]]\n");
		end;
	["userdata"] = function (file, item)
			file:write("nil --[[userdata]]\n");
		end;
}
-- End MIT licensed code

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local message
message = function(text, duration)
    local ass = mp.get_property_osd("osd-ass-cc/0")
    ass = ass .. text
    return mp.osd_message(ass, duration or options.message_duration)
end

function drawMenu()
    local window_w, window_h = mp.get_osd_size()
    local ass = assdraw.ass_new()
    ass:new_event()
    ass:append(" \\N\\N")    
    ass:append("{\\b1}Multiloop{\\b0}\\N")
    ass:append("{\\b1}1{\\b0} set start time\\N")
    ass:append("{\\b1}2{\\b0} set end time\\N")
    ass:append("{\\b1}d{\\b0} duplicate last a-b point\\N")
    ass:append("{\\b1}s{\\b0} save positions to file\\N")
    ass:append("{\\b1}l{\\b0} loop\\N")
    ass:append("{\\b1}ESC{\\b0} hide\\N")
    mp.set_osd_ass(window_w, window_h, ass.text)
end

function clearMenu()
      local window_w, window_h = mp.get_osd_size()
      mp.set_osd_ass(window_w, window_h, "")
      mp.osd_message("", 0)
end

function setStartTime()
    local start_time = mp.get_property_number("time-pos")
    clearMenu()
    if #ab == 0 then
        table.insert(ab, start_time)
    else
        ab = {}
        table.insert(ab, start_time)
    end
    message("start time set")
end

function setEndTime()
    if #ab == 1 then
        local end_time = mp.get_property_number("time-pos")
        table.insert(ab, end_time)
        table.insert(positions, ab)
        ab = {}
        message("end time set")
    else
        message("you have to set a start time")
    end
    drawMenu()
end

function duplicateLastPoint()
    table.insert(positions, positions[#positions])
    message("point added!")
end

function savePositions()
    if #ab == 1 then
        message("ab point without an end time")
    elseif #positions == 0 then
        message("nothing to save")
    else
        local fn = mp.get_property("filename/no-ext")
        persistence.store(fn .. ".mab", positions)
        message("saved to file")
    end
end

function loopab(abpoint)
    mp.set_property_native("time-pos", abpoint[1])
    local tp = mp.get_property_number("time-pos")
    while tp < abpoint[2] do
        tp = mp.get_property_number("time-pos")
    end
end

function loop()
    clearMenu()
    local count = 1
    looping = true
    if #positions ~= 0 then
        while looping == true do
            loopab(positions[count])
            if count == #positions then
                count = 1
            else
                count = count + 1
            end
        end
    else
        message("you have to set some points first!")
        drawMenu()
    end
end

-- doesn't work as expected because apparently 
-- lua doesn't have keyboard interrupts
function endLoop()
    if looping == true then 
        looping = false
    end
    clearMenu()
end

function main()
    mp.add_forced_key_binding("1", "1", setStartTime)
    mp.add_forced_key_binding("2", "2", setEndTime)    
    mp.add_forced_key_binding("d", "d", duplicateLastPoint)        
    mp.add_forced_key_binding("s", "s", savePositions)    
    mp.add_forced_key_binding("l", "l", loop)    
    mp.add_forced_key_binding("ESC", "ESC", clearMenu)    
    
    local fn = mp.get_property("filename/no-ext")
    if file_exists(fn .. ".mab") == true then
        positions = persistence.load(fn .. ".mab")
    end
    
    drawMenu()
    
end
    
mp.add_key_binding(options.keybind, "display-multiloop", main)

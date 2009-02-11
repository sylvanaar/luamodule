--[[

This is an implemenation of the Lua Module API http://www.lua.org/manual/5.1/manual.html#pdf-module

It is a modified version of the one found here: http://www.keplerproject.org/compat/

Its reuse requires inclusion of this liscense:

Copyright © 2004-2006 The Kepler Project.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
associated documentation files (the "Software"), to deal in the Software without restriction, including 
without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.
]]



local dbg = function() end

--@debug@ 
local dbg = print 
--@end-debug@


local assert, error, getfenv, ipairs, loadfile, loadlib, pairs, setfenv, setmetatable, type = assert, error, getfenv, ipairs, loadfile, loadlib, pairs, setfenv, setmetatable, type
local find, format, gfind, gsub, sub = string.find, string.format, string.gfind, string.gsub, string.sub

--
-- avoid overwriting the package table if it's already there
--
package = package or {}
local _PACKAGE = package

package.path = "" -- Not used in WoW 
package.cpath = "" -- Not used in WoW

--
-- make sure require works with standard libraries
--
package.loaded = package.loaded or {}
package.loaded.debug = debug
package.loaded.string = string
package.loaded.math = math
--package.loaded.io = io
package.loaded.os = os
package.loaded.table = table 
package.loaded.base = _G
package.loaded.coroutine = coroutine
local _LOADED = package.loaded

--
-- avoid overwriting the package.preload table if it's already there
--
package.preload = package.preload or {}
local _PRELOAD = package.preload


--
-- check whether library is already loaded
--
local function loader_preload (name)
	assert (type(name) == "string", format (
		"bad argument #1 to `require' (string expected, got %s)", type(name)))
	assert (type(_PRELOAD) == "table", "`package.preload' must be a table")
	return _PRELOAD[name]
end

local function loader_WoWAddon (name)
    if name == nil or name == "" then return end

    local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(name)

    if not name then return end

	local loaded  = IsAddOnLoaded(addon)
	local isondemand = IsAddOnLoadOnDemand(addon)

    if loaded then
        return LoadAddOn
    elseif loadable and isondemand and enabled then
        return LoadAddOn
    end
end


local function libstubLoad(name)
    return _G.LibStub(name)
end

local function loader_LibStub(name)
    if not _G.LibStub then return end

    if LibStub:GetLibrary(lib,true) then
        return libstubLoad
    end
end

-- create `loaders' table
package.loaders = package.loaders or { loader_preload, loader_WoWAddon, loader_LibStub }
local _LOADERS = package.loaders

--
-- iterate over available loaders
--
local function load (name, loaders)
	-- iterate over available loaders
	assert (type (loaders) == "table", "`package.loaders' must be a table")
	for i, loader in ipairs (loaders) do
		local f = loader (name)
		if f then
			return f
		end
	end
	error (format ("module `%s' not found", name))
end

-- sentinel
local sentinel = function () end



--
-- new package.seeall function
--
function _PACKAGE.seeall (module)
	local t = type(module)
	assert (t == "table", "bad argument #1 to package.seeall (table expected, got "..t..")")
	local meta = getmetatable (module)
	if not meta then
		meta = {}
		setmetatable (module, meta)
	end
	meta.__index = _G
end


-- findtable
local function findtable (t, f)
	assert (type(f)=="string", "not a valid field name ("..tostring(f)..")")
	local ff = f.."."
	local ok, e, w = find (ff, '(.-)%.', 1)
	while ok do
		local nt = rawget (t, w)
		if not nt then
			nt = {}
			t[w] = nt
		elseif type(t) ~= "table" then
			return sub (f, e+1)
		end
		t = nt
		ok, e, w = find (ff, '(.-)%.', e+1)
	end
	return t
end


---Creates a Lua Module.
--If there is a table in package.loaded[name], this table is the module. 
--Otherwise, if there is a global table t with the given name, this table is the module. 
--Otherwise creates a new table t and sets it as the value of the global name and the value of package.loaded[name]. 
--This function also initializes t._NAME with the given name, t._M with the module (t itself), and t._PACKAGE with the package name (the full module name minus last component). 
--Finally, module sets t as the new environment of the current function and the new value of package.loaded[name], so that require returns t. 
--
--This function can receive optional options after the module name, where each option is a function to be applied over the module
-- @param modname The package name. If name is a compound name (that is, one with components separated by dots), module creates (or reuses, if they already exist) tables for each component. 
-- For instance, if name is a.b.c, then module stores the module table in field c of field b of global a
-- @param ... usually starts with the pattern visibility package.seeall e.g module("foo", package.seeall)
function _G.module (modname, ...)
	local ns = _LOADED[modname]
	if type(ns) ~= "table" then
		ns = findtable (_G, modname)
		if not ns then
			error (string.format ("name conflict for module '%s'", modname))
		end
		_LOADED[modname] = ns
	end
	if not ns._NAME then
		ns._NAME = modname
		ns._M = ns
		ns._PACKAGE = gsub (modname, "[^.]*$", "")
	end
	setfenv (2, ns)
	for i, f in ipairs ({...}) do
		f (ns)
	end
end

---Loads the given module. The function starts by looking into the package.loaded table to determine whether modname is already loaded. 
-- If it is, then require returns the value stored at package.loaded[modname]. Otherwise, it tries to find a loader for the module. 
--
--To find a loader, require is guided by the package.loaders array. By changing this array, we can change how require looks for a module. 
-- The following explanation is based on the default configuration for package.loaders. 
--
--First require queries package.preload[modname]. If it has a value, this value (which should be a function) is the loader. 
--
--Once a loader is found, require calls the loader with a single argument, modname. 
-- If the loader returns any value, require assigns the returned value to package.loaded[modname]. 
-- If the loader returns no value and has not assigned any value to package.loaded[modname], then require assigns true to this entry. 
-- In any case, require returns the final value of package.loaded[modname]. 
--
--If there is any error loading or running the module, or if it cannot find any loader for the module, then require signals an error. 
--@param modname The package name.
function _G.require (modname)
	assert (type(modname) == "string", format (
		"bad argument #1 to `require' (string expected, got %s)", type(name)))
	local p = _LOADED[modname]
	if p then -- is it there?
		if p == sentinel then
			error (format ("loop or previous error loading module '%s'", modname))
		end
		return p -- package is already loaded
	end
	local init = load (modname, _LOADERS)
	_LOADED[modname] = sentinel
	local actual_arg = _G.arg
	_G.arg = { modname }
	local res = init (modname)
	if res then
		_LOADED[modname] = res
	end
	_G.arg = actual_arg
	if _LOADED[modname] == sentinel then
		_LOADED[modname] = true
	end
	return _LOADED[modname]
end
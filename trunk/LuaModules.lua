--@debug@ 
local dbg = print 
--@end-debug@
package = package or {} 
package.seeall = package.seeall or {__index = _G, __tostring="Global Visibiltity"} 
package.preload = package.preload or {}
package.loaders = package.loaders or {}


--- Create a Lua Module
--Creates a module. If there is a table in package.loaded[name], this table is the module. Otherwise, if there is a global table t with the given name, this table is the module. Otherwise creates a new table t and sets it as the value of the global name and the value of package.loaded[name]. This function also initializes t._NAME with the given name, t._M with the module (t itself), and t._PACKAGE with the package name (the full module name minus last component; see below). Finally, module sets t as the new environment of the current function and the new value of package.loaded[name], so that require returns t. 
--
--If name is a compound name (that is, one with components separated by dots), module creates (or reuses, if they already exist) tables for each component. For instance, if name is a.b.c, then module stores the module table in field c of field b of global a. 
--
--This function can receive optional options after the module name, where each option is a function to be applied over the module
-- @param name The package name. If name is a compound name (that is, one with components separated by dots), module creates (or reuses, if they already exist) tables for each component. For instance, if name is a.b.c, then module stores the module table in field c of field b of global a
-- @param vs The pattern visibility (package.seeall, or nil)
function module(name, vs) 
    dbg("\nModule Defined: "..name.."  with visibitlity "..tostring(vs)) 
    local P = package.loaded[name] or _G[name] 
    if not p then
        P = setmetatable({}, vs)
        _G[name], package.loaded[name] = P, P

        P._NAME = name
        P._M = P
        P._PACKAGE = name -- no a.b.c form (easy case)
    end
    setfenv(2, P) 
end 

---Loads the given module. The function starts by looking into the package.loaded table to determine whether modname is already loaded. 
-- If it is, then require returns the value stored at package.loaded[modname]. Otherwise, it tries to find a loader for the module. 
--
--To find a loader, require is guided by the package.loaders array. By changing this array, we can change how require looks for a module. 
-- The following explanation is based on the default configuration for package.loaders. 
--
--First require queries package.preload[modname]. If it has a value, this value (which should be a function) is the loader. 
-- Otherwise require searches for a Lua loader using the path stored in package.path. If that also fails, it searches for a C loader using the path stored in package.cpath. 
-- If that also fails, it tries an all-in-one loader (see package.loaders). 
--
--Once a loader is found, require calls the loader with a single argument, modname. 
-- If the loader returns any value, require assigns the returned value to package.loaded[modname]. 
--  If the loader returns no value and has not assigned any value to package.loaded[modname], then require assigns true to this entry. 
--  In any case, require returns the final value of package.loaded[modname]. 
--
--If there is any error loading or running the module, or if it cannot find any loader for the module, then require signals an error. 
--@param name The package name.
function require(name)
    dbg("  Requirment For: %s by %s"):format(name, tostring(_NAME)) 
    local P = package.loaded[name]
    if P then return P end

    local result

    P = package.preload[name]
    if P then 
        result = P(name)
    end

    if not result then
        for _, L in ipairs(package.loaders) do
            result = L(name)
            if result then break end
        end
    end

    if result or package.loaded[name] then 
        package.loaded[name] = result or true
    
        return package.loaded[name]
    end

    error("require() does not support any loaders")
end
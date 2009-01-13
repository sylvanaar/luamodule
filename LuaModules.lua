--@debug@ 
local dbg = print 
--@end-debug@
package = {} 
package.seeall = {__index = _G} 
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
function require(name)
    dbg("  Requirment For: %s by %s"):format(name, tostring(_NAME)) 
    local P = package.loaded[name]
    if P then return P end

    error("require() does not support any loaders")
end
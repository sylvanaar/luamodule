-- For package.preload
local function LibStubLoader(lib)
    package.loaded[lib] = LibStub(maj)
    return package.loaded[lib]  
end
    
-- Create a package loader for LibStub
package.loaders[#package.loaders+1] = function(lib)
    for maj, min in LibStub:IterateLibraries() do
        if maj == lib then
            return LibStubLoader(lib)
        end
    end
end

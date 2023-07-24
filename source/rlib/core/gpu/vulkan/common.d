module rlib.core.gpu.vulkan.common;
import std.exception;
import std.conv;
import std.traits;
import std.string;

package import erupted;

uint toVKVersion(VS)(VS verString) if (isSomeString!VS)
{
    if(verString.length == 0)
    {
        return 0;
    }

    uint count;
    uint[4] versions;
    
    for(; count < versions.length; ++count)
    {
        auto pIndex = verString.indexOf('.');
        
        if(pIndex == -1)
        {
            versions[count] = verString.to!uint;
            verString = null;
            break;
        }
        
        versions[count] = verString[0..pIndex].to!uint;

        if(verString.length == pIndex + 1)
        {
            verString = null;
            break;
        }

        verString = verString[pIndex + 1 .. $];
    }

    enforce(verString is null, "version string contain more than 4 numbers.");
    
    switch(count)
    {
        case 1:
            return VK_MAKE_API_VERSION(0, 0, versions[0], 0);
        case 2:
            return VK_MAKE_API_VERSION(0, versions[0], versions[1], 0);
        case 3:
            return VK_MAKE_API_VERSION(0, versions[0], versions[1], versions[2]);
        case 4:
            return VK_MAKE_API_VERSION(versions[0], versions[1], versions[2], versions[3]);
        default:
            assert(0);
    }
}

package void enforceVK(VkResult res)
{
    enforce(res == VkResult.VK_SUCCESS, res.to!string);
}

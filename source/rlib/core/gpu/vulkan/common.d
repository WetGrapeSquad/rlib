module rlib.core.gpu.vulkan.common;
import std.exception;
import std.conv;
import std.traits;
import std.string;
import semver;

package import erupted;

package uint toVkVersion(string verString)
{
    SemVer ver = SemVer(verString);

    return VK_MAKE_API_VERSION(0,
        ver.query(VersionPart.MAJOR),
        ver.query(VersionPart.MINOR),
        ver.query(VersionPart.PATCH));
}

package uint toVkVersion(const SemVer ver)
{
    return VK_MAKE_API_VERSION(0,
        ver.query(VersionPart.MAJOR),
        ver.query(VersionPart.MINOR),
        ver.query(VersionPart.PATCH));
}

package SemVer vkVersionToSemVer(uint ver)
{
    // ( variant << 29 ) | ( major << 22 ) | ( minor << 12 ) | patch;
    uint major, minor, patch;
    major = (ver >> 22) & 0x7F;
    minor = (ver >> 12) & 0x3FF;
    patch = ver & 0xFFF;
    
    return SemVer(major, minor, patch);
}

package void enforceVk(VkResult res)
{
    enforce(res == VkResult.VK_SUCCESS, res.to!string);
}

@("Vulkan Common")
unittest
{
    assert(VK_MAKE_API_VERSION(0, 1, 0, 0) == toVkVersion("1.0.0"));
    assert(VK_MAKE_API_VERSION(0, 1, 0, 0) == toVkVersion("1"));
}

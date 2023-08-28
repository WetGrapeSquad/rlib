module rlib.core.gpu.vulkan.instance;
package import rlib.core.gpu.vulkan.common;
import rlib.core.utils.atomic;
import std.exception;
import std.string;
import std.format;
import std.conv : to;
import rlib.core.utils.logger;
import semver;
package import erupted;
package import erupted.vulkan_lib_loader;

__gshared const SemVer gVkHeaderVersion;

__gshared const SemVer gPlatformVkVer;
__gshared bool gVkLoaded;

shared static this()
{
    uint tmp;
    
    gVkHeaderVersion = vkVersionToSemVer(VK_HEADER_VERSION_COMPLETE);
    if (loadGlobalLevelFunctions)
    {
        gVkLoaded = true;

        vkEnumerateInstanceVersion(&tmp);
        gPlatformVkVer = vkVersionToSemVer(tmp);

        log.debugging("Vulkan global functions loaded successfully");
        log.debugging("The application is built with the Vulkan version: " ~ gVkHeaderVersion.toString);
        log.debugging("Platform Vulkan version: " ~ gPlatformVkVer.toString);
    }
    else
    {
        log.error("Couldn't load Vulkan");
    }
}

class Instance
{
    this(
        const SemVer reqVer,
        string engName = null, SemVer engVersion = SemVer(0, 0, 0),
        string appName = null, SemVer appVer = SemVer(0, 0, 0)
    )
    {
        scope (success)
        {
            this.mInstanced = true;
        }
        scope (failure)
        {
            this.mInstanced = false;
        }

        if (!gVkLoaded)
        {
            immutable criticalMessage = "Impossible to create instance vulkan, because vulkan is not loaded.";
            log.critical(criticalMessage);
            throw new Exception(criticalMessage);
        }

        log.debugging("Trying to create Vulkan instance. Required version " ~ reqVer.toString);
        {
            auto errors = this.checkVersions(reqVer);
            if (errors !is null)
            {

                foreach (error; errors)
                {
                    log.error(error);
                }

                string error = "Failed to create instance vulkan";

                log.error(error);
                throw new Exception(error);
            }
        }

        // dfmt off
        VkApplicationInfo appInfo = {
            pApplicationName: (appName is null) ? appName.toStringz : "untitled".toStringz,
            pEngineName: (engName is null) ? engName.toStringz : "untitled".toStringz,
            apiVersion: toVkVersion(reqVer),
            engineVersion: toVkVersion(engVersion),
            applicationVersion: toVkVersion(appVer)
        };
        // dfmt on

        VkInstanceCreateInfo createInfo = {pApplicationInfo: &appInfo,};

        auto result = vkCreateInstance(&createInfo, null, &this.mVkInstance);
        if (result != VkResult.VK_SUCCESS)
        {
            string criticalMessage = "Failed to create vulkan instance with error: " ~ result.to!string;
            log.error(criticalMessage);
            throw new Exception(criticalMessage);
        }
        log.debugging("Vulkan instance has been successfully created");
        log.debugging("Number of vulkan instance: " ~ (++this.gInstanceCount).to!string);

        if (!this.gLoadedILF)
        {
            synchronized (Instance.classinfo)
            {
                if (!this.gLoadedILF)
                {
                    loadInstanceLevelFunctions(this.mVkInstance);
                    log.debugging("Vulkan instance level functions loaded successfully");
                }
                this.gLoadedILF = true;
            }
        }
    }

    VkInstance nativeInstance()
    {
        return this.mVkInstance;
    }

    /** 
     * Checks `reqVer` for compatibility with vulkan header and platform.
     * Returns: null if no errors, or error list.
     */
    static string[] checkVersions(const SemVer reqVer)
    {
        string[] errors = null;

        if (reqVer > gVkHeaderVersion)
        {
            string message =
                "The engine tries to work with version of vulkan (%s) above the vulkan header versions (%s)";
            message = message.format(reqVer, gVkHeaderVersion);
            errors = [message];
        }

        if (reqVer > gPlatformVkVer)
        {
            string message =
                "The engine tries to work with version of vulkan (%s) above the version supported by the platform (%s)";
            message = message.format(reqVer, gPlatformVkVer);
            errors ~= message;
        }
        return errors;
    }

    ~this()
    {
        if (this.mInstanced)
        {
            vkDestroyInstance(this.mVkInstance, null);
            this.mInstanced = false;
            --this.gInstanceCount;
        }
    }

    bool mInstanced = false;
    __gshared bool gLoadedILF; // instance level functions.
    shared static Atomic!size_t gInstanceCount;

    VkInstance mVkInstance;
}

@("Instance")
unittest
{
    import core.memory;

    try
    {
        Instance instance = new Instance(gVkHeaderVersion.increment(VersionPart.PATCH));
    }
    catch (Exception)
    {
        SemVer ver = cast(SemVer)((gVkHeaderVersion < gPlatformVkVer) ? gVkHeaderVersion: gPlatformVkVer);
        Instance instance1 = new Instance(ver);
        Instance instance2 = new Instance(ver);
        __delete(instance1);
        __delete(instance2);
        return;
    }
    throw new Exception("The instance is not working normally");
}

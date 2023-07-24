module rlib.core.gpu.vulkan.instance;
package import rlib.core.gpu.vulkan.common;
package import erupted;



class VKInstance 
{
    private this()
    {
        import erupted.vulkan_lib_loader;
        loadGlobalLevelFunctions;
        
        VkApplicationInfo appInfo = {
            pApplicationName: "Vulkan Test",
            pEngineName: "EvoEngine",
            apiVersion: VK_HEADER_VERSION_COMPLETE,
            engineVersion: VK_MAKE_API_VERSION(0,0,0,1),
        };
    }


    VkInstance instance;
}
module rlib.core.gpu.vulkan.device;
import rlib.core.utils.atomic;
import rlib.core.gpu.vulkan.common;
import std.string;
import semver;
import erupted;
import rlib.core.gpu.vulkan.instance;

shared class PhysicalDevice
{
    struct DeviceExtension
    {    
        string extensionName;
        SemVer specVersion;
    }
    struct LayerProperties 
    {
        string layerName;
        string layerDescription;
        SemVer specVersion;
        SemVer implementationVersion;
    }

    private this(VkPhysicalDevice device)
    {
        this.mVkPhysicalDevice = cast(shared VkPhysicalDevice)device;
        uint tmp;
        VkLayerProperties[] layerProperties;
        VkExtensionProperties[] extensionProperties;

        vkEnumerateDeviceLayerProperties(device, &tmp, null);
        layerProperties.length = tmp;
        vkEnumerateDeviceLayerProperties(device, &tmp, layerProperties.ptr);

        foreach(ref layer; layerProperties)
        {
            LayerProperties properties = {
                layerName: cast(string)fromStringz(layer.layerName),
                layerDescription: cast(string)fromStringz(layer.description),
                specVersion: vkVersionToSemVer(layer.specVersion),
                implementationVersion: vkVersionToSemVer(layer.implementationVersion)
            };
            this.mLayers[properties.layerName] = properties;

            vkEnumerateDeviceExtensionProperties(device, layer.layerName.ptr, &tmp, null);
            extensionProperties.length = tmp;
            vkEnumerateDeviceExtensionProperties(device, layer.layerName.ptr, &tmp, extensionProperties.ptr);

            DeviceExtension[string]* extensionMap = &(this.mExtensions[properties.layerName] = null);

            foreach(ref property; extensionProperties)
            {
                DeviceExtension extension = {
                    extensionName: cast(string)fromStringz(property.extensionName),
                    specVersion: vkVersionToSemVer(property.specVersion)
                };
                (*extensionMap)[extension.extensionName] = extension;
            }
        }
    }

    public static PhysicalDevice[] enumeratePhysicalDevices(Instance instance)
    {
        if (this.mDevices is null)
        {
            synchronized (this.classinfo)
            {
                if (this.mDevices is null)
                {
                    uint deviceCount;
                    VkPhysicalDevice[] vkDevices;
                    PhysicalDevice[] devices;

                    vkEnumeratePhysicalDevices(instance.nativeInstance, &deviceCount, null);
                    vkDevices.length = deviceCount;
                    devices.length = deviceCount;

                    vkEnumeratePhysicalDevices(instance.nativeInstance, &deviceCount, vkDevices.ptr);

                    foreach (i, ref device; devices)
                    {
                        device = new shared PhysicalDevice(vkDevices[i]);
                    }
                    this.mDevices = devices;
                }
            }
        }
        return mDevices;
    }

    private UnShared!(DeviceExtension[string][string]) mExtensions;
    private UnShared!(LayerProperties[string]) mLayers;
    private __gshared PhysicalDevice[] mDevices = null;
    private shared VkPhysicalDevice mVkPhysicalDevice;
}

@("PhysicalDevice")
unittest
{
    Instance instance = new Instance(Instance.getSupportVersion);
    PhysicalDevice[] devices = PhysicalDevice.enumeratePhysicalDevices(instance);
}
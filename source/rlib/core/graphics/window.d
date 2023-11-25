module rlib.core.graphics.window;
import rlib.core.utils.math;
import std.string : toStringz;
import rlib.core.graphics.common;
import sdl.events;
import bindbc.wgpu.funcs;

class Window
{
    this(string title = "untitled", UIVec2 winSize = [1280, 720])
    {
        this._winSize = winSize;
        this._sdlWindow = SDL_CreateWindow(toStringz(title),
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
            winSize.x, winSize.y,
            SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
        this._title = title;

        SDL_SysWMinfo wmInfo;
        SDL_GetWindowWMInfo(this._sdlWindow, &wmInfo);
        this._surface = createSurface(wgpuInstance, wmInfo);

        WGPUAdapter adapter;
        WGPURequestAdapterOptions adapterOpts = {
            nextInChain: null,
            compatibleSurface: this._surface
        };
        wgpuInstanceRequestAdapter(wgpuInstance, &adapterOpts, &requestAdapterCallback, cast(void*)&adapter);
        //dfmt off
        WGPUDevice device;
        WGPUDeviceExtras deviceExtras = {
            chain: {
                next: null,
                sType: cast(WGPUSType) WGPUNativeSType.DeviceExtras
            }, // nativeFeatures: WGPUNativeFeature.TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES,
                // label: "Device",
            tracePath: null,
        };
        WGPURequiredLimits limits = {
            nextInChain: null,
            limits: {
            }
        };
        WGPUDeviceDescriptor deviceDesc = {
            nextInChain: cast(const(WGPUChainedStruct)*)&deviceExtras,
            requiredFeaturesCount: 0,
            requiredFeatures: null,
            requiredLimits: &limits
        };
        //dfmt on
        wgpuAdapterRequestDevice(adapter, &deviceDesc, &requestDeviceCallback, cast(void*)&device);
    }

    void testLoop()
    {
        SDL_Event event;
        bool isRunning = true;

        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
            case SDL_WINDOWEVENT:
                if (event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED)
                {
                    this._winSize = [event.window.data1, event.window.data2];
                    //swapChain = createSwapChain(winWidth, winHeight);
                }
                break;
            case SDL_QUIT:
                isRunning = false;
                break;
            default:
                break;
            }
        }
    }

    ~this()
    {
        wgpuSurfaceRelease(this._surface);
        SDL_DestroyWindow(this._sdlWindow);
    }

    private string _title;
    private UIVec2 _winSize;
    private SDL_Window* _sdlWindow;
    private WGPUSurface _surface;
}

@("Window")
unittest
{
    import rlib.core.memory;

    Window window = New!Window;
    window.testLoop();
    Delete(window);
}

WGPUSurface createSurface(WGPUInstance instance, SDL_SysWMinfo wmInfo)
{
    WGPUSurface surface;
    version (Windows)
    {
        if (wmInfo.subsystem == SDL_SYSWM_WINDOWS)
        {
            auto win_hwnd = wmInfo.info.win.window;
            auto win_hinstance = wmInfo.info.win.hinstance;
            WGPUSurfaceDescriptorFromWindowsHWND sfdHwnd = {
                chain: {
                    next: null,
                    sType: WGPUSType.SurfaceDescriptorFromWindowsHWND},
                    hinstance: win_hinstance,
                    hwnd: win_hwnd
                };
                WGPUSurfaceDescriptor sfd = {
                    label: null,
                    nextInChain: cast(const(WGPUChainedStruct)*)&sfdHwnd
            };
            surface = wgpuInstanceCreateSurface(instance, &sfd);
        }
        else
        {
            log.critical("Unsupported subsystem, sorry");
            throw new Exception("Unsupported subsystem, sorry");
        }
    }
    else version (linux)
    {
        if (wmInfo.subsystem == SDL_SYSWM_WAYLAND)
        {
            // TODO: support Wayland
            log.critical("Unsupported subsystem, sorry");
            throw new Exception("Unsupported subsystem, sorry");
        }
        // System might use XCB so SDL_SysWMinfo will contain subsystem SDL_SYSWM_UNKNOWN. Although, X11 still can be used to create surface
    else
        {
            auto x11_display = wmInfo.info.x11.display;
            auto x11_window = wmInfo.info.x11.window;
            WGPUSurfaceDescriptorFromXlibWindow sfdX11 = {
                chain: {
                    next: null,
                    sType: WGPUSType.SurfaceDescriptorFromXlibWindow
                },
                display: x11_display,
                window: x11_window
                };
                WGPUSurfaceDescriptor sfd = {
                    label: null,
                    nextInChain: cast(const(WGPUChainedStruct)*)&sfdX11
            };
            surface = wgpuInstanceCreateSurface(instance, &sfd);
        }
    }
    else version (OSX)
    {
        // Needs test!
        SDL_Renderer* renderer = SDL_CreateRenderer(window.sdlWindow, -1, SDL_RENDERER_PRESENTVSYNC);
        auto metalLayer = SDL_RenderGetMetalLayer(renderer);

        WGPUSurfaceDescriptorFromMetalLayer sfdMetal = {
            chain: {next: null,
            sType: WGPUSType.SurfaceDescriptorFromMetalLayer
                },
            layer: metalLayer};
            WGPUSurfaceDescriptor sfd = {
                label: null,
                nextInChain: cast(const(WGPUChainedStruct)*)&sfdMetal
        };
        surface = wgpuInstanceCreateSurface(instance, &sfd);

        SDL_DestroyRenderer(renderer);
    }
    return surface;
}

import std.stdio;

extern (C)
{
    void requestAdapterCallback(WGPURequestAdapterStatus status, WGPUAdapter adapter, const(char)* message, void* userdata)
    {
        if (status == WGPURequestAdapterStatus.Success)
            *cast(WGPUAdapter*) userdata = adapter;
        else
        {
            writeln(status);
            writeln(message);
        }
    }

    void requestDeviceCallback(WGPURequestDeviceStatus status, WGPUDevice device, const(char)* message, void* userdata)
    {
        if (status == WGPURequestDeviceStatus.Success)
            *cast(WGPUDevice*) userdata = device;
        else
        {
            writeln(status);
            writeln(message);
        }
    }
}

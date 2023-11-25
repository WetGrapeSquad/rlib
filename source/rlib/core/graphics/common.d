module rlib.core.graphics.common;
public import rlib.core.utils.logger;
package import bindbc.wgpu;
package import bindbc.sdl;
import loader = bindbc.loader.sharedlib;
import std.conv: text;

__gshared const bool sdlInited;
__gshared const bool wgpuLoaded;

package __gshared WGPUInstanceDescriptor wgpuInstanceDesc;
package __gshared WGPUInstance wgpuInstance;

extern(C) void logCallback(WGPULogLevel level, const(char)* msg, void* user_data)
{
    const(char)[] level_message;
    switch(level)
    {
        case WGPULogLevel.Error: log.error(text("WebGPU ", msg)); break;
        case WGPULogLevel.Warn: log.warning(text("WebGPU ", msg)); break;
        case WGPULogLevel.Info: log.information(text("WebGPU ", msg)); break;
        case WGPULogLevel.Debug: log.debugging(text("WebGPU ", msg)); break;
        case WGPULogLevel.Trace: log.notice(text("WebGPU ", msg)); break;
        default: break;
    }
}

shared static this()
{
    auto _wgpuSupport = loadWGPU();
	
    if (loader.errors.length)
	{
        log.error("The loader encountered errors!");
        foreach(info; loader.errors)
        {
            log.error(text(info.error, ": ", info.message));
        }
	}
    
    WGPULogLevel logLevel = WGPULogLevel.Debug; 

    wgpuSetLogLevel(logLevel);
    wgpuSetLogCallback(&logCallback, null);
    
    log.information("WGPU loaded!");

    wgpuInstance = wgpuCreateInstance(&wgpuInstanceDesc);

    log.debugging("WGPU instance created!");
    
    auto _sdlSupport = loadSDL();
	
    if (loader.errors.length)
	{
        log.error("The loader encountered errors!");
        foreach(info; loader.errors)
        {
            log.error(text(info.error, ": ", info.message));
        }
	}

	version(OSX)
	{
		SDL_SetHint(SDL_HINT_RENDER_DRIVER, toStringz("metal"));
	}
    if (SDL_Init(SDL_INIT_EVERYTHING) == -1)
	{
		log.error(text("failed to init SDL. ", SDL_GetError()));
	}

    sdlInited = true;
    log.information("SDL inited!");
}
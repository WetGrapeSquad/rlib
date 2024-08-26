#!/usr/bin/env dub
/+ dub.sdl:
    name "build"
    dependency "colorize" version="~>1.0.5"
+/
module thirdparty.build;

import std.process;
import colorize : fg, color, cwriteln, cwritefln;
import std.file;
import std.format;
import std.string;
import std.conv;
import io = std.stdio;

int build_cmake(string folder, string config = "Release", string target)
{
    string fullprojectinfo = text(" ~master: target for configuration [",
        config.color(fg.magenta), "], target [",
        ((target !is null) ? target : "default").color(fg.light_blue),
        "] using cmake"
    );

    cwriteln("Staring ".rightJustify(13).color(fg.light_green), folder, fullprojectinfo);

    version (Windows)
    {
        string project_path = environment["THIRDPARTY_DIR"] ~ '\\' ~ folder ~ '\\' ~ folder;
        string build_path = environment["THIRDPARTY_DIR"] ~ '\\' ~ folder ~ "\\.build\\";
    }
    else
    {
        string project_path = environment["THIRDPARTY_DIR"] ~ '/' ~ folder ~ '\\' ~ folder;
        string build_path = environment["THIRDPARTY_DIR"] ~ '/' ~ folder ~ "/.build/";
    }

    mkdirRecurse(build_path);

    cwriteln("Generate ".rightJustify(13).color(fg.green), folder, " cmake project");
    auto result = executeShell(
        "cmake -S \"%s\" -B \"%s\" -D CMAKE_BUILD_TYPE:STRING=%s".format(
            project_path,
            build_path,
            config
    ));
    if (result.status != 0)
    {
        cwriteln("Error ".rightJustify(13).color(fg.magenta), "while generate cmake project: ");
        io.writeln(result.output);
        return 1;
    }

    cwriteln("Building ".rightJustify(13).color(fg.light_green), folder);
    result = executeShell(
        "cmake --build \"%s\" --config %s%s".format(
            build_path,
            config,
            (target !is null) ? " --target " ~ target : null
    ));

    if (result.status != 0)
    {
        cwriteln("Error ".rightJustify(13).color(fg.magenta), "while generate cmake project: ");
        io.writeln(result.output);
        return 1;
    }
    return 0;
}

int build_cmake_static(string folder, string[] libs, string config = "Release", string target)
{
    if (build_cmake(folder, config, target) != 0)
    {
        return 1;
    }

    version (Windows)
    {
        string output_path = environment["THIRDPARTY_DIR"] ~ '\\' ~ folder ~ "\\.out\\";
        string build_path = environment["THIRDPARTY_DIR"] ~ '\\' ~ folder ~ "\\.build\\";
    }
    else
    {
        string output_path = environment["THIRDPARTY_DIR"] ~ '/' ~ folder ~ "/.out/";
        string build_path = environment["THIRDPARTY_DIR"] ~ '/' ~ folder ~ "/.build/";
    }

    mkdirRecurse(output_path);

    foreach (lib; libs)
    {
        version (Windows)
        {
            string filename = lib ~ ".lib";
        }
        else
        {
            string filename = "lib" ~ lib ~ ".a";
        }

        cwriteln("Copy-File ".rightJustify(13).color(fg.green), filename.color(fg.light_cyan));
        try
        {
            version (Windows)
            {
                copy(
                    "%s\\%s\\%s".format(build_path, config, filename),
                    "%s\\%s".format(output_path, filename)
                );
            }
            else
            {
                copy(
                    "%s/%s".format(build_path, filename),
                    "%s/%s".format(output_path, filename)
                );
            }
        }
        catch (Exception)
        {
            version (Windows)
            {
                cwriteln("Error ".rightJustify(13).color(fg.magenta), "while copy ",
                    "%s\\%s\\%s".format(build_path, config, filename));
            }
            else
            {
                cwriteln("Error ".rightJustify(13).color(fg.magenta), "while copy ",
                    "%s/%s".format(build_path, filename));
            }
            return 1;
        }
    }
    return 0;
}

int main()
{
    version (Windows)
    {
        return build_cmake_static("mimalloc", ["mimalloc-static"], "Debug", "mimalloc-static");
    }
    else
    {
        return build_cmake_static("mimalloc", ["mimalloc-debug"], "Debug", "mimalloc-static");
    }
}

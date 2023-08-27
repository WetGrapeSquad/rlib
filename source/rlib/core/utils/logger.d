module rlib.core.utils.logger;
public import rlib.core.memory.dispose;
public import singlog;

version(unittest)
{
    enum LogFileName = "./logs.txt";

    shared static this()
    {   
        import std.file;
        singlog.log.output(singlog.log.output.syslog.stderr.stdout.file)    // write to syslog, stderr/stdout and file
            .level(singlog.log.level.debugging)                             // logging level
            .color(true)                                                    // color text output
            .file(LogFileName);                                             // set file name.
    }
}
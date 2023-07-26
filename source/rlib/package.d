module rlib;
public import rlib.core;

/**
* This shared static constructor set coverage output directory.
*/
version(D_Coverage) shared static this() {
    import core.runtime : dmd_coverDestPath;
    import std.file : exists, mkdir;

    enum COVPATH = "coverage";

    if(!COVPATH.exists) // Compiler won't create this directory
    {
        COVPATH.mkdir; // That's why it should be done manually
    }
    dmd_coverDestPath(COVPATH); // Now all *.lst files are written into ./coverage/ directory
}

version(unittest)
{
    enum LogFileName = "./logs.txt";

    shared static this()
    {   
        import std.file;
        import singlog;
        log.output(log.output.syslog.stderr.stdout.file)    // write to syslog, standard error/output streams and file
            .level(log.level.debugging)                   // logging level
            .color(true)                                    // color text output
            .file(LogFileName);
        if(!LogFileName.exists || !isFile(LogFileName))
        {
            
        }
        
        log.alert("Test");
        log.critical("Test");
        log.error("Test");
        log.warning("Test");
        log.notice("Test");
        log.information("Test");
        log.debugging("Test");
    }
}
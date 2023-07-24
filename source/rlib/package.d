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
        COVPATH.mkdir; // That's why it should be done manually
    dmd_coverDestPath(COVPATH); // Now all *.lst files are written into ./coverage/ directory
}

shared static this()
{
    
}
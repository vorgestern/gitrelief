
import std/[strutils, parsecfg]

switch("path", "deps/httpbeast_fork/src")
switch("path", "deps/jester_fork")
switch("path", "deps/npeg/src")
switch("path", "deps/checksums/src")
switch("path", "src")
switch("warning", "UnusedImport:off")

switch("nimcache", "bb/nimcache")

var OUTDIR="bb"

if fileexists "config.cfg":
        let cfg=loadconfig "config.cfg"
        let X=cfg.getsectionvalue("Build", "OUTDIR")
        if X!="": OUTDIR=X

# Startergui is a GUI-program, that allows launching and terminating several servers in different
# directories, for example in worktrees. It is implemented for gtk3, but further development is
# on hold until a good binding is available.

# task starter, "starter release build":
#         switch("define", "release")
#         switch("out", "gitreliefstarter")
#         switch("outdir", OUTDIR)
#         setcommand "c", "startergui/startergui.nim"

task server, "server release build":
        switch("define", "release")
        switch("outdir", OUTDIR)
        setcommand "c", "src/gitrelief.nim"

task ttfollow, "test page follow":
        switch("outdir", "bb")
        setcommand "r", "src/page/follow.nim"

task tthelper, "test helper":
        switch("outdir", "bb")
        setcommand "r", "src/helper.nim"

task ttdiff, "test page diff":
        switch("outdir", "bb")
        setcommand "r", "src/page/diff.nim"

task demo1, "gtkdemo1 build":
        switch("outdir", "bb")
        setcommand "c", "startergui/gtkdemo1.nim"

task demo2, "gtkdemo2 build":
        switch("outdir", "bb")
        setcommand "c", "startergui/gtkdemo2.nim"

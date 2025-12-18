
import strutils

switch("path", "deps/httpbeast_fork/src")
switch("path", "deps/jester_fork")
switch("path", "deps/npeg")
switch("path", "deps/checksums/src")
switch("path", "src")
switch("warning", "UnusedImport:off")

switch("nimcache", "bb/nimcache")

var OUTDIR="bb"
if existsenv "OUTDIR": OUTDIR=getenv "OUTDIR"
if fileexists "OUTDIR":
        let k=readfile "OUTDIR";
        if k.len>0: OUTDIR=split(k, '\n')[0]

task starter, "starter release build":
        switch("out", "gitreliefstarter")
        switch("outdir", OUTDIR)
        setcommand "c", "startergui/startergui.nim"

task server, "server release build":
        switch("outdir", OUTDIR)
        setcommand "c", "src/gitrelief.nim"

task ttfollow, "test page follow":
        switch("outdir", "bb")
        setcommand "r", "src/page/follow.nim"

task tthelper, "test helper":
        switch("outdir", "bb")
        setcommand "r", "src/helper.nim"

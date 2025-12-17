
switch("path", "deps/httpbeast_fork/src")
switch("path", "deps/jester_fork")
switch("path", "deps/npeg")
switch("path", "deps/checksums/src")
switch("path", "src")
switch("warning", "UnusedImport:off")

switch("nimcache", "bb/nimcache")

var OUTDIR="bb"
if existsenv "ROBINSON": OUTDIR=getenv("ROBINSON") & "/userbin/"
if existsenv "OUTDIR": OUTDIR=getenv "OUTDIR"

task starter, "starter release build":
        switch("out", "gitreliefstarter")
        switch("outdir", OUTDIR)
        setcommand "c", "startergui/startergui.nim"

task server, "server release build":
        switch("outdir", OUTDIR)
        setcommand "c", "src/gitrelief.nim"

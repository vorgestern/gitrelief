
import std/tables
import std/[osproc, strutils, streams]

# import std/[strformat, strscans, times, os, locks]

proc process_diff()=
    let p=startprocess("git", args=["log", "-10", """--format="> %ai %h p%p \"%an\" \"%s\"""""], options={poUsePath})
    let pipe=outputstream(p)
    echo "process_diff"
    var cl: string
    while not atend(pipe):
        var s=pipe.readstr(1)
        case s[0]
        of char 13, char 10:
            cl=strip(cl)
            if cl.len()>0:
                echo "== "&cl
                cl=""
        else: cl.add s[0]

proc git_log*(A: Table[string,string]): string=
    result="<h1>Hier ist git_log()</h1>"
    # for k,v in A: result.add("<p>"&k&"="&v&"</p>")
    process_diff()

# =====================================================================

import npeg

type
    Dict = Table[string, string]
    Entry=object
        datum, zeit, hash, parent: string

let parser=peg("entry", e: Entry):
    datum <- {'0'..'9','-'}[10]
    zeit <- {'0'..'9', ':'}[8]
    zone <- '+' * 4
    hash <- {'0'..'9', 'a'..'f'}[7]
    parent <- {'0'..'9', 'a'..'f'}[7]
    entry <- "> " * @>datum * @>zeit * @zone * @>hash * @'p' * ? >parent:
        e.datum= $1
        e.zeit= $2
        e.hash= $3
        if capture.len>4:
            e.parent= $4

const demooutput="""
> 2025-10-30 01:18:26 +0100 cb955c3 pe849cbf \"vorgestern\" \"alias\"
> 2025-10-30 01:18:13 +0100 e849cbf pb55621a \"vorgestern\" \"gitrelief: Auswertung von query-Argumenten (Demo)\"
> 2025-10-30 00:59:09 +0100 b55621a p1bd2286 \"vorgestern\" \"Anpassung an Submodul jester_fork\"
> 2025-10-29 21:32:14 +0100 1bd2286 p6ffb97f \"vorgestern\" \"Anpassung an commits in Submodulen\"
> 2025-10-29 21:03:59 +0100 6ffb97f p6fb1704 \"vorgestern\" \"alias\"
> 2025-10-29 21:03:31 +0100 6fb1704 p640d3ce \"vorgestern\" \"Nachtrag\"
> 2025-10-29 19:58:07 +0100 640d3ce p505519f \"vorgestern\" \"Httpbeast_fork als Submodul hinzugefügt\"
> 2025-10-29 19:43:43 +0100 505519f pd137133 \"vorgestern\" \"ignore\"
> 2025-10-29 19:37:35 +0100 d137133 p7c78e2a \"vorgestern\" \"Jester_fork als Submodul hinzugefügt.\"
> 2025-10-28 20:32:50 +0100 7c78e2a p \"vorgestern\" \"Start\"
"""

proc parsertest(inp: string)=
    let L=split(inp, '\n')
    for k in L:
        var e: Entry
        let r=parser.match(k, e)
        if r.ok:
            echo "~~~ " & k & "\n\tmatched " & $e
        else:
            echo "~~~ " & k & "\n\tfailed"

when isMainModule:
    parsertest demooutput

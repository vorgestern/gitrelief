
import std/tables
import std/[osproc, strutils, streams]
import npeg

# import std/[strformat, strscans, times, os, locks]

# https://stackoverflow.com/questions/49196841/warning-matchiter-is-not-gc-safe-as-it-accesses-x-which-is-a-global-using-g
# Verwendung von {.threadvar.} (thread-local-storage)
# Das läuft darauf hinaus, den Parser einmal für jeden Thread zu erzeugen (was eigentlich nicht nötig sein sollte, da er const ist.)
# Da wir auf die Threaderzeugung keinen Einfluss haben, ist das ohnehin keine Option.

type
    Entry=object
        datum, zeit, hash, parent, user, subject: string

# const parser=peg("entry", e: Entry):

let logentryparser=peg("entry", e: Entry):
    utfchar <- utf8.any
    datum <- {'0'..'9','-'}[10]
    zeit <- {'0'..'9', ':'}[8]
    zone <- '+' * 4
    hash <- {'0'..'9', 'a'..'f'}[7]
    parent <- 'p' * ? {'0'..'9', 'a'..'f'}[7]
    noquote <- {1..33, 35..255} # Der ASCII-Code von " ist 34.
    wp <- +noquote
    entry <- '>' * @>datum * @>zeit * @zone * @>hash * @ >parent * @ '"' * >wp * '"' * @ '"' * >wp * '"':
        e.datum= $1
        e.zeit= $2
        e.hash= $3
        e.parent=substr($4, 1)
        e.user= $5
        e.subject= $6

let logentryparser1234{.used.}=peg("entry", e: Entry):
    # datum <- {'0'..'9','-'}[10]
    datum <- 10
    zeit <- {'0'..'9', ':'}[8]
    zone <- '+' * 4
    hash <- {'0'..'9', 'a'..'f'}[7]
    parent <- 'p' * ? {'0'..'9', 'a'..'f'}[7]
    # entry <- @>datum:
    entry <- "> " * >datum:
        e.datum= $1

proc process_log(): seq[Entry]=
    let p=startprocess("git", args=["log", "-10", """--format=> %ai %h p%p "%an" "%s""""], options={poUsePath})
    let pipe=outputstream(p)
    var cl: string
    while not atend(pipe):
        var s=pipe.readstr(1)
        case s[0]
        of char 13, char 10:
            cl=strip(cl)
            if cl.len()>0:
                var e: Entry
                {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                    let r=logentryparser.match(cl, e)
                    if not r.ok:
                        e.datum=""
                        e.zeit=""
                        e.subject=cl
                result.add e
                cl=""
        else: cl.add s[0]

proc git_log*(A: Table[string,string]): string=
    var cmd="""git log -10 --format=> %ai %h p%p "%an" "%s""""
    result="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="/gitrelief.css">
<title></title>
</head>
<body>
<table>
<tr><th>Navigate</th><th>Command</th></tr>
<tr><td><a href='/'>Start</a></td><td>""" & $cmd & """</td></tr>
</table>
<p></p>
<table>"""
    let X=process_log()
    for e in X:
        if e.datum!="": result.add "<tr><td>"&e.datum&" "&e.zeit&"</td><td>"&e.user&"</td><td>"&e.subject&"</td></tr>"
        else:           result.add "<tr><td>fail</td><td></td><td></td><td>"&e.subject&"</td></tr>"
    result.add "</table></body></html>"

# =====================================================================

# import unicode, npeg/lib/utf8

const demooutput{.used.}="""
> 2025-10-30 01:18:26 +0100 cb955c3 pe849cbf "vorgestern" "alias"
> 2025-10-30 01:18:13 +0100 e849cbf pb55621a "vorgestern" "gitrelief: Auswertung von query-Argumenten (Demo)"
> 2025-10-30 00:59:09 +0100 b55621a p1bd2286 "vorgestern" "Anpassung an Submodul jester_fork"
> 2025-10-29 21:32:14 +0100 1bd2286 p6ffb97f "vorgestern" "Anpassung an commits in Submodulen"
> 2025-10-29 21:03:59 +0100 6ffb97f p6fb1704 "vorgestern" "alias"
> 2025-10-29 21:03:31 +0100 6fb1704 p640d3ce "vorgestern" "Nachtrag"
> 2025-10-29 19:58:07 +0100 640d3ce p505519f "vorgestern" "Httpbeast_fork als Submodul hinzugefügt"
> 2025-10-29 19:43:43 +0100 505519f pd137133 "vorgestern" "ignore"
> 2025-10-29 19:37:35 +0100 d137133 p7c78e2a "vorgestern" "Jester_fork als Submodul hinzugefügt."
> 2025-10-28 20:32:50 +0100 7c78e2a p "vorgestern" "Start" """

when isMainModule:

    proc parsertest(inp: string)=
        let L=split(inp, '\n')
        for k in L:
            var e: Entry
            let r=logentryparser.match(k, e)
            if r.ok:
                echo k & "\n\tmatched " & $e
            else:
                echo k & "\tfailed"

    parsertest demooutput

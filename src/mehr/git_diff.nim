
import std/tables
import std/[osproc, strutils, streams]
import npeg

type
    Entry=object
        zeile: string

func htmlescape(s: string): string=
    replace(s, "<", "&lt;")

proc git_diff*(Args: Table[string,string]): string=

    let gitargs=block:
        var A= @["diff", "-U999999"]
        if Args.contains "a":
            var arg=Args["a"]
            if Args.contains "b":
                arg.add ".."&Args["b"]
            A.add arg
        elif Args.contains "b":
            A.add ".."&Args["b"]
        if Args.contains "path":
            A.add "--"
            A.add Args["path"]
        A

    let entries=block:
        var entries: seq[Entry]
        const diffentryparser=peg("entry", e: Entry):
            path <- +{1..31, 33..255}
            hash <- +{'0'..'9', 'a'..'f'}
            flags <- +{'0'..'9'}
            num <- +{'0'..'9'}
            diff <- "diff --git" * @>path * @>path:
                e.zeile="=== diff " & $1 & " === " & $2
            index <- "index" * @>hash * ".." * @>hash * @flags:
                e.zeile="=== index " & $1 & "===" & $2
            aaa <- "---" * @>path:
                e.zeile="=== apath: " & $1
            bbb <- "+++" * @>path:
                e.zeile="=== bpath: " & $1
            atat <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num:
                e.zeile="=== arange=" & $1 & ".." & $2 & " brange=" & $3 & ".." & $4
            sonst <- >(*1) * !1:
                e.zeile= $1
            entry <- >diff | >index | >aaa | >bbb | >atat | >sonst
        # Starte git und parse die Ausgabe zeilenweise in die Sequenz entries.
        let p=startprocess("git", args=gitargs, options={poUsePath})
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
                        let r=diffentryparser.match(cl, e)
                        if not r.ok: e.zeile="??????"
                    entries.add e
                    cl=""
            else: cl.add s[0]
        entries

    var cmd="git"
    for a in gitargs: cmd=cmd & " " & a

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
<p></p>"""
    # for k,v in gitargs: result.add "<p>" & $k & "=" & $v & "</p>"
    result.add "<table class='diff'>"
    for e in entries:
        result.add "\n<tr><td>" & htmlescape(e.zeile) & "</td></tr>"
    result.add "</table>"
    result.add "</body></html>"


import std/tables
import std/[osproc, strutils, streams]
import npeg

type
    Entry=object
        zeile: string
        na, nb: int
    NABR=enum N, A, B, R
    FileSection=object
        case kind: NABR
        of N:
            nzeilen: seq[string]
        of A:
            azeilen: seq[string]
        of B:
            bzeilen: seq[string]
        of R:
            razeilen, rbzeilen: seq[string]
    FileEntry=object
        apath, bpath: string
        ahash, bhash: string
        content: seq[FileSection]

proc addline(S: var FileSection, z: string): bool=
    if z.len<1: return false
    let num=case S.kind
    of N: S.nzeilen.len
    of A: S.azeilen.len
    of B: S.bzeilen.len
    of R: S.razeilen.len
    let
        k=z[0]
        z1=substr(z,1)
    case k
    of '-':
        if num==0: S=FileSection(kind: A, azeilen: @[])
        if S.kind==A: S.azeilen.add z1
        return S.kind==A
    of '+':
        if num==0: S=FileSection(kind: B, bzeilen: @[])
        if S.kind==B:
            S.bzeilen.add z1
            return true
        elif S.kind==A:
            let temp=S.azeilen
            S=FileSection(kind: R, razeilen: temp, rbzeilen: @[z1])
            return true
        elif S.kind==R:
            S.rbzeilen.add z1
            return true
        else: return false
    of ' ':
        if num==0: S=FileSection(kind: N, nzeilen: @[])
        if S.kind==N:
            S.nzeilen.add z1
            return true
        else: return false
    else:
        # error
        return false

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

    let (entries, Entries)=block:
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
                e.na=parseint($2)-parseint($1)+1
                e.nb=parseint($4)-parseint($3)+1
                e.zeile="=== arange=" & $1 & ".." & $2 & " brange=" & $3 & ".." & $4 & " ==> na=" & $e.na & ", nb=" & $e.nb
            sonst <- >(*1) * !1:
                e.zeile= $1
            entry <- >diff | >index | >aaa | >bbb | >atat | >sonst
        # Starte git und parse die Ausgabe zeilenweise in die Sequenz entries.
        let p=startprocess("git", args=gitargs, options={poUsePath})
        let pipe=outputstream(p)
        var entries: seq[Entry]
        var
            cl: string
            na=0
            nb=0
            Entries: seq[FileEntry]
            Section: FileSection
        while not atend(pipe):
            var s=pipe.readstr(1)
            case s[0]
            of char 13, char 10:
                if cl.len()>0:
                    if Entries.len==0:
                        Entries.add FileEntry()
                        # Section=undefined
                    if na>0 or nb>0:
                        let ok=Section.addline cl
                        if not ok:
                            Entries[^1].content.add Section
                            case cl[0]
                            of '+':
                                Section=FileSection(kind: B)
                                Section.bzeilen.add cl
                            of '-':
                                Section=FileSection(kind: A)
                                Section.azeilen.add cl
                            of ' ':
                                Section=FileSection(kind: N)
                                Section.nzeilen.add cl
                            else:
                                # error
                                discard

                        if cl[0]=='+':
                            dec nb
                            entries.add Entry(zeile: "_b " & strip(cl))
                        elif cl[0]=='-':
                            dec na
                            entries.add Entry(zeile: "a_ " & strip(cl))
                        else:
                            dec na
                            dec nb
                            entries.add Entry(zeile: "ab " & strip(cl))
                    else:
                        cl=strip(cl)
                        var e: Entry
                        {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                            let r=diffentryparser.match(cl, e)
                            if not r.ok: e.zeile="??????"
                        entries.add e
                        if e.na>0: na=e.na
                        if e.nb>0: nb=e.nb
                    cl=""
            else: cl.add s[0]
        (entries, Entries)

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
    # for e in entries:
    #     result.add "\n<tr><td>" & htmlescape(e.zeile) & "</td></tr>"
    for fileentry in Entries:
        result.add "\n<tr><td>" & $fileentry.content.len & "</td></tr>"
        for section in fileentry.content:
            result.add "\n<tr><td>" & $section.kind & "</td></tr>"
    result.add "</table>"
    result.add "</body></html>"

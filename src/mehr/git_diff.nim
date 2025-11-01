
import std/tables
import std/[osproc, strutils, streams]
import npeg

type
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
        sections: seq[FileSection]

proc numlines(S: FileSection): int=
    case S.kind
    of N: S.nzeilen.len
    of A: S.azeilen.len
    of B: S.bzeilen.len
    of R: S.razeilen.len

proc addline(S: var FileSection, z: string): bool=
    if z.len<1: return false
    let
        neu=numlines(S)==0
        k=z[0]
        z1=substr(z,1)
    case k
    of '-':
        if neu: S=FileSection(kind: A, azeilen: @[])
        if S.kind==A: S.azeilen.add z1
        return S.kind==A
    of '+':
        if neu: S=FileSection(kind: B, bzeilen: @[])
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
        if neu: S=FileSection(kind: N, nzeilen: @[])
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

    let Entries=block:
        type
            parsercontext=object
                na, nb: int
                fe: ptr seq[FileEntry]
        const diffentryparser=peg("entry", e: parsercontext):
            path <- +{1..31, 33..255}
            hash <- +{'0'..'9', 'a'..'f'}
            flags <- +{'0'..'9'}
            num <- +{'0'..'9'}
            diff <- "diff --git" * @>path * @>path:
                add(e.fe[], FileEntry())
            index <- "index" * @>hash * ".." * @>hash * @flags:
                e.fe[^1].ahash= $1
                e.fe[^1].bhash= $2
            aaa <- "---" * @>path:
                e.fe[^1].apath= $1
            bbb <- "+++" * @>path:
                e.fe[^1].bpath= $1
            atat <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num:
                e.na=parseint($2)-parseint($1)+1
                e.nb=parseint($4)-parseint($3)+1
            sonst <- >(*1) * !1:
                discard
            entry <- >diff | >index | >aaa | >bbb | >atat | >sonst
        # Starte git und parse die Ausgabe zeilenweise in die Sequenz entries.
        let p=startprocess("git", args=gitargs, options={poUsePath})
        let pipe=outputstream(p)
        var
            cl: string
            Entries: seq[FileEntry]
            na, nb: int
        while not atend(pipe):
            var s=pipe.readstr(1)
            case s[0]
            of char 13, char 10:
                if cl.len()>0:
                    if na>0 or nb>0:
                        if Entries[^1].sections.len==0: Entries[^1].sections.add FileSection()
                        let added=Entries[^1].sections[^1].addline cl
                        if not added:
                            case cl[0]
                            of '+': Entries[^1].sections.add FileSection(kind: B, bzeilen: @[cl])
                            of '-': Entries[^1].sections.add FileSection(kind: A, azeilen: @[cl])
                            of ' ': Entries[^1].sections.add FileSection(kind: N, nzeilen: @[cl])
                            else:
                                # error
                                discard
                        case cl[0]
                        of '+': dec nb
                        of '-': dec na
                        else:
                            dec na
                            dec nb
                    else:
                        cl=strip(cl)
                        {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                            var e=parsercontext(fe: addr Entries)
                            if diffentryparser.match(cl, e).ok:
                                if e.na>0 or e.nb>0:
                                    na=e.na
                                    nb=e.nb
                            else:
                                # error
                                # e.zeile="??????"
                                discard
                    cl=""
            else: cl.add s[0]
        Entries

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
"""
    result.add "<p>Anzahl Dateien: " & $Entries.len & "</p>"
    for fileentry in Entries:
        result.add "\n<p>Changes to " & fileentry.apath.substr(2) & "</p>"
        result.add "<table class='diff'>"
        result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
        result.add "\n<tr><th>" & fileentry.ahash & "</th><th>" & fileentry.bhash & "</th></tr>"
        var
            a=0
            b=0
        for section in fileentry.sections:
            case section.kind
            of N:
                for z in section.nzeilen:
                    inc a
                    inc b
                    if z.len==0: result.add "\n<tr><td class='Ncmp'><span>" & $a & "</span>&nbsp;</td><td><span></span>" & $b & "</span></td></tr>"
                    else:        result.add "\n<tr><td class='Ncmp'><span>" & $a & "</span>" & htmlescape(z) & "</td><td><span>" & $b & "</span></tr>"
            of A:
                result.add "\n<tr><td class='Acmp'>"
                for z in section.azeilen:
                    inc a
                    result.add "<span>" & $a & "</span>" & htmlescape(z) & "\n"
                result.add "</td><td/></tr>"
            of B:
                result.add "\n<tr><td/><td class='Bcmp'>"
                for z in section.bzeilen:
                    inc b
                    result.add "<span>" & $b & "</span>" & htmlescape(z) & "\n"
                result.add "</td></tr>"
            of R:
                let A=block:
                    var X: string
                    for z in section.razeilen:
                        inc a
                        X.add "<span>" & $a & "</span>" & htmlescape(z) & "\n"
                    X
                let B=block:
                    var X: string
                    for z in section.rbzeilen:
                        inc b
                        X.add "<span>" & $b & "</span>" & htmlescape(z) & "\n"
                    X
                result.add "\n<tr><td class='Acmp'>" & A & "</td><td class='Bcmp'>" & B & "</td></tr>"
        result.add "</table>"
    result.add "</body></html>"

# =====================================================================

when isMainModule:

    let output=git_diff(toTable({"nix":"nix"}))
    echo output

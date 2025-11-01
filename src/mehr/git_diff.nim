
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
        content: seq[FileSection]

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
            PL=object
                na, nb: int
                fe: ptr seq[FileEntry]
        const diffentryparser=peg("entry", e: PL):
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
            Section: FileSection
            na, nb: int
        while not atend(pipe):
            var s=pipe.readstr(1)
            case s[0]
            of char 13, char 10:
                if cl.len()>0:
                    if Entries.len==0:
                        Section=FileSection()
                    if na>0 or nb>0:
                        # echo ">>> ", cl
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
                        elif cl[0]=='-':
                            dec na
                        else:
                            dec na
                            dec nb
                        if na==0 and nb==0:
                            Section=FileSection()
                    else:
                        cl=strip(cl)
                        {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                            var e=PL(fe: addr Entries)
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
        if numlines(Section)>0: Entries[^1].content.add Section
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
    # for k,v in gitargs: result.add "<p>" & $k & "=" & $v & "</p>"
    for fileentry in Entries:
        result.add "\n<p>Changes to " & fileentry.apath.substr(2) & "</p>"
        result.add "<table class='diff'>"
        result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
        result.add "\n<tr><th>" & fileentry.ahash & "</th><th>" & fileentry.bhash & "</th></tr>"
        for section in fileentry.content:
            # result.add "\n<tr><td>" & $section.kind & "</td></tr>"
            case section.kind
            of N:
                for z in section.nzeilen:
                    if z.len==0: result.add "\n<tr><td class='Ncmp'>&nbsp;</td></tr>"
                    else:        result.add "\n<tr><td class='Ncmp'>" & htmlescape(z) & "</td></tr>"
            of A:
                for z in section.azeilen: result.add "\n<tr><td class='Acmp'>" & htmlescape(z) & "</td></tr>"
            of B:
                for z in section.bzeilen: result.add "\n<tr><td class='Bcmp'>" & htmlescape(z) & "</td></tr>"
            of R:
                let A=block:
                    var X: string
                    for z in section.razeilen: X.add htmlescape(z)&"\n"
                    X
                let B=block:
                    var X: string
                    for z in section.rbzeilen: X.add htmlescape(z)&"\n"
                    X
                result.add "\n<tr><td class='Acmp'>" & A & "</td><td class='Bcmp'>" & B & "</td></tr>"
        result.add "</table>"
    result.add "</body></html>"

# =====================================================================

when isMainModule:

    let output=git_diff(toTable({"nix":"nix"}))
    echo output

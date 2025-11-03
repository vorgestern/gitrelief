
import std/[tables, strformat]
import std/[osproc, strutils, streams]
import npeg

func htmlescape(s: string): string=replace(s, "<", "&lt;")

const html_template="""
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="{cssurl}">
<title>{htmlescape title}</title>
</head>
<body>
<table>
<tr><th>Navigate</th><th>Command</th></tr>
<tr><td><a href='/'>Start</a></td><td>{htmlescape cmd}<td></td></tr>
</table>
{content}
</body></html>
"""

type
    FileOp=enum Other, Modified, Deleted, Added
    NABR=enum N, A, B, R
    FileSection=object
        case kind: NABR
        of N, A, B:
            zeilen: seq[string]
        of R:
            razeilen, rbzeilen: seq[string]
    FileEntry=object
        op: FileOp
        apath, bpath: string
        sections: seq[FileSection]

func `$`(X: FileEntry): string=
    case X.op
    of Modified: fmt"Modified{'\t'}{X.apath} {X.sections.len} Abschnitte"
    of Deleted:  fmt"Deleted {'\t'}{X.apath} {X.sections.len} Abschnitte"
    of Added:    fmt"Added   {'\t'}{X.bpath} {X.sections.len} Abschnitte"
    of Other:    fmt"Other   {'\t'}'{X.apath}' '{X.bpath}' {X.sections.len} Abschnitte"

func numlines(S: FileSection): int=
    case S.kind
    of N, A, B: S.zeilen.len
    of R: S.razeilen.len

proc addline(S: var FileSection, z: string): bool=
    if z.len<1: return false
    let
        neu=numlines(S)==0
        k=z[0]
        z1=substr(z,1)
    case k
    of '-':
        if neu: S=FileSection(kind: A, zeilen: @[])
        if S.kind==A: S.zeilen.add z1
        return S.kind==A
    of '+':
        if neu: S=FileSection(kind: B, zeilen: @[])
        if S.kind==B:
            S.zeilen.add z1
            return true
        elif S.kind==A:
            let temp=S.zeilen
            S=FileSection(kind: R, razeilen: temp, rbzeilen: @[z1])
            return true
        elif S.kind==R:
            S.rbzeilen.add z1
            return true
        else: return false
    of ' ':
        if neu: S=FileSection(kind: N, zeilen: @[])
        if S.kind==N:
            S.zeilen.add z1
            return true
        else: return false
    else:
        # error
        return false

proc parse_patch(patch: seq[string]): seq[FileEntry]=
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
            # echo "diff ", $1, $2
            add(e.fe[], FileEntry())
            e.fe[^1].apath= $1
            e.fe[^1].bpath= $2
        index <- "index" * @>hash * ".." * @>hash * @flags:
            e.fe[^1].op=Modified
        aaa <- "---" * @>path:
            e.fe[^1].apath= $1
        bbb <- "+++" * @>path:
            e.fe[^1].bpath= $1
        newfile <- "new file mode" * @>flags:
            e.fe[^1].op=Added
        deletedfile <- "deleted file mode" * @>flags:
            e.fe[^1].op=Deleted
        atat <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num * @"@@":
            e.na=parseint $2
            e.nb=parseint $4
        atat1 <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * @"@@":
            e.na=parseint($2)
            e.nb=1
        atat2 <- "@@" * @'-' * >num * @'+' * >num * @"@@":
            e.na=1
            e.nb=1
        sonst <- >(*1) * !1:
            discard
        entry <- >diff | >index | >newfile | >deletedfile | >aaa | >bbb | >atat | >atat1 | >atat2 | >sonst

    var
        na=0
        nb=0

    for z in patch:
        if na>0 or nb>0:
            if result[^1].sections.len==0: result[^1].sections.add FileSection()
            let added=result[^1].sections[^1].addline z
            if not added:
                let z1=substr(z, 1)
                case z[0]
                of '+': result[^1].sections.add FileSection(kind: B, zeilen: @[z1])
                of '-': result[^1].sections.add FileSection(kind: A, zeilen: @[z1])
                of ' ': result[^1].sections.add FileSection(kind: N, zeilen: @[z1])
                else:
                    # error
                    discard
            case z[0]
            of '+': dec nb
            of '-': dec na
            else:
                dec na
                dec nb
        else:
            {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                var e=parsercontext(fe: addr result)
                if diffentryparser.match(strip z, e).ok:
                    if e.na>0 or e.nb>0:
                        na=e.na
                        nb=e.nb
                else:
                    # error
                    # e.zeile="??????"
                    discard

proc format_html_toc(Patches: seq[FileEntry], ahash, bhash: string): string=
    result.add "<p>Anzahl Dateien: " & $Patches.len & "</p>"
    result.add "<table>"
    for index,entry in Patches:
        case entry.op:
        of Modified: result.add fmt"<tr><td>{entry.op}</td><td><a href='/action/git_diff?a={ahash}&b={bhash}&path={entry.bpath.substr(2)}'>{entry.bpath.substr(2)}</a></td></tr>"
        of Added:    result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.bpath.substr(2)}</a></td></tr>"
        of Deleted:  result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.apath.substr(2)}</a></td></tr>"
        of Other:    result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.apath.substr(2)}</a></td></tr>"
    result.add "</table>"

proc format_html(Patches: seq[FileEntry], ahash, bhash: string): string=
    result.add "<p>Anzahl Dateien: " & $Patches.len & "</p>"
    result.add "<table>"
    for index,entry in Patches:
        case entry.op:
        of Modified: result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.bpath.substr(2)}</a></td></tr>"
        of Added:    result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.bpath.substr(2)}</a></td></tr>"
        of Deleted:  result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.apath.substr(2)}</a></td></tr>"
        of Other:    result.add fmt"<tr><td>{entry.op}</td><td><a href='#file{index:04}'>{entry.apath.substr(2)}</a></td></tr>"
    result.add "</table>"
    for index,fileentry in Patches:
        case fileentry.op:
        of Modified: result.add fmt"{'\n'}<p><a name='file{index:04}'/>Changes to {fileentry.apath.substr(2)}</p>"
        of Deleted:  result.add fmt"{'\n'}<p><a name='file{index:04}'/>Deleted {fileentry.apath.substr(2)}</p>"
        of Added:    result.add fmt"{'\n'}<p><a name='file{index:04}'/>Added {fileentry.bpath.substr(2)}</p>"
        of Other:    result.add fmt"{'\n'}<p><a name='file{index:04}'/>Unknown operation {fileentry.apath.substr(2)}</p>"
        if fileentry.op!=Other:
            result.add "<table class='diff'>"
            case fileentry.op:
            of Modified:
                result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
                result.add "\n<tr><th>" & ahash & "</th><th>" & bhash & "</th></tr>"
            of Deleted:
                result.add "\n<tr><th>" & fileentry.apath & "</th><th>---</th></tr>"
                result.add "\n<tr><th>" & ahash & "</th><th/></tr>"
            of Added:
                result.add "\n<tr><th/><th>" & fileentry.bpath & "</th></tr>"
                result.add "\n<tr><th/><th>" & bhash & "</th></tr>"
            of Other:
                result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
                result.add "\n<tr><th>" & ahash & "</th><th>" & bhash & "</th></tr>"
            var
                a=0
                b=0
            for section in fileentry.sections:
                case section.kind
                of N:
                    for z in section.zeilen:
                        inc a
                        inc b
                        if z.len==0: result.add fmt"{'\n'}<tr><td class='Ncmp'><span>{a}</span>&nbsp;</td><td class='Ncmp'><span>{b}</span>&nbsp;</td></tr>"
                        else:        result.add fmt"{'\n'}<tr><td class='Ncmp'><span>{a}</span>{htmlescape z}</td><td class='Ncmp'><span>{b}</span>{htmlescape z}</tr>"
                of A:
                    result.add "\n<tr><td class='Acmp'>"
                    for z in section.zeilen:
                        inc a
                        result.add fmt"<span>{a}</span>{htmlescape z}{'\n'}"
                    result.add "</td><td/></tr>"
                of B:
                    result.add "\n<tr><td/><td class='Bcmp'>"
                    for z in section.zeilen:
                        inc b
                        result.add fmt"<span>{b}</span>{htmlescape z}{'\n'}"
                    result.add "</td></tr>"
                of R:
                    let A=block:
                        var X: string
                        for z in section.razeilen:
                            inc a
                            X.add fmt"<span>{a}</span>{htmlescape z}{'\n'}"
                        X
                    let B=block:
                        var X: string
                        for z in section.rbzeilen:
                            inc b
                            X.add fmt"<span>{b}</span>{htmlescape z}{'\n'}"
                        X
                    result.add fmt"{'\n'}<tr><td class='Acmp'>{A}</td><td class='Bcmp'>{B}</td></tr>"
            result.add "</table>"

proc git_diff*(Args: Table[string,string]): string=

    let (gitargs,toc)=block:
        var
            A= @["diff"]
            toc=false
        if Args.contains "toc": A.add "-U0"
        else: A.add "-U999999"
        if Args.contains "a":
            var arg=Args["a"]
            if Args.contains "b": arg.add ".."&Args["b"]
            A.add arg
        elif Args.contains "b":
            A.add ".."&Args["b"]
        if Args.contains "path":
            A.add "--"
            A.add Args["path"]
        if Args.contains "staged":
            A.add "--staged"
        (A, toc)

    # Starte git und sammele Ausgabezeilen ein.
    let p=startprocess("git", args=gitargs, options={poUsePath})
    let pipe=outputstream(p)
    var
        patchlines: seq[string]
        patchline:  string
    while readline(pipe, patchline): patchlines.add patchline

    # Bilde die Werte title, cmd, content und cssurl für die Auswertung der Schablone.
    let
        title="diff"
        cmd=block:
            var cmd="git"
            for a in gitargs: cmd=cmd & " " & a
            cmd
        cssurl="/gitrelief.css"
        content=block:
            let
                ahash=Args.getordefault("a", "")
                bhash=Args.getordefault("b", "")
            if toc: format_html_toc(parse_patch(patchlines), ahash, bhash)
            else:   format_html(    parse_patch(patchlines), ahash, bhash)
    return fmt html_template

# =====================================================================

when isMainModule:

    import std/cmdline
    var
        patchfile=""
        output_html=false
        skip=false
    let args=commandlineparams()
    for k in 0..<args.len:
            if skip:
                skip=false
            elif args[k]=="--patch":
                if k+1<args.len:
                    patchfile=args[k+1]
                    skip=true
            elif args[k]=="--html":
                output_html=true
                skip=true
    if patchfile!="":
        let Patches=parse_patch(split(readfile(patchfile), "\n"))
        if output_html:
            let
                content=format_html(Patches, "ahash", "bhash")
                cmd="patchfile"
                title="diff"
                cssurl="gitrelief.css"
            echo fmt html_template
        else:
            for f in Patches: echo $f

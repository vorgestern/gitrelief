
import std/[tables, strformat, strutils]
import mehr/helper
import git/processes

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
<tr><td><a href='/'>Start</a></td><td>{htmlescape cmd}</td></tr>
</table>
{content}
</body></html>
"""

proc format_html_toc(Patches: seq[FileDiff], staged: bool, ahash, bhash: SecureHash): string=
    result.add "<p><table>"
    for index,entry in Patches:
        let path=case entry.op
        of Modified,Added,Renamed: entry.bpath
        of Deleted,Other:  entry.apath
        let (url,tag)=case entry.op
        of Modified,Added: (url_diff(ahash, bhash, staged, path), path)
        of Deleted,Other:  (url_diff(ahash, bhash, staged, path), path)
        of Renamed:        (url_diff(ahash, bhash, staged, path, entry.bpath), path)
        result.add fmt"<tr><td>{entry.op}</td><td><a href='{url}'>{tag}</a></td><td><a href='{url_follow path}'>Follow</a></td></tr>"
    result.add "</table></p>"

proc format_html_patch(fileentry: FileDiff, staged: bool, ahash, bhash: SecureHash): string=
    let followurl=case fileentry.op
    of Modified: fmt"{url_follow fileentry.bpath, bhash}"
    of Added:    fmt"{url_follow fileentry.bpath, bhash}"
    of Deleted:  fmt"{url_follow fileentry.apath, bhash}"
    of Renamed:  fmt"{url_follow fileentry.bpath, bhash}"
    of Other:    fmt"{url_follow fileentry.apath}"
    case fileentry.op:
    of Modified: result.add fmt"{'\n'}<p>Modified {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"
    of Deleted:  result.add fmt"{'\n'}<p>Deleted {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"
    of Added:    result.add fmt"{'\n'}<p>Added {fileentry.bpath} <span><a href='{followurl}'>Follow</a></span></p>"
    of Renamed:  result.add fmt"{'\n'}<p>Renamed {fileentry.apath} to {fileentry.bpath} <span><a href='{followurl}'>Follow</a></span></p>"
    of Other:    result.add fmt"{'\n'}<p>Unknown operation {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"
    if fileentry.op!=Other:
        result.add "<p><table class='diff'>"
        case fileentry.op:
        of Modified:
            result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
            result.add "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
        of Deleted:
            result.add "\n<tr><th>" & fileentry.apath & "</th><th>---</th></tr>"
            result.add "\n<tr><th>" & shaform(ahash) & "</th><th/></tr>"
        of Added:
            result.add "\n<tr><th/><th>" & fileentry.bpath & "</th></tr>"
            result.add "\n<tr><th/><th>" & shaform(bhash) & "</th></tr>"
        of Renamed:
            result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
            result.add "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
        of Other:
            result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>"
            result.add "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
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
        result.add "</table></p>"

proc page_diff*(Args: Table[string,string]): string=
    let paths=block:
        var X: seq[string]
        if Args.contains "path": X.add Args["path"]
        if Args.contains "oldpath": X.add Args["oldpath"]
        X
    let staged=Args.contains "staged"
    let
        ahash=if Args.contains "a": gitcompletehash Args["a"] else: shanull
        bhash=if Args.contains "b": gitcompletehash Args["b"] else: shanull
    let (Diffs,cmd)=if staged: gitdiff_staged(ahash, bhash, paths)
                    else:      gitdiff(       ahash, bhash, paths)
    let
        title="diff"
        cssurl="/gitrelief.css"
        content=block:
            if Diffs.len>1:    format_html_toc(Diffs, staged, ahash, bhash)
            elif Diffs.len==1: format_html_patch(Diffs[0], staged, ahash, bhash)
            else: "<p>No Modifications</p>"
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
                content=format_html(Patches, "ahash", "bhash", "chash")
                cmd="patchfile"
                title="diff"
                cssurl="public/gitrelief.css"
            echo fmt html_template
        else:
            for f in Patches: echo $f

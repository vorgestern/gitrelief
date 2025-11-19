
import std/[tables, strformat, strutils, times]
import mehr/helper
import git/processes

func format_html_toc(Patches: seq[FileDiff], staged: bool, ahash, bhash: SecureHash): string=
        result.add "<p><table>"
        for index,entry in Patches:
                let path=case entry.op
                of Modified,Added,Renamed,Copied: entry.bpath
                of Deleted,Other:  entry.apath
                let (url,tag)=case entry.op
                of Modified,Added: (url_diff(ahash, bhash, staged, path), path)
                of Deleted,Other:  (url_diff(ahash, bhash, staged, path), path)
                of Renamed,Copied: (url_diff(ahash, bhash, staged, path, entry.bpath), path)
                result.add fmt"<tr><td>{entry.op}</td><td><a href='{url}'>{tag}</a></td><td><a href='{url_follow path}'>Follow</a></td></tr>"
        result.add "</table></p>"

func format_html_head(fileentry: FileDiff, hash: SecureHash): string=
        let followurl=case fileentry.op
        of Modified: fmt"{url_follow fileentry.bpath, 100, hash}"
        of Added:    fmt"{url_follow fileentry.bpath, 100, hash}"
        of Deleted:  fmt"{url_follow fileentry.apath, 100, hash}"
        of Renamed:  fmt"{url_follow fileentry.bpath, 100, hash}"
        of Copied:   fmt"{url_follow fileentry.bpath, 100, hash}"
        of Other:    fmt"{url_follow fileentry.apath}"
        case fileentry.op:
        of Modified: result.add fmt"{'\n'}<p>Modified {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"
        of Deleted:  result.add fmt"{'\n'}<p>Deleted {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"
        of Added:    result.add fmt"{'\n'}<p>Added {fileentry.bpath} <span><a href='{followurl}'>Follow</a></span></p>"
        of Renamed:  result.add fmt"{'\n'}<p>Renamed {fileentry.apath} to {fileentry.bpath} <span><a href='{followurl}'>Follow</a></span></p>"
        of Copied:   result.add fmt"{'\n'}<p>Copied {fileentry.apath} to {fileentry.bpath} <span><a href='{followurl}'>Follow</a></span></p>"
        of Other:    result.add fmt"{'\n'}<p>Unknown operation {fileentry.apath} <span><a href='{followurl}'>Follow</a></span></p>"

func format_html_patch(fileentry: FileDiff, staged: bool, ahash, bhash: SecureHash): string=
        if fileentry.op!=Other:
                result.add "<p><table class='diff'>"
                case fileentry.op:
                of Modified: result.add "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>" &
                                        "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
                of Deleted: result.add  "\n<tr><th>" & fileentry.apath & "</th><th>---</th></tr>" &
                                        "\n<tr><th>" & shaform(ahash) & "</th><th/></tr>"
                of Added: result.add    "\n<tr><th/><th>" & fileentry.bpath & "</th></tr>" &
                                        "\n<tr><th/><th>" & shaform(bhash) & "</th></tr>"
                of Renamed: result.add  "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>" &
                                        "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
                of Copied: result.add   "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>" &
                                        "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
                of Other: result.add    "\n<tr><th>" & fileentry.apath & "</th><th>" & fileentry.bpath & "</th></tr>" &
                                        "\n<tr><th>" & shaform(ahash) & "</th><th>" & shaform(bhash) & "</th></tr>"
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
        let
                paths=block:
                        var X: seq[string]
                        if Args.contains "path": X.add Args["path"]
                        if Args.contains "oldpath": X.add Args["oldpath"]
                        X
                staged=Args.contains "staged"
                ahash=if Args.contains "a": gitcompletehash Args["a"] else: shanull
                bhash=if Args.contains "b": gitcompletehash Args["b"] else: shanull
                (Diffs,cmd)=    if staged: gitdiff_staged(ahash, bhash, paths)
                                else:      gitdiff(       ahash, bhash, paths)
        let
                html_title= $servertitle & " diff"
                html_cmd=htmlescape cmd
                html_content=block:
                        if Diffs.len>1: format_html_toc(Diffs, staged, ahash, bhash)
                        elif Diffs.len==1:
                                let ci=if bhash!=shanull:
                                        let X=gitcommit(bhash)
                                        var h="<p><table><tr><td>" & X.author & "</td><th>" & htmlescape(X.subject) & "</th></tr>"
                                        h.add "<tr><td>" & X.date.format("d. MMM yyyy HH:mm") & "</td><td>"
                                        for k in X.details: h.add htmlescape(k) & "<br/>"
                                        h & "</td></tr></table>"
                                else: ""
                                format_html_head(Diffs[0], bhash) & ci & format_html_patch(Diffs[0], staged, ahash, bhash)
                        else: "<p>No Modifications</p>"
        return fmt staticread "../public/diff.html"

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


import std/[tables, strformat, strutils, times]
import mehr/helper
import git/processes

# Usecases for page 'diff'
# What to compare
#       1 filepath                                                                      Show diff immediately. If several references are available, use the first and offer the others via links.
#       2 pattern oder folder                                                           Show a table of filepaths. Each row offers a link to a filepath (1).
#                                                                                       A folder is specified with a trailing /.
#                                                                                       A pattern includes wildcards recognised by git.
#       3 filepath, oldfilepath                                                         Display diff between filepath before and after rename or copy.
# Compare between what states
#       A Display diff between working copy (staged or unstaged) and HEAD.              Filepath, pattern or folder given in url (path=...). If staged, url contains query param staged.
#       B Display diff between commit b and one of its parent commits.                  B given in url (b=...)
#         Commit b is given in url, parents are not specified but queried here.
#       C Display diff between commit b and given ancestor a.                           B and a are given in url (a=...&b=...)
#         Commits a and b are given in url.

# type
#         Usecase=enum None, A12, B12, C12, A3, B3, C3
#         xy=object
#                 path: string
#
#                 case usecase: Usecase
#                 of A3, B3, C3:
#                         oldpath: string
#
#                 case usecase:
#                         of A12, A3:
#                                 staged: bool
#                         of C12, C3:
#                                 a: SecureHash
#
#                 case usecase:
#                         of B12, B3, C12, C3:
#                                 b: SecureHash
#
#
# func url_diff*(staged: bool, path:string): string= # url_diff_A12
#         if staged: "/git/diff?path=" & path & "&staged"
#         else:      "/git/diff?path=" & path
# func url_diff*(commit: SecureHash, path:string): string= "/git/diff?b=" & $commit & "&path=" & path # url_diff_B12
# func url_diff*(parent, commit: SecureHash, path:string): string="/git/diff?path=" & path & "&a=" & shaform(parent) & "&b=" & shaform(commit) # url_diff_C12
# func url_diff*(staged: bool, path:string, oldpath:string): string= # url_diff_A3
#         if staged: "/git/diff&path=" & path & "&oldpath=" & oldpath & "&staged"
#         else:      "/git/diff&path=" & path & "&oldpath=" & oldpath
# func url_diff*(commit: SecureHash, path:string, oldpath:string): string="/git/diff?b=" & shaform(commit) & "&path=" & path & "&oldpath=" & oldpath # url_diff_B3
# func url_diff*(parent, commit: SecureHash, path, oldpath:string): string="/git/diff?a=" & shaform(parent) & "&b=" & shaform(commit) & "&path=" & path & "&oldpath=" & oldpath # url_diff_C3

# proc url_diff_A(path: string, staged: bool) # A1, A2
# proc url_diff_B(path: string, b: SecureHash) # B1, B2
# proc url_diff_C(path: string, b, a: SecureHash) # C1, C2
# proc url_diff_A(path, oldpath: string, staged: bool) # A3
# proc url_diff_B(path, oldpath: string, b: SecureHash) # B3
# proc url_diff_C(path, oldpath: string, b, a: SecureHash) # C3

# proc usecase(Args: Table[string,string]): Usecase=
#         if not Args.contains "path":
#                 return None
#         if Args.contains "oldpath":
#                 if Args.contains "staged": return A3
#                 elif Args.contains "b" and Args.contains "a": return C3
#                 elif Args.contains "b": return B3
#                 else: return None
#         else:
#                 if Args.contains "staged": return A12
#                 elif Args.contains "b" and Args.contains "a": return C12
#                 elif Args.contains "b": return B12
#                 else: return None

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

func format_html_heading(fileentry: FileDiff, hash: SecureHash): string=
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
                                        var h="<table>"
                                        h.add "<tr><td>" & X.author & "</td><th>" & htmlescape(X.subject) & "</th></tr>"
                                        h.add "<tr><td>" & X.date.format("d. MMM yyyy HH:mm") & "</td><td>"
                                        for k in X.details: h.add htmlescape(k) & "<br/>"
                                        h.add "</td></tr>"
                                        h.add "</table>"
                                        h
                                else: ""
                                format_html_heading(Diffs[0], bhash) & ci & format_html_patch(Diffs[0], staged, ahash, bhash)
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

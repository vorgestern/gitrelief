
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

func format_html_toc(Patches: seq[FileDiff], staged: bool, ahash, bhash: SecureHash): string=
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

func format_html_diff(fileentry: FileDiff, staged: bool, ahash, bhash: SecureHash): string=
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

type
        DiffUsecase=enum None, A12, B12, C12, A3, B3, C3
        DiffArgs=object
                uc: DiffUsecase
                path, oldpath: string
                staged: bool
                a, b: SecureHash

func paths(X: DiffArgs): seq[string]=
        case X.uc
        of A12, B12, C12: @[X.path]
        else: @[X.oldpath, X.path]

proc mkhash(x: string): SecureHash=
        if x.len>40: shanull
        elif x.len==40: parsesecurehash x
        else: gitcompletehash x

proc parseargs(Args: Table[string, string]): DiffArgs=
        result.uc=None
        result.path=Args.getordefault("path", "")
        if result.path=="": return
        if Args.contains "staged":
                result.staged=true
                result.a=shanull
                result.b=shanull
                if Args.contains("oldpath") and Args.contains "path":
                        result.uc=A3
                        result.oldpath=Args["oldpath"]
                else:
                        result.uc=A12
        else:
                result.staged=false
                if Args.contains("oldpath") and Args.contains "path":
                        result.oldpath=Args["oldpath"]
                        if Args.contains("b") and Args.contains "a":
                                result.uc=C3
                                result.a=mkhash Args["a"]
                                result.b=mkhash Args["b"]
                        elif Args.contains "b":
                                result.uc=B3
                                result.b=mkhash Args["b"]
                        else:
                                result.uc=A3
                                result.a=shanull;
                                result.b=shanull;
                else:
                        if Args.contains("b") and Args.contains "a":
                                result.uc=C12
                                result.a=mkhash Args["a"]
                                result.b=mkhash Args["b"]
                        elif Args.contains "b":
                                result.uc=B12
                                result.b=mkhash Args["b"]
                        else:
                                result.uc=A12

proc format_commitinfo(X: Commit, fileentry: FileDiff, current_parent: SecureHash): string=
        if X.hash==shanull: return ""
        result="<table>"
        result.add "<tr><td>" & X.author & "</td><td>parents</td><th>" & htmlescape(X.subject) & "</th></tr>"
        result.add "<tr><td>" & X.date.format("d. MMM yyyy HH:mm") & "</td><td>"
        if X.parents.len>0: result.add shaform(current_parent)
        for phash in X.parents:
                if phash!=current_parent:
                        case fileentry.op
                        of Renamed, Copied: result.add fmt"<br/><a href='{url_diff phash, X.hash, false, fileentry.bpath, fileentry.apath}'>{shaform phash}</a>"
                        else:  result.add fmt"<br/><a href='{url_diff              phash, X.hash, false, fileentry.bpath}'>{shaform phash}</a>"
        result.add "</td><td>"
        for k in X.details: result.add htmlescape(k) & "<br/>"
        result.add "</td></tr>"
        result.add "</table>"

proc page_diff*(Args: Table[string,string]): string=
        let
                html_title= $servertitle & " diff"
                A=parseargs Args
                staged=case A.uc
                of A12, A3: A.staged
                else: false
                commit=A.b
                Info=case A.uc
                of B12, B3, C12, C3: gitcommit commit
                else: Commit()
                parent=case A.uc
                        of C12, C3: A.a
                        else:
                                if Info.parents.len>0: Info.parents[0] else: shanull
                (Diffs,cmd)=gitdiff(parent, commit, staged, paths A)
                html_cmd=htmlescape cmd
                html_content = if Diffs.len>1:
                        format_html_toc(Diffs, staged, parent, commit)
                elif Diffs.len==1:
                        format_html_heading(Diffs[0], commit) &
                        format_commitinfo(Info, Diffs[0], parent) &
                        format_html_diff(Diffs[0], staged, parent, commit)
                else:
                        let Diff=FileDiff(op: Other, bpath: Args["path"])
                        fmt"<p>Not Modified: {Diff.bpath}</p>" &
                        format_commitinfo(Info, Diff, parent)
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

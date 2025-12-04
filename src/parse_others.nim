
import std/[strutils, strformat, tables, times, assertions]
import checksums/sha1
import npeg
import helper

type
        FileCommitStatus* =enum Other, Modified, Deleted, Added, Renamed, Copied
        CommittedOperation* =object
                case status*: FileCommitStatus
                of Renamed, Copied:
                        oldpath*, newpath*: string
                else:
                        path*: string
        Commit* =object
                hash*: SecureHash
                parents*: seq[SecureHash]
                author*: string
                date*: DateTime
                subject*: string
                details*: seq[string]
                files*: seq[CommittedOperation]
                mergeinfo*: seq[string]

func datestring*(C: Commit): string=C.date.format("d. MMM HH:mm")

func url_diff*(parent, commit: SecureHash, staged: bool, op: CommittedOperation): string=
        var X: seq[string]
        if parent!=shanull and commit!=shanull:
                X.add "a="&shaform parent
                X.add "b="&shaform commit
        elif parent!=shanull:
                X.add "a="&shaform parent
        if staged:
                X.add "staged"
        case op.status
        of Renamed, Copied:
                X.add "path="&op.newpath
                X.add "oldpath="&op.oldpath
        else:
                X.add "path="&op.path
        var url="/git/diff"
        for j,q in X:
                url.add if j==0: "?" else: "&"
                url.add q
        url

# =====================================================================
# gitbranches_remote

type
        remoteurls* =tuple[fetchurl, pushurl: string]
        remoteinfo* =Table[string, remoteurls]

proc parse_remote_v*(L: seq[string]): remoteinfo=
        const lineparser=peg("line", cx: remoteinfo):
                name <- +{33..128}
                url <- +{33..128}
                fetchentry <- >name * @>url * @"(fetch)":
                        # cx.fetch[$1]= $2
                        if    cx.contains $1: cx[$1].fetchurl= $2
                        else: cx[$1]=($2, "")
                pushentry <- >name * @>url * @"(push)":
                        # cx.push[$1]= $2
                        if    cx.contains $1: cx[$1].pushurl= $2
                        else: cx[$1]=("", $2)
                sonst <- >(*1) * !1: echo "parse_remote: Nicht erwartet: ", $1
                line <- fetchentry | pushentry | sonst
        for z in L:
                {.gcsafe.}:
                        discard lineparser.match(z, result)

proc parse_branches_remote*(L: seq[string], remotename: string): seq[string]=
        let s=remotename & "/"
        for k in L:
                let k1=k.substr(2)
                if k1.startswith s: result.add k1.substr(s.len)
                else:
                        echo "fail startswith '", k, "': ", s
                        result.add "?? " & k

proc parse_branches_local*(L: seq[string]): seq[string]=
        for k in L: result.add k.substr(2)

# =====================================================================
# gitshowbranches

type
        taggedcommit* =object
                tags*, hash*, subject*: string
        ShowBranch* =object
                branches*: seq[string]
                commits*: seq[taggedcommit]

proc parse_show_branches*(Lines: openarray[string]): ShowBranch=
        type
                bcontext=object
                        s: string
        const branchparser=peg("line", name: bcontext):
                line <- @>+{'*', '!', ' '} * '[' * >+{33..0x5c, 0x5e..127} * "] " * >+1:
                        # echo "     branch '", $1, "', '", $2, "', '", $3, "'"
                        name.s= $2
        const commitparser=peg("line", cx: taggedcommit):
                line <- >+{' ', '*', '+', '-'} * '[' * >+{'0'..'9', 'a'..'f'} * "] " * >+1:
                        let tags=if len($1)>1: substr($1, 0, len($1)-2)
                        else: $1
                        cx=taggedcommit(tags: tags, hash: $2, subject: $3)
        var k=0
        while k<Lines.len:
                {.gcsafe.}:
                        let z=Lines[k]
                        inc k
                        var e=bcontext(s: "")
                        if branchparser.match(z, e).ok: result.branches.add e.s
                        else: break
        while k<Lines.len:
                {.gcsafe.}:
                        let z=Lines[k]
                        inc k
                        var x: taggedcommit
                        if commitparser.match(z, x).ok: result.commits.add x
                        else:
                                # echo "failed to parse commit."
                                break;
        if k<Lines.len:
                echo "Nicht mehr gelesen: ", Lines.len-k, " Zeilen:"
                while k<Lines.len:
                        echo "'", Lines[k], "'"
                        inc k

func path_short(path, leading: string, followfile: bool): string=
                if followfile: return ""
                if leading.len>0 and path.startswith(leading): " " & path.substr(leading.len)
                else: " " & path

proc format_commits*(L: seq[Commit], leading: string, followfile=false, highlight=""): string=
        let ynow=year(now())
        var yage_merk=0
        result="<table class='diff'>\n<tr><th>commit</th><th>who</th><th>when</th><th>affected</th><th>subject/details</th></tr>"
        for commitindex,commit in L:
                        # Vielfache von 100 erhalten eine Hinweiszeile, die auch als Sprungziel dient.
                        if commitindex>0 and commitindex mod 100==0: result.add "\n" & fmt"<tr><td><a id='top{commitindex}'>{commitindex}</a></td></tr>"
                        let
                                tr=if shamatch(commit.hash, highlight): "\n<tr class='highlight'>" else: "\n<tr>"
                                tdcommit=block:
                                        let hx=shaform commit.hash
                                        var X="<td>" & hx
                                        when false:
                                                for p in 0..<commit.parents.len: X.add "<br/>" & $p & ": " & shaform(commit.parents[p])
                                        X.add "</td>"
                                        X
                                tdauthor="<td>" & commit.author & "</td>"
                                tdcomments=block:
                                        var s=htmlescape(commit.subject)
                                        for d in commit.details: s.add "<br/>"&htmlescape(d)
                                        "<td>" & s & "</td>"
                                parent=if commit.parents.len>0: commit.parents[0] else: shanull
                                tdaffected=block:
                                        var files=""
                                        for fileindex,op in commit.files:
                                                        if fileindex>0: files.add "<br/>"
                                                        let url=url_diff(parent, commit.hash, false, op)
                                                        case op.status
                                                        of Renamed, Copied: files.add fmt"<a href='{url}'>{op.status}</a> to {path_short op.newpath, leading, false}<br/>from {path_short op.oldpath, leading, false}"
                                                        of Added:           files.add fmt"<a href='{url}'>{op.status}</a>{path_short op.path, leading, false}"
                                                        else:               files.add fmt"<a href='{url}'>{op.status}</a>{path_short op.path, leading, followfile and commitindex>0}"
                                        "<td>" & files & "</td>"
                        let yage=ynow-year(commit.date)
                        if yage>yage_merk:
                                        let yclass=if yage mod 2==0: "yeven" else: "yodd"
                                        result.add "\n<tr class='newyear'><td/><td/><td class='" & yclass & "'><b>" & $year(commit.date) & "</b></td><td/><td/></tr>"
                                        yage_merk=yage
                        let tddate=block:
                                        let df=commit.date.format("d. MMM HH:mm")
                                        if yage==0:             "<td>" & df & "</td>"
                                        elif yage mod 2==0:     "<td class='yeven'>" & df & "</td>"
                                        else:                   "<td class='yodd'>" & df & "</td>"
                        result.add tr & tdcommit & tdauthor & tddate & tdaffected & tdcomments & "</tr>"
        result.add "\n" & fmt"<tr><td><a id='top{L.len}'>{L.len}</a></td></tr>"
        result.add "</table>"

when ismainmodule:
        import std/[cmdline, sets, parseutils]
        var Tests=inithashset[uint8]()
        let args=commandlineparams()
        if args.len==0:
                for k in 1..1: Tests.incl uint8 k
        else:
                for a in args:
                        var k: uint
                        if parseuint(a, k)>0: Tests.incl uint8 k
                        else: echo "Failed to parse argument '", a, "', expected numbers in 1..1"
        if 1 in Tests:
                const X=parse_show_branches(staticread("testdata/show_branches_1.txt").split('\n'))
                echo "Zweige: ", X.branches
                echo "Commits: ", X.commits

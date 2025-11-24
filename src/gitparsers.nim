
import std/[strutils, strformat, tables, times]
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
#               gitdiff
#               gitdiff_staged

type
    NABR* =enum N, A, B, R
    DiffSection* =object
        case kind*: NABR
        of N, A, B:
            zeilen*: seq[string]
        of R:
            razeilen*, rbzeilen*: seq[string]
    FileDiff* =object
        op*: FileCommitStatus
        apath*, bpath*: string
        sections*: seq[DiffSection]

func numlines(S: DiffSection): int=
    case S.kind
    of N, A, B: S.zeilen.len
    of R: S.razeilen.len

proc addline(S: var DiffSection, z: string): bool=
    if z.len<1: return false
    let
        neu=numlines(S)==0
        k=z[0]
        z1=substr(z,1)
    case k
    of '-':
        if neu: S=DiffSection(kind: A, zeilen: @[])
        if S.kind==A: S.zeilen.add z1
        return S.kind==A
    of '+':
        if neu: S=DiffSection(kind: B, zeilen: @[])
        if S.kind==B:
            S.zeilen.add z1
            return true
        elif S.kind==A:
            let temp=S.zeilen
            S=DiffSection(kind: R, razeilen: temp, rbzeilen: @[z1])
            return true
        elif S.kind==R:
            S.rbzeilen.add z1
            return true
        else: return false
    of ' ':
        if neu: S=DiffSection(kind: N, zeilen: @[])
        if S.kind==N:
            S.zeilen.add z1
            return true
        else: return false
    else:
        # error
        return false

proc parse_diff*(patch: seq[string]): seq[FileDiff]=
    type
        parsercontext=object
            na, nb: int
            fe: ptr seq[FileDiff]
    const diffentryparser=peg("entry", e: parsercontext):
        path <- +{1..31, 33..255}
        hash <- +{'0'..'9', 'a'..'f'}
        flags <- +{'0'..'9'}
        num <- +{'0'..'9'}
        diff <- "diff --git" * @>path * @>path:
            add(e.fe[], FileDiff())
            e.fe[^1].apath= substr($1, 2)
            e.fe[^1].bpath= substr($2, 2)
        index <- "index" * @>hash * ".." * @>hash * @flags:
            # Beachte: Die Hashes sind keine Commit-Hashes, sondern bezeichnen Blobs im Index.
            discard
        aaa <- "---" * @>path: e.fe[^1].apath= substr($1, 2)
        bbb <- "+++" * @>path:
            e.fe[^1].bpath= substr($1, 2)
            if e.fe[^1].op==Other: e.fe[^1].op=Modified
        newfile <- "new file mode" * @>flags: e.fe[^1].op=Added
        deletedfile <- "deleted file mode" * @>flags: e.fe[^1].op=Deleted
        similarity <- "similarity index" * @>num * '%': discard
        rename_from <- "rename from" * @>path: e.fe[^1].op=Renamed
        rename_to <- "rename to" * @>path: e.fe[^1].op=Renamed
        atat <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num * @"@@":
            e.na=parseint $2
            e.nb=parseint $4
        atat1 <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * @"@@":
            e.na=parseint($2)
            e.nb=1
        atat2 <- "@@" * @'-' * >num * @'+' * >num * @"@@":
            e.na=1
            e.nb=1
        sonst <- >(*1) * !1: discard
        entry <- diff | index | newfile | deletedfile | aaa | bbb | rename_from | rename_to | similarity | atat | atat1 | atat2 | sonst

    var
        na=0
        nb=0

    for z in patch:
        if na>0 or nb>0:
            if result[^1].sections.len==0: result[^1].sections.add DiffSection()
            let added=result[^1].sections[^1].addline z
            if not added:
                let z1=substr(z, 1)
                case z[0]
                of '+': result[^1].sections.add DiffSection(kind: B, zeilen: @[z1])
                of '-': result[^1].sections.add DiffSection(kind: A, zeilen: @[z1])
                of ' ': result[^1].sections.add DiffSection(kind: N, zeilen: @[z1])
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

# =====================================================================

type
    RepoStatus_v2* =object
        currentcommit*: SecureHash
        currentbranch*: string
        staged*, unstaged*: seq[tuple[status: FileCommitStatus, path, oldpath: string]]
        notcontrolled*: seq[string]
        unmerged*: seq[string]
        unparsed*: seq[string]

proc parse_status_v2*(Lines: seq[string]): RepoStatus_v2=
    type
        parsercontext=object
            res: ptr RepoStatus_v2
    const statuslineparser=peg("entry", e: parsercontext):
        path <- +{33..255}
        name <- +{1..31, 33..255}
        nosp <- {1..31, 33..255}
        nosp2 <- {1..31, 33..255}[2]
        nosp4 <- {1..31, 33..255}[4]
        sub <- nosp[4]
        octalmode <- nosp[6]
        flags <- +{'0'..'9'}
        num <- +{'0'..'9'}
        hash <- +{'0'..'9', 'a'..'f'}
        xscore <- +nosp
        # ===============================
        oid <- "# branch.oid " * >hash * !1: e.res[].currentcommit=parsesecurehash $1
        oid_initial <- "# branch.oid (initial)" * !1: e.res[].currentcommit=shanull
        head <- "# branch.head " * >name * !1: e.res[].currentbranch= $1
        head_detached <- "# branch.head (detached)" * !1: e.res[].currentbranch=""
        branch_upstream <- "# branch.upstream ": discard
        branch_ab <- "# branch.ab ": discard
        xM <- "1 .M " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "xM '", $1, "'"
            e.res.unstaged.add (status: Modified, path: strip $1, oldpath: "")
        Mx <- "1 M. " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "Mx '", $1, "'"
            e.res.staged.add (status: Modified, path: strip $1, oldpath: "")
        MM <- "1 MM " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "MM '", $1, "'"
            e.res.staged.add (status: Modified, path: strip $1, oldpath: "")
            e.res.unstaged.add (status: Modified, path: strip $1, oldpath: "")
        Ax <- "1 A. " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "Ax '", $1, "'"
            e.res.staged.add (status: Added, path: strip $1, oldpath: "")
        AM <- "1 AM " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "AM '", $1, "'"
            e.res.staged.add (status: Added, path: strip $1, oldpath: "")
        xD <- "1 .D " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "xD '", $1, "'"
            e.res.staged.add (status: Deleted, path: strip $1, oldpath: "")
        Dx <- "1 D. " * sub * (@octalmode[3]) * (@hash[2]) * @>path:
            # echo "Dx '", $1, "'"
            e.res.unstaged.add (status: Deleted, path: strip $1, oldpath: "")
        ignored <- "1 !! " * @>path:
            # echo "ignored '", $1, "'"
            discard
        untracked <- "? " * @>path:
            e.res.notcontrolled.add strip $1
        U <- "u >nosp2 " * sub * (@octalmode[4]) * (@hash[3]) * @>path:
            echo "unmerged ", $1, " '", $2, "'"
            e.res.unmerged.add ($1 & " " & strip($2))

        xR <- "2 .R " * sub * (@octalmode[3]) * (@hash[2]) * @xscore * @>path * '\t' * >path:
            # echo "xR '", $1, "'"
            e.res.unstaged.add (status: Renamed, path: strip $2, oldpath: strip $1)
        Rx <- "2 R. " * sub * (@octalmode[3]) * (@hash[2]) * @xscore * @>path * '\t' * >path:
            # echo "Rx '", $1, "'"
            e.res.staged.add (status: Renamed, path: strip $2, oldpath: strip $1)
        xC <- "2 .C " * sub * (@octalmode[3]) * (@hash[2]) * @xscore * @>path * '\t' * >path:
            # echo "xC '", $1, "'"
            e.res.unstaged.add (status: Copied, path: strip $2, oldpath: strip $1)
        Cx <- "2 C. " * sub * (@octalmode[3]) * (@hash[2]) * @xscore * @>path * '\t' * >path:
            # echo "Cx '", $1, "'"
            e.res.staged.add (status: Copied, path: strip $2, oldpath: strip $1)
        sonst <- >(*1) * !1: e.res.unparsed.add $1
        # ===============================
        entry <- oid | oid_initial | head | head_detached | branch_upstream | branch_ab | xM | Mx | MM | Ax | AM | xD | Dx | xR | Rx | xC | Cx | U | untracked | ignored | sonst
    var e=parsercontext(res: addr result)
    for z in Lines:
        {.gcsafe.}:
            let mr=statuslineparser.match(z, e)
            if not mr.ok: echo "failed to parse: ", z

# =====================================================================

proc parse_log*(L: seq[string]): seq[Commit]=
    type
        context=enum None, Header, Subject, Details, Files
        parsercontext=object
            st: context
            was: ptr seq[Commit]
    const lineparser=peg("line", e: parsercontext):
        hash <- +{'0'..'9', 'a'..'f'}
        path <- +{33..255}
        commit <- "commit " * +@>hash:
            var parents: seq[SecureHash]
            for k in 2..<capture.len: parents.add parsesecurehash capture[k].s
            e.was[].add Commit(hash: parsesecurehash $1, parents: parents)
            e.st=Header
        merge <- "Merge:" * @>hash * @+>hash:
            # capture[0] beschreibt die ganze Zeile.
            # capture[1..] sind die Hashes.
            # Die hier genannten Hashes sind einfach die Kurzformen der in der commit-Zeile genannten.
            for k in 1..<capture.len: e.was[^1].mergeinfo.add capture[k].s
        authorname <- {33..128} * +{33..128}
        author <- "Author:" * @>authorname * @'<': e.was[^1].author= $1
        datestring <- {'0'..'9', '-'}[10] * @{'0'..'9', ':'}[8] * @ {'0'..'9', '-', '+'}[5]
        date <- "Date: " * @>datestring * !1:
            let ts=substr($1, 0, 18)
            e.was[^1].date=times.parse(ts, "yyyy-MM-dd HH:mm:ss")
        empty <- *{' ', '\t'} * !1:
            e.st=case e.st
            of Header:  Subject
            of Subject: Details
            of Details: Details
            else: Files
        comment <- "    " * >+1:
            case e.st
            of Subject:
                e.was[^1].subject= $1
                e.st=Details
            of Details: e.was[^1].details.add $1
            else: discard
        filestatus_added <- 'A' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Added, path: $1)
        filestatus_modified <- 'M' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Modified, path: $1)
        filestatus_deleted <- 'D' * +{' ','\t'} * >+1: e.was[^1].files.add CommittedOperation(status: Deleted, path: $1)
        filestatus_renamed <- 'R' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add CommittedOperation(status: Renamed, newpath: $3, oldpath: $2)
        filestatus_copied <- 'C' * >{'0'..'9'}[3] * @>path * @>path: e.was[^1].files.add CommittedOperation(status: Copied, newpath: $3, oldpath: $2)
        sonst <- >(*1) * !1: echo "Nicht erwartet: ", $1
        line <- commit | merge | author | date | empty | comment | filestatus_added | filestatus_modified | filestatus_deleted | filestatus_renamed | filestatus_copied | sonst
    var e=parsercontext(st: None, was: addr result)
    for z in L:
        {.gcsafe.}:
            discard lineparser.match(z, e)

# =====================================================================

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
    # git show-branch --date-order --color=never --sha1-name master zv Zustandsvariable
    const demo1="""
* [master] Anpassung Hilfetext nach #944
 ! [zv] zv Start
  ! [Zustandsvariable] Aktualisierung (26.9.)
---
-   [f41c19345] Anpassung Hilfetext nach #944
*   [994535807] Anpassung Hilfetext nach #944
*   [059005df7] Schreibende Transaktion im SunSpec-Modbus und EEBUS Anwendung Limit Power Consumption (#946)
*   [fc6dbe86f] Externe Leistung von SC3 an SolvisTom (#942)
*   [ffe50e903] fix: display correct version number of SolvisTim #925
*   [e036b5af8] Enable multiple network interfaces (#939)
*   [435257f65] Clever pv basic (#936)
*   [fdda88e4e] Xtra tcp heap (#938)
*   [eec760a9e] update min/max capacity curves
*   [59a51dfe3] fix: display the correct charge pump value in Waermeerzeuger->Waermepumpe #879
 +  [c27972932] zv Start
*+  [89db6131e] Nachtrag/ Bugfix 3.23 (#927)
*+  [3aaf8a9ed] Behandlung der Watchdog-Semaphore bei idle-Jobs verbessert (#923)
*+  [4f13226e5] #918 Bruno Influx-Logging aktiviert
*+  [ca98c5104] annotations in s6-log #920
*+  [e402cfc86] in Tabellen/SDKarte/ an Dateienden Zeilenenden entfernt; Typofix
*+  [c9297f6ea] aus Branch cpp: einige Typo-Fixes und Umlautanpassungen
*+  [1316699a9] aus Branch cpp: kleinere Fixes
*+  [125a50581] aus Branch cpp: Generierung von ParamNames.h/.c zur Verwendung in der RegelungsAkademie
--  [577f48c8d] Merge pull request #916 from solvis-bs/Translate3237
*+  [7bbefb802] Übersetzungen für 3.23.7 aktualisiert
*+  [8f097c743] Vertausch VL/RL des Alsonic (#911)
*+  [75c5fa22a] Dashboard Menü (#912)
  - [b5f98a49d] Aktualisierung (26.9.)
*+  [fe65eaa15] fix fan setting dialog for burner (#909)
  + [26d4e4fb2] Nachtrag
  + [a49cde2d4] Status: Aktualisierung
*+  [5342595a2] Fehler im S6-Logging (#908)
*+  [3fb016467] replace heatingrod_autoLevel() with heatingrod_outputLevel() (#907)
*+  [c91c02a6f] rework IWS_getMessages, saves about 700 bytes (#897)
*+  [50b82e256] text and parameter changes (#910)
  + [177a0ecfa] Alias aktualisiert
  + [83a17beca] Alias repariert
--- [4fcfc498a] Merge pull request #902 from solvis-bs/Translate3236
    """
    if false:
        let X=parse_show_branches(demo1.split('\n'))
        echo "Zweige: ", X.branches
        echo "Commits: ", X.commits

    const demo2="""
# branch.oid dc17a5335e4137b1fd3c6f9cd13662d84466a710
# branch.head master
1 .M N... 100644 100644 100644 d8a49c2f1739e7571648a025ad12df4b5351c8e3 d8a49c2f1739e7571648a025ad12df4b5351c8e3 src/git/parsers.nim
1 .M N... 100644 100644 100644 83192ca64e572eb66a38d63387e799e0206462ac 83192ca64e572eb66a38d63387e799e0206462ac src/git/processes.nim
1 .M N... 100644 100644 100644 7ce235a1e0dbb8efae3d42adfbe8d92b7abb2c24 7ce235a1e0dbb8efae3d42adfbe8d92b7abb2c24 src/page/status.nim
    """
    if false:
        echo "parse_status_v2:"
        let X=parse_status_v2(demo2.split '\n')
        echo "currentcommit: ", X.currentcommit
        echo "currentbranch: ", X.currentbranch

    const demo3="""
2 R. N... 100644 100644 100644 3d9668b87c829ec87818a3940fee3f5130fc561b 3d9668b87c829ec87818a3940fee3f5130fc561b R100 src/helper.nim	src/mehr/helper.nim
"""
    if true:
        echo "parse_status_v2:"
        let X=parse_status_v2(demo3.split '\n')
        echo "currentcommit: ", X.currentcommit
        echo "currentbranch: ", X.currentbranch
        echo "unparsed: ", X.unparsed


import std/[strutils, tables, times]
import checksums/sha1
import npeg
import mehr/helper

type
    FileCommitStatus* =enum Other, Modified, Deleted, Added, Renamed
    CommittedOperation* =object
        case status*: FileCommitStatus
        of Renamed:
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
    of Renamed:
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
    RepoStatus* =object
        staged*, unstaged*: seq[tuple[status: FileCommitStatus, path: string]]
        notcontrolled*: seq[string]
        unparsed*: seq[string]

proc parse_status*(Lines: seq[string]): RepoStatus=
    type
        parsercontext=object
            res: ptr RepoStatus
    const statuslineparser=peg("entry", e: parsercontext):
        path <- +{1..31, 33..255}
        flags <- +{'0'..'9'}
        num <- +{'0'..'9'}
        XM <- " M " * >path: e.res.unstaged.add (status: Modified, path: strip $1)
        MX <- "M  " * >path: e.res.staged.add (status: Modified, path: strip $1)
        MM <- "MM " * >path:
            e.res.staged.add (status: Modified, path: strip $1)
            e.res.unstaged.add (status: Modified, path: strip $1)
        AX <- "A  " * >path: e.res.staged.add (status: Added, path: strip $1)
        AM <- "AM " * >path: e.res.staged.add (status: Added, path: strip $1)
        DX <- "D  " * >path: e.res.unstaged.add (status: Deleted, path: strip $1)
        XD <- " D " * >path: e.res.staged.add (status: Deleted, path: strip $1)
        uncontrolled <- "?? " * >path: e.res.notcontrolled.add (strip $1)
        sonst <- >(*1) * !1: e.res.unparsed.add $1
        entry <- XM | MX | MM | AX | AM | DX | XD | uncontrolled | sonst
    var e=parsercontext(res: addr result)
    for z in Lines:
        {.gcsafe.}:
            let mr=statuslineparser.match(z, e)
            if not mr.ok:
                echo "failed to parse: ", z

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
        sonst <- >(*1) * !1: echo "Nicht erwartet: ", $1
        line <- commit | merge | author | date | empty | comment | filestatus_added | filestatus_modified | filestatus_deleted | filestatus_renamed | sonst
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

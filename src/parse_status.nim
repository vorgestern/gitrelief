
import std/[strutils, strformat, tables, times, assertions]
import checksums/sha1
import npeg
import helper
import parse_others

# =====================================================================
# gitstatus_v2

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
                unmerged <- "u " * >nosp2 * @sub * (@octalmode[4]) * (@hash[3]) * @>path:
                        e.res.unmerged.add (strip $2)

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
                entry <- oid | oid_initial | head | head_detached | branch_upstream | branch_ab | xM | Mx | MM | Ax | AM | xD | Dx | xR | Rx | xC | Cx | unmerged | untracked | ignored | sonst
        var e=parsercontext(res: addr result)
        for z in Lines:
                {.gcsafe.}:
                        let mr=statuslineparser.match(z, e)
                        if not mr.ok: echo "failed to parse: ", z

when ismainmodule:
        import std/[cmdline, sets, parseutils]
        var Tests=inithashset[uint8]()
        let args=commandlineparams()
        if args.len==0:
                for k in 1..4: Tests.incl uint8 k
        else:
                for a in args:
                        var k: uint
                        if parseuint(a, k)>0: Tests.incl uint8 k
                        else: echo "Failed to parse argument '", a, "', expected numbers in 1..4"

        # Beachte bei diesen Tests, dass sie zur Laufzeit ausgeführt werden sollen.
        # Erzeuge die Eingabedaten zur Kompilezeit (const), aber die Rückgabedaten
        # des Parsers zur Laufzeit (let X=parse_status_v2(inp)).
        if 1 in Tests:
                const inp=staticread("testdata/status_v2_1.txt").split 
                let X=parse_status_v2(inp)
                echo "currentcommit: ", X.currentcommit
                echo "currentbranch: ", X.currentbranch

        if 2 in Tests:
                const inp=staticread("testdata/status_v2_2.txt").split '\n'
                let X=parse_status_v2(inp)
                echo "currentcommit: ", X.currentcommit
                echo "currentbranch: ", X.currentbranch
                echo "unparsed: ", X.unparsed

        if 3 in Tests:
                const inp=staticread("testdata/status_v2_3.txt").split '\n'
                let X=parse_status_v2(inp)
                echo "currentcommit: ", X.currentcommit
                echo "currentbranch: ", X.currentbranch
                echo "unparsed: ", X.unparsed
                echo "unmerged: ", X.unmerged

        if 4 in Tests:
                echo "Parse Status Test 4"
                const inp=staticread("testdata/status_v2_4.txt").split '\n'
                let X=parse_status_v2(inp)
                echo "currentcommit: ", X.currentcommit
                echo "currentbranch: ", X.currentbranch
                echo "unparsed: ", X.unparsed
                echo "unmerged: ", X.unmerged

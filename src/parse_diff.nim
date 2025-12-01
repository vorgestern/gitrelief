
import std/[strutils, strformat, tables, times, assertions]
import checksums/sha1
import npeg
import helper, gitparsers

type
        NABRM* =enum N, A, B, R, M
        DiffSection* =object
                case kind*: NABRM
                of N, A, B:
                        zeilen*: seq[string]
                of R:
                        razeilen*, rbzeilen*: seq[string]
                of M:
                        ourname, expectedname, theirname: string
                        ours*, expected*, theirs*: seq[string]
        FileDiff* =object
                op*: FileCommitStatus
                apath*, bpath*: string
                sections*: seq[DiffSection]

func numlines(S: DiffSection): int=
        case S.kind
        of N, A, B: S.zeilen.len
        of R: S.razeilen.len
        of M:
                let a=max(S.ours.len, S.expected.len)
                max(a, S.theirs.len)

proc addline(S: var DiffSection, z: string): bool=
        if z.len<1: return false
        if S.kind==M: return false
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
                if S.kind==B:   S.zeilen.add z1;                                             return true
                elif S.kind==A: S=DiffSection(kind: R, razeilen: S.zeilen, rbzeilen: @[z1]); return true
                elif S.kind==R: S.rbzeilen.add z1;                                           return true
                else:                                                                        return false
        of ' ':
                if neu: S=DiffSection(kind: N, zeilen: @[])
                if S.kind==N:   S.zeilen.add z1; return true
                else:                            return false
        else: return false # Fehler, wird noch nicht richtig behandelt.

proc parse_diff*(Difflines: seq[string]): seq[FileDiff]=
        type
                cxcontrolparser=object
                        na, nb, nc: int
                        FE: ptr seq[FileDiff]
                mergestage=enum none,ours,expected,theirs
                cxmergeparser=tuple[transition: mergestage, name: string]

        const DiffControlParser=peg("entry", e: cxcontrolparser):
                path <- +{1..31, 33..255}
                name <- +{1..31, 33..255}
                hash <- +{'0'..'9', 'a'..'f'}
                flags <- +{'0'..'9'}
                num <- +{'0'..'9'}
                diff_git <- "diff --git" * @>path * @>path:
                        add(e.FE[], FileDiff())
                        assert(e.FE[].len>0, "A")
                        e.FE[^1].apath= substr($1, 2)
                        e.FE[^1].bpath= substr($2, 2)
                diff_cc <- "diff --cc" * @>path:
                        add(e.FE[], FileDiff())
                        assert(e.FE[].len>0, "B")
                        e.FE[^1].apath=substr($1, 2)
                        e.FE[^1].bpath=substr($1, 2)
                index1 <- "index" * @>hash * ".." * @>hash * @flags: discard # Beachte: Die Hashes sind keine Commit-Hashes, sondern bezeichnen Blobs im Index.
                index2 <- "index" * @>hash * ',' * @>hash * ".." * @>hash: discard
                aaa <- "---" * @>path: assert(e.FE[].len>0, "C"); e.FE[^1].apath= substr($1, 2)
                bbb <- "+++" * @>path:
                        assert(e.FE[].len>0, "D")
                        e.FE[^1].bpath= substr($1, 2)
                        if e.FE[^1].op==Other: e.FE[^1].op=Modified
                newfile <- "new file mode" * @>flags:
                        assert(e.FE[].len>0, "E")
                        e.FE[^1].op=Added
                deletedfile <- "deleted file mode" * @>flags:
                        assert(e.FE[].len>0, "F")
                        e.FE[^1].op=Deleted
                similarity <- "similarity index" * @>num * '%': discard
                rename_from <- "rename from" * @>path:
                        assert(e.FE[].len>0, "G")
                        e.FE[^1].op=Renamed
                rename_to <- "rename to" * @>path:
                        assert(e.FE[].len>0, "H")
                        e.FE[^1].op=Renamed
                atat <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num * @"@@":
                        e.na=parseint $2
                        e.nb=parseint $4
                atat1 <- "@@" * @'-' * >num * ',' * >num * @'+' * >num * @"@@":
                        e.na=parseint($2)
                        e.nb=1
                atat2 <- "@@" * @'-' * >num * @'+' * >num * @"@@":
                        e.na=1
                        e.nb=1
                atatat <- "@@@" * @'-' * >num * ',' * >num * @'-' * >num * ',' * >num * @'+' * >num * ',' * >num * @"@@@":
                        e.na=parseint $2
                        e.nb=parseint $4
                        e.nc=parseint $6
                        # echo "atatat ", e.na, e.nb, e.nc
                sonst <- >(*1) * !1:
                        echo "Sonst '", $1, "'"
                entry <- diff_git | diff_cc | index1 | index2 | newfile | deletedfile | aaa | bbb | rename_from | rename_to | similarity | atatat | atat | atat1 | atat2 | sonst

        const MergeControlParser=peg("entry", e: cxmergeparser):
                name <- +{1..31, 33..255}
                ours <- "++<<<<<<<" * @>name: e=(transition: ours, name: $1)
                expected <- "++|||||||" * @>name: e=(transition: expected, name: $1)
                theirs <- "++=======": e=(transition: theirs, name: "")
                merged <- "++>>>>>>>" * @>name: e=(transition: none, name: $1)
                entry <- ours | expected | theirs | merged

        var
                na=0
                nb=0
                nc=0
                cxmerge: mergestage=none

        for z in Difflines:
                # echo "=====> ", z
                if nc>0:
                        {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                                # echo nc, " Merging '", z, "'"
                                let X=addr result[^1].sections[^1]
                                if X[].kind!=M: raise newException(ValueError, "Merge inkonsistent")
                                var e: cxmergeparser=(transition: none, name: "")
                                if MergeControlParser.match(strip z, e).ok:
                                        cxmerge=e.transition
                                        case cxmerge
                                        of ours:     result[^1].sections[^1].ourname=e.name
                                        of expected: result[^1].sections[^1].expectedname=e.name
                                        of theirs:   result[^1].sections[^1].theirname=e.name
                                        of none:     discard
                                else:
                                        case cxmerge
                                        of none: X.ours.add z; X.expected.add z; X.theirs.add z
                                        of ours: X.ours.add z
                                        of expected: X.expected.add z
                                        of theirs: X.theirs.add z
                        dec nc
                        if nc==0:
                                # Vorläufig
                                na=0
                                nb=0
                elif na>0 or nb>0:
                        if result[^1].sections.len==0: result[^1].sections.add DiffSection()
                        let added=result[^1].sections[^1].addline z
                        if not added:
                                let z1=substr(z, 1)
                                case z[0]
                                of '+': result[^1].sections.add DiffSection(kind: B, zeilen: @[z1])
                                of '-': result[^1].sections.add DiffSection(kind: A, zeilen: @[z1])
                                of ' ': result[^1].sections.add DiffSection(kind: N, zeilen: @[z1])
                                else: discard # Fehler, wird noch nicht richtig behandelt.
                        case z[0]
                        of '+': dec nb
                        of '-': dec na
                        else:   dec na; dec nb
                else:
                        {.gcsafe.}: # Ohne dies lässt sich der parser nicht in einer Multithreaded-Umgebung verwenden.
                                var e=cxcontrolparser(FE: addr result)
                                if DiffControlParser.match(strip z, e).ok:
                                        if e.nc>0:
                                                na=e.na
                                                nb=e.nb
                                                nc=e.nc
                                                result[^1].sections.add DiffSection(kind: M)
                                        elif e.na>0 or e.nb>0:
                                                na=e.na
                                                nb=e.nb
                                else: discard # Fehler, wird noch nicht richtig behandelt.

when ismainmodule:
        import std/[cmdline, sets, parseutils]
        var Tests=inithashset[uint8]()
        let args=commandlineparams()
        if args.len==0:
                for k in 1..2: Tests.incl uint8 k
        else:
                for a in args:
                        var k: uint
                        if parseuint(a, k)>0: Tests.incl uint8 k
                        else: echo "Failed to parse argument '", a, "', expected numbers in 1..2"

        if 1 in Tests:
                # Wenn man diese Beispieldaten zur Compilezeit parst (const X=parse_diff(...)),
                # erhält man eine unverstandene Fehlermeldung. Deshalb wird hier mit let X=parse_diff()
                # ein Parsen zur Laufzeit zugelassen.
                const data=staticread "testdata/diff_1.txt"
                let X=parse_diff(data.split '\n')
                for F in X:
                        # echo "FileDiff ", F.apath, " ", F.bpath, " (", F.sections.len, " Abschnitte)"
                        for s in F.sections:
                                # echo "section ", s.kind, "=========="
                                if s.kind==M:
                                        echo "\tours: ", s.ours
                                        echo "\texpected: ", s.expected
                                        echo "\ttheirs: ", s.theirs
                                else: echo $s

        if 2 in Tests:
                const data=staticread "testdata/diff_2.txt"
                let X=parse_diff(data.split '\n')
                for F in X:
                        echo "File ", F.apath
                        for s in F.sections:
                                if s.kind==M:
                                        echo "\tours: ", s.ours
                                        echo "\texpected: ", s.expected
                                        echo "\ttheirs: ", s.theirs
                                else: echo $s

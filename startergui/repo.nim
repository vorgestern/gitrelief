
import std/[strformat, strutils, strtabs, osproc]

type
        Repo* =ref object
                root*: string
                name*: string
                port*: int
                process: owned Process

proc `$`*(X: Repo): string {.used.}=
        if X.process!=nil: "repo(" & $X.port & ", '" & X.name & "', '" & X.root & "', " & $processid(X.process) & ")"
        else:              "repo(" & $X.port & ", '" & X.name & "', '" & X.root & "')"

proc newrepo*(r, n: string, p: int): Repo {.used.}=Repo(root: r, name: n, port: p)

proc parse_repos*(content: string): seq[Repo]=
        let L=content.split '\n'
        for k in L:
                let A=k.split ' '
                if A.len==3:
                        let p=parseint A[0]
                        result.add Repo(port: p, name: A[1], root: A[2])

proc serialise_repos*(R: seq[Repo]): string=
        echo "Serialise ", R.len, " repositories."
        for r in R:
                result.add fmt"{r.port} {r.name} {r.root}" & '\n'

# func iscomplete(port: int, name, root: string): bool= port>0 and name.len>0 and name!="-" and root.len>0 and root!="-"
# func iscomplete(r: Repo): bool= iscomplete(r.port, r.name, r.root)

proc running*(X: Repo): bool= X.process!=nil and running(X.process)
proc processid*(X: Repo): int= processid(X.process)

proc startserver*(X: Repo)=
        let
                args= @["--port", $X.port, "--name", X.name]
                env: StringTableRef=nil
                options={poUsePath}
        X.process=startprocess("gitrelief", X.root, args, env, options)

proc terminateserver*(X: Repo)=
        terminate(X.process)
        X.process=nil

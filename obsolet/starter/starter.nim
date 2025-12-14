
import system/iterators
import std/[sequtils, strutils, strscans, strformat, files, paths]
import owlkettle, owlkettle/[adw, dataentries]

type
        Repo* =ref object
                root*: string
                name*: string
                port*: int
                running: bool

proc newrepo(r, n: string, p: int): Repo {.used.}=Repo(root: r, name: n, port: p)

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

func iscomplete(port: int, name, root: string): bool= port>0 and name.len>0 and name!="-" and root.len>0 and root!="-"
func iscomplete(r: Repo): bool= iscomplete(r.port, r.name, r.root)

# =====================================================================

var
        merks: string
        merki: int

func checkport(p: int): bool=p>0 and p<65536
func checkname(s: string): bool=s.len>0
func checkroot(s: string): bool=s.len>0

viewable RepoLine:
        repo: Repo

method view(RLS: RepoLineState): Widget=
        gui:
                # Box(orient=OrientX, spacing=0):
                ListboxRow:
                        proc activate()=echo "Aktiviere ", RLS.repo.name
                        Flowbox(homogeneous=true):
                                Checkbutton {.addchild.}:
                                        sensitive=iscomplete(RLS.repo)
                                        proc changed(x: bool)=
                                                RLS.repo.running=x
                                                echo "Running ", RLS.repo.name, " ", RLS.repo.running
                                # Label(text="Hoppla")
                                EditableLabel {.addchild.}:
                                        text= $RLS.repo.port
                                        sensitive=not RLS.repo.running
                                        sizeRequest=(1,1)
                                        proc changed(x: string)= RLS.repo.port=parseint x
                                        proc editstatechanged(start: bool)=
                                                if start: merki=RLS.repo.port
                                                elif not checkport(RLS.repo.port):
                                                        echo "check port failed: ", RLS.repo.port, " gegen ", merki
                                                        RLS.repo.port=merki
                                EditableLabel {.addchild.}:
                                        text=RLS.repo.name
                                        sensitive=not RLS.repo.running
                                        sizeRequest=(1,1)
                                        proc changed(x: string)=RLS.repo.name=x
                                        proc editstatechanged(start: bool)=
                                                if start: merks=RLS.repo.name
                                                elif not checkname(RLS.repo.name):
                                                        echo "check name failed: '", RLS.repo.name, "' gegen ", merks
                                                        RLS.repo.name=merks
                                EditableLabel {.addchild.}:
                                        text=RLS.repo.root
                                        sensitive=not RLS.repo.running
                                        sizeRequest=(1,1)
                                        proc changed(x: string)=RLS.repo.root=x
                                        proc editstatechanged(start: bool)=
                                                if start: merks=RLS.repo.root
                                                elif not checkroot(RLS.repo.root):
                                                        echo "check root failed: '", RLS.repo.root, "' gegen ", merks
                                                        RLS.repo.root=merks

# =====================================================================

type
        AppData=ref object
                repos: seq[Repo]

viewable App:
        state: AppData

method view(app: AppState): Widget=
        result=gui:
                Window:
                        HeaderBar {.addtitlebar.}:
                                WindowTitle {.addtitle, addleft.}: title="Repositories"; subtitle= $app.state.repos.len & " items"
                                Button {.addLeft.}:
                                        icon="list-add-symbolic"
                                        proc clicked()=
                                                var p=0
                                                for r in app.state.repos: p=max(p, r.port)
                                                app.state.repos.add Repo(root: "-", name: "-", port: p+1)
                                # Button {.addRight.}: icon="open-menu-symbolic"
                        ScrolledWindow:
                                Listbox:
                                        margin=20
                                        for (j,r) in pairs(app.state.repos):
                                                RepoLine(repo=r)

proc main=
        const configfile="repositories.txt"
        var state=AppData(repos: @[])
        if fileexists Path configfile: state.repos=parse_repos readfile configfile
        adw.brew(gui App(state=state))
        writefile(configfile, serialise_repos state.repos)

main()

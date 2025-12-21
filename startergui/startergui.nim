
import std/[strutils, files, dirs, paths, envvars, cmdline]
import gio, gtk3
import repo, gtk3helper

proc nth[T](C: Container, n: int): T=
        let children=gtk_container_get_children(C)
        if children==nil: return nil
        let cn=g_list_nth(children, cuint n)
        if cn==nil: return nil
        if cn.data==nil: return nil
        result=cast[T](cn.data)
        g_list_free(children)

proc binchild[T](B: Bin): T=
        let X=gtk_bin_get_child(B)
        if X==nil: return nil
        return cast[T](X)

proc clicked_close(B: Button, data: GPointer) {.cdecl.}= g_print("Knopf '%s' geklickt!\n", gtk_button_get_label(B)); gtk_main_quit()

proc clicked_repobutton(B: CheckButton, data: GPointer) {.cdecl.}=
        let active=bool cast[ToggleButton](B).gtk_toggle_button_get_active
        let repo=cast[Repo](data)
        if active and not running(repo):
                repo.startserver()
                echo "pid=", processid(repo), ", root=", repo.root
        elif not active and running(repo):
                echo "Beende den Server mit pid=", processid(repo)
                repo.terminateserver()

proc port_edited(X: Entry, data: GPointer) {.cdecl.}= cast[Repo](data).port=parseint $gtk_entry_get_text X
proc name_edited(X: Entry, data: GPointer) {.cdecl.}= cast[Repo](data).name= $gtk_entry_get_text X
proc root_edited(X: Entry, data: GPointer) {.cdecl.}= cast[Repo](data).root= $gtk_entry_get_text X

proc unfocus(X: Widget, data: GPointer) {.cdecl.}=
        gtk_widget_set_name(X, "FBChildContainer")
        gtk_widget_set_can_focus(X, Gboolean false)
        gtk_style_context_add_class(gtk_widget_get_style_context(X), "ebox")

proc mkrepodetail(detail, default: string, width: int): Entry=
        result=gtk_entry_new()
        if valid result:
                gtk_widget_set_halign(result, START)
                gtk_entry_set_placeholder_text(result, cstring default)
                gtk_entry_set_text(result, cstring detail)
                gtk_entry_set_width_chars(result, cint width)
                gtk_entry_set_has_frame(result, Gboolean true)
                gtk_style_context_add_class(gtk_widget_get_style_context(result), "repodetail")

proc mkreporow(repo: Repo): ListboxRow=
        result=gtk_list_box_row_new()
        if valid result:
                gtk_style_context_add_class(gtk_widget_get_style_context(result), "reporow")
                let F=gtk_flow_box_new()
                if valid F:
                        gtk_style_context_add_class(gtk_widget_get_style_context(F), "reporow")
                        gtk_widget_set_can_focus(F, Gboolean false)
                        gtk_container_add(result, F)
                        let cb=gtk_check_button_new_with_label "running"
                        if valid cb:
                                gtk_style_context_add_class(gtk_widget_get_style_context(cb), "reporunning")
                                gtk_container_add(F, cb)
                                discard g_signal_connect(GPointer cb, cstring "toggled", cast[GCallback](clicked_repobutton), cast[GPointer](repo))
                        let E1=mkrepodetail($repo.port, "port", 6)
                        discard g_signal_connect(GPointer E1, cstring "changed", cast[GCallback](port_edited), cast[GPointer](repo))
                        gtk_container_add(F, E1)
                        let E2=mkrepodetail(repo.name, "page title", 30)
                        discard g_signal_connect(GPointer E2, cstring "changed", cast[GCallback](name_edited), cast[GPointer](repo))
                        gtk_container_add(F, E2)
                        let E3=mkrepodetail(repo.root, "repo path", 80)
                        discard g_signal_connect(GPointer E3, cstring "changed", cast[GCallback](root_edited), cast[GPointer](repo))
                        gtk_container_add(F, E3)
                        # Beim Einfügen wickelt die Flowbox jedes Entryfeld in einen weiteren Container ein.
                        # Hier werden diese Container eingestellt (kein Tastaturfokus, css-Klasse .ebox).
                        gtk_container_forall(F, Callback unfocus, GPointer nil)

proc mkrepolist(repos: seq[Repo]): tuple[S: ScrolledWindow, L: Listbox]=
        let SW=gtk_scrolled_window_new(nil, nil)
        if valid SW:
                let LB=gtk_list_box_new()
                if valid LB:
                        gtk_container_add(SW, LB)
                        for repo in repos:
                                let LBR=mkreporow(repo)
                                if valid LBR: gtk_container_add(LB, LBR)
                        gtk_scrolled_window_set_shadow_type(SW, NONE)
                        gtk_scrolled_window_set_propagate_natural_width(SW, Gboolean true)
                        gtk_scrolled_window_set_propagate_natural_height(SW, Gboolean true)
                        result=(S: SW, L: LB)

proc startbutton_to_listbox(B: Button): tuple[VB: Widget, LB: Listbox]=
        let BG=gtk_widget_get_ancestor(B.parent, GTK_TYPE_CONTAINER())
        if BG!=nil:
                let VB=gtk_widget_get_ancestor(BG.parent, GTK_TYPE_BOX())
                if VB!=nil:
                        let SW=nth[ScrolledWindow](Container VB, 1)
                        if SW!=nil:
                                let VP=nth[Viewport](SW, 0)
                                if VP!=nil: result=(VB: VB, LB: binchild[Listbox](VP))

proc clicked_addrepo(B: Button, data: GPointer) {.cdecl.}=
                                        let Repos=cast[ptr seq[Repo]](data)
                                        let (VB,LB)=startbutton_to_listbox(B)
                                        if LB!=nil:
                                                echo "Hier ist die Listbox ", bool GTK_IS_LISTBOX(LB), " ", $gtk_widget_get_name(LB)
                                                let
                                                        port=8090
                                                        name="-"
                                                        root="-"
                                                let r=Repo(port: port, name: name, root: root)
                                                var repo=r
                                                let LBR=mkreporow(repo)
                                                if valid LBR:
                                                        echo "Add LBR to LB", LBR.gtk_widget_get_name()
                                                        gtk_container_add(LB, LBR)
                                                        gtk_widget_show_all(VB)
                                                        Repos[].add r

proc clicked_remrepo(B: CheckButton, data: GPointer) {.cdecl.}=
        let Repos=cast[ptr seq[Repo]](data)
        let (VB,LB)=startbutton_to_listbox(B)
        if LB!=nil:
                let R=gtk_list_box_get_selected_row(LB)
                if R!=nil:
                        var index=0;
                        while true:
                                let J=gtk_list_box_get_row_at_index(LB, cint index);
                                if J==nil: break
                                if J==R:
                                        gtk_container_remove(LB, R)
                                        Repos[].delete(index)
                                inc index
                        gtk_widget_show_all(VB)

# std/paths
# func parentdir(path: Path): Path
# std/dirs
# proc direxists(dir: Path): bool
# std/files
# proc fileexists(filename: Path): bool

proc loadconfig(Repos: var seq[Repo], configfile: Path): Path=
        const repositories=Path "repositories.txt"
        if $configfile!="":
                if fileexists configfile: Repos=parse_repos readfile $configfile
                let configdir=parentdir configfile
                if not direxists configdir: createdir configdir
                return configfile
        if existsenv "XDG_CONFIG_HOME":
                let configdir=(Path getenv "XDG_CONFIG_HOME") / Path "gitrelief"
                let configfile=configdir/repositories
                if fileexists configfile: Repos=parse_repos readfile $configfile
                if not direxists configdir: createdir configdir
                return configfile
        if existsenv "HOME":
                let configdir=(Path getenv "HOME") / Path ".config/gitrelief"
                let configfile=configdir / repositories
                if fileexists configfile: Repos=parse_repos readfile $configfile
                if not direxists configdir: createdir configdir
                return configfile
        return repositories

var Repos: seq[Repo]= @[]

proc main=
        var
                argc: cint=0
                argv: cstringarray
        gtk_init(argc, argv)

        var
                dump=false
        for arg in commandlineparams():
                if arg=="-d": dump=true

        let configfile=loadconfig(Repos, Path "")

        const css=compile_css(".", "start", "start.gresource.xml")
        discard cssload_from_memory(css, "/path/for/bundle/start.css")

        let MainWindow=gtk_window_new(TOPLEVEL)
        if valid MainWindow:
                let VertikalBox=gtk_box_new(VERTICAL, 7)
                if valid VertikalBox:
                        VertikalBox.name="columnbox"
                        let Hinweis=gtk_label_new "Repositories"
                        if valid Hinweis:
                                Hinweis.name="hinweis"
                                gtk_widget_set_halign(Hinweis, START)
                                gtk_container_add(VertikalBox, Hinweis)

                        let (S,L)=mkrepolist(Repos)
                        if valid(S) and valid(L):
                                gtk_container_add(VertikalBox, S)
                                discard g_signal_connect(GPointer L, cstring "clicked", cast[GCallback](clicked_addrepo), cast[GPointer](addr Repos))

                        let Buttons=gtk_button_box_new(HORIZONTAL)
                        if valid Buttons:
                                gtk_container_add(VertikalBox, Buttons)
                                gtk_button_box_set_layout(Buttons, EXPAND)
                                Buttons.name="buttons"
                                let B1=gtk_button_new_with_label "Add Repo"
                                if valid B1:
                                        gtk_container_add(Buttons, B1)
                                        B1.name="addrepo"
                                        discard g_signal_connect(GPointer B1, cstring "clicked", cast[GCallback](clicked_addrepo), cast[GPointer](addr Repos))

                                let B2=gtk_button_new_with_label "Remove Repo"
                                if valid B2:
                                        gtk_container_add(Buttons, B2)
                                        B2.name="remrepo"
                                        discard g_signal_connect(GPointer B2, cstring "clicked", cast[GCallback](clicked_remrepo), cast[GPointer](addr Repos))

                                let B0=gtk_button_new_with_label "Close"
                                if valid B0:
                                        gtk_container_add(Buttons, B0)
                                        B0.name="closebutton"
                                        discard g_signal_connect(GPointer B0, cstring "clicked", cast[GCallback](clicked_close), GPointer nil)

                        gtk_container_add(MainWindow, VertikalBox)
                gtk_window_set_title(MainWindow, "Demo simple4") # MainWindow.title="Demo simple4"
                gtk_window_set_default_size(MainWindow, 800, 300)
                gtk_container_set_border_width(MainWindow, 10)
                if dump: dump_hierarchy(Widget MainWindow)
                discard g_signal_connect(MainWindow, "destroy", gtk_main_quit)
                gtk_widget_show_all(MainWindow)
                gtk_main()
                for repo in Repos:
                        if running(repo): repo.terminateserver()

                # echo "writefile ", $configfile
                writefile($configfile, serialise_repos Repos)

main()

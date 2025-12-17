
import std/[strutils, files, paths]
import gio, gtk3
import repo, gtk3helper

proc clicked_close(B: Button, data: GPointer) {.cdecl.}= g_print("Knopf '%s' geklickt!\n", gtk_button_get_label(B)); gtk_main_quit()
proc clicked_addrepo(B: Button, data: GPointer) {.cdecl.}= g_print "Klick ", gtk_button_get_label(B)

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
        gtk_widget_set_name(X, "FBC99")
        gtk_widget_set_can_focus(X, Gboolean false)

proc mkrepodetail(detail, default: string, width: int): Entry=
        result=gtk_entry_new()
        if valid result:
                gtk_widget_set_halign(result, START)
                gtk_entry_set_placeholder_text(result, cstring default)
                gtk_entry_set_text(result, cstring detail)
                gtk_entry_set_width_chars(result, cint width)
                gtk_entry_set_has_frame(result, Gboolean false)
                gtk_style_context_add_class(gtk_widget_get_style_context(result), "repodetail")

proc mkreporow(repo: Repo): ListboxRow=
        result=gtk_list_box_row_new()
        if valid result:
                gtk_style_context_add_class(gtk_widget_get_style_context(result), "reporow")
                let F=gtk_flow_box_new()
                if valid F:
                        gtk_widget_set_name(F, "F99")
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

var Repos: seq[Repo]= @[]

proc main=
        var
                argc: cint=0
                argv: cstringArray
        gtk_init(argc, argv)

        const configfile="repositories.txt"
        if fileexists Path configfile: Repos=parse_repos readfile configfile

        const css=compile_css(".", "start", "start.gresource.xml")
        discard cssload_from_memory(css, "/path/for/bundle/start.css")

        let MainWindow=gtk_window_new(TOPLEVEL)
        if valid MainWindow:
                let VertikalBox=gtk_box_new(VERTICAL, 7)
                if valid VertikalBox:
                        let Hinweis=gtk_label_new "Repositories"
                        if valid Hinweis:
                                gtk_widget_set_name(Hinweis, "hinweis")
                                gtk_widget_set_halign(Hinweis, START)
                                gtk_container_add(VertikalBox, Hinweis)

                        let (S,L)=mkrepolist(Repos)
                        if valid(S) and valid(L):
                                gtk_container_add(VertikalBox, S)

                        let Buttons=gtk_button_box_new(HORIZONTAL)
                        if valid Buttons:
                                gtk_button_box_set_layout(Buttons, EXPAND)
                                let B0=gtk_button_new_with_label "Close"
                                if valid B0:
                                        gtk_container_add(Buttons, B0)
                                        discard g_signal_connect(GPointer B0, cstring "clicked", cast[GCallback](clicked_close), GPointer nil)

                                when false:
                                        let B1=gtk_button_new_with_label("Add Repo")
                                        if valid B1:
                                                gtk_container_add(Buttons, B1);
                                                gtk_widget_set_name(B1, "hoppla")
                                                discard g_signal_connect(GPointer B1, cstring "clicked", cast[GCallback](clicked_addrepo), GPointer nil)

                                gtk_container_add(VertikalBox, Buttons)
                        gtk_container_add(MainWindow, VertikalBox)
                gtk_window_set_title(MainWindow, "Demo simple4") # MainWindow.title="Demo simple4"
                gtk_window_set_default_size(MainWindow, 700, 300)
                gtk_container_set_border_width(MainWindow, 10)
                dump_hierarchy(Widget MainWindow)
                discard g_signal_connect(MainWindow, "destroy", gtk_main_quit)
                gtk_widget_show_all(MainWindow)
                gtk_main()
                for repo in Repos:
                        if running(repo): repo.terminateserver()
                writefile(configfile, serialise_repos Repos)

main()

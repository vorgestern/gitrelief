
import std/[strformat, strutils, strtabs, files, paths, osproc]
import gio, gtk3

type
        repodetail=enum
                root # =(1, "root") # import std/enumutils
                name # =(2, "name")
                port # =(3, "port")
        Repo=ref object
                root: string
                name: string
                port: int

# proc `$`(X: Repo): string = "repo(" & $X.port & ", '" & X.name & "', '" & X.root & "')"

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

# func iscomplete(port: int, name, root: string): bool= port>0 and name.len>0 and name!="-" and root.len>0 and root!="-"
# func iscomplete(r: Repo): bool= iscomplete(r.port, r.name, r.root)

# =====================================================================

proc compile_css(): string=
        discard staticexec("glib-compile-resources --sourcedir . --target start.gresource start.gresource.xml")
        staticread "start.gresource"

proc cssload_from_memory(X: string, csspath: string): bool=
        var E: GError
        let
                start=cast[ptr UncheckedArray[char]](addr X[0])
                len: Gsize=cast[uint](X.len)
                B=g_bytes_new_static(start, len)
                R=g_resource_new_from_data(B, E)
        if E==nil:
                g_resources_register R
                let P=gtk_css_provider_new()
                gtk_css_provider_load_from_resource(P, csspath)
                gtk_style_context_add_provider_for_screen(gdk_screen_get_default(), cast[StyleProvider](P), STYLE_PROVIDER_PRIORITY_USER)
                return true
        else:
                g_print("Fehlermeldung: %d '%s'\n", E.code, E.message)
                g_error_free E
                return false

proc clicked_close(B: Button, data: GPointer) {.cdecl.}=
        g_print("Knopf '%s' geklickt!\n", gtk_button_get_label(B))
        echo "clicked_close"
        gtk_main_quit()

proc clicked_hoppla(B: Button, data: GPointer) {.cdecl.}=
        g_print "Klick Knopf:\n"
        g_print "\tlabel='%s'\n", gtk_button_get_label(B)
        g_print "\tname='%s'\n", gtk_widget_get_name(B)

# Iteriere mit Hilfe einer Liste.
# proc clicked_repobutton1(B: CheckButton, data: GPointer) {.cdecl.}=
#         g_print "Klick Repobutton:\n"
#         let F=cast[FlowBox](data)
#         let Cs=gtk_container_get_children(F)
#         var index: int=0
#         proc f(data: Gpointer; inst: Gpointer) {.cdecl.}=
#                 var indexpointer=cast[ptr int](inst)
#                 case indexpointer[]
#                 of 99:
#                         let cb=cast[ToggleButton](data)
#                         let p=gtk_toggle_button_get_active(cb)
#                         echo "checkbutton ", bool p
#                 else:
#                         echo "function f ", indexpointer[], "\n"
#                 inc indexpointer[]
#         g_list_foreach(Cs, f, addr index)

# Iteriere direkt über die Kinder eines Containers.
proc clicked_repobutton(B: CheckButton, data: GPointer) {.cdecl.}=
        type cxtype=tuple[index: int, state: bool, port: string, name: string, root: string]
        proc f(X: Widget; inst: Gpointer) {.cdecl.}=
                var cx=cast[ptr cxtype](inst)
                inc cx[].index
                let C=gtk_bin_get_child cast[FlowBoxChild](X)
                if not valid C: return
                case cx[].index
                of 1:
                        let cb=cast[ToggleButton](C)
                        cx[].state=bool gtk_toggle_button_get_active(cb)
                of 2:
                        gtk_widget_set_sensitive(C, Gboolean(not cx[].state))
                        cx[].port= $gtk_entry_get_text(Entry C)
                of 3:
                        gtk_widget_set_sensitive(C, Gboolean(not cx[].state))
                        cx[].name= $gtk_entry_get_text(Entry C)
                of 4:
                        gtk_widget_set_sensitive(C, Gboolean(not cx[].state))
                        cx[].root= $gtk_entry_get_text(Entry C)
                else: discard
        var cx=(index:0, state: false, port: "", name: "", root: "")
        gtk_container_foreach(cast[FlowBox](data), f, addr cx)

        if cx.state:
                let args= @["--port", cx.port, "--name", cx.name]
                let env: StringTableRef=nil
                let options={poUsePath}
                let process=startprocess("gitrelief", cx.root, args, env, options)
                echo "process=", processid(process)

proc entry_changed(X: Entry, data: GPointer) {.cdecl.}=
        let repo=cast[Repo](g_object_get_data(cast[GObject](X), "repo"))
        let role=cast[repodetail](data)
        case role
        of port:
                let text=gtk_entry_get_text X
                let str= $text
                let p=parseint(str)
                echo "changed port to ", p
                repo.port=p
        of name:
                repo.name= $gtk_entry_get_text X
                echo "changed name to ", repo.name
        of root:
                repo.root= $gtk_entry_get_text X
                echo "changed root to ", repo.root

proc unfocus(X: Widget, data: GPointer) {.cdecl.}=
        # echo "unfocus ", gtk_widget_get_name(X)
        gtk_widget_set_name(X, "FBC99")
        gtk_widget_set_can_focus(X, Gboolean false)

proc mkrepodetail(detail, default: string, width: int, instance: GPointer, role: repodetail): Entry=
        result=gtk_entry_new()
        if valid result:
                gtk_widget_set_halign(result, START)
                gtk_entry_set_placeholder_text(result, cstring default)
                gtk_entry_set_text(result, cstring detail)
                gtk_entry_set_width_chars(result, cint width)
                gtk_entry_set_has_frame(result, Gboolean false)
                gtk_style_context_add_class(gtk_widget_get_style_context(result), "repodetail") # CSS-Klasse .repodetail
                g_object_set_data(cast[GObject](result), "repo", instance)
                # g_object_set_data(cast[GObject](result), "role", role.symbolname)
                discard g_signal_connect(GPointer result, cstring "changed", cast[GCallback](entry_changed), cast[GPointer](role))
                # gtk_entry_set_alignment(result, 0)
                # gtk_entry_set_visibility(result, Gboolean false)
                # gtk_entry_set_invisible_char(result, 0x2055)
                # gtk_entry_set_overwrite_mode(result, Gboolean true)

proc reporow(repo: Repo): ListboxRow=
        result=gtk_list_box_row_new()
        if valid result:
                # gtk_widget_set_margin_bottom(result, 10)
                # gtk_widget_set_can_focus(result, Gboolean false) ListboxRow muss anscheinend fokussierbar sein, sonst bleibt die ganze Zeile mit der Tabulatortaste unerreichbar.
                let context=gtk_widget_get_style_context(result)
                gtk_style_context_add_class(context, "reporow") # CSS-Klasse .repodetail
                let F=gtk_flow_box_new()
                if valid F:
                        gtk_widget_set_name(F, "F99")
                        gtk_widget_set_can_focus(F, Gboolean false)
                        gtk_container_add(result, F)
                        let cb=gtk_check_button_new_with_label "running"
                        if valid cb:
                                # gtk_widget_set_halign(cb, START)
                                gtk_style_context_add_class(gtk_widget_get_style_context(cb), "reporunning")
                                gtk_container_add(F, cb)
                                discard g_signal_connect(GPointer cb, cstring "toggled", cast[GCallback](clicked_repobutton), cast[GPointer](F))
                        gtk_container_add(F, mkrepodetail($repo.port, "port", 6, cast[GPointer](repo), port))
                        gtk_container_add(F, mkrepodetail(repo.name, "page title", 30, cast[GPointer](repo), name))
                        gtk_container_add(F, mkrepodetail(repo.root, "repo path", 80, cast[GPointer](repo), root))
                        gtk_container_forall(F, Callback unfocus, GPointer nil)

proc repolist(content: seq[Repo]): tuple[S: ScrolledWindow, L: Listbox]=
        let S=gtk_scrolled_window_new(nil, nil)
        if valid S:
                let L=gtk_list_box_new()
                if valid L:
                        gtk_container_add(S, L);
                        for k in content:
                                let F=reporow(k)
                                if valid F: gtk_container_add(L, F)
                        gtk_scrolled_window_set_shadow_type(S, NONE)
                        gtk_scrolled_window_set_propagate_natural_width(S, Gboolean true)
                        gtk_scrolled_window_set_propagate_natural_height(S, Gboolean true)
                        result=(S: S, L: L)

var Repos: seq[Repo]= @[]

proc main=
        var
                argc: cint=0
                argv: cstringArray
        gtk_init(argc, argv)

        const configfile="repositories.txt"
        if fileexists Path configfile: Repos=parse_repos readfile configfile

        const css=compile_css()
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

                        let (S,L)=repolist(Repos)
                        if valid(S) and valid(L):
                                gtk_container_add(VertikalBox, S)

                        let Buttons=gtk_button_box_new(HORIZONTAL)
                        if valid Buttons:
                                gtk_button_box_set_layout(Buttons, EXPAND)
                                let B0=gtk_button_new_with_label "Close"
                                if valid B0:
                                        gtk_container_add(Buttons, B0)
                                        discard g_signal_connect(GPointer B0, cstring "clicked", cast[GCallback](clicked_close), GPointer nil)

                                let B1=gtk_button_new_with_label("more ..")
                                if valid B1:
                                        gtk_container_add(Buttons, B1);
                                        gtk_widget_set_name(B1, "hoppla")
                                        discard g_signal_connect(GPointer B1, cstring "clicked", cast[GCallback](clicked_hoppla), GPointer nil)

                                gtk_container_add(VertikalBox, Buttons)
                        gtk_container_add(MainWindow, VertikalBox)
                gtk_window_set_title(MainWindow, "Demo simple4") # MainWindow.title="Demo simple4"
                gtk_window_set_default_size(MainWindow, 700, 300)
                gtk_container_set_border_width(MainWindow, 10)
                discard g_signal_connect(MainWindow, "destroy", gtk_main_quit)
                gtk_widget_show_all(MainWindow)
                gtk_main()
                writefile(configfile, serialise_repos Repos)

main()

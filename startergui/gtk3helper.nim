
import std/[strformat, strutils]
import gio, gtk3

proc dumphierarchy*(X: Widget, level=0)=
        if X==nil:
                echo repeat("    ", level), "nil"
                return
        let name=gtk_widget_get_name(X)
        if bool GTK_IS_CONTAINER(X):
                echo repeat("    ", level), "Container ", name
                let Cs=gtk_container_get_children(Container X)
                var C=Cs
                while C!=nil:
                        let Y=cast[Widget](C.data)
                        if Y!=nil: dumphierarchy(Y, level+1)
                        C=C.next
                g_list_free(Cs)
        elif bool GTK_IS_BIN(X):
                echo repeat("    ", level), "Bin ", name
                dump_hierarchy(gtk_bin_get_child(Bin X), level+1)
        else:
                echo repeat("    ", level), name, " ", $X.path

# =====================================================================

proc compile_css*(sourcedir, name, xmlfile: string): string=
        discard staticexec fmt"glib-compile-resources --sourcedir {sourcedir} --target {name}.gresource {xmlfile}"
        staticread "start.gresource"

proc cssload_from_memory*(X: string, csspath: string): bool=
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

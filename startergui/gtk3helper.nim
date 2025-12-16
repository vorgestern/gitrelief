
import std/strutils
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

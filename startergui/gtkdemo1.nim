
import std/[strutils, files, dirs, paths, envvars, cmdline]
import gio, gtk3
import gtk3helper

# void destroy(GtkWidget*self, gpointer user_data)
proc destroywindow(X: Widget) {.cdecl.}=
        gtk_widget_destroy(X)
        gtk_main_quit()

proc main=
        var
                argc: cint=0
                argv: cstringarray
        gtk_init(argc, argv)

        var
                dump=false
                level=9
        let
                xxargv=commandlineparams()
                xxargc=xxargv.len
        for j in 0..<xxargc:
                let arg=xxargv[j]
                if arg=="-d": dump=true
                if arg=="-l" and j<xxargc-1: level=parseint xxargv[j+1]

        echo "============================================== ", level

        proc clicked_close(B: Button, data: GPointer) {.cdecl.}=
                let MainWindow=cast[Window](data)
                echo "MainWindow=", cast[int](MainWindow)
                gtk_widget_destroy(MainWindow)
                gtk_main_quit()

        let MainWindow=gtk_window_new(TOPLEVEL)
        if level>1 and valid MainWindow:
                let VertikalBox=gtk_box_new(VERTICAL, 7)
                if level>2 and valid VertikalBox:
                        # VertikalBox.name="columnbox"
                        let Hinweis=gtk_label_new "Repositories"
                        if valid Hinweis:
                                # Hinweis.name="hinweis"
                                gtk_widget_set_halign(Hinweis, START)
                                gtk_container_add(VertikalBox, Hinweis)

                        let Buttons=gtk_button_box_new(HORIZONTAL)
                        if valid Buttons:
                                gtk_container_add(VertikalBox, Buttons)
                                gtk_button_box_set_layout(Buttons, EXPAND)
                                # Buttons.name="buttons"
                                let B0=gtk_button_new_with_label "Close"
                                if valid B0:
                                        gtk_container_add(Buttons, B0)
                                        # B0.name="closebutton"
                                        discard g_signal_connect(GPointer B0, cstring "clicked", cast[GCallback](clicked_close), GPointer MainWindow)

                        gtk_container_add(MainWindow, VertikalBox)

                gtk_window_set_title(MainWindow, "Demo simple4") # MainWindow.title="Demo simple4"
                gtk_window_set_default_size(MainWindow, 800, 300)
                gtk_container_set_border_width(MainWindow, 10)
                if dump: dump_hierarchy(Widget MainWindow)
                discard g_signal_connect(MainWindow, "destroy", destroywindow)
                gtk_widget_show_all(MainWindow)
                echo "==== next main ==============================="
                gtk_main()
#               gtk_widget_destroy(MainWindow)

main()

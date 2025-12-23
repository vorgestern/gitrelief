
import std/[strutils, files, dirs, paths, envvars, cmdline]
import gio, gtk3
import gtk3helper

proc activate(app: Application, user_data: GPointer) {.cdecl.}=
        let W=gtk_application_window_new(app)
        gtk_window_set_title(W, "Demowindow")
        gtk_window_set_default_size(W, 200, 200)
        gtk_widget_show_all(W)

proc main()=
        let app=gtk_application_new("gtk.demo2", NONE) # Der Name scheint nicht beliebig zu sein. 'gtk.' oä muss sein.
        discard g_signal_connect(app, "activate", cast[GCallback](activate), nil)
        var
                argc: cint=0
                argv: cstringarray
        let status=g_application_run(app, argc, argv)
        g_object_unref(app)

main()

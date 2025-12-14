
import gobject

when defined(windows):
        const LIB_GDK* ="libgdk-3-0.dll"
elif defined(gtk_quartz):
        const LIB_GDK* ="libgdk-3.0.dylib"
elif defined(macosx):
        const LIB_GDK* ="libgdk-x11-3.0.dylib"
else:
        const LIB_GDK* ="libgdk-3.so(|.0)"

{.pragma: libgdk, cdecl, dynlib: LIB_GDK.}

type
        Screen* =ptr ScreenObj
        ScreenObj* {.final.} =object of GObject

proc gdk_screen_get_default*(): Screen {.importc: "gdk_screen_get_default", libgdk.}

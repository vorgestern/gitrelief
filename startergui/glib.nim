
when defined(windows):
        const LIB_GLIB* = "libglib-2.0-0.dll"
elif defined(macosx):
        const LIB_GLIB* = "libglib-2.0.dylib"
else:
        const LIB_GLIB* = "libglib-2.0.so(|.0)"

{.pragma: libglib, cdecl, dynlib: LIB_GLIB.}

type
        Gboolean* =distinct cint
        Gint* =cint # glib aliases which are not really needed
        Guint* =cuint
        Gshort* =cshort
        Gushort* =cushort
        Glong* =clong
        Gulong* =culong
        Gchar* =cchar
        Guchar* =uint8
        Gfloat* =cfloat
        Gdouble* =cdouble
        Gunichar* =cuint

        Gssize* = int # csize # fix for Nim > 1.04 to avoid many deprecation warnings
        Gsize* = uint # csize # note: csize is signed in Nim!
        Goffset* = int64
        # GPid = cint

        Gpointer* =pointer
        Gconstpointer* =pointer
        # GCompareFunc* =proc (a: Gconstpointer; b: Gconstpointer): cint {.cdecl.}
        # GCompareDataFunc* =proc (a: Gconstpointer; b: Gconstpointer; userData: Gpointer): cint {.cdecl.}
        # GEqualFunc* =proc(a: Gconstpointer; b: Gconstpointer): Gboolean {.cdecl.}
        # GDestroyNotify* =proc(data: Gpointer) {.cdecl.}
        GFunc* =proc(data: Gpointer; inst: Gpointer) {.cdecl.}
        # GHashFunc* =proc(key: Gconstpointer): cuint {.cdecl.}
        # GHFunc* =proc(key: Gpointer; value: Gpointer; userData: Gpointer) {.cdecl.}

const
        G_MAXUINT* =high(cuint)
        G_MAXUSHORT* =high(cushort)
        GLIB_SIZEOF_VOID_P =sizeof(pointer)
        GLIB_SIZEOF_SIZE_T* =GLIB_SIZEOF_VOID_P
        GLIB_SIZEOF_LONG* =sizeof(clong)

type
        GData* =ptr GDataObj
        GDataObj* =object

        GList* =ptr GListObj
        GListObj* =object
                data*: Gpointer
                next*: GList
                prev*: GList

        GSList* =ptr GSListObj
        GSListObj* =object
                data*: Gpointer
                next*: GSList

        GQuark* =uint32

        GError* =ptr GErrorObj
        GErrorObj* =object
                domain*: GQuark
                code*: cint
                message*: cstring

        GBytes* =ptr GBytesObj
        GBytesObj* =object

proc g_print*(format: cstring) {.varargs, importc: "g_print", libglib.}
proc g_bytes_new_static*(data: Gconstpointer; size: Gsize): GBytes {.importc: "g_bytes_new_static", libglib.}
proc g_error_free*(error: GError) {.importc: "g_error_free", libglib.}

proc g_list_alloc*(): GList {.importc: "g_list_alloc", libglib.}
proc g_list_free*(list: GList) {.importc: "g_list_free", libglib.}
proc g_list_free_1*(list: GList) {.importc: "g_list_free_1", libglib.}
# proc g_list_free_full*(list: GList; freeFunc: GDestroyNotify) {.importc: "g_list_free_full", libglib.}
proc g_list_append*(list: GList; data: Gpointer): GList {.importc: "g_list_append", libglib.}
proc g_list_prepend*(list: GList; data: Gpointer): GList {.importc: "g_list_prepend", libglib.}
proc g_list_insert*(list: GList; data: Gpointer; position: cint): GList {.importc: "g_list_insert", libglib.}

proc g_list_nth*(list: GList; n: cuint): GList {.importc: "g_list_nth", libglib.}
proc g_list_nth_prev*(list: GList; n: cuint): GList {.importc: "g_list_nth_prev", libglib.}

proc g_list_foreach*(list: GList; f: GFunc; data: Gpointer) {.importc: "g_list_foreach", libglib.}

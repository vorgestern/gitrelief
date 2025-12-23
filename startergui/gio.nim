
import glib, gobject

when defined(windows):
        const LIB_GIO = "libgio-2.0-0.dll"
elif defined(macosx):
        const LIB_GIO = "libgio-2.0(|-0).dylib"
else:
        const LIB_GIO = "libgio-2.0.so(|.0)"

{.pragma: libgio, cdecl, dynlib: LIB_GIO.}

type
        GResource* =ptr GResourceObj
        GResourceObj* =object

        GListModel* =ptr GListModelObj
        GListModelObj* = object

        GApplication* =ptr GApplicationObj
        # GApplicationPtr* =ptr GApplicationObj
        GApplicationObj* =object of GObjectObj

proc g_resource_new_from_data*(X: glib.GBytes; error: var GError): GResource {.importc: "g_resource_new_from_data", libgio.}
proc g_resources_register*(X: GResource) {.importc: "g_resources_register", libgio.}

proc listmodelgettype*(): GType {.importc: "g_list_model_get_type", libgio.}

proc g_application_run*(application: GApplication; argc: cint; argv: cstringArray): cint {.importc: "g_application_run", libgio.}

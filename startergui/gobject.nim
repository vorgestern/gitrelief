
when defined(windows):
        const LIB_GOBJ* = "libgobject-2.0-0.dll"
elif defined(macosx):
        const LIB_GOBJ* = "libgobject-2.0.dylib"
else:
        const LIB_GOBJ* = "libgobject-2.0.so(|.0)"

{.pragma: libgobj, cdecl, dynlib: LIB_GOBJ.}

import glib

const
        CPLUSPLUS=false
        G_DISABLE_CAST_CHECKS {.used.}=false

when GLIB_SIZEOF_SIZE_T!=GLIB_SIZEOF_LONG or not CPLUSPLUS:
        type
                GType* =Gsize
else:
        type
                GType* =culong

type
        GTypeClass* =ptr GTypeClassObj
        GTypeClassObj* {.inheritable, pure.} =object
                g_type*: GType

        GTypeInstance* =ptr GTypeInstanceObj
        GTypeInstanceObj* {.inheritable, pure.} =object
                g_class*: GTypeClass

        value_union* {.union.} =object
                vInt*: cint
                vUint*: cuint
                vLong*: clong
                vUlong*: culong
                vInt64*: int64
                vUint64*: uint64
                vFloat*: cfloat
                vDouble*: cdouble
                vPointer*: Gpointer

        GValue* =ptr GValueObj
        GValueObj* =object
                g_type*: GType
                data*: array[2, value_union]

        GObject* =ptr GObjectObj
        GObjectObj* =object of GTypeInstanceObj
                refcount*: cuint
                qdata*: GData

type
        GParamFlags* {.size: sizeof(cint), pure.} =enum
                DEPRECATED = (1.cint shl 31)
                READABLE = 1 shl 0, WRITABLE = 1 shl 1,
                CONSTRUCT = 1 shl 2, CONSTRUCT_ONLY = 1 shl 3,
                LAX_VALIDATION = 1 shl 4, STATIC_NAME = 1 shl 5,
                STATIC_NICK = 1 shl 6, STATIC_BLURB = 1 shl 7,
                EXPLICIT_NOTIFY = 1 shl 30

        GParamSpec* =  ptr GParamSpecObj
        GParamSpecObj* = object of GTypeInstanceObj
                name*: cstring
                flags*: GParamFlags
                valueType*: GType
                ownerType*: GType
                nick*: cstring
                blurb*: cstring
                qdata*: GData
                refCount*: cuint
                paramId*: cuint

        GObjectConstructParam* =ptr GObjectConstructParamObj
        GObjectConstructParamObj* =object
                pspec*: GParamSpec
                value*: GValue
type
        GObjectClass* =  ptr GObjectClassObj
        GObjectClassObj* = object of GTypeClassObj
                constructProperties*: GSList
                constructor*: proc (`type`: GType; nConstructProperties: cuint; constructProperties: GObjectConstructParam): GObject {.cdecl.}
                setProperty*: proc (`object`: GObject; propertyId: cuint; value: GValue; pspec: GParamSpec) {.cdecl.}
                getProperty*: proc (`object`: GObject; propertyId: cuint; value: GValue; pspec: GParamSpec) {.cdecl.}
                dispose*: proc (`object`: GObject) {.cdecl.}
                finalize*: proc (`object`: GObject) {.cdecl.}
                dispatchPropertiesChanged*: proc (`object`: GObject; nPspecs: cuint; pspecs: var GParamSpec) {.cdecl.}
                notify*: proc (`object`: GObject; pspec: GParamSpec) {.cdecl.}
                constructed*: proc (`object`: GObject) {.cdecl.}
                flags*: Gsize
                pdummy: array[6, Gpointer]
type
        GInitiallyUnowned* =ptr GInitiallyUnownedObj
        GInitiallyUnownedObj* =GObjectObj
        GInitiallyUnownedClass* =ptr GInitiallyUnownedClassObj
        GInitiallyUnownedClassObj* =GObjectClassObj
type
        GConnectFlags* {.size: sizeof(cint), pure.} = enum AFTER=1 shl 0, SWAPPED=1 shl 1
        GCallback* =proc() {.cdecl.}
type
        GClosureNotify* =proc(data: Gpointer; closure: GClosure) {.cdecl.}
        GClosureMarshal* =proc (closure: GClosure; returnValue: GValue; nParamValues: cuint; paramValues: GValue; invocationHint: Gpointer; marshalData: Gpointer) {.cdecl.}
        GClosureNotifyData* =  ptr GClosureNotifyDataObj
        GClosureNotifyDataObj* =object
                data*: Gpointer
                notify*: GClosureNotify
        GClosure* =  ptr GClosureObj
        GClosureObj*{.inheritable, pure.} =object
                refCount* {.bitsize: 15.}: cuint
                metaMarshalNouse* {.bitsize: 1.}: cuint
                nGuards* {.bitsize: 1.}: cuint
                nFnotifiers* {.bitsize: 2.}: cuint
                nInotifiers* {.bitsize: 8.}: cuint
                inInotify* {.bitsize: 1.}: cuint
                floating* {.bitsize: 1.}: cuint
                derivativeFlag* {.bitsize: 1.}: cuint
                inMarshal* {.bitsize: 1.}: cuint
                isInvalid* {.bitsize: 1.}: cuint
                marshal*: proc(closure: GClosure; returnValue: GValue; nParamValues: cuint;
                                paramValues: GValue; invocationHint: Gpointer;
                                marshalData: Gpointer) {.cdecl.}
                data*: Gpointer
                notifiers*: GClosureNotifyData

proc g_object_get_data*(X: GObject; key: cstring): Gpointer {.importc: "g_object_get_data", libgobj.}
proc data*(X: GObject; key: cstring): Gpointer {.importc: "g_object_get_data", libgobj.}
proc g_object_set_data*(X: GObject; key: cstring; data: Gpointer) {.importc: "g_object_set_data", libgobj.}
proc `data=`*(X: GObject; key: cstring; data: Gpointer) {.importc: "g_object_set_data", libgobj.}

proc signalconnectdata*(X: Gpointer; S: cstring; handler: GCallback; data: Gpointer; destroy: GClosureNotify; flags: GConnectFlags): culong {.importc: "g_signal_connect_data", libgobj.}

template g_signal_connect*(instance, signalname, handler: untyped, data: untyped): untyped=signalconnectdata(instance, signalname, handler, data, cast[GClosureNotify](nil), cast[GConnectFlags](0))
template g_signal_connect*(instance, signalname, handler: untyped): untyped=               signalconnectdata(instance, signalname, handler, nil, cast[GClosureNotify](nil), cast[GConnectFlags](0))

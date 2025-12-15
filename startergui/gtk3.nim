
import glib, gobject, gdk
export glib, gobject, gdk

when defined(windows):
        const LIB_GTK* ="libgtk-3-0.dll"
elif defined(gtk_quartz):
        const LIB_GTK* ="libgtk-3.0.dylib"
elif defined(macosx):
        const LIB_GTK* ="libgtk-x11-3.0.dylib"
else:
        const LIB_GTK* ="libgtk-3.so(|.0)"

{.pragma: libgtk, cdecl, dynlib: LIB_GTK.}

type
        Widget* =ptr WidgetObj
        WidgetObj =object of GInitiallyUnownedObj

        Container* =ptr ContainerObj
        ContainerObj* =object of WidgetObj

        Bin* =  ptr BinObj
        BinObj* = object of ContainerObj

        Window* =ptr WindowObj
        WindowObj* =object of BinObj

type
        WindowType* {.size: sizeof(cint), pure.} =enum TOPLEVEL, POPUP

type
        Misc* =ptr MiscObj
        MiscObj* =object of WidgetObj
type
        Adjustment* =ptr AdjustmentObj
        AdjustmentObj*{.final.} =object of GInitiallyUnownedObj

type
        Label* =ptr LabelObj
        LabelObj* =object of MiscObj

type
        Box* =ptr BoxObj
        BoxObj* =object of ContainerObj

        ButtonBox* =ptr ButtonBoxObj
        ButtonBoxObj* =object of BoxObj

        Button* =ptr ButtonObj
        ButtonObj* =object of BinObj

        ScrolledWindow* =ptr ScrolledWindowObj
        ScrolledWindowObj* =object of BinObj

        ListBox* =ptr ListBoxObj
        ListBoxObj*{.final.} =object of ContainerObj

        ListBoxRow* =ptr ListBoxRowObj
        ListBoxRowObj*{.final.} =object of BinObj

        FlowBox* =ptr FlowBoxObj
        FlowBoxObj* {.final.} =object of ContainerObj
        FlowBoxChild* =ptr FlowBoxChildObj
        FlowBoxChildObj* {.final.} =object of BinObj

        ToggleButton* =ptr ToggleButtonObj
        ToggleButtonObj* =object of ButtonObj

        CheckButton* =ptr CheckButtonObj
        CheckButtonObj* =object of ToggleButtonObj

        Entry* =ptr EntryObj
        EntryObj =object of WidgetObj

type
        CssProvider* =ptr CssProviderObj
        CssProviderObj* {.final.} =object of GObjectObj

        StyleProvider* =ptr StyleProviderObj
        StyleProviderObj* =object

        StyleContext* =ptr StyleContextObj
        StyleContextObj* {.final.} =object of GObjectObj

type
        Orientation*    {.size: sizeof(cint), pure.}=enum HORIZONTAL, VERTICAL
        Align*          {.size: sizeof(cint), pure.}=enum FILL, START, `END`, CENTER, BASELINE
        ButtonBoxStyle* {.size: sizeof(cint), pure.}=enum SPREAD=1, EDGE, START, END, CENTER, EXPAND
        ShadowType*     {.size: sizeof(cint), pure.}=enum NONE, `IN`, `OUT`, ETCHED_IN, ETCHED_OUT
        StateType*      {.size: sizeof(cint), pure.}=enum NORMAL, ACTIVE, PRELIGHT, SELECTED, INSENSITIVE, INCONSISTENT, FOCUSED
        StateFlags*     {.size: sizeof(cint), pure.}=enum FLAG_NORMAL=0, FLAG_ACTIVE=1, FLAG_PRELIGHT=2, FLAG_SELECTED=4, FLAG_INSENSITIVE=8, FLAG_INCONSISTENT=16, FLAG_FOCUSED=32, FLAG_BACKDROP=64, FLAG_DIR_LTR=128, FLAG_DIR_RTL=256, FLAG_LINK=512, FLAG_VISITED=1024, FLAG_CHECKED=2048, FLAG_DROP_ACTIVE=4096

type
        Callback* =proc(X: Widget; data: Gpointer) {.cdecl.}

const
        STYLE_PROVIDER_PRIORITY_FALLBACK* =1
        STYLE_PROVIDER_PRIORITY_THEME* =200
        STYLE_PROVIDER_PRIORITY_SETTINGS* =400
        STYLE_PROVIDER_PRIORITY_APPLICATION* =600
        STYLE_PROVIDER_PRIORITY_USER* =800

proc gtk_init*(argc: var cint; argv: var cstringArray) {.importc: "gtk_init", libgtk.}
proc gtk_main*() {.importc: "gtk_main", libgtk.}

func valid*(X: Window): bool= cast[int](addr X)!=0
func valid*(X: Box): bool= cast[int](addr X)!=0
func valid*(X: Label): bool= cast[int](addr X)!=0
func valid*(X: Button): bool= cast[int](addr X)!=0
func valid*(X: ScrolledWindow): bool= cast[int](addr X)!=0
func valid*(X: Listbox): bool= cast[int](addr X)!=0
func valid*(X: ListboxRow): bool= cast[int](addr X)!=0
func valid*(X: FlowBox): bool= cast[int](addr X)!=0
func valid*(X: Entry): bool= cast[int](addr X)!=0
func valid*(X: Widget): bool= cast[int](addr X)!=0

proc gtk_window_new*(`type`: WindowType): Window {.importc: "gtk_window_new", libgtk.}
proc gtk_window_set_title*(window: Window; title: cstring) {.importc: "gtk_window_set_title", libgtk.}
proc `title=`*(window: Window; title: cstring) {.importc: "gtk_window_set_title", libgtk.}
proc gtk_window_set_default_size*(window: Window; width: cint; height: cint) {.importc: "gtk_window_set_default_size", libgtk.}

# =====================================================================

proc gtk_widget_destroy*(widget: Widget) {.importc: "gtk_widget_destroy", libgtk.}

proc gtk_widget_get_name*(X: Widget): cstring {.importc: "gtk_widget_get_name", libgtk.}
proc gtk_widget_set_name*(X: Widget; name: cstring) {.importc: "gtk_widget_set_name", libgtk.}
proc `name=`*(X: Widget; name: cstring) {.importc: "gtk_widget_set_name", libgtk.}
proc gtk_widget_show_all*(X: Widget) {.importc: "gtk_widget_show_all", libgtk.}
proc gtk_widget_get_halign*(X: Widget): Align {.importc: "gtk_widget_get_halign", libgtk.}
proc gtk_widget_set_halign*(X: Widget; align: Align) {.importc: "gtk_widget_set_halign", libgtk.}
proc `halign=`*(X: Widget; align: Align) {.importc: "gtk_widget_set_halign", libgtk.}
proc gtk_widget_set_valign*(X: Widget; align: Align) {.importc: "gtk_widget_set_valign", libgtk.}
proc `valign=`*(X: Widget; align: Align) {.importc: "gtk_widget_set_valign", libgtk.}
proc gtk_widget_set_sensitive*(X: Widget; sensitive: Gboolean) {.importc: "gtk_widget_set_sensitive", libgtk.}
proc `sensitive=`*(X: Widget; sensitive: Gboolean) {.importc: "gtk_widget_set_sensitive", libgtk.}
proc gtk_widget_get_sensitive*(X: Widget): Gboolean {.importc: "gtk_widget_get_sensitive", libgtk.}
proc gtk_widget_is_sensitive*(X: Widget): Gboolean {.importc: "gtk_widget_is_sensitive", libgtk.}
proc gtk_widget_get_margin_top*(X: Widget): cint {.importc: "gtk_widget_get_margin_top", libgtk.}
proc margin_top*(X: Widget): cint {.importc: "gtk_widget_get_margin_top", libgtk.}
proc gtk_widget_set_margin_top*(X: Widget; margin: cint) {.importc: "gtk_widget_set_margin_top", libgtk.}
proc `margin_top=`*(X: Widget; margin: cint) {.importc: "gtk_widget_set_margin_top", libgtk.}
proc gtk_widget_get_margin_bottom*(X: Widget): cint {.importc: "gtk_widget_get_margin_bottom", libgtk.}
proc margin_bottom*(X: Widget): cint {.importc: "gtk_widget_get_margin_bottom", libgtk.}
proc gtk_widget_set_margin_bottom*(X: Widget; margin: cint) {.importc: "gtk_widget_set_margin_bottom", libgtk.}
proc `margin_bottom=`*(X: Widget; margin: cint) {.importc: "gtk_widget_set_margin_bottom", libgtk.}

proc gtk_widget_set_state*(X: Widget; state: StateType) {.importc: "gtk_widget_set_state", libgtk.}
proc `state=`*(X: Widget; state: StateType) {.importc: "gtk_widget_set_state", libgtk.}
proc gtk_widget_get_state*(X: Widget): StateType {.importc: "gtk_widget_get_state", libgtk.}
proc state*(X: Widget): StateType {.importc: "gtk_widget_get_state", libgtk.}

proc gtk_widget_set_state_flags*(X: Widget; flags: StateFlags; clear: Gboolean) {.importc: "gtk_widget_set_state_flags", libgtk.}
proc `state_flags=`*(X: Widget; flags: StateFlags; clear: Gboolean) {.importc: "gtk_widget_set_state_flags", libgtk.}
proc gtk_widget_unset_state_flags*(X: Widget; flags: StateFlags) {.importc: "gtk_widget_unset_state_flags", libgtk.}
proc gtk_widget_get_state_flags*(X: Widget): StateFlags {.importc: "gtk_widget_get_state_flags", libgtk.}
proc state_flags*(X: Widget): StateFlags {.importc: "gtk_widget_get_state_flags", libgtk.}

proc gtk_widget_get_style_context*(X: Widget): StyleContext {.importc: "gtk_widget_get_style_context", libgtk.}
proc style_context*(X: Widget): StyleContext {.importc: "gtk_widget_get_style_context", libgtk.}
proc gtk_style_context_add_class*(X: StyleContext; name: cstring) {.importc: "gtk_style_context_add_class", libgtk.}
proc gtk_style_context_remove_class*(X: StyleContext; name: cstring) {.importc: "gtk_style_context_remove_class", libgtk.}
proc gtk_style_context_has_class*(X: StyleContext; name: cstring): Gboolean {.importc: "gtk_style_context_has_class", libgtk.}

proc gtk_widget_set_can_focus*(X: Widget; f: Gboolean) {.importc: "gtk_widget_set_can_focus", libgtk.}
proc `can_focus=`*(X: Widget; f: Gboolean) {.importc: "gtk_widget_set_can_focus", libgtk.}
proc gtk_widget_get_can_focus*(X: Widget): Gboolean {.importc: "gtk_widget_get_can_focus", libgtk.}
proc can_focus*(X: Widget): Gboolean {.importc: "gtk_widget_get_can_focus", libgtk.}
proc gtk_widget_has_focus*(X: Widget): Gboolean {.importc: "gtk_widget_has_focus", libgtk.}
proc gtk_widget_is_focus*(X: Widget): Gboolean {.importc: "gtk_widget_is_focus", libgtk.}
proc gtk_widget_has_visible_focus*(X: Widget): Gboolean {.importc: "gtk_widget_has_visible_focus", libgtk.}
proc gtk_widget_grab_focus*(X: Widget) {.importc: "gtk_widget_grab_focus", libgtk.}
proc gtk_widget_set_focus_on_click*(X: Widget; f: Gboolean) {.importc: "gtk_widget_set_focus_on_click", libgtk.}
proc `focus_on_click=`*(X: Widget; f: Gboolean) {.importc: "gtk_widget_set_focus_on_click", libgtk.}
proc gtk_widget_get_focus_on_click*(X: Widget): Gboolean {.importc: "gtk_widget_get_focus_on_click", libgtk.}
proc focus_on_click*(X: Widget): Gboolean {.importc: "gtk_widget_get_focus_on_click", libgtk.}

# =====================================================================

proc gtk_bin_get_child*(X: Bin): Widget {.importc: "gtk_bin_get_child", libgtk.}
proc child*(X: Bin): Widget {.importc: "gtk_bin_get_child", libgtk.}

proc gtk_label_new*(str: cstring): Label {.importc: "gtk_label_new", libgtk.}
proc gtk_box_new*(X: Orientation; S: cint): Box {.importc: "gtk_box_new", libgtk.}
proc gtk_button_box_new*(X: Orientation): ButtonBox {.importc: "gtk_button_box_new", libgtk.}
proc gtk_button_new_with_label*(X: cstring): Button {.importc: "gtk_button_new_with_label", libgtk.}
proc gtk_scrolled_window_new*(horz, vert: Adjustment): ScrolledWindow {.importc: "gtk_scrolled_window_new", libgtk.}
proc gtk_list_box_new*(): ListBox {.importc: "gtk_list_box_new", libgtk.}
proc gtk_list_box_row_new*(): ListBoxRow {.importc: "gtk_list_box_row_new", libgtk.}
proc gtk_flow_box_new*(): FlowBox {.importc: "gtk_flow_box_new", libgtk.}
proc gtk_check_button_new_with_label*(label: cstring): CheckButton {.importc: "gtk_check_button_new_with_label", libgtk.}
proc gtk_check_button_new_with_mnemonic*(label: cstring): CheckButton {.importc: "gtk_check_button_new_with_mnemonic", libgtk.}
proc gtk_entry_new*(): Entry {.importc: "gtk_entry_new", libgtk.}

proc gtk_label_get_text*(X: Label): cstring {.importc: "gtk_label_get_text", libgtk.}
proc text*(X: Label): cstring {.importc: "gtk_label_get_text", libgtk.}
proc gtk_label_set_label*(X: Label; str: cstring) {.importc: "gtk_label_set_label", libgtk.}
proc `label=`*(X: Label; str: cstring) {.importc: "gtk_label_set_label", libgtk.}

proc gtk_button_box_set_layout*(X: ButtonBox; S: ButtonBoxStyle) {.importc: "gtk_button_box_set_layout", libgtk.}
proc `layout=`*(X: ButtonBox; S: ButtonBoxStyle) {.importc: "gtk_button_box_set_layout", libgtk.}

proc gtk_list_box_insert*(X: ListBox; C: Widget; position: cint) {.importc: "gtk_list_box_insert", libgtk.}
proc gtk_list_box_row_get_index*(X: ListBoxRow): cint {.importc: "gtk_list_box_row_get_index", libgtk.}
proc index*(X: ListBoxRow): cint {.importc: "gtk_list_box_row_get_index", libgtk.}
proc gtk_list_box_row_get_type*(): GType {.importc: "gtk_list_box_row_get_type", libgtk.}

proc gtk_scrolled_window_set_shadow_type*(X: ScrolledWindow; `type`: ShadowType) {.importc: "gtk_scrolled_window_set_shadow_type", libgtk.}
proc `shadowtype=`*(X: ScrolledWindow; `type`: ShadowType) {.importc: "gtk_scrolled_window_set_shadow_type", libgtk.}
proc gtk_scrolled_window_set_propagate_natural_width*(X: ScrolledWindow; propagate: Gboolean) {.importc: "gtk_scrolled_window_set_propagate_natural_width", libgtk.}
proc `propagatenaturalwidth=`*(X: ScrolledWindow; propagate: Gboolean) {.importc: "gtk_scrolled_window_set_propagate_natural_width", libgtk.}
proc gtk_scrolled_window_set_propagate_natural_height*(X: ScrolledWindow; propagate: Gboolean) {.importc: "gtk_scrolled_window_set_propagate_natural_height", libgtk.}
proc `propagatenaturalheight=`*(X: ScrolledWindow; propagate: Gboolean) {.importc: "gtk_scrolled_window_set_propagate_natural_height", libgtk.}

proc gtk_button_get_label*(X: Button): cstring {.importc: "gtk_button_get_label", libgtk.}

proc gtk_toggle_button_get_active*(X: ToggleButton): Gboolean {.importc: "gtk_toggle_button_get_active", libgtk.}
proc gtk_toggle_button_set_active*(X: ToggleButton, state: Gboolean) {.importc: "gtk_toggle_button_set_active", libgtk.}

proc gtk_entry_get_text*(X: Entry): cstring {.importc: "gtk_entry_get_text", libgtk.}
proc gtk_entry_set_text*(X: Entry, text: cstring) {.importc: "gtk_entry_set_text", libgtk.}
proc `text=`*(X: Entry; str: cstring) {.importc: "gtk_entry_set_text", libgtk.}
proc gtk_entry_get_placeholder_text*(X: Entry): cstring {.importc: "gtk_entry_get_placeholder_text", libgtk.}
proc gtk_entry_set_placeholder_text*(X: Entry, text: cstring) {.importc: "gtk_entry_set_placeholder_text", libgtk.}
proc gtk_entry_get_text_length*(X: Entry): Gushort {.importc: "gtk_entry_get_text_length", libgtk.}
proc gtk_entry_get_visibility*(X: Entry): Gboolean {.importc: "gtk_entry_get_visibility", libgtk.}
proc gtk_entry_set_visibility*(X: Entry, vis: Gboolean) {.importc: "gtk_entry_set_visibility", libgtk.}
proc gtk_entry_get_width_chars*(X: Entry): Gint {.importc: "gtk_entry_get_width_chars", libgtk.}
proc gtk_entry_set_width_chars*(X: Entry, vis: Gint) {.importc: "gtk_entry_set_width_chars", libgtk.}
proc gtk_entry_grab_focus_without_selecting*(X: Entry) {.importc: "gtk_entry_grab_focus_without_selecting", libgtk.}
proc gtk_entry_get_activates_default*(X: Entry): Gboolean {.importc: "gtk_entry_get_activates_default", libgtk.}
proc gtk_entry_set_activates_default*(X: Entry, vis: Gboolean) {.importc: "gtk_entry_set_activates_default", libgtk.}
proc gtk_entry_get_alignment*(X: Entry): Gfloat {.importc: "gtk_entry_get_alignment", libgtk.}
proc gtk_entry_set_alignment*(X: Entry, a: Gfloat) {.importc: "gtk_entry_set_alignment", libgtk.}
proc gtk_entry_get_has_frame*(X: Entry): Gboolean {.importc: "gtk_entry_get_has_frame", libgtk.}
proc gtk_entry_set_has_frame*(X: Entry, f: Gboolean) {.importc: "gtk_entry_set_has_frame", libgtk.}
proc gtk_entry_get_invisible_char*(X: Entry): Gunichar {.importc: "gtk_entry_get_invisible_char", libgtk.}
proc gtk_entry_set_invisible_char*(X: Entry, c: Gunichar) {.importc: "gtk_entry_set_invisible_char", libgtk.}
proc gtk_entry_unset_invisible_char*(X: Entry) {.importc: "gtk_entry_unset_invisible_char", libgtk.}
proc gtk_entry_get_max_length*(X: Entry): Gint {.importc: "gtk_entry_get_max_length", libgtk.}
proc gtk_entry_set_max_length*(X: Entry, c: Gint) {.importc: "gtk_entry_set_max_length", libgtk.}
proc gtk_entry_get_overwrite_mode*(X: Entry): Gboolean {.importc: "gtk_entry_get_overwrite_mode", libgtk.}
proc gtk_entry_set_overwrite_mode*(X: Entry, f: Gboolean) {.importc: "gtk_entry_set_overwrite_mode", libgtk.}

proc gtk_container_set_border_width*(X: Container; width: cuint) {.importc: "gtk_container_set_border_width", libgtk.}
proc gtk_container_add*(X: Container; W: Widget) {.importc: "gtk_container_add", libgtk.}
proc gtk_container_get_children*(X: Container): GList {.importc: "gtk_container_get_children", libgtk.}
proc gtk_container_foreach*(X: Container; cb: Callback; data: Gpointer) {.importc: "gtk_container_foreach", libgtk.}
proc gtk_container_forall*(X: Container; cb: Callback; data: Gpointer) {.importc: "gtk_container_forall", libgtk.}

# GTK_IS...
proc gtk_bin_get_type*(): GType {.importc: "gtk_bin_get_type", libgtk.}
proc gtk_container_get_type*(): GType {.importc: "gtk_container_get_type", libgtk.}
proc gtk_widget_get_type*(): GType {.importc: "gtk_widget_get_type", libgtk.}
proc gtk_entry_get_type*(): GType {.importc: "gtk_entry_get_type", libgtk.}
proc GTK_IS_BIN*(obj: Widget): Gboolean= g_type_check_instance_is_a(cast[GTypeInstance](obj), gtk_bin_get_type())
proc GTK_IS_CONTAINER*(obj: Widget): Gboolean= g_type_check_instance_is_a(cast[GTypeInstance](obj), gtk_container_get_type())
proc GTK_IS_WIDGET*(obj: Widget): Gboolean= g_type_check_instance_is_a(cast[GTypeInstance](obj), gtk_widget_get_type())
proc GTK_IS_ENTRY*(obj: Widget): Gboolean= g_type_check_instance_is_a(cast[GTypeInstance](obj), gtk_entry_get_type())

proc gtk_css_provider_new*(): CssProvider {.importc: "gtk_css_provider_new", libgtk.}
proc gtk_css_provider_to_string*(X: CssProvider): cstring {.importc: "gtk_css_provider_to_string", libgtk.}
proc gtk_css_provider_load_from_resource*(X: CssProvider; ResourcePath: cstring) {.importc: "gtk_css_provider_load_from_resource", libgtk.}

proc gtk_style_context_add_provider_for_screen*(X: gdk.Screen; P: StyleProvider; priority: cuint) {.importc: "gtk_style_context_add_provider_for_screen", libgtk.}

proc gtk_main_quit*() {.importc: "gtk_main_quit", libgtk.}

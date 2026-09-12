pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

// Stands in for Omarchy's Ui/PluginBarApi for widgets hosted inside Celeste.
//
// That type lives in the Omarchy shell tree and is constructed by the built-in
// bar, so a third-party bar cannot hand out a real one. Hosted widgets read it
// as `bar` and call its methods directly, so this must mirror the whole public
// surface -- supplying only the underscore-prefixed hooks is not enough, and a
// panel that calls a missing method dies with "not a function" and never opens.
//
// Property mutability matters too: panels assign to centerHoverRevealSuppressed
// and activePopout, so those cannot be readonly.
QtObject {
    id: api

    required property string pluginId
    required property string moduleName

    property var shell: null

    readonly property color foreground: Colours.palette.m3onSurface
    readonly property color barForeground: Colours.palette.m3onSurface
    readonly property color background: Colours.tPalette.m3surface
    readonly property color urgent: Colours.palette.m3error

    readonly property string fontFamily: Tokens.font.sans
    readonly property string position: "top"
    readonly property bool vertical: false
    property int barSize: 0
    readonly property bool transparent: Config.appearance.transparency.enabled
    readonly property bool foregroundAnimationEnabled: true

    property bool centerSectionRevealHeld: false
    property bool _centerHoverRevealSuppressed: false
    property bool centerHoverRevealSuppressed: api._centerHoverRevealSuppressed

    property var activePopout: null
    property var clickTargets: []
    property var layoutConfig: ({})
    readonly property var foreignPopoutMarker: ({ foreign: true })

    // Only one hosted panel is open at a time, so requesting a popout closes
    // whichever other one currently holds it.
    signal popoutRequested(var owner)
    signal popoutReleased(var owner)

    function setCenterHoverRevealSuppressed(value) {
        api._centerHoverRevealSuppressed = !!value;
    }

    // Tooltips are Celeste's job to draw and it does not yet; accepting the call
    // silently is correct, and far better than throwing at the widget.
    function showTooltip(target, text) {}

    function hideTooltip(target) {}

    function registerClickTarget(target) {}

    function unregisterClickTarget(target) {}

    function requestPopout(owner) {
        api.activePopout = owner;
        api.popoutRequested(owner);
    }

    function releasePopout(owner) {
        if (api.activePopout === owner)
            api.activePopout = null;
        api.popoutReleased(owner);
    }

    // Keyboard panel-switching across bar widgets is not wired up; report that
    // nothing was switched so the caller keeps its own panel open.
    function switchPanelFrom(owner, direction) {
        return false;
    }

    function targetBelongsToWindow(target, window) {
        if (!target || !window)
            return false;
        return target.QsWindow && target.QsWindow.window === window;
    }

    function moduleWidgets(id) {
        return [];
    }

    function run(command) {
        const cmd = String(command || "");
        if (cmd)
            Quickshell.execDetached(["sh", "-c", cmd]);
    }
}

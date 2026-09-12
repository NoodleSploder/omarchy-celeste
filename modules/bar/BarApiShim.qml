pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Stands in for Omarchy's Ui/PluginBarApi for widgets hosted inside Celeste.
//
// That type lives in the Omarchy shell tree and is constructed by the built-in
// bar, so a third-party bar cannot hand out a real one. Hosted widgets read it
// as `bar`, so this mirrors its property names and supplies Celeste's palette.
//
// The underscore-prefixed members are the host's internal callbacks. They are
// provided as no-ops rather than left undefined: a widget that calls one gets a
// harmless nothing instead of "not a function". The visible consequence is that
// a hosted widget's own popouts and tooltips do not open -- it renders and
// updates, but its richer interactions are inert.
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
    readonly property bool centerHoverRevealSuppressed: _centerHoverRevealSuppressed

    property var activePopout: null
    property var clickTargets: []
    property var layoutConfig: ({})
    readonly property var foreignPopoutMarker: ({ foreign: true })

    function _noop() {
        return null;
    }

    property var _showTooltip: api._noop
    property var _hideTooltip: api._noop
    property var _registerClickTarget: api._noop
    property var _unregisterClickTarget: api._noop
    property var _requestPopout: api._noop
    property var _releasePopout: api._noop
    property var _switchPanelFrom: api._noop
    property var _targetBelongsToWindow: api._noop
    property var _moduleWidgets: api._noop
    property var _run: api._noop
}

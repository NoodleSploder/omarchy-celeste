pragma Singleton

// State for Celeste's own settings panel: whether it's open, and which
// monitor owns it. Nothing about the panel's contents lives here -- those are
// modules/settings/SettingsContent.qml.
//
// Same ownership shape as OmarchyMenu.screenName and Bar.qml's
// calendarScreen: the name IS the owner, captured when the panel opens rather
// than tracked live off focus, so moving focus to another monitor doesn't
// relocate the panel out from under the user.

import QtQuick

QtObject {
    id: root

    property bool open: false
    property string screenName: ""

    // Toggling from a DIFFERENT monitor moves the panel there rather than
    // closing it -- otherwise clicking the gear on the screen you're looking
    // at would dismiss a panel sitting on another one, which reads as the
    // button doing nothing.
    function toggle(screenName) {
        const name = String(screenName || "");
        if (root.open && root.screenName === name)
            root.close();
        else
            root.show(name);
    }

    function show(screenName) {
        root.screenName = String(screenName || "");
        root.open = true;
    }

    function close() {
        root.open = false;
    }
}

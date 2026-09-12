pragma Singleton

// Shared clock. One timer for the whole shell rather than one per consumer.

import QtQuick

QtObject {
    id: root

    property date now: new Date()

    readonly property int hours: now.getHours()
    readonly property int minutes: now.getMinutes()
    readonly property int seconds: now.getSeconds()

    readonly property string hourStr: {
        const h = Config.services.useTwelveHourClock ? (hours % 12 || 12) : hours;
        return String(h).padStart(2, "0");
    }
    readonly property string minuteStr: String(minutes).padStart(2, "0")
    readonly property string secondStr: String(seconds).padStart(2, "0")
    readonly property string amPmStr: hours < 12 ? "AM" : "PM"

    function format(fmt) {
        return Qt.formatDateTime(root.now, fmt);
    }

    property Timer ticker: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}

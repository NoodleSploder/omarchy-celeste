import QtQuick
import Quickshell.Widgets

// Clips children to the rounded rect -- Rectangle alone cannot.
ClippingRectangle {
    color: "transparent"

    Behavior on color {
        CAnim {}
    }
}

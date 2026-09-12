import QtQuick
import QtQuick.Shapes
import "../core"

// A progress ring. Caelestia draws this with a native scene-graph item; a
// QtQuick Shape with a PathAngleArc is equivalent here and needs no plugin.
Item {
    id: root

    property real value: 0            // 0..1
    property int implicitSize: 24
    property int strokeWidth: 3
    property color fgColour: Colours.palette.m3primary
    property color bgColour: Colours.palette.m3surfaceContainerHighest

    // Clamped separately so callers can animate it without fighting the binding.
    readonly property real clampedVal: Math.max(0, Math.min(1, value))

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true

        // Track
        ShapePath {
            strokeColor: root.bgColour
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.implicitSize - root.strokeWidth) / 2
                radiusY: (root.implicitSize - root.strokeWidth) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        // Value
        ShapePath {
            strokeColor: root.fgColour
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.implicitSize - root.strokeWidth) / 2
                radiusY: (root.implicitSize - root.strokeWidth) / 2
                startAngle: -90
                sweepAngle: 360 * root.clampedVal
            }
        }
    }
}

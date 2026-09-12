pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../core"

// The screen frame: a solid fill everywhere except a rounded rectangle in the
// middle, which produces the concave "arched" inner corners where the bar meets
// the screen edges.
//
// Caelestia draws this with a native signed-distance-field item. A single
// ShapePath with two subpaths and an odd-even fill rule is equivalent: the outer
// subpath covers the screen, the inner rounded-rect subpath punches the content
// area out of it, and only the difference is painted.
//
// The inset is asymmetric on purpose -- `top` is the full bar height, so the bar
// and the frame read as one continuous surface rather than a bar with a border
// under it.
Shape {
    id: root

    property int borderLeft: 0
    property int borderRight: 0
    property int borderTop: 0
    property int borderBottom: 0
    property int radius: 0
    property color colour: Colours.tPalette.m3surface

    // Never let the corner radius exceed half the content box, or the arcs
    // overlap and the shape inverts.
    readonly property real r: Math.max(0, Math.min(root.radius,
        Math.min((width - borderLeft - borderRight) / 2, (height - borderTop - borderBottom) / 2)))

    readonly property real x0: borderLeft
    readonly property real y0: borderTop
    readonly property real x1: width - borderRight
    readonly property real y1: height - borderBottom

    preferredRendererType: Shape.CurveRenderer
    asynchronous: true

    ShapePath {
        fillColor: root.colour
        strokeWidth: 0
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill

        // Outer subpath: the whole screen.
        PathMove {
            x: 0
            y: 0
        }
        PathLine {
            x: root.width
            y: 0
        }
        PathLine {
            x: root.width
            y: root.height
        }
        PathLine {
            x: 0
            y: root.height
        }
        PathLine {
            x: 0
            y: 0
        }

        // Inner subpath: the rounded content area, punched out.
        PathMove {
            x: root.x0 + root.r
            y: root.y0
        }
        PathLine {
            x: root.x1 - root.r
            y: root.y0
        }
        PathArc {
            x: root.x1
            y: root.y0 + root.r
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.x1
            y: root.y1 - root.r
        }
        PathArc {
            x: root.x1 - root.r
            y: root.y1
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.x0 + root.r
            y: root.y1
        }
        PathArc {
            x: root.x0
            y: root.y1 - root.r
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
        PathLine {
            x: root.x0
            y: root.y0 + root.r
        }
        PathArc {
            x: root.x0 + root.r
            y: root.y0
            radiusX: root.r
            radiusY: root.r
            direction: PathArc.Clockwise
        }
    }
}

import QtQuick
import QtQuick.Shapes
import "../core"

// A concave corner fillet: a square of `size` filled everywhere EXCEPT a
// quarter-disc, so a panel meeting a flat edge curves into it instead of
// butting against it at a hard right angle.
//
// This is what makes a drawer look like it grew out of the border rather than
// being parked under it. Caelestia gets the same effect from a signed-distance
// field; the geometry is simple enough to state directly.
//
// The canonical shape curves toward the bottom-right; `corner` mirrors it with a
// transform rather than duplicating the path four times.
Shape {
    id: root

    enum Corner {
        TopLeft,
        TopRight,
        BottomLeft,
        BottomRight
    }

    property int size: Tokens.rounding.large
    property int corner: InvertedCorner.TopLeft
    property color colour: Colours.tPalette.m3surface

    implicitWidth: size
    implicitHeight: size

    preferredRendererType: Shape.CurveRenderer
    asynchronous: true

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: (root.corner === InvertedCorner.TopRight || root.corner === InvertedCorner.BottomRight) ? -1 : 1
        yScale: (root.corner === InvertedCorner.BottomLeft || root.corner === InvertedCorner.BottomRight) ? -1 : 1
    }

    ShapePath {
        fillColor: root.colour
        strokeWidth: 0
        strokeColor: "transparent"

        PathMove {
            x: 0
            y: 0
        }
        PathLine {
            x: root.size
            y: 0
        }
        // Arc centred on the opposite corner, carving the disc out of the square.
        PathArc {
            x: 0
            y: root.size
            radiusX: root.size
            radiusY: root.size
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: 0
            y: 0
        }
    }
}

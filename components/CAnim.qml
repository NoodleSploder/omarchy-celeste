import QtQuick
import "../core"

// Colour counterpart of Anim. Every styled surface installs one as an implicit
// Behavior, which is why a theme switch cross-fades instead of snapping.
ColorAnimation {
    duration: Tokens.anim.durations.expressiveDefaultEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tokens.anim.standard
}

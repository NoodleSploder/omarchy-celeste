import QtQuick
import "../core"

// Material Symbols Rounded is a variable font: FILL morphs outlined glyphs to
// solid, GRAD thickens strokes slightly to hold weight on dark backgrounds, and
// opsz tunes optical size. Qt 6.7+ exposes these axes on font directly.
StyledText {
    id: root

    property real fill: 0
    property int grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small

    font.family: Tokens.font.material
    font.pointSize: fontStyle.pointSize
    font.weight: fontStyle.weight
    font.variableAxes: ({
        FILL: root.fill.toFixed(1),
        GRAD: root.grade,
        opsz: fontStyle.pointSize,
        wght: fontStyle.weight
    })

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}

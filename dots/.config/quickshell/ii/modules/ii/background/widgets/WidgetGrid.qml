pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Design grid shared by background widgets: one cell = one 132x132 card plus
// one 12px gutter, i.e. a square 144x144 pitch. Card sizes are whole spans of
// this cell, so snapping positions to the same pitch keeps edges and gutters
// aligned across every widget. See AbstractBackgroundWidget.qml for placement.
Singleton {
    id: root

    readonly property real cardUnitWidth: 132
    readonly property real cardUnitHeight: 132
    readonly property real gutter: 12
    readonly property real cellWidth: cardUnitWidth + gutter // 144
    readonly property real cellHeight: cardUnitHeight + gutter // 144

    // Size of a widget spanning `cells` columns/rows (gutter only between cells)
    function spanWidth(cells) { return cells * root.cellWidth - root.gutter }
    function spanHeight(cells) { return cells * root.cellHeight - root.gutter }

    // Grid dimensions that fit the scaled screen, bounded by the user's setting
    function effectiveColumns(scaledWidth, configuredColumns) {
        return Math.max(1, Math.min(configuredColumns, Math.floor(scaledWidth / root.cellWidth)));
    }
    function effectiveRows(scaledHeight, configuredRows) {
        return Math.max(1, Math.min(configuredRows, Math.floor(scaledHeight / root.cellHeight)));
    }

    // The widget block ends one gutter short of cols*cell, so centering that
    // block keeps screen edge margins symmetric
    function originX(scaledWidth, columns) { return (scaledWidth - root.spanWidth(columns)) / 2 }
    function originY(scaledHeight, rows) { return (scaledHeight - root.spanHeight(rows)) / 2 }
}

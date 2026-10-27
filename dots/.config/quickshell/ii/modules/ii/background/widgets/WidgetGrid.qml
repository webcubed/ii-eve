pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

// Design grid shared by background widgets: one cell = one card unit plus one
// gutter, i.e. a square pitch. Card sizes are whole spans of this cell, so
// snapping positions to the same pitch keeps edges and gutters aligned across
// every widget. See AbstractBackgroundWidget.qml for placement.
//
// Two knobs keep the grid practical on a real desktop:
//  - `scale` shrinks or grows the card unit (the gutter follows it), so every
//    card keeps its proportions while taking less space.
//  - `subdivisions` splits each cell into smaller snap steps, so a card can be
//    moved half a cell at a time instead of jumping a full card width.
Singleton {
    id: root

    readonly property real scale: {
        const configured = Config.options.background.widgets.scale ?? 0.85;
        return Math.max(0.6, Math.min(1.2, configured));
    }
    readonly property real cardUnitWidth: Math.round(132 * root.scale)
    readonly property real cardUnitHeight: Math.round(132 * root.scale)
    readonly property real gutter: Math.max(4, Math.round(12 * root.scale))
    readonly property real cellWidth: cardUnitWidth + gutter
    readonly property real cellHeight: cardUnitHeight + gutter

    readonly property int subdivisions: {
        const configured = Config.options.background.widgets.grid.subdivisions ?? 2;
        return Math.max(1, Math.min(8, Math.round(configured)));
    }
    readonly property real snapWidth: root.cellWidth / root.subdivisions
    readonly property real snapHeight: root.cellHeight / root.subdivisions

    // Size of a widget spanning `cells` columns/rows (gutter only between cells)
    function spanWidth(cells) { return cells * root.cellWidth - root.gutter }
    function spanHeight(cells) { return cells * root.cellHeight - root.gutter }

    // Grid dimensions that fit the available area, bounded by the user's setting
    function effectiveColumns(availableWidth, configuredColumns) {
        return Math.max(1, Math.min(configuredColumns, Math.floor(availableWidth / root.cellWidth)));
    }
    function effectiveRows(availableHeight, configuredRows) {
        return Math.max(1, Math.min(configuredRows, Math.floor(availableHeight / root.cellHeight)));
    }

    // The widget block ends one gutter short of cols*cell, so centering that
    // block keeps screen edge margins symmetric
    function originX(availableWidth, columns) { return (availableWidth - root.spanWidth(columns)) / 2 }
    function originY(availableHeight, rows) { return (availableHeight - root.spanHeight(rows)) / 2 }
}

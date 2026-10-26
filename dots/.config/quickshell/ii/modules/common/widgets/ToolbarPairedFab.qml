pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common

Item {
    id: root

    signal clicked(event: var)
    property alias iconText: fabWidget.iconText
    default property alias fabData: fabWidget.data
    property bool enableShadow: true
    property real baseSize: fabWidget.baseSize

    // No self-anchoring: this component is usually placed inside a RowLayout, where
    // layout-managed anchors are invalid (Qt warns and the alignment is undefined).
    // Call sites that need vertical centering set Layout.alignment / anchors there.
    implicitWidth: fabWidget.implicitWidth
    implicitHeight: fabWidget.implicitHeight
    // Direct child (not inside a Loader): StyledRectangularShadow anchors itself to
    // `target`, and an anchor target must be a parent or sibling — inside a Loader it
    // is neither, which Qt rejects with "Cannot anchor to an item that isn't a
    // parent or sibling" and the shadow silently never renders.
    StyledRectangularShadow {
        target: fabWidget
        radius: fabWidget.buttonRadius
        visible: root.enableShadow
    }
    FloatingActionButton {
        id: fabWidget
        onClicked: e => root.clicked(e)
        baseSize: 48
        colBackground: Appearance.colors.colTertiaryContainer
        colBackgroundHover: Appearance.colors.colTertiaryContainerHover
        colRipple: Appearance.colors.colTertiaryContainerActive
        colOnBackground: Appearance.colors.colOnTertiaryContainer
    }
}
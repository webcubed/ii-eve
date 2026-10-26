pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool notificationAllowed: true
    readonly property string notificationPrivacy: "default"
}

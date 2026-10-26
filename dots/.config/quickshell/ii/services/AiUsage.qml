pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    function recordResponse(modelId, inputTokens, outputTokens, thoughtTokens, totalTokens, success, cost) {
        // Stub - no-op
        return;
    }
}

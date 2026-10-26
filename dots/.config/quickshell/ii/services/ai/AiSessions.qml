import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string dir: Directories.aiSessions ?? ""
    property string legacyDir: Directories.aiChats ?? ""
    property string scriptPath: Directories.aiSessionsScriptPath ?? ""
    property string exportDir: Directories.aiExports ?? ""
    readonly property string newDraftId: "__new__"

    property string currentId: "sess_init_" + String(Date.now())
    readonly property var currentEntry: root.index.length > 0 ? root.index.find(e => String(e?.id ?? "") === String(root.currentId)) : null
    readonly property bool loaded: true
    readonly property var index: []

    signal currentDropped
    signal saveRequested
    signal sessionOpened(string sessionId)
    signal saveSucceeded(string operationId, string sessionId)
    signal saveFailed(string operationId, string sessionId, string reason)
    signal stageSucceeded(string operationId, string sessionId)
    signal stageFailed(string operationId, string sessionId, string reason)
    signal commitSubmissionSucceeded(string operationId, string sessionId)
    signal commitSubmissionFailed(string operationId, string sessionId, string reason)
    signal abortSubmissionSucceeded(string operationId, string sessionId)
    signal abortSubmissionFailed(string operationId, string sessionId, string reason)

    Timer { id: deferredTimer; interval: 10; repeat: false; onTriggered: root.emitPending() }
    property var pendingEmit: null

    function emitPending() {
        if (!root.pendingEmit) return;
        const task = root.pendingEmit;
        root.pendingEmit = null;
        if (task.type === "stage") root.stageSucceeded(task.op, task.sid);
        else if (task.type === "save") root.saveSucceeded(task.op, task.sid);
        else if (task.type === "commit") root.commitSubmissionSucceeded(task.op, task.sid);
        else if (task.type === "abort") root.abortSubmissionSucceeded(task.op, task.sid);
    }

    function newId() {
        return "sess_" + Date.now() + "_" + Math.random().toString(36).substring(2, 8);
    }
    function ensureLoaded() { return; }
    function scheduleSave() { return; }
    function setProject(sessionId, projectId) { return; }
    function openSession(sessionId) {
        if (sessionId && String(sessionId).length > 0 && String(sessionId) !== String(root.currentId)) {
            root.currentId = String(sessionId);
            root.sessionOpened(String(sessionId));
        }
        return root.currentId;
    }
    function stageSubmission(session, operationId) {
        root.pendingEmit = { type: "stage", op: operationId, sid: session?.id ?? "" };
        deferredTimer.start();
        return operationId;
    }
    function commitSubmissionForDispatch(sessionId, stagingOperationId, operationId) {
        root.pendingEmit = { type: "commit", op: operationId, sid: sessionId };
        deferredTimer.start();
        return operationId;
    }
    function abortSubmission(sessionId, stageOperationId, operationId) {
        root.pendingEmit = { type: "abort", op: operationId, sid: sessionId };
        deferredTimer.start();
        return operationId;
    }
    function commit(snapshot, operationId, flushNow) {
        root.pendingEmit = { op: operationId, sid: snapshot?.id ?? "", type: "save" };
        deferredTimer.start();
        return operationId;
    }

    Component.onCompleted: {
        // Initialize with a fresh session ID
        root.currentId = root.newId();
    }
}

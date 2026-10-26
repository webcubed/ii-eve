pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import qs.modules.common.functions

Singleton {
    id: root

    signal emailSent(bool success, string errorMsg)

    property bool authenticated: false
    readonly property bool loading: tokenRefresher.running || inboxFetcher.running
    property bool sendingEmail: emailSender.running
    property string userEmail: ""
    property string userAvatar: ""
    property int maxEmails: 20
    property bool enableUnreadBadges: false
    property int refreshIntervalMinutes: 5

    property string _accessToken: ""
    property int _tokenExpiry: 0
    property string _refreshToken: ""

    property ListModel inboxMessages: ListModel {}
    property int inboxUnreadCount: 0

    property bool credentialsConfigured: false
    property string tempGmailClientId: ""
    property string tempGmailClientSecret: ""

    readonly property string scriptDir: FileUtils.trimFileProtocol(`${Directories.scriptPath}/email`)

    Timer {
        id: autoRefreshTimer
        interval: root.refreshIntervalMinutes * 60 * 1000
        running: root.authenticated && root.refreshIntervalMinutes > 0
        repeat: true
        onTriggered: root.syncAll()
    }

    Component.onCompleted: {
        if (KeyringStorage.loaded) _tryInit()
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded && !root.authenticated) _tryInit()
        }
    }

    function _tryInit() {
        const token = KeyringStorage.keyringData["gmail_refresh_token"]
        const email = KeyringStorage.keyringData["gmail_user_email"]
        const avatar = KeyringStorage.keyringData["gmail_user_avatar"]
        if (token && token !== "" && email) {
            root._refreshToken = token
            root.userEmail = email
            root.userAvatar = avatar || ""
            _refreshAndFetch()
        }
    }

    function startOAuth() {
        authProcess.running = true
    }

    function syncAll() {
        if (_refreshToken && _refreshToken !== "") _refreshAndFetch()
    }

    function _refreshAndFetch() {
        if (_refreshToken === "") return
        tokenRefresher.command = ["python3", scriptDir + "/token_refresh.py", _refreshToken]
        tokenRefresher.running = true
    }

    function _getBestToken() {
        const now = Math.floor(Date.now() / 1000)
        if (_accessToken !== "" && now < (_tokenExpiry - 30)) return _accessToken
        return _refreshToken
    }

    function markAsRead(messageId) {
        _ensureValidToken(token => {
            const bodyStr = JSON.stringify({ removeLabelIds: ["UNREAD"] })
            Quickshell.execDetached(["curl", "-s", "-X", "POST",
                "-H", "Authorization: Bearer " + token,
                "-H", "Content-Type: application/json",
                "-d", bodyStr,
                `https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}/modify`])
        })
    }

    function trashMessage(messageId) {
        _ensureValidToken(token => {
            Quickshell.execDetached(["python3", scriptDir + "/trash_email.py", token, messageId])
        })
        _removeFromModel(messageId)
    }

    function sendEmail(to, subject, body) {
        if (!authenticated || _refreshToken === "") {
            root.emailSent(false, "Not authenticated")
            return
        }
        emailSender.command = ["python3", scriptDir + "/send_email.py", _refreshToken, to, subject, body]
        emailSender.running = true
    }

    function _ensureValidToken(callback) {
        const now = Math.floor(Date.now() / 1000)
        if (_accessToken !== "" && now < _tokenExpiry) { callback(_accessToken); return }
        if (_refreshToken === "") return
        const conn = root.onAuthenticatedChanged.connect(() => {
            if (root.authenticated && root._accessToken !== "") {
                root.onAuthenticatedChanged.disconnect(conn)
                callback(root._accessToken)
            }
        })
        _refreshAndFetch()
    }

    function _removeFromModel(messageId) {
        for (let i = 0; i < inboxMessages.count; i++) {
            if (inboxMessages.get(i).id === messageId) {
                if (inboxMessages.get(i).unread) inboxUnreadCount = Math.max(0, inboxUnreadCount - 1)
                inboxMessages.remove(i)
                break
            }
        }
    }

    function formatRelativeDate(timestamp) {
        if (!timestamp) return ""
        const date = new Date(timestamp * 1000)
        const now = Math.floor(Date.now() / 1000)
        const diff = now - timestamp
        if (diff < 60) return "Just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        if (diff < 172800) return "Yesterday"
        return date.toLocaleDateString(Qt.locale(), "MMM d")
    }

    Process {
        id: authProcess
        command: ["python3", scriptDir + "/oauth_server.py"]
    }

    Process {
        id: tokenRefresher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root._accessToken = data.access_token
                    root._tokenExpiry = Math.floor(Date.now() / 1000) + data.expires_in - 60
                    root.authenticated = true
                    syncLabel("inbox")
                } catch (e) {
                    root.authenticated = false
                    console.warn("[Gmail] Token parse error:", e)
                }
            }
        }
    }

    function syncLabel(label) {
        if (!authenticated || _refreshToken === "") return
        inboxFetcher.command = ["python3", scriptDir + "/fetch_emails.py", _getBestToken(), label.toUpperCase(), maxEmails.toString()]
        inboxFetcher.running = true
    }

    Process {
        id: inboxFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    const msgs = res.messages || []
                    root.inboxMessages.clear()
                    let unread = 0
                    msgs.forEach(msg => {
                        root.inboxMessages.append({
                            id: msg.id,
                            threadId: msg.threadId || "",
                            subject: msg.subject || "(no subject)",
                            from: msg.from || "",
                            snippet: msg.snippet || "",
                            unread: msg.unread || false,
                            timestamp: msg.timestamp || 0
                        })
                        if (msg.unread) unread++
                    })
                    root.inboxUnreadCount = unread
                } catch (e) {
                    console.warn("[Gmail] Fetch error:", e)
                }
            }
        }
    }

    Process {
        id: emailSender
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.emailSent(data.success, data.error || "")
                } catch (e) {
                    root.emailSent(false, "Parse error: " + e)
                }
            }
        }
    }
}

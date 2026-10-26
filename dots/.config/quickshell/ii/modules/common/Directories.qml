pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common.functions
import QtCore
import QtQuick
import Quickshell

Singleton {
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]

    readonly property string cliPath: FileUtils.trimFileProtocol(`${Directories.home}/.local/bin/eve`)

    // Config paths

    property string generalConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/GeneralConfig.qml`)
    property string barConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/BarConfig.qml`)
    property string backgroundConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/BackgroundConfig.qml`)
    property string interfaceConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/InterfaceConfig.qml`)
    property string servicesConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/ServicesConfig.qml`)
    property string advancedConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/modules/settings/AdvancedConfig.qml`)

    // Other dirs used by the shell, without "file://"
    property string assetsPath: Quickshell.shellPath("assets")
    property string scriptPath: Quickshell.shellPath("scripts")
    property string favicons: FileUtils.trimFileProtocol(`${Directories.cache}/media/favicons`)
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/media/coverart`)
    property string tempImages: "/tmp/quickshell/media/images"
    property string booruPreviews: FileUtils.trimFileProtocol(`${Directories.cache}/media/boorus`)
    property string booruDownloads: FileUtils.trimFileProtocol(Directories.pictures  + "/homework")
    property string booruDownloadsNsfw: FileUtils.trimFileProtocol(Directories.pictures + "/homework/🌶️")
    property string latexOutput: FileUtils.trimFileProtocol(`${Directories.cache}/media/latex`)
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
	property string customAppsPath: FileUtils.trimFileProtocol(`${Directories.state}/user/customApps.json`)
    // Per-app usage stats sampler state (AppStats service); the sampler is given this
    // directory via --state-dir, so the shell and the daemon must agree on it.
    property string appStats: FileUtils.trimFileProtocol(`${Directories.state}/appStats`)
	property string todoPath: FileUtils.trimFileProtocol(`${Directories.state}/user/todo.json`)
	property string commandsPath: FileUtils.trimFileProtocol(`${Directories.state}/user/commands.json`)
	property string notesPath: FileUtils.trimFileProtocol(`${Directories.state}/user/notes.json`)
	property string conflictCachePath: FileUtils.trimFileProtocol(`${Directories.cache}/conflict-killer`)
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/notifications/notifications.json`)
    property string lyricsPath: FileUtils.trimFileProtocol(`${Directories.cache}/lyrics/lyrics.json`)
    property string generatedMaterialThemePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/colors.json`)
    property string generatedWallpaperCategoryPath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/wallpaper/category.txt`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/quickshell/media/cliphist`)
    property string screenshotTemp: "/tmp/quickshell/media/screenshot"
    property string wallpaperSwitchScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/switchwall.sh`)
    property string defaultAiPrompts: Quickshell.shellPath("defaults/ai/prompts")
    property string defaultThemes: Quickshell.shellPath("defaults/themes")
    property string userPresetsPath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/presets`)
    property string presetsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/presets/presets.sh`)
    property string customThemes: `${Directories.shellConfig}/themes`
    property string userAiPrompts: FileUtils.trimFileProtocol(`${Directories.shellConfig}/ai/prompts`)
    property string userActions: FileUtils.trimFileProtocol(`${Directories.shellConfig}/actions`)
    property string aiChats: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/chats`)
    property string aiSessions: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/sessions`)
    property string aiSessionsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/sessions.py`)
    property string aiExports: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/exports`)
    property string aiDrafts: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/drafts`)
    property string aiDraftsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/drafts.py`)
    property string aiSettingsIndexScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/settings_index.py`)
    property string aiRagIndexDir: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/rag_index`)
    property string aiRagScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/rag.py`)
    property string aiWebScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/web.py`)
    property string aiHttpScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/http_request.py`)
    property string aiTranslationScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/gemini-translate.sh`)
    property string aiLastAnswer: FileUtils.trimFileProtocol(`${Directories.state}/user/ai/last_answer.json`)
    property string aiAttachScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/ai/attach.py`)
    property string recordScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/videos/record.sh`)
    property string extractColorsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/wallpapers/extract-colors.sh`)
    property string colorCachePath: FileUtils.trimFileProtocol(`${Directories.cache}/wallpapers/colors.json`)
    property string userAvatarPathAccountsService: FileUtils.trimFileProtocol(`/var/lib/AccountsService/icons/${SystemInfo.username}`)
    property string userAvatarPathRicersAndWeirdSystems: FileUtils.trimFileProtocol(`${Directories.home}/.face`)
    property string userAvatarPathRicersAndWeirdSystems2: FileUtils.trimFileProtocol(`${Directories.home}/.face.icon`)
    property string screenshareStateScript: FileUtils.trimFileProtocol(`${Directories.scriptPath}/screenShare/screensharestate.sh`)
    property string screenshareStatePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/screenshare/apps.txt`)
    property string geniusLyricsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/lyrics/genius-lyrics.js`)
    property string localSendDownloadPath: FileUtils.trimFileProtocol(`${Directories.home}/Downloads/localsend`)

    // Extension system paths
    property string extensionsPath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/extensions`)
    property string extensionsCachePath: `${Directories.extensionsPath}/cache`
    property string extensionsInstalledPath: `${Directories.extensionsPath}/installed`
    property string pluginsJsonPath: `${Directories.extensionsPath}/plugins.json`

    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${coverArt}'; mkdir -p '${coverArt}'`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${booruPreviews}'; mkdir -p '${booruPreviews}'`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${latexOutput}'; mkdir -p '${latexOutput}'`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`])
        Quickshell.execDetached(["mkdir", "-p", `${aiChats}`])
        Quickshell.execDetached(["mkdir", "-p", `${FileUtils.trimFileProtocol(Directories.state)}/user`])
        Quickshell.execDetached(["mkdir", "-p", `${userActions}`])
        Quickshell.execDetached(["mkdir", "-p", `${Directories.extensionsCachePath}`])
        Quickshell.execDetached(["mkdir", "-p", `${Directories.extensionsInstalledPath}`])
        Quickshell.execDetached(["rm", "-rf", `${tempImages}`])
    }
}

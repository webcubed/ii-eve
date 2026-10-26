pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.services
import ".."

TranslatorApi {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("scripts/free-translate/mymemory-translate.py")

    property list<string> pendingStrings

    function translateStrings(strings: list<string>) {
        resetState();
        root.pendingStrings = strings;
        root.state = TranslatorApi.State.Preparing;

        const targetLang = Config.options.screenTranslator.targetLanguage || Translation.languageCode;
        const payload = {
            target: targetLang,
            strings: strings
        };

        root.state = TranslatorApi.State.Processing;
        transProc.runSequence([
            ["bash", "-c",
                `printf '%s' '${StringUtils.shellSingleQuoteEscape(JSON.stringify(payload))}' \
| python3 '${StringUtils.shellSingleQuoteEscape(root.scriptPath)}'`
            ],
            (out) => { root.handleApiOutput(out); }
        ]);
    }

    MultiTurnProcess {
        id: transProc
    }
}

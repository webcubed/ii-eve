pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Trims the File protocol off the input string
     * @param {string} str
     * @returns {string}
     */
    function trimFileProtocol(str) {
        let s = str;
        if (typeof s !== "string") s = str.toString(); // Convert to string if it's an url or whatever
        if (s.startsWith("file://")) {
            try { return decodeURIComponent(s.slice(7)); } catch (e) { return s.slice(7); }
        }
        // Qt hands out single-slash URLs (`file:/home/...`) for some resolved paths; treating
        // those as plain strings made callers create a literal `file:` directory on disk.
        if (s.startsWith("file:/")) {
            try { return decodeURIComponent("/" + s.slice(6)); } catch (e) { return "/" + s.slice(6); }
        }
        return s;
    }

    /**
     * Converts a folder path to a file:// URL. Returns "" for empty input.
     * @param {string} path
     * @returns {string}
     */
    function folderUrl(path) {
        const trimmed = root.trimFileProtocol(path ?? "").trim();
        if (trimmed === "") return "";
        const expanded = trimmed.startsWith("~") ? Quickshell.env("HOME") + trimmed.slice(1) : trimmed;
        return "file://" + expanded.replace(/\/+$/, "");
    }

    /**
     * Extracts the file name from a file path
     * @param {string} str
     * @returns {string}
     */
    function fileNameForPath(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        return trimmed.split(/[\\/]/).pop();
    }

    /**
     * Extracts the folder name from a directory path
     * @param {string} str
     * @returns {string}
     */
    function folderNameForPath(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        // Remove trailing slash if present
        const noTrailing = trimmed.endsWith("/") ? trimmed.slice(0, -1) : trimmed;
        if (!noTrailing) return "";
        return noTrailing.split(/[\\/]/).pop();
    }

    /**
     * Removes the file extension from a file path or name
     * @param {string} str
     * @returns {string}
     */
    function trimFileExt(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        const lastDot = trimmed.lastIndexOf(".");
        if (lastDot > -1 && lastDot > trimmed.lastIndexOf("/")) {
            return trimmed.slice(0, lastDot);
        }
        return trimmed;
    }

    /**
     * Returns the parent directory of a given file path
     * @param {string} str
     * @returns {string}
     */
    function parentDirectory(str) {
        if (typeof str !== "string") return "";
        const trimmed = trimFileProtocol(str);
        const parts = trimmed.split(/[\\/]/);
        if (parts.length <= 1) return "";
        parts.pop();
        return parts.join("/");
    }
}

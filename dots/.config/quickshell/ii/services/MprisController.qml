pragma Singleton
pragma ComponentBehavior: Bound

// From https://git.outfoxxed.me/outfoxxed/nixnew
// It does not have a license, but the author is okay with redistribution.

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * A service that provides easy access to the active Mpris player.
 */
Singleton {
	id: root;
	property list<MprisPlayer> allPlayers: Mpris.players.values;
	// `values` can briefly contain a null entry while a player disappears, so drop
	// those before any callback touches player properties.
	property list<MprisPlayer> players: Mpris.players.values.filter(player => player).filter(player => isRealPlayer(player));

	// Desktop-entry name (e.g. "spotify") of the user-pinned app. Persisted
	// via Config so the pin survives shell reloads. Empty = no manual pin.
	property string priorityPlayer: Config.options.media.priorityPlayer;

	// The currently-attached player whose desktopEntry (or dbusName fallback,
	// for players that ship no .desktop file like raw MPD/MPRIS bridges)
	// matches priorityPlayer. Looked up only in `players` (the filtered
	// list) so the pin can never resolve to a duplicate that the UI hides.
	readonly property MprisPlayer pinnedPlayer: priorityPlayer
		? (root.players.find(p => p.desktopEntry === priorityPlayer || p.dbusName === priorityPlayer) ?? null)
		: null;

	// Returns true if the given player is the currently persisted pin —
	// matched via desktopEntry first, then dbusName as a fallback.
	function isPinned(player: MprisPlayer): bool {
		if (!player || !root.priorityPlayer) return false;
		return player.desktopEntry === root.priorityPlayer
			|| player.dbusName === root.priorityPlayer;
	}

	// Last player observed in the playing state — sticky on pause so the bar
	// keeps showing the track you last played instead of jumping around.
	// Cleared if the player disappears.
	property MprisPlayer trackedPlayer: null;

	// activePlayer is a pure derivation. Do NOT assign to it imperatively —
	// that breaks the binding chain and freezes selection on whatever was
	// last written (the old onAllPlayersChanged handler did this and was the
	// reason the active player wouldn't auto-pin after a shell reload).
	readonly property MprisPlayer activePlayer: pinnedPlayer
		?? trackedPlayer
		?? players.find(p => p?.isPlaying)
		?? players[0]
		?? Mpris.players.values[0]
		?? null;

	property bool __reverse: false;

	property var activeTrack;

	// True only when a plasma-browser-integration MPRIS bus is currently
	// advertised on D-Bus — not merely when the host binary is installed.
	// Without this, distros that ship plasma-browser-integration as a
	// transitive dependency (e.g. CachyOS) hide native Firefox/Chromium
	// players when the browser extension isn't installed.
	property bool hasActivePlasmaIntegration: Mpris.players.values.some(p => p.dbusName?.startsWith('org.mpris.MediaPlayer2.plasma-browser-integration'))

	function isRealPlayer(player) {
		if (!Config.options.media.filterDuplicatePlayers) {
			return true;
		}
		return (
			// Remove native browser buses only if plasma-browser-integration is actually active on D-Bus
			!(root.hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.firefox')) && !(root.hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.chromium')) &&
			// playerctld just copies other buses and we don't need duplicates
			!player.dbusName?.startsWith('org.mpris.MediaPlayer2.playerctld') &&
			// Non-instance mpd bus
			!(player.dbusName?.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd')));
	}

	// Update trackedPlayer only when a player actually starts playing — never
	// on pause. The activePlayer binding fans out the rest (pin > tracked >
	// any-playing > first). Previously this handler reassigned trackedPlayer
	// on every playbackState change, including pauses, which kept stealing
	// focus to whatever paused last.
	Instantiator {
		model: Mpris.players;

		Connections {
			required property MprisPlayer modelData;
			target: modelData;

			Component.onCompleted: {
				// Capture players that were already playing when the shell
				// (re)started — otherwise nothing seeds trackedPlayer until
				// the user pauses/plays something manually.
				if (modelData.isPlaying) {
					root.trackedPlayer = modelData;
				}
			}

			Component.onDestruction: {
				if (root.trackedPlayer === modelData) {
					root.trackedPlayer = null;
				}
			}

			function onPlaybackStateChanged() {
				if (modelData.isPlaying) {
					root.trackedPlayer = modelData;
				}
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
			root.updateTrack();
		}

		function onTrackArtUrlChanged() {
			// activeTrack is initialised lazily by updateTrack() — guard the
			// first cover-art tick that can fire before activePlayer settles
			// and updateTrack has populated activeTrack.
			if (!root.activePlayer || !root.activeTrack) return;
			if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
				// cantata likes to send cover updates *BEFORE* updating the track info.
				// as such, art url changes shouldn't be able to break the reverse animation
				const r = root.__reverse;
				root.updateTrack();
				root.__reverse = r;
			}
		}
	}

	onActivePlayerChanged: {
		this.updateTrack();
	}

	function updateTrack() {
		//console.log(`update: ${this.activePlayer?.trackTitle ?? ""} : ${this.activePlayer?.trackArtists}`)
		this.activeTrack = {
			uniqueId: this.activePlayer?.uniqueId ?? 0,
			artUrl: this.activePlayer?.trackArtUrl ?? "",
			title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
			artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
			album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
		};

		this.__reverse = false;
	}

	property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying;
	property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
	function togglePlaying() {
		if (this.canTogglePlaying) this.activePlayer.togglePlaying();
	}

	property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
	function previous() {
		if (this.canGoPrevious) {
			this.__reverse = true;
			this.activePlayer.previous();
		}
	}

	property bool canGoNext: this.activePlayer?.canGoNext ?? false;
	function next() {
		if (this.canGoNext) {
			this.__reverse = false;
			this.activePlayer.next();
		}
	}

	property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

	// Shared position tick. MPRIS only pushes position updates over D-Bus on
	// discontinuous seeks, so QML bindings on `position` would freeze between
	// updates. Firing positionChanged() at a steady cadence makes every
	// position-derived binding (sliders, lyrics, progress dots, ...) refresh
	// without each one having to host its own Timer.
	Timer {
		running: Mpris.players.values.some(p => p.isPlaying)
		interval: Config.options.resources.updateInterval
		repeat: true
		onTriggered: {
			for (const p of Mpris.players.values) {
				if (p.isPlaying) p.positionChanged();
			}
		}
	}

	// User-initiated pin. Persists the choice via Config.options.media.priorityPlayer
	// so the same app is selected automatically after a shell reload.
	// Calling this on the player that's already pinned un-pins it.
	function setActivePlayer(player: MprisPlayer) {
		const targetPlayer = player ?? null;
		console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

		if (targetPlayer && this.activePlayer) {
			const oldIdx = Mpris.players.values.indexOf(this.activePlayer);
			const newIdx = Mpris.players.values.indexOf(targetPlayer);
			this.__reverse = newIdx < oldIdx;
		} else {
			// always animate forward if going to null
			this.__reverse = false;
		}

		// Resolve a stable identifier for the pin, falling back to dbusName
		// when no .desktop entry is exposed (raw MPD/MPRIS bridges).
		const entry = targetPlayer?.desktopEntry || targetPlayer?.dbusName || "";
		if (targetPlayer === null) {
			// Explicit unpin (e.g. pause-everything path) — clear the
			// persisted pin so the activePlayer fallback chain takes over.
			Config.options.media.priorityPlayer = "";
		} else if (entry !== "") {
			Config.options.media.priorityPlayer =
				(Config.options.media.priorityPlayer === entry) ? "" : entry;
		} else {
			// Player has no stable identifier we can persist — clear any
			// existing pin instead of silently leaving it pointing at
			// something else.
			Config.options.media.priorityPlayer = "";
		}
		// Drive trackedPlayer too so the change is visible immediately,
		// without waiting for the Config write debounce.
		this.trackedPlayer = targetPlayer;
	}

	IpcHandler {
		target: "mpris"

		function pauseAll(): void {
			for (const player of Mpris.players.values) {
				if (player.canPause) player.pause();
			}
		}

		function playPause(): void { root.togglePlaying(); }
		function previous(): void { root.previous(); }
		function next(): void { root.next(); }
	}
}

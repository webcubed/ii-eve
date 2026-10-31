import QtQuick
import qs.modules.common
import qs.modules.common.functions

// The day's sun, drawn the way Trail Sense's astronomy chart draws it: the whole
// midnight-to-midnight span, a horizon across it, the sky above the line and the
// ground below it shaded, and the sun's arc with the daylight filled down to the
// horizon. Time maps linearly across the width, so sunrise and sunset land exactly
// where the curve crosses — the marker cannot drift out of step with the shape,
// because both come from the same function.
Canvas {
    id: root

    // Minutes of the day. A negative sunrise means the provider has no sun data
    // yet, and the chart stays empty rather than inventing a curve.
    property int sunriseMinutes: -1
    property int sunsetMinutes: -1
    property int nowMinutes: -1

    // The sun keeps the sun's own colour instead of a theme accent: it is the one
    // thing on this card that is literally the sun, and the reference's warm yellow
    // is most of what makes its chart read as daylight.
    property color sunColor: "#ffdd55"
    property color horizonColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.72)
    // The ground is shaded in the shell background, the way the reference shades it
    // in its own background colour rather than a foreign gray.
    property color groundColor: ColorUtils.transparentize(Appearance.colors.colLayer0Base, 0.45)
    property real fillAlpha: 0.18
    property real strokeWidth: 1.8
    property real markerRadius: 3
    // How deep the night trough runs, as a fraction of the day's peak. The real sun
    // dips far below the horizon; at this height a shallower trough keeps the arc
    // legible instead of squashing the day into the top half.
    property real nightDepth: 0.4

    // A taller sky than ground, so a low winter sun still has room to arc.
    readonly property real horizonRatio: 0.54
    // Keep the peak and the trough a marker radius away from the canvas edges: a
    // canvas clips to its own rect, so anything drawn closer comes back sliced flat.
    readonly property real edgeInset: markerRadius + 0.5
    readonly property int minuteCount: 1440
    readonly property bool hasSun: root.sunriseMinutes >= 0
        && root.sunsetMinutes > root.sunriseMinutes

    onSunriseMinutesChanged: requestPaint()
    onSunsetMinutesChanged: requestPaint()
    onNowMinutesChanged: requestPaint()
    onSunColorChanged: requestPaint()
    onHorizonColorChanged: requestPaint()
    onGroundColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // +1 at solar noon, 0 at sunrise and sunset, dipping to -nightDepth in the middle
    // of the night: the day as a sine over the daylight window, and the night as a
    // shallower sine between the two darknesses. Both halves meet the horizon at
    // exactly zero, which is what puts the curve's crossings on the printed times.
    function levelAt(minute) {
        if (!root.hasSun) return 0;
        const rise = root.sunriseMinutes;
        const set = root.sunsetMinutes;
        const dayLength = set - rise;
        if (minute >= rise && minute <= set)
            return Math.sin(Math.PI * (minute - rise) / dayLength);
        const nightLength = Math.max(1, root.minuteCount - dayLength);
        const intoNight = minute < rise
            ? (minute + root.minuteCount - set)
            : (minute - set);
        return -root.nightDepth * Math.sin(Math.PI * intoNight / nightLength);
    }

    function xFor(minute) {
        return root.width * minute / root.minuteCount;
    }

    function yFor(minute) {
        const horizon = root.height * root.horizonRatio;
        const sky = Math.max(1, horizon - root.edgeInset);
        const ground = Math.max(1, root.height - root.edgeInset - horizon);
        const level = root.levelAt(minute);
        if (level >= 0) return horizon - level * sky;
        // The trough is scaled to its own depth so the deepest night reaches the
        // bottom of the strip instead of leaving the lower half empty.
        return horizon - level * (ground / Math.max(0.01, root.nightDepth));
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width;
        const h = height;
        if (w <= 12 || h <= 10 || !root.hasSun) return;

        const horizon = h * root.horizonRatio;
        const steps = 60;

        // Daylight: the arc closed along the horizon, so the area under the sun is
        // warm and the night side stays card-coloured.
        ctx.beginPath();
        ctx.moveTo(root.xFor(root.sunriseMinutes), horizon);
        for (let i = 0; i <= steps; i++) {
            const minute = root.sunriseMinutes
                + (root.sunsetMinutes - root.sunriseMinutes) * i / steps;
            ctx.lineTo(root.xFor(minute), root.yFor(minute));
        }
        ctx.lineTo(root.xFor(root.sunsetMinutes), horizon);
        ctx.closePath();
        ctx.fillStyle = ColorUtils.applyAlpha(root.sunColor, root.fillAlpha);
        ctx.fill();

        // The arc runs the whole day, so the night half is drawn too — and dimmed by
        // the ground painted over it, which is what turns it olive in the reference.
        ctx.beginPath();
        for (let i = 0; i <= steps * 2; i++) {
            const minute = root.minuteCount * i / (steps * 2);
            const x = root.xFor(minute);
            const y = root.yFor(minute);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.lineWidth = root.strokeWidth;
        ctx.strokeStyle = root.sunColor;
        ctx.stroke();

        ctx.fillStyle = root.groundColor;
        ctx.fillRect(0, horizon, w, h - horizon);

        // The horizon itself, crisp on top of the ground it bounds.
        ctx.beginPath();
        ctx.moveTo(0, horizon);
        ctx.lineTo(w, horizon);
        ctx.lineWidth = 1;
        ctx.strokeStyle = root.horizonColor;
        ctx.stroke();

        if (root.nowMinutes >= 0) {
            // Clamped in x only: at 00:00 the marker would otherwise lose half of
            // itself off the left edge.
            const x = Math.min(Math.max(root.xFor(root.nowMinutes), root.markerRadius),
                w - root.markerRadius);
            const y = root.yFor(root.nowMinutes);
            const up = root.levelAt(root.nowMinutes) >= 0;
            ctx.globalAlpha = up ? 1 : 0.45;
            ctx.fillStyle = root.sunColor;
            ctx.beginPath();
            ctx.arc(x, y, root.markerRadius, 0, 2 * Math.PI);
            ctx.fill();
            ctx.globalAlpha = 1;
        }
    }
}

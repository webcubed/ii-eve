import QtQuick
import qs.modules.common
import qs.modules.common.functions

// The sun's travel between sunrise and sunset. The curve is a raised cosine, not
// a semicircle: it leaves and meets the horizon with a flat slope and climbs
// steepest mid-morning/mid-afternoon, so it reads as a landscape hill instead of
// a bump stuck on top of the labels. Time maps linearly across the width, and the
// marker rides the curve at the current fraction of the daylight window.
Canvas {
    id: root

    property real progress: 0
    property bool aboveHorizon: true
    property color arcColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.45)
    property color markerColor: Appearance.colors.colPrimary
    property real strokeWidth: 1.6
    property real markerRadius: 3
    property real glowRadius: 6

    onProgressChanged: requestPaint()
    onAboveHorizonChanged: requestPaint()
    onArcColorChanged: requestPaint()
    onMarkerColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function pointAt(fraction) {
        const inset = 2;
        const baseY = height - 2;
        const peak = Math.max(4, height - 8);
        const x = inset + (width - inset * 2) * fraction;
        const lift = 0.5 - 0.5 * Math.cos(2 * Math.PI * fraction);
        return [x, baseY - peak * lift];
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width;
        const h = height;
        if (w <= 12 || h <= 10) return;

        // Sample the curve: 48 segments is smooth at widget sizes and avoids
        // depending on bezier control-point math for a shape this shallow.
        const steps = 48;
        ctx.beginPath();
        for (let i = 0; i <= steps; i++) {
            const p = pointAt(i / steps);
            if (i === 0) ctx.moveTo(p[0], p[1]);
            else ctx.lineTo(p[0], p[1]);
        }
        ctx.lineWidth = root.strokeWidth;
        ctx.strokeStyle = root.arcColor;
        ctx.stroke();

        const marker = pointAt(Math.max(0, Math.min(1, root.progress)));
        const mx = marker[0];
        const my = marker[1];
        ctx.fillStyle = root.markerColor;
        ctx.globalAlpha = root.aboveHorizon ? 0.2 : 0.08;
        ctx.beginPath();
        ctx.arc(mx, my, root.glowRadius, 0, 2 * Math.PI);
        ctx.fill();
        ctx.globalAlpha = root.aboveHorizon ? 1 : 0.45;
        ctx.beginPath();
        ctx.arc(mx, my, root.markerRadius, 0, 2 * Math.PI);
        ctx.fill();
        ctx.globalAlpha = 1;
    }
}

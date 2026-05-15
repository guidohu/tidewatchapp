import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

class StatsView extends WatchUi.View {
    private var _pageIndex as Number = 0;

    function initialize() {
        View.initialize();
    }

    function setPage(index as Number) as Void {
        _pageIndex = index;
    }

    function getPage() as Number {
        return _pageIndex;
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var distUnitProp = Application.Properties.getValue("DistanceUnits");
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var app = getApp();
        if (app.activityTracker == null) { return; }
        var tracker = app.activityTracker;
        
        // --- Draw Indicator ---
        drawIndicator(dc);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var scale = width / 416.0;
        var startY = (height * 0.15).toNumber();
        var lh = dc.getFontHeight(Graphics.FONT_XTINY) + (4 * scale).toNumber();

        if (_pageIndex == 0) {
            drawPage0(dc, tracker, startY, lh, distUnitProp, scale);
        } else {
            drawPage1(dc, tracker, startY, lh, distUnitProp, scale);
        }
    }

    private function drawIndicator(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var barW = 4;
        var barH = height * 0.2;
        var barX = 10;
        var barY = (_pageIndex == 0) ? (height * 0.3) : (height * 0.5);
        
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, height * 0.3, barW, height * 0.4); // Background bar
        
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX - 1, barY, barW + 2, barH, 2);
    }

    private function drawPage0(dc as Graphics.Dc, tracker as ActivityTracker, startY as Number, lh as Number, distUnitProp as Object?, scale as Float) as Void {
        var width = dc.getWidth();
        
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, startY, Graphics.FONT_TINY, "WAVE STATS", Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh * 1.5;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Total Waves
        var waveCount = tracker.getWaveCount();
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Total Waves: " + waveCount, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Longest Wave
        var maxLen = tracker.getMaxWaveLength();
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Longest Wave: " + maxLen.format("%.0f") + "m", Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Max Speed
        var maxSpeedMs = tracker.getMaxWaveSpeed();
        var speedVal = maxSpeedMs * 3.6f; // km/h
        var sUnit = "km/h";
        if (distUnitProp != null && (distUnitProp as Number) == DataKeys.SETTING_DISTANCE_UNIT_MILES) { // Miles
            speedVal = maxSpeedMs * 2.23694f;
            sUnit = "mph";
        }
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Max Speed: " + speedVal.format("%.1f") + " " + sUnit, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Surf Time (Moving Time on waves)
        var surfSec = tracker.getTotalWaveTime();
        var surfStr = formatDuration(surfSec);
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Surf Time: " + surfStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawPage1(dc as Graphics.Dc, tracker as ActivityTracker, startY as Number, lh as Number, distUnitProp as Object?, scale as Float) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, startY, Graphics.FONT_TINY, "SESSION & PATH", Graphics.TEXT_JUSTIFY_CENTER);
        startY += (lh * 1.2).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Session Time
        var info = Activity.getActivityInfo();
        var elapsedMs = (info != null && info.elapsedTime != null) ? info.elapsedTime : 0;
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Session: " + formatDuration(elapsedMs / 1000), Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Total Distance
        var distMeters = tracker.getDistance();
        var distVal = UnitUtils.formatDistance(distMeters, distUnitProp != null ? distUnitProp as Number : DataKeys.SETTING_DISTANCE_UNIT_KM);
        var dUnit = UnitUtils.getDistanceUnitString(distUnitProp != null ? distUnitProp as Number : DataKeys.SETTING_DISTANCE_UNIT_KM);
        
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Distance: " + distVal + dUnit, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Average Wave Length
        var avgLen = tracker.getAvgWaveLength();
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Avg Wave: " + avgLen.format("%.0f") + "m", Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        // Paddle Strokes
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, "Strokes: " + tracker.getPaddleStrokes(), Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh + (10 * scale).toNumber();

        // Mini Map
        drawPath(dc, tracker, startY, (width * 0.4).toNumber(), (height * 0.15).toNumber(), scale);
    }

    private function drawPath(dc as Graphics.Dc, tracker as ActivityTracker, y as Number, boxW as Number, boxH as Number, scale as Float) as Void {
        var width = dc.getWidth();
        var path = tracker.getPathPoints();
        if (path.size() < 2) { return; }

        var minLat = 90.0; var maxLat = -90.0;
        var minLon = 180.0; var maxLon = -180.0;
        for (var i = 0; i < path.size(); i += 2) {
            var lat = path[i]; var lon = path[i + 1];
            if (lat < minLat) { minLat = lat; } if (lat > maxLat) { maxLat = lat; }
            if (lon < minLon) { minLon = lon; } if (lon > maxLon) { maxLon = lon; }
        }

        var boxX = (width - boxW) / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(boxX, y, boxW, boxH);
        
        var latDiff = maxLat - minLat;
        var lonDiff = maxLon - minLon;
        if (latDiff == 0.0) { latDiff = 0.0001; }
        if (lonDiff == 0.0) { lonDiff = 0.0001; }

        // Maintain aspect ratio: Use the same scale for both axes
        var lonScale = boxW.toFloat() / lonDiff;
        var latScale = boxH.toFloat() / latDiff;
        var finalScale = (lonScale < latScale) ? lonScale : latScale;

        // Center the path within the bounding box
        var offsetX = boxX + (boxW - lonDiff * finalScale) / 2;
        var offsetY = y + (boxH - latDiff * finalScale) / 2;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var prevX = 0; var prevY = 0;
        for (var i = 0; i < path.size(); i += 2) {
            var px = offsetX + (path[i+1] - minLon) * finalScale;
            var py = offsetY + (latDiff * finalScale) - ((path[i] - minLat) * finalScale);
            if (i > 0) { dc.drawLine(prevX, prevY, px.toNumber(), py.toNumber()); }
            prevX = px.toNumber(); prevY = py.toNumber();
        }
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(prevX, prevY, 3);
    }

    private function formatDuration(seconds as Number) as String {
        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        var s = seconds % 60;
        if (h > 0) {
            return Lang.format("$1$:$2$:$3$", [h, m.format("%02d"), s.format("%02d")]);
        }
        return Lang.format("$1$:$2$", [m, s.format("%02d")]);
    }
}

class StatsDelegate extends WatchUi.BehaviorDelegate {
    private var _view as StatsView;

    function initialize(view as StatsView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        var currentPage = _view.getPage();

        if (dir == WatchUi.SWIPE_DOWN) {
            if (currentPage == 0) {
                _view.setPage(1);
                WatchUi.requestUpdate();
                return true;
            }
        } else if (dir == WatchUi.SWIPE_UP) {
            if (currentPage == 1) {
                _view.setPage(0);
                WatchUi.requestUpdate();
                return true;
            } else {
                WatchUi.popView(WatchUi.SLIDE_UP);
                return true;
            }
        }
        return false;
    }

    function onBack() as Boolean {
        if (_view.getPage() == 1) {
            _view.setPage(0);
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_UP);
        return true;
    }
}

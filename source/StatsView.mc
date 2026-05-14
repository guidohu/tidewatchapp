import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Application;
import Toybox.Lang;

class StatsView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var distUnitProp = Application.Properties.getValue("DistanceUnits");
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var app = getApp();
        if (app.activityTracker == null) {
            return;
        }
        
        var tracker = app.activityTracker;
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        var scale = width / 416.0;
        var startY = (height * 0.1).toNumber();
        var lh = dc.getFontHeight(Graphics.FONT_XTINY);
        
        // HR
        var curHR = tracker.getCurrentHR();
        var avgHR = tracker.getAverageHR();
        var maxHR = tracker.getMaxHR();
        var hrStr = "HR: ";
        hrStr += (curHR != null) ? curHR.toString() + " cur, " : "-- cur, ";
        hrStr += (avgHR != null) ? avgHR.toString() + " avg, " : "-- avg, ";
        hrStr += (maxHR != null) ? maxHR.toString() + " max" : "-- max";
        
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, hrStr, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;
        
        // Waves
        var waveCount = tracker.getWaveCount();
        var waveStr = "Waves: " + waveCount.toString();
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, waveStr, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;

        if (waveCount > 0) {
            // Max Wave Speed (converted to km/h or mph)
            var maxSpeedMs = tracker.getMaxWaveSpeed();
            var speedVal = maxSpeedMs * 3.6f; // km/h
            var sUnit = "km/h";
            if (distUnitProp != null && (distUnitProp as Number) == DataKeys.SETTING_DISTANCE_UNIT_MILES) {
                speedVal = maxSpeedMs * 2.23694f; // mph
                sUnit = "mph";
            }
            var speedStr = "Max Speed: " + speedVal.format("%.1f") + " " + sUnit;
            dc.drawText(width / 2, startY, Graphics.FONT_XTINY, speedStr, Graphics.TEXT_JUSTIFY_CENTER);
            startY += lh;

            // Longest Wave
            var maxLen = tracker.getMaxWaveLength();
            var lenStr = "Longest: " + maxLen.format("%.0f") + "m";
            dc.drawText(width / 2, startY, Graphics.FONT_XTINY, lenStr, Graphics.TEXT_JUSTIFY_CENTER);
            startY += lh;

            // Total Wave Time
            var surfSec = tracker.getTotalWaveTime();
            var surfMin = surfSec / 60;
            var surfS = surfSec % 60;
            var surfStr = "Surf Time: " + surfMin.toString() + ":" + surfS.format("%02d");
            dc.drawText(width / 2, startY, Graphics.FONT_XTINY, surfStr, Graphics.TEXT_JUSTIFY_CENTER);
            startY += lh;
        }
        
        // Strokes
        var strokeStr = "Strokes: " + tracker.getPaddleStrokes().toString();
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, strokeStr, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;
        
        // Distance
        var distVal = tracker.getDistance() / 1000.0f;
        var dUnit = "km";
        if (distUnitProp != null && (distUnitProp as Number) == DataKeys.SETTING_DISTANCE_UNIT_MILES) {
            distVal = tracker.getDistance() * 0.000621371f;
            dUnit = "mi";
        }
        var distStr = "Distance: " + distVal.format("%.2f") + " " + dUnit;
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, distStr, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh;
        
        // Time Still
        var stillSec = tracker.getTimeStillSec();
        var stillMin = stillSec / 60;
        var stillS = stillSec % 60;
        var stillStr = "Time Still: " + stillMin.toString() + ":" + stillS.format("%02d");
        dc.drawText(width / 2, startY, Graphics.FONT_XTINY, stillStr, Graphics.TEXT_JUSTIFY_CENTER);
        startY += lh + (10 * scale).toNumber();
        
        // Schematic Path
        var path = tracker.getPathPoints();
        if (path.size() > 1) {
            var minLat = 90.0; var maxLat = -90.0;
            var minLon = 180.0; var maxLon = -180.0;
            
            for (var i = 0; i < path.size(); i++) {
                var pt = path[i];
                if (pt[0] < minLat) { minLat = pt[0]; }
                if (pt[0] > maxLat) { maxLat = pt[0]; }
                if (pt[1] < minLon) { minLon = pt[1]; }
                if (pt[1] > maxLon) { maxLon = pt[1]; }
            }
            
            var boxW = width * 0.6;
            var boxH = height * 0.3;
            var boxX = (width - boxW) / 2;
            var boxY = startY;
            
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(boxX, boxY, boxW, boxH);
            
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((2 * scale).toNumber());
            
            var latDiff = maxLat - minLat;
            var lonDiff = maxLon - minLon;
            if (latDiff == 0.0) { latDiff = 0.0001; }
            if (lonDiff == 0.0) { lonDiff = 0.0001; }
            
            // Adjust scaling to keep aspect ratio rough (lat/lon isn't square but it's schematic)
            var prevX = 0; var prevY = 0;
            for (var i = 0; i < path.size(); i++) {
                var pt = path[i];
                var px = boxX + (pt[1] - minLon) / lonDiff * boxW;
                var py = boxY + boxH - ((pt[0] - minLat) / latDiff * boxH); // Invert Y for latitude
                
                if (i > 0) {
                    dc.drawLine(prevX, prevY, px.toNumber(), py.toNumber());
                }
                prevX = px.toNumber();
                prevY = py.toNumber();
            }
            
            // Draw current position indicator
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(prevX, prevY, (3 * scale).toNumber());
            
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, startY + (20 * scale).toNumber(), Graphics.FONT_XTINY, "No path data yet", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class StatsDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        if (evt.getDirection() == WatchUi.SWIPE_UP) {
            WatchUi.popView(WatchUi.SLIDE_UP);
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_UP);
        return true;
    }
}

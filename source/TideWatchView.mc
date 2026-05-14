import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Timer;

class TideWatchView extends WatchUi.View {

    const METERS_TO_FEET = 3.28084;
    const STALE_DATA_THRESHOLD_SEC = 43200; // 12 hours
    const ERROR_DISPLAY_WINDOW_SEC = 300;   // 5 minutes
    const GRAPH_PAST_HOURS = 2;
    const GRAPH_FUTURE_HOURS = 16;
    const SCREEN_WIDTH_REFERENCE = 416.0;
    const DISPLAY_TIMEOUT_SEC = 30;

    var mDisplayOn as Boolean = true;
    var mDisplayTimer as Timer.Timer?;
    var mFullRedrawNeeded as Boolean = true;
    var mLastUpdateMin as Number = -1;

    // Cache for Storage values
    var mcTideData as Array? = null;
    var mcTideTimes as Array? = null;
    var mcTideExtrema as Array? = null;
    var mcWaveData as Array? = null;
    var mcSpotName as String? = null;
    var mSyncError as Number? = null;
    var mWeatherError as Number? = null;
    var mErrorAt as Number? = null;
    var mcTideUnitApi as Number? = null;
    var mcSwellUnitApi as Number? = null;
    var mLastDataUpdatedAt as Number = 0;
    var mLastSyncAttemptAt as Number = 0;
    var mLastSettingsHash as Number = 0;
    var mLastLazyDataUpdate as Number = 0;
    var mCurrentIdx as Number = 0;

    // Calculated values (Memory Cache)
    var mBattery as Float = 0.0;
    var mDateStr as String = "";
    var mDowStr as String = "";
    var mCurrentHeight as Float = 0.0;
    var mIsRising as Boolean = false;
    var mNextExtremaStr as String? = null;
    var mDispUnit as String = "";
    var mTideNumStr as String = "";
    var mValidSwells as Array = [];
    var mSwellTexts as Array = [];
    var mMinH as Float = 9999.0;
    var mMaxH as Float = -9999.0;
    var mMinSwellH as Float = 9999.0;
    var mMaxSwellH as Float = -9999.0;
    var mMinT as Number = 0;
    var mMaxT as Number = 0;

    // Settings Cache
    var mUse24Hour as Boolean = true;
    var mShowDate as Boolean = true;
    var mShowSwellSummary as Boolean = true;
    var mShowSwellGraph as Boolean = true;
    var mTideColor as Number = Graphics.COLOR_BLUE;
    var mGraphColor as Number = Graphics.COLOR_LT_GRAY;
    var mBaseColor as Number = Graphics.COLOR_WHITE;
    var mDistanceUnits as Number = DataKeys.SETTING_DISTANCE_UNIT_KM;

    // Graphics Buffering
    var mGraphBuffer as Graphics.BufferedBitmap?;
    var mGraphBufferValid as Boolean = false;

    var mTimer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTick), 1000, true);
        
        mDisplayTimer = new Timer.Timer();
        resetDisplayTimer();
        
        mFullRedrawNeeded = true;
        mGraphBufferValid = false;
    }

    function resetDisplayTimer() as Void {
        if (mDisplayTimer != null) {
            mDisplayTimer.stop();
            mDisplayTimer.start(method(:onDisplayTimeout), DISPLAY_TIMEOUT_SEC * 1000, false);
        }
        mDisplayOn = true;
        mFullRedrawNeeded = true;
    }

    function onDisplayTimeout() as Void {
        mDisplayOn = false;
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        if (mTimer != null) { mTimer.stop(); mTimer = null; }
        if (mDisplayTimer != null) { mDisplayTimer.stop(); mDisplayTimer = null; }
    }

    function onTimerTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var now = Time.now().value();
        Log.debug("UI", "onUpdate at " + now);
        if (!mDisplayOn) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            return;
        }

        var clockTime = System.getClockTime();
        var isMinuteChanged = (clockTime.min != mLastUpdateMin);
        mLastUpdateMin = clockTime.min;
        
        
        mFullRedrawNeeded = false;
        updateCache(now);

        // --- DRAWING ---
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var scale = width / SCREEN_WIDTH_REFERENCE;

        // 1. Time / Battery / Date
        renderTimeSection(dc, width, height, scale, clockTime);

        // 2. Main Tide Display
        if (mcTideData == null || mcTideTimes == null) {
            renderSyncStatus(dc, height);
            return;
        }

        renderTideSection(dc, width, height, scale);

        // 3. Swell Section
        if (mShowSwellSummary) {
            renderSwellSection(dc, width, height, scale);
        }

        // 4. Graph Section
        renderGraphArea(dc, width, height, now);

        // 5. Spot Name / Error
        renderFooter(dc, height, now);
    }

    function updateCache(now as Number) as Void {
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        var targetTideUnit = (tideUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var targetSwellUnit = (swellUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var timeFormatVal = Application.Properties.getValue("TimeFormat");
        var distUnits = Application.Properties.getValue("DistanceUnits");
        mDistanceUnits = (distUnits != null) ? distUnits as Number : DataKeys.SETTING_DISTANCE_UNIT_KM;
        
        mUse24Hour = (timeFormatVal == null || timeFormatVal == DataKeys.TIME_FORMAT_24_H);
        var showDate = Application.Properties.getValue("ShowDate");
        mShowDate = (showDate != null && showDate == true);
        mShowSwellGraph = Application.Properties.getValue("ShowSwellGraph");
        mShowSwellSummary = Application.Properties.getValue("ShowSwellSummary");
        mTideColor = getColorFromIndex(Application.Properties.getValue("TideColor"));
        mGraphColor = getColorFromIndex(Application.Properties.getValue("GraphColor"));
        mBaseColor = getColorFromIndex(Application.Properties.getValue("BaseColor"));

        var dataUpdatedAt = Application.Storage.getValue("dataUpdatedAt") as Number?;
        if (dataUpdatedAt == null) { dataUpdatedAt = 0; }

        if (now - mLastLazyDataUpdate >= Constants.DATA_UPDATE_INTERVAL_SEC || dataUpdatedAt != mLastDataUpdatedAt) {
            mLastLazyDataUpdate = now;
            mLastDataUpdatedAt = dataUpdatedAt;
            mGraphBufferValid = false; // Data changed, invalidate graph
            Log.info("Data", "Refreshing cache from storage. dataUpdatedAt: " + dataUpdatedAt);

            mcTideData = Application.Storage.getValue("tideData") as Array?;
            mcTideTimes = Application.Storage.getValue("tideTimes") as Array?;
            mcTideExtrema = Application.Storage.getValue("tideExtrema") as Array?;
            mcWaveData = Application.Storage.getValue("waveData") as Array?;
            mcTideUnitApi = Application.Storage.getValue("tideUnitApi") as Number?;
            mcSwellUnitApi = Application.Storage.getValue("swellUnitApi") as Number?;
            mcSpotName = Application.Storage.getValue("spotName") as String?;
            mSyncError = Application.Storage.getValue("syncError") as Number?;
            mErrorAt = Application.Storage.getValue("errorAt") as Number?;
            mWeatherError = Application.Storage.getValue("weatherError") as Number?;
        }

        mBattery = System.getSystemStats().battery;
        var todayMed = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var todayLong = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        mDateStr = todayMed.day.format("%d") + " " + todayMed.month;
        mDowStr = todayLong.day_of_week;

        mMinH = 9999.0; mMaxH = -9999.0;
        mMinSwellH = 9999.0; mMaxSwellH = -9999.0;
        mMinT = now - GRAPH_PAST_HOURS * Constants.SECONDS_IN_HOUR;
        mMaxT = now + GRAPH_FUTURE_HOURS * Constants.SECONDS_IN_HOUR;

        if (mcTideData != null && mcTideTimes != null) {
            calculateCurrentTide(now, targetTideUnit);
            calculateExtrema(now, targetTideUnit);
            calculateSwells(targetSwellUnit);
            calculateGraphBounds();
        }
    }

    function calculateCurrentTide(now as Number, targetTideUnit as Number) as Void {
        var found = false;
        var tTimesArray = mcTideTimes as Array;
        var tDataArray = mcTideData as Array;
        for (var i = 0; i < tTimesArray.size() - 1; i++) {
            var t1 = tTimesArray[i] as Number;
            var t2 = tTimesArray[i + 1] as Number;
            if (now >= t1 && now <= t2) {
                var h1 = convertHeight(tDataArray[i] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                var h2 = convertHeight(tDataArray[i + 1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                var ratio = (now - t1).toFloat() / (t2 - t1).toFloat();
                mCurrentHeight = h1 + (h2 - h1) * ratio;
                mIsRising = h2 > h1;
                mCurrentIdx = i;
                found = true;
                break;
            }
        }
        if (!found) {
            if (tDataArray.size() > 0) {
                mCurrentHeight = convertHeight(tDataArray[0] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                mCurrentIdx = 0;
            }
        }

        var dispHeight = convertHeight((mCurrentHeight * 100).toNumber(), DataKeys.UNIT_METER, targetTideUnit);
        mDispUnit = (targetTideUnit == DataKeys.UNIT_FEET) ? "ft" : "m";
        mTideNumStr = dispHeight.format("%.2f");
    }

    function calculateExtrema(now as Number, targetTideUnit as Number) as Void {
        mNextExtremaStr = null;
        if (mcTideExtrema != null) {
            for (var i = 0; i < mcTideExtrema.size(); i++) {
                var ext = mcTideExtrema[i] as Array;
                if (ext[0] > now) {
                    var extTs = ext[0] as Number;
                    var rawExtH = ext[1] as Number;
                    var typeCode = ext[2];
                    var extType = (typeCode == DataKeys.TIDE_TYPE_HIGH) ? "High" : "Low";
                    var extInfo = Gregorian.info(new Time.Moment(extTs.toNumber()), Time.FORMAT_SHORT);
                    var hourAmPm = formatHourAmPm(extInfo.hour, mUse24Hour, false);
                    var extTimeStr = Lang.format("$1$:$2$$3$", [hourAmPm[0].format(mUse24Hour ? "%02d" : "%d"), extInfo.min.format("%02d"), hourAmPm[1]]);
                    var dispExtH = convertHeight(rawExtH, mcTideUnitApi, targetTideUnit);
                    mNextExtremaStr = Lang.format("$1$: $2$$3$ $4$", [extType, dispExtH.format("%.2f"), mDispUnit, extTimeStr]);
                    break;
                }
            }
        }
    }

    function calculateSwells(targetSwellUnit as Number) as Void {
        mValidSwells = [];
        mSwellTexts = [];
        if (mcWaveData != null && mcWaveData.size() > 0) {
            var waveIdx = mCurrentIdx;
            if (waveIdx >= mcWaveData.size()) { waveIdx = mcWaveData.size() - 1; }
            var currentWave = mcWaveData[waveIdx] as Array;
            for (var s = 0; s < 2; s++) {
                var h = currentWave[s*3];
                if (h != null && (h as Number) > 0) {
                    var hvRaw = h as Number;
                    var pValNum = currentWave[s*3+1] as Number;
                    var dValFloat = (currentWave[s*3+2] instanceof Number) ? (currentWave[s*3+2] as Number).toFloat() : currentWave[s*3+2] as Float;
                    mValidSwells.add([hvRaw, pValNum, dValFloat]);
                    var dispH = convertHeight(hvRaw, mcSwellUnitApi, targetSwellUnit);
                    mSwellTexts.add(dispH.format("%.1f") + ((targetSwellUnit == DataKeys.UNIT_FEET) ? "ft" : "m") + "@" + pValNum);
                }
            }
        }
    }

    function calculateGraphBounds() as Void {
        var tTimesArray = mcTideTimes as Array;
        var tDataArray = mcTideData as Array;
        for (var i = 0; i < tDataArray.size(); i++) {
            var tTs = tTimesArray[i] as Number;
            if (tTs >= mMinT - 3600 && tTs <= mMaxT + 3600) {
                var hFloat = convertHeight(tDataArray[i] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                if (hFloat < mMinH) { mMinH = hFloat; }
                if (hFloat > mMaxH) { mMaxH = hFloat; }
            }
        }
        if (mcWaveData != null) {
            for (var i = 0; i < mcWaveData.size(); i++) {
                var wPoint = mcWaveData[i] as Array;
                for (var s = 0; s < 2; s++) {
                    var hVal = wPoint[s*3];
                    if (hVal != null) {
                        var h = convertHeight(hVal as Number, mcSwellUnitApi, DataKeys.UNIT_METER);
                        if (h < mMinSwellH) { mMinSwellH = h; }
                        if (h > mMaxSwellH) { mMaxSwellH = h; }
                    }
                }
            }
        }
        if (mMinSwellH == 9999.0) { mMinSwellH = 0.0; mMaxSwellH = 1.0; }
        if (mMaxSwellH == mMinSwellH) { mMaxSwellH = mMinSwellH + 1.0; }
    }



    function renderTimeSection(dc as Dc, width as Number, height as Number, scale as Float, clockTime as System.ClockTime) as Void {
        var hourAmPmVal = formatHourAmPm(clockTime.hour, mUse24Hour, true);
        var timeStr = Lang.format("$1$:$2$", [hourAmPmVal[0].format(mUse24Hour ? "%02d" : "%d"), clockTime.min.format("%02d")]);
        var timeY = height * 0.24;
        var timeFont = Graphics.FONT_NUMBER_MEDIUM;
        
        dc.setColor(mBaseColor, Graphics.COLOR_TRANSPARENT);
        if (hourAmPmVal[1].length() > 0) {
            var tw = dc.getTextWidthInPixels(timeStr, timeFont);
            var totalW = tw + (5 * scale).toNumber() + dc.getTextWidthInPixels(hourAmPmVal[1] as String, Graphics.FONT_XTINY);
            var startX = (width - totalW) / 2;
            dc.drawText(startX, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + tw + (5*scale).toNumber(), timeY - (8*scale), Graphics.FONT_XTINY, hourAmPmVal[1] as String, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            drawCenteredText(dc, timeY, timeFont, timeStr, mBaseColor);
        }
        drawBattery(dc, width/2, (height * 0.08).toNumber(), mBattery, mBaseColor);
        if (mShowDate) {
            var tw = dc.getTextWidthInPixels(timeStr, timeFont);
            var amPmW = (hourAmPmVal[1].length() > 0) ? (dc.getTextWidthInPixels(hourAmPmVal[1] as String, Graphics.FONT_XTINY) + (5 * scale).toNumber()) : 0;
            var totalTimeW = tw + amPmW;
            var timeStartX = (width - totalTimeW) / 2;
            
            dc.setColor(mBaseColor, Graphics.COLOR_TRANSPARENT);
            // Date on the left
            dc.drawText(timeStartX - (10 * scale).toNumber(), timeY, Graphics.FONT_XTINY, mDateStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            // Day on the right
            dc.drawText(timeStartX + totalTimeW + (10 * scale).toNumber(), timeY, Graphics.FONT_XTINY, mDowStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function renderSyncStatus(dc as Dc, height as Number) as Void {
        var msg = (mSyncError != null) ? "Sync Error" : "Waiting for sync...";
        drawCenteredText(dc, height / 2, Graphics.FONT_XTINY, msg, (mSyncError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY));
    }

    function renderTideSection(dc as Dc, width as Number, height as Number, scale as Float) as Void {
        var numWidth = dc.getTextWidthInPixels(mTideNumStr, Graphics.FONT_NUMBER_MEDIUM);
        var unitWidth = dc.getTextWidthInPixels(mDispUnit, Graphics.FONT_MEDIUM);
        var startX = (width - (numWidth + unitWidth)) / 2;
        
        dc.setColor(mTideColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, height * 0.44, Graphics.FONT_NUMBER_MEDIUM, mTideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth, height * 0.44, Graphics.FONT_MEDIUM, mDispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        var arrowX = startX + numWidth + unitWidth + (15 * scale).toNumber();
        drawArrow(dc, arrowX, (height * 0.44).toNumber(), mIsRising);

        // Surfing Session Metrics
        var tracker = getApp().activityTracker;
        if (tracker != null && tracker.isRecording()) {
            var waves = tracker.getWaveCount();
            var distance = tracker.getDistance();
            
            var distVal = formatDistanceValue(distance);
            var distUnit = (mDistanceUnits == DataKeys.SETTING_DISTANCE_UNIT_KM) ? "km" : "mi";
            var sessionY = height * 0.44;
            var labelYOffset = (25 * scale).toNumber();
            var sessionFont = Graphics.FONT_SMALL;
            var labelFont = Graphics.FONT_XTINY;
            
            dc.setColor(mBaseColor, Graphics.COLOR_TRANSPARENT);
            
            // Waves (Left)
            var wavesX = startX - (50 * scale).toNumber();
            dc.drawText(wavesX, sessionY - (5 * scale).toNumber(), sessionFont, waves.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(wavesX, sessionY + labelYOffset, labelFont, "Waves", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            
            // Distance (Right)
            var distX = arrowX + (55 * scale).toNumber();
            dc.drawText(distX, sessionY - (5 * scale).toNumber(), sessionFont, distVal, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(distX, sessionY + labelYOffset, labelFont, distUnit, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (mNextExtremaStr != null) {
            drawCenteredText(dc, height * 0.67, Graphics.FONT_XTINY, mNextExtremaStr, mBaseColor);
        }
    }

    function renderSwellSection(dc as Dc, width as Number, height as Number, scale as Float) as Void {
        if (mValidSwells.size() > 0) {
            var curY = (height * 0.57).toNumber();
            var totalW = 0;
            for (var i = 0; i < mSwellTexts.size(); i++) {
                totalW += (10*scale).toNumber() + 5 + dc.getTextWidthInPixels(mSwellTexts[i] as String, Graphics.FONT_XTINY);
            }
            var curX = (width - totalW) / 2;
            for (var i = 0; i < mValidSwells.size(); i++) {
                drawSwellArrow(dc, (curX + 5*scale).toNumber(), curY, (mValidSwells[i] as Array)[2] as Float);
                curX += (10*scale).toNumber() + 5;
                dc.setColor(mBaseColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(curX, curY, Graphics.FONT_XTINY, mSwellTexts[i] as String, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                curX += dc.getTextWidthInPixels(mSwellTexts[i] as String, Graphics.FONT_XTINY) + 10;
            }
        }
    }

    function renderGraphArea(dc as Dc, width as Number, height as Number, now as Number) as Void {
        if (mMaxH <= mMinH) { return; }
        var graphY = height * 0.88;
        var graphHeight = height * 0.18;
        var graphMargin = width * 0.15;
        var drawWidth = width - 2 * graphMargin;

        if (!mGraphBufferValid || mGraphBuffer == null) {
            renderGraphToBuffer(drawWidth.toNumber(), graphHeight.toNumber());
        }
        
        if (mGraphBuffer != null) {
            dc.drawBitmap(graphMargin.toNumber(), (graphY - graphHeight).toNumber(), mGraphBuffer);
        }

        // Current Time Marker (Always dynamic)
        var nowX = graphMargin + drawWidth * (now - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
        if (nowX >= 0 && nowX <= width) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            var markerY = graphY - graphHeight * (mCurrentHeight - mMinH) / (mMaxH - mMinH);
            dc.fillCircle(nowX.toNumber(), markerY.toNumber(), (6 * (width/SCREEN_WIDTH_REFERENCE)).toNumber());
        }
    }

    function renderGraphToBuffer(w as Number, h as Number) as Void {
        mGraphBuffer = new Graphics.BufferedBitmap({ :width => w, :height => h });
        var bdc = mGraphBuffer.getDc();
        bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        bdc.clear();
        
        var drawWidth = w.toFloat();
        var graphHeight = h.toFloat();

        // Tide Graph
        bdc.setColor(mGraphColor, Graphics.COLOR_TRANSPARENT);
        var lastX = -1, lastY = -1;
        var tTimesArray = mcTideTimes as Array;
        var tDataArray = mcTideData as Array;
        for (var i = 0; i < tDataArray.size(); i++) {
            var x = drawWidth * (tTimesArray[i] - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
            var y = graphHeight - graphHeight * (convertHeight(tDataArray[i] as Number, mcTideUnitApi, DataKeys.UNIT_METER) - mMinH) / (mMaxH - mMinH);
            if (lastX >= 0 && x >= 0 && x <= drawWidth) {
                bdc.drawLine(lastX, lastY, x.toNumber(), y.toNumber());
            }
            lastX = x.toNumber(); lastY = y.toNumber();
        }
        mGraphBufferValid = true;
    }

    function renderFooter(dc as Dc, height as Number, now as Number) as Void {
        if (mcSpotName != null) {
            var isStale = (now - mLastDataUpdatedAt > STALE_DATA_THRESHOLD_SEC);
            drawCenteredText(dc, height * 0.93, Graphics.FONT_XTINY, mcSpotName as String, isStale ? Graphics.COLOR_YELLOW : mBaseColor);
        }
    }

    function drawArrow(dc as Dc, x as Number, y as Number, isRising as Boolean) as Void {
        var sz = (8 * (dc.getWidth()/SCREEN_WIDTH_REFERENCE)).toNumber();
        dc.setColor(isRising ? Graphics.COLOR_GREEN : Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        var pts = isRising ? [[x, y - sz], [x - sz, y + sz], [x + sz, y + sz]] : [[x, y + sz], [x - sz, y - sz], [x + sz, y - sz]];
        dc.fillPolygon(pts as Array<[Lang.Numeric, Lang.Numeric]>);
    }

    function drawSwellArrow(dc as Dc, x as Number, y as Number, direction as Float) as Void {
        var s = dc.getWidth() / SCREEN_WIDTH_REFERENCE;
        var rad = (direction + 180.0) * Math.PI / 180.0;
        var cos = Math.cos(rad); var sin = Math.sin(rad);
        var px = 0.0; var py = -5.0 * s;
        var p0x = x + px*cos - py*sin; var p0y = y + px*sin + py*cos;
        px = -3.5 * s; py = 3.5 * s;
        var p1x = x + px*cos - py*sin; var p1y = y + px*sin + py*cos;
        px = 3.5 * s; py = 3.5 * s;
        var p2x = x + px*cos - py*sin; var p2y = y + px*sin + py*cos;
        dc.fillPolygon([[p0x, p0y], [p1x, p1y], [p2x, p2y]] as Array<[Lang.Numeric, Lang.Numeric]>);
    }

    function drawBattery(dc as Dc, x as Number, y as Number, battery as Float, colorPrimary as Number) as Void {
        var s = dc.getWidth() / SCREEN_WIDTH_REFERENCE;
        var width = (24 * s).toNumber(); var height = (12 * s).toNumber();
        var color = (battery < 20.0) ? (battery < 10.0 ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW) : colorPrimary;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - (2 * s).toNumber(), y, Graphics.FONT_XTINY, battery.toNumber().toString() + "%", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawRectangle(x + (2*s).toNumber(), y - height/2, width, height);
        dc.fillRectangle(x + (2*s).toNumber() + width, y - (3*s).toNumber(), (2*s).toNumber(), (6*s).toNumber());
        dc.fillRectangle(x + (4*s).toNumber(), y - height/2 + (2*s).toNumber(), ((width - 4*s) * (battery / 100.0)).toNumber(), height - 4*s);
    }

    function getColorFromIndex(idx as Number) as Number {
        if (idx == DataKeys.SETTING_COLOR_PINK) { return Graphics.COLOR_PINK; }
        if (idx == DataKeys.SETTING_COLOR_RED) { return Graphics.COLOR_RED; }
        if (idx == DataKeys.SETTING_COLOR_GREEN) { return Graphics.COLOR_GREEN; }
        if (idx == DataKeys.SETTING_COLOR_WHITE) { return Graphics.COLOR_WHITE; }
        if (idx == DataKeys.SETTING_COLOR_YELLOW) { return Graphics.COLOR_YELLOW; }
        if (idx == DataKeys.SETTING_COLOR_ORANGE) { return Graphics.COLOR_ORANGE; }
        if (idx == DataKeys.SETTING_COLOR_PURPLE) { return Graphics.COLOR_PURPLE; }
        if (idx == DataKeys.SETTING_COLOR_LT_GRAY) { return Graphics.COLOR_LT_GRAY; }
        if (idx == DataKeys.SETTING_COLOR_DK_GRAY) { return Graphics.COLOR_DK_GRAY; }
        if (idx == DataKeys.SETTING_COLOR_LIGHT_BLUE) { return 0x55AAFF; }
        if (idx == DataKeys.SETTING_COLOR_PETROL) { return 0x005F6B; }
        if (idx == DataKeys.SETTING_COLOR_TURQUOISE) { return 0x00CCCC; }
        return Graphics.COLOR_BLUE;
    }

    function formatHourAmPm(hour as Number, use24Hour as Boolean, upperCase as Boolean) as Array {
        var amPm = "";
        if (!use24Hour) {
            amPm = (hour >= 12) ? (upperCase ? "PM" : "pm") : (upperCase ? "AM" : "am");
            hour = (hour > 12) ? (hour - 12) : (hour == 0 ? 12 : hour);
        }
        return [hour, amPm];
    }

    function drawCenteredText(dc as Dc, y as Lang.Numeric, font, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function formatDistanceValue(meters as Float) as String {
        var absMeters = (meters < 0) ? -meters : meters;
        if (absMeters < 0.005) { absMeters = 0.0; } // Threshold to avoid -0.00
        
        if (mDistanceUnits == DataKeys.SETTING_DISTANCE_UNIT_KM) {
            return (absMeters / 1000.0).format("%.2f");
        } else {
            return (absMeters / 1609.344).format("%.2f");
        }
    }

    function convertHeight(rawValue as Number, apiUnit as Number?, targetUnit as Number) as Float {
        var valFloat = rawValue.toFloat() / 100.0;
        if (apiUnit == DataKeys.UNIT_METER && targetUnit == DataKeys.UNIT_FEET) { return valFloat * METERS_TO_FEET; }
        if (apiUnit == DataKeys.UNIT_FEET && targetUnit == DataKeys.UNIT_METER) { return valFloat / METERS_TO_FEET; }
        return valFloat;
    }
}

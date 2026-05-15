import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;

class SyncTimer {
    private var _timer as Timer.Timer?;
    function start(methodSym as Symbol, obj as Object) as Void {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(obj.method(methodSym), 50, false);
    }
}

(:background)
class SyncEngine {
    private var mApiKey as String? = null;
    private var mTargetLat as Float? = null;
    private var mTargetLon as Float? = null;
    private var mStart as Number? = null;
    private var mEnd as Number? = null;
    private var mTideEnd as Number? = null;
    private var mDatumStr as String? = null;
    private var mDataUpdatedThisRun as Boolean = false;
    private var mIsBackground as Boolean = true;
    private var mNextStepTimer = null; // SyncTimer in foreground

    function initialize(isBackground as Boolean) {
        mIsBackground = isBackground;
        if (!mIsBackground) {
            mNextStepTimer = new SyncTimer();
        }
    }

    function run() as Void {
        var appId = Application.Storage.getValue("AppId") as String?;
        if (appId == null) {
            System.println("AppId missing. Sync aborted.");
            finishSync(false);
            return;
        }

        mApiKey = Application.Properties.getValue("StormglassApiKey");
        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        if (gpsLat != null && gpsLon != null && (gpsLat != 0.0 || gpsLon != 0.0)) {
            mTargetLat = gpsLat.toFloat();
            mTargetLon = gpsLon.toFloat();
        } else {
            Log.warn("Sync", "No valid coordinates. Sync aborted.");
            finishSync(false);
            return;
        }

        var datumProp = Application.Properties.getValue("TideDatum") as Number;
        if (datumProp == DataKeys.DATUM_MSL) { mDatumStr = "MSL"; }
        else if (datumProp == DataKeys.DATUM_MLLW) { mDatumStr = "MLLW"; }
        else if (datumProp == DataKeys.DATUM_LAT) { mDatumStr = "LAT"; }
        else { mDatumStr = null; }

        var now = Time.now();
        mStart = now.subtract(new Time.Duration(4 * 3600)).value();
        mEnd = now.add(new Time.Duration(48 * 3600)).value();
        mTideEnd = now.add(new Time.Duration(48 * 3600)).value();

        Log.info("Sync", Lang.format("Sync started. Background: $1$", [mIsBackground]));
        makeBigDataCloudRequest();
    }

    private function finishSync(status as Boolean) as Void {
        Log.info("Sync", "Finishing. Success: " + status);
        if (mDataUpdatedThisRun) {
            Application.Storage.setValue("dataUpdatedAt", Time.now().value());
        }
        if (status) {
            Application.Storage.deleteValue("syncError");
            Application.Storage.deleteValue("errorAt");
        }
        
        if (mIsBackground) {
            Background.exit(status);
        } else {
            var app = Application.getApp() as TideWatchApp;
            app.onBackgroundData(status);
        }
    }

    private function processNextStep(methodSym as Symbol) as Void {
        if (mNextStepTimer != null) {
            mNextStepTimer.method(:start).invoke(methodSym, self);
        } else {
            var m = method(methodSym);
            m.invoke();
        }
    }

    function makeBigDataCloudRequest() as Void {
        if (isFresh("geocodeUpdatedAt", Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            if (mApiKey != null && !mApiKey.equals("")) {
                processNextStep(:makeStormglassWeatherRequest);
            } else {
                processNextStep(:makeTideTimelineRequest);
            }
            return;
        }

        var url = "https://forecast.wakeandsurf.ch/data/reverse-geocode";
        var params = { "latitude" => mTargetLat, "longitude" => mTargetLon, "localityLanguage" => "en" };
        Communications.makeWebRequest(url, params, getOptions(true), method(:onReceiveGeocode));
    }

    function onReceiveGeocode(code as Number, data as Dictionary?) as Void {
        var spotName = null;
        if (code == 200 && data != null) {
            spotName = data.get("locality");
            if (spotName == null) { spotName = data.get("city"); }
        }
        if (spotName == null) { spotName = Lang.format("$1$, $2$", [mTargetLat.format("%.2f"), mTargetLon.format("%.2f")]); }
        
        Application.Storage.setValue("spotName", spotName);
        Application.Storage.setValue("geocodeUpdatedAt", Time.now().value());
        mDataUpdatedThisRun = true;

        if (mApiKey != null && !mApiKey.equals("")) {
            processNextStep(:makeStormglassWeatherRequest);
        } else {
            processNextStep(:makeTideTimelineRequest);
        }
    }

    function makeStormglassWeatherRequest() as Void {
        if (isFresh("weatherUpdatedAt", Constants.SLOW_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            processNextStep(:makeTideTimelineRequest);
            return;
        }
        var url = "https://forecast.wakeandsurf.ch/v2/weather/point";
        var params = { "lat" => mTargetLat, "lng" => mTargetLon, "start" => mStart, "end" => mEnd, "params" => "swellHeight,swellPeriod,swellDirection,secondarySwellHeight,secondarySwellPeriod,secondarySwellDirection", "source" => "noaa" };
        Communications.makeWebRequest(url, params, getOptions(true), method(:onReceiveWeather));
    }

    function onReceiveWeather(code as Number, data as Dictionary?) as Void {
        if (code == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var waveResults = new Array<Array<Number?>>[pts.size()];
            for (var i = 0; i < pts.size(); i++) {
                var pt = pts[i] as Dictionary;
                var wPoint = new Array<Number?>[9];
                var h = pt.get("h1"); if (h != null) { wPoint[0] = (parseFloat(h) * 100.0).toNumber(); }
                var p = pt.get("p1"); if (p != null) { wPoint[1] = parseNumber(p); }
                var d = pt.get("d1"); if (d != null) { wPoint[2] = parseNumber(d); }
                var h2 = pt.get("h2"); if (h2 != null) { wPoint[3] = (parseFloat(h2) * 100.0).toNumber(); }
                var p2 = pt.get("p2"); if (p2 != null) { wPoint[4] = parseNumber(p2); }
                var d2 = pt.get("d2"); if (d2 != null) { wPoint[5] = parseNumber(d2); }
                waveResults[i] = wPoint;
            }
            Application.Storage.setValue("waveData", waveResults);
            Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_METER);
            Application.Storage.setValue("weatherUpdatedAt", Time.now().value());
            Application.Storage.deleteValue("weatherError");
            mDataUpdatedThisRun = true;
        } else if (code != 200) {
            var err = DataKeys.ERROR_OTHER;
            if (code == 402 || code == 429) { err = DataKeys.ERROR_QUOTA_EXCEEDED; }
            Application.Storage.setValue("weatherError", err);
        }
        processNextStep(:makeTideTimelineRequest);
    }

    function makeTideTimelineRequest() as Void {
        if (isFresh("tideTimelineUpdatedAt", Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            processNextStep(:makeTideExtremesRequest);
            return;
        }
        var url = "https://forecast.wakeandsurf.ch/tides/timeline";
        var params = { "latitude" => mTargetLat, "longitude" => mTargetLon, "start" => mStart, "end" => mTideEnd };
        if (mDatumStr != null) { params.put("datum", mDatumStr); }
        Communications.makeWebRequest(url, params, getOptions(false), method(:onReceiveTide));
    }

    function onReceiveTide(code as Number, data as Dictionary?) as Void {
        if (code == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var gridHeights = new Array<Number>[pts.size()];
            var gridTimes = new Array<Number>[pts.size()];
            for (var i = 0; i < pts.size(); i++) {
                var point = pts[i] as Dictionary;
                gridTimes[i] = point.get("ts") as Number;
                var h = point.get("h");
                gridHeights[i] = (h != null) ? (parseFloat(h) * 100.0).toNumber() : 0;
            }
            Application.Storage.setValue("tideTimes", gridTimes);
            Application.Storage.setValue("tideData", gridHeights);
            Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_METER);
            Application.Storage.setValue("tideTimelineUpdatedAt", Time.now().value());
            mDataUpdatedThisRun = true;
            processNextStep(:makeTideExtremesRequest);
        } else {
            saveError(code);
            finishSync(false);
        }
    }

    function makeTideExtremesRequest() as Void {
        if (isFresh("tideExtremesUpdatedAt", Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            processNextStep(:finalizeSync);
            return;
        }
        var url = "https://forecast.wakeandsurf.ch/tides/extremes";
        var params = { "latitude" => mTargetLat, "longitude" => mTargetLon, "start" => mStart, "end" => mTideEnd };
        if (mDatumStr != null) { params.put("datum", mDatumStr); }
        Communications.makeWebRequest(url, params, getOptions(false), method(:onReceiveExtremes));
    }

    function onReceiveExtremes(code as Number, data as Dictionary?) as Void {
        if (code == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var extrema = [];
            for (var i = 0; i < pts.size(); i++) {
                var point = pts[i] as Dictionary;
                var typeStr = point.get("t");
                if (typeStr != null && (typeStr.equals("high") || typeStr.equals("low"))) {
                    var typeCode = typeStr.equals("high") ? DataKeys.TIDE_TYPE_HIGH : DataKeys.TIDE_TYPE_LOW;
                    extrema.add([point.get("ts"), (parseFloat(point.get("h")) * 100.0).toNumber(), typeCode]);
                }
            }
            Application.Storage.setValue("tideExtrema", extrema);
            Application.Storage.setValue("tideExtremesUpdatedAt", Time.now().value());
            mDataUpdatedThisRun = true;
            processNextStep(:finalizeSync);
        } else {
            saveError(code);
            finishSync(false);
        }
    }

    function finalizeSync() as Void {
        finishSync(true);
    }

    private function getOptions(auth as Boolean) as Dictionary {
        var headers = { "X-App-Id" => Application.Storage.getValue("AppId") as String };
        if (auth && mApiKey != null) { headers.put("Authorization", mApiKey); }
        return { :method => Communications.HTTP_REQUEST_METHOD_GET, :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, :headers => headers };
    }

    private function isFresh(key as String, sec as Number) as Boolean {
        var val = Application.Storage.getValue(key);
        return (val != null && (Time.now().value() - (val as Number)) < sec);
    }

    private function parseFloat(val as Object) as Float {
        return (val instanceof Number) ? (val as Number).toFloat() : val as Float;
    }

    private function parseNumber(val as Object) as Number {
        return (val instanceof Float) ? (val as Float).toNumber() : val as Number;
    }

    private function saveError(code as Number) as Void {
        Application.Storage.setValue("syncError", code);
        Application.Storage.setValue("errorAt", Time.now().value());
    }
}

(:background)
class TideWatchBackground extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }
    function onTemporalEvent() as Void {
        (new SyncEngine(true)).run();
    }
}

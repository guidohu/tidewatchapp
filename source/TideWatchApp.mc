import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

(:background)
class TideWatchApp extends Application.AppBase {

    var activityTracker as ActivityTracker?;
    var isSyncing as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        if (activityTracker != null) {
            activityTracker.deinitialize();
        }
    }

    function triggerForegroundSync() as Void {
        if (isSyncing) {
            System.println("Sync already in progress, skipping.");
            return;
        }

        // Only sync if data is missing or older than 5 minutes
        var lastUpdate = Application.Storage.getValue("dataUpdatedAt");
        if (lastUpdate != null && lastUpdate instanceof Number && (Time.now().value() - (lastUpdate as Number)) < 300) {
            System.println("Data is fresh, skipping foreground sync.");
            return;
        }

        System.println("Starting foreground sync...");
        isSyncing = true;
        var engine = new SyncEngine(false);
        engine.run();
    }

    function onSettingsChanged() {
        TideWatchSettingsMenu.triggerImmediateSync(true);
        WatchUi.requestUpdate();
    }

    function getInitialView() {
        // Store AppId for background service since Rez isn't accessible there
        Application.Storage.setValue("AppId", WatchUi.loadResource(Rez.Strings.AppId));

        // Trigger foreground sync on startup
        triggerForegroundSync();

        if (System has :ServiceDelegate) {
            scheduleNextBackgroundEvent(null);
        }
        activityTracker = new ActivityTracker();
        var view = new TideWatchView();
        return [ view, new TideWatchDelegate(view) ] as [WatchUi.Views, WatchUi.InputDelegates];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("onBackgroundData called with data: " + (data == null ? "null" : data.toString()));
        logMemoryUsage();
        
        isSyncing = false;
        WatchUi.requestUpdate();
        
        // Configure periodic intervals
        if (System has :ServiceDelegate) {
            var interval = Constants.SYNC_INTERVAL_RETRY_SEC;
            // If background process exited with true, it was a successful sync
            if (data instanceof Boolean && data == true) {
                interval = Constants.SYNC_INTERVAL_SUCCESS_SEC;
                System.println("Sync successful, scheduling next in 30m");
            } else {
                System.println("Sync failed or no data, retrying in 5m");
            }
            
            var earliest = Time.now().add(new Time.Duration(interval));
            scheduleNextBackgroundEvent(earliest);
        }
    }

    function getServiceDelegate() {
        return [ new TideWatchBackground() ] as [System.ServiceDelegate];
    }

    function getSettingsView() {
        return [ new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate() ] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

function getApp() as TideWatchApp {
    return Application.getApp() as TideWatchApp;
}

function scheduleNextBackgroundEvent(earliestTime as Time.Moment?) as Void {
    if (Toybox has :Background) {
        try { 
            var lastTime = Background.getLastTemporalEventTime();
            var nextTime = Time.now();

            if (earliestTime != null && earliestTime.value() > nextTime.value()) {
                nextTime = earliestTime;
            }

            // Garmin only allows events that are at least 5 minutes after the last event
            if (lastTime != null) {
                var lastPlus5 = lastTime.add(new Time.Duration(5 * 60));
                if (lastPlus5.value() > nextTime.value()) {
                    nextTime = lastPlus5;
                }
            } else {
                // First event, ensure it's slightly in the future to avoid out of bounds
                nextTime = nextTime.add(new Time.Duration(5 * 60)); 
            }
            
            var info = Gregorian.info(nextTime, Time.FORMAT_SHORT);
            System.println(Lang.format("Scheduling background event for: $1$-$2$-$3$ $4$:$5$:$6$", [
                info.year,
                info.month.format("%02d"),
                info.day.format("%02d"),
                info.hour.format("%02d"),
                info.min.format("%02d"),
                info.sec.format("%02d")
            ]));

            Background.registerForTemporalEvent(nextTime);
        } catch (e) {
            System.println("Background registration failed: " + e.getErrorMessage()); 
        }
    } else {
        System.println("Background not available"); 
    }
}

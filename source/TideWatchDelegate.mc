import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class TideWatchDelegate extends WatchUi.InputDelegate {

    private var _view as TideWatchView;

    function initialize(view as TideWatchView) {
        InputDelegate.initialize();
        _view = view;
    }

    function checkWake() as Boolean {
        if (!_view.mDisplayOn) {
            _view.resetDisplayTimer();
            WatchUi.requestUpdate();
            return true;
        }
        _view.resetDisplayTimer();
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (checkWake()) { return true; }
        
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            return handleActionStartStop();
        } else if (key == WatchUi.KEY_ESC) {
            return handleActionBack();
        } else if (key == WatchUi.KEY_MENU) {
            return handleActionMenu();
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (checkWake()) { return true; }
        
        var app = getApp();
        if (app.activityTracker != null && app.activityTracker.isRecording()) {
            System.println("TideWatchDelegate: Ignoring onTap because activity is recording.");
            return true; // Consume the event, ignoring it
        }
        
        return handleActionStartStop();
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (checkWake()) { return true; }
        
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) {
            var app = getApp();
            if (app.activityTracker != null && app.activityTracker.isActivityActive()) {
                var view = new StatsView();
                WatchUi.pushView(view, new StatsDelegate(view), WatchUi.SLIDE_DOWN);
                return true;
            }
        } else if (dir == WatchUi.SWIPE_LEFT) {
            return handleActionMenu();
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            return handleActionBack();
        }
        return false;
    }

    function handleActionStartStop() as Boolean {
        var app = getApp();
        if (app.activityTracker != null) {
            if (app.activityTracker.isRecording()) {
                app.activityTracker.pauseRecording();
                WatchUi.pushView(new SaveActivityView(), new SaveActivityDelegate(), WatchUi.SLIDE_UP);
            } else {
                var view = new StartActivityView();
                WatchUi.pushView(view, new StartActivityDelegate(view), WatchUi.SLIDE_UP);
            }
            return true;
        }
        return false;
    }

    function handleActionMenu() as Boolean {
        WatchUi.pushView(new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function handleActionBack() as Boolean {
        var app = getApp();
        if (app.activityTracker != null) {
            if (app.activityTracker.isRecording()) {
                app.activityTracker.pauseRecording();
                WatchUi.pushView(new DiscardActivityView(), new DiscardActivityDelegate(), WatchUi.SLIDE_UP);
                return true;
            }
        }
        return false; // Let the OS close the app
    }
}

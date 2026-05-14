import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class TideWatchDelegate extends WatchUi.BehaviorDelegate {

    private var _view as TideWatchView;

    function initialize(view as TideWatchView) {
        BehaviorDelegate.initialize();
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
            return onSelect();
        } else if (key == WatchUi.KEY_ESC) {
            return onBack();
        }
        return false;
    }

    function onMenu() as Boolean {
        if (checkWake()) { return true; }
        WatchUi.pushView(new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (checkWake()) { return true; }
        if (swipeEvent.getDirection() == WatchUi.SWIPE_DOWN) {
            var view = new StatsView();
            WatchUi.pushView(view, new StatsDelegate(view), WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }

    function onSelect() as Boolean {
        if (checkWake()) { return true; }
        var app = getApp();
        if (app.activityTracker != null) {
            if (app.activityTracker.isRecording()) {
                app.activityTracker.pauseRecording();
                WatchUi.pushView(new SaveActivityView(), new SaveActivityDelegate(), WatchUi.SLIDE_UP);
            } else {
                WatchUi.pushView(new StartActivityView(), new StartActivityDelegate(), WatchUi.SLIDE_UP);
            }
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        if (checkWake()) { return true; }
        var app = getApp();
        if (app.activityTracker != null) {
            if (app.activityTracker.isRecording()) {
                app.activityTracker.pauseRecording();
                WatchUi.pushView(new DiscardActivityView(), new DiscardActivityDelegate(), WatchUi.SLIDE_UP);
                return true;
            }
        }
        return false; // Close app
    }
}

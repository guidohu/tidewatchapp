import Toybox.WatchUi;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Timer;

class StartActivityView extends WatchUi.View {
    private var _gpsAccuracy as Number = Position.QUALITY_NOT_AVAILABLE;
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
    }

    function onPosition(info as Position.Info) as Void {
        _gpsAccuracy = info.accuracy;
        WatchUi.requestUpdate();
    }

    function onShow() as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        if (_timer != null) {
            _timer.start(method(:onTimerTick), 1000, true);
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
        var app = getApp();
        if (app.activityTracker != null && !app.activityTracker.isRecording()) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        }
    }

    function onTimerTick() as Void {
        var info = Position.getInfo();
        if (info != null && info.accuracy != null) {
            _gpsAccuracy = info.accuracy;
        }
        WatchUi.requestUpdate();
    }

    function getGpsAccuracy() as Number {
        return _gpsAccuracy;
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Top Half (Confirm - Positive)
        var isGpsReady = _gpsAccuracy >= Position.QUALITY_USABLE;
        var confirmColor = isGpsReady ? Graphics.COLOR_DK_GREEN : Graphics.COLOR_DK_GRAY;
        
        dc.setColor(confirmColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var confirmText = WatchUi.loadResource(isGpsReady ? Rez.Strings.DialogConfirm : Rez.Strings.DialogWaitGps) as String;
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, confirmText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Cancel - Negative)
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.DialogCancel) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question & GPS Status
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = WatchUi.loadResource(Rez.Strings.DialogStartSurfing) as String;
        var isGpsOk = _gpsAccuracy >= Position.QUALITY_USABLE;
        var gpsText = WatchUi.loadResource(isGpsOk ? Rez.Strings.DialogGpsOk : Rez.Strings.DialogNoGps) as String;
        var gpsColor = isGpsOk ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        var dims = dc.getTextDimensions(text, Graphics.FONT_SMALL);
        var gpsDims = dc.getTextDimensions(gpsText, Graphics.FONT_XTINY);
        
        var spacing = 2;
        var totalH = dims[1] + gpsDims[1] + spacing;
        
        dc.fillRectangle(0, (height - totalH) / 2 - 5, width, totalH + 10);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2 - (gpsDims[1] + spacing) / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        dc.setColor(gpsColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2 + (dims[1] + spacing) / 2, Graphics.FONT_XTINY, gpsText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class StartActivityDelegate extends WatchUi.BehaviorDelegate {
    private var _view as StartActivityView;

    function initialize(view as StartActivityView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var y = coords[1];
        var screenHeight = System.getDeviceSettings().screenHeight;
        
        if (y < screenHeight / 2) {
            confirm();
        } else {
            cancel();
        }
        return true;
    }
    
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            confirm();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            cancel();
            return true;
        }
        return false;
    }
    
    function onBack() as Boolean {
        cancel();
        return true;
    }

    private function confirm() as Void {
        var accuracy = _view.getGpsAccuracy();
        // Double check with getInfo() in case the view's cache is slightly behind
        var info = Position.getInfo();
        if (info != null && info.accuracy != null && info.accuracy > accuracy) {
            accuracy = info.accuracy;
        }

        if (accuracy < Position.QUALITY_USABLE) {
            System.println("GPS not ready (Accuracy: " + accuracy + "), ignoring confirm.");
            return;
        }

        var app = getApp();
        if (app.activityTracker != null) {
            app.activityTracker.startRecording();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    private function cancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

class SaveActivityView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Top Half (Resume)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.DialogResume) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Save - Positive)
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.DialogSave) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = WatchUi.loadResource(Rez.Strings.DialogSaveActivity) as String;
        var dims = dc.getTextDimensions(text, Graphics.FONT_SMALL);
        dc.fillRectangle(0, (height - dims[1]) / 2 - 5, width, dims[1] + 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class SaveActivityDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var y = coords[1];
        var screenHeight = System.getDeviceSettings().screenHeight;
        
        if (y < screenHeight / 2) {
            resume();
        } else {
            save();
        }
        return true;
    }
    
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            resume();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            save();
            return true;
        }
        return false;
    }

    private function save() as Void {
        var app = getApp();
        if (app.activityTracker != null) {
            app.activityTracker.saveSession();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    private function resume() as Void {
        var app = getApp();
        if (app.activityTracker != null) {
            app.activityTracker.startRecording();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

class DiscardActivityView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Top Half (Discard - Negative)
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.DialogDiscard) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Resume - Positive)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.DialogResume) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = WatchUi.loadResource(Rez.Strings.DialogDiscardActivity) as String;
        var dims = dc.getTextDimensions(text, Graphics.FONT_SMALL);
        dc.fillRectangle(0, (height - dims[1]) / 2 - 5, width, dims[1] + 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class DiscardActivityDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var y = coords[1];
        var screenHeight = System.getDeviceSettings().screenHeight;
        
        if (y < screenHeight / 2) {
            discard();
        } else {
            resume();
        }
        return true;
    }
    
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            discard();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            resume();
            return true;
        }
        return false;
    }

    private function discard() as Void {
        var app = getApp();
        if (app.activityTracker != null) {
            app.activityTracker.discardSession();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    private function resume() as Void {
        var app = getApp();
        if (app.activityTracker != null) {
            app.activityTracker.startRecording();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

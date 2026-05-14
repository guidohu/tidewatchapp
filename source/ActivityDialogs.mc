import Toybox.WatchUi;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Lang;

class StartActivityView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Top Half (Confirm - Positive)
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, "Confirm", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Cancel - Negative)
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, "Cancel", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = "Start Surfing?";
        var dims = dc.getTextDimensions(text, Graphics.FONT_SMALL);
        dc.fillRectangle(0, (height - dims[1]) / 2 - 5, width, dims[1] + 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class StartActivityDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
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
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, "Resume", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Save - Positive)
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, "Save", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = "Save Activity?";
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
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, "Discard", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom Half (Resume - Positive)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 2, width, height / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 3 / 4, Graphics.FONT_MEDIUM, "Resume", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Middle Question
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        var text = "Discard Activity?";
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

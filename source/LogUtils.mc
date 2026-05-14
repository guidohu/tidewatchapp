import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

(:background)
module Log {
    (:background)
    const LEVEL_INFO = 0;
    (:background)
    const LEVEL_DEBUG = 1;
    (:background)
    const LEVEL_ERROR = 2;
    (:background)
    const LEVEL_WARN = 3;

    (:background)
    function info(component as String, msg as String) as Void {
        log(LEVEL_INFO, component, msg);
    }

    (:background)
    function debug(component as String, msg as String) as Void {
        log(LEVEL_DEBUG, component, msg);
    }

    (:background)
    function error(component as String, msg as String) as Void {
        log(LEVEL_ERROR, component, msg);
    }

    (:background)
    function warn(component as String, msg as String) as Void {
        log(LEVEL_WARN, component, msg);
    }

    (:background)
    function log(level as Number, component as String, msg as String) as Void {
        var now = System.getClockTime();
        var levelStr = "";
        if (level == LEVEL_INFO) { levelStr = "INFO"; }
        else if (level == LEVEL_DEBUG) { levelStr = "DEBUG"; }
        else if (level == LEVEL_ERROR) { levelStr = "ERROR"; }
        else if (level == LEVEL_WARN) { levelStr = "WARN"; }

        var timeStr = Lang.format("$1$:$2$:$3$", [
            now.hour.format("%02d"),
            now.min.format("%02d"),
            now.sec.format("%02d")
        ]);

        System.println(Lang.format("[$1$] [$2$] [$3$] $4$", [timeStr, levelStr, component, msg]));
    }
}

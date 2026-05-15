import Toybox.Lang;
import Toybox.Math;

module UnitUtils {
    const METERS_TO_FEET = 3.28084f;
    const METERS_TO_MILES = 0.000621371f;

    function convertHeight(rawValue as Number, fromUnit as Number?, toUnit as Number) as Float {
        var valFloat = rawValue.toFloat() / 100.0f;
        if (fromUnit == DataKeys.UNIT_METER && toUnit == DataKeys.UNIT_FEET) {
            return valFloat * METERS_TO_FEET;
        }
        if (fromUnit == DataKeys.UNIT_FEET && toUnit == DataKeys.UNIT_METER) {
            return valFloat / METERS_TO_FEET;
        }
        return valFloat;
    }

    function formatDistance(meters as Float, unitSetting as Number) as String {
        var absMeters = (meters < 0) ? -meters : meters;
        if (absMeters < 0.005f) { absMeters = 0.0f; } // Threshold to avoid -0.00
        
        if (unitSetting == DataKeys.SETTING_DISTANCE_UNIT_KM) {
            return (absMeters / 1000.0f).format("%.2f");
        } else {
            return (absMeters * METERS_TO_MILES).format("%.2f");
        }
    }

    function getDistanceUnitString(unitSetting as Number) as String {
        return (unitSetting == DataKeys.SETTING_DISTANCE_UNIT_KM) ? "km" : "mi";
    }

    function getTideUnitString(unitSetting as Number) as String {
        return (unitSetting == DataKeys.SETTING_UNIT_FEET) ? "ft" : "m";
    }
}

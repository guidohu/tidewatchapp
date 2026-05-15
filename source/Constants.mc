import Toybox.Lang;

(:background)
module Constants {
    const SECONDS_IN_HOUR = 3600;
    const DATA_UPDATE_INTERVAL_SEC = 1800; // 30 minutes
    const SYNC_INTERVAL_SUCCESS_SEC = 10800; // 3 hours
    const SYNC_INTERVAL_RETRY_SEC = 1800;    // 30 minutes
    const FAST_SYNC_FRESHNESS_THRESHOLD_SEC = 1800; // 30 minutes
    const SLOW_SYNC_FRESHNESS_THRESHOLD_SEC = 21600; // 6 hours
}

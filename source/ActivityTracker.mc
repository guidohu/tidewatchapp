import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.Position;
import Toybox.Time;
import Toybox.Sensor;
import Toybox.Math;

class ActivityTracker {
    private var _session as ActivityRecording.Session?;
    private var _waveField as FitContributor.Field?;
    private var _strokeField as FitContributor.Field?;
    private var _waveSessionField as FitContributor.Field?;
    private var _strokeSessionField as FitContributor.Field?;
    private var _maxWaveSpeedField as FitContributor.Field?;
    private var _maxWaveLengthField as FitContributor.Field?;
    private var _totalWaveTimeField as FitContributor.Field?;
    private var _avgWaveSpeedField as FitContributor.Field?;
    private var _avgWaveLengthField as FitContributor.Field?;
    private var _totalWaveDistanceField as FitContributor.Field?;
    
    private var _isRecording as Boolean = false;
    private var _timerRunning as Boolean = false;
    
    private var _waveCount as Number = 0;
    private var _strokeAccumulator as Float = 0.0f;
    private var _paddleStrokes as Number = 0;
    
    private var _timer as Timer.Timer;
    
    private var _highSpeedTime as Number = 0;
    private var _inWave as Boolean = false;
    private var _timeSinceLastWave as Number = 10;

    // Surfing Session Metrics
    private var _maxWaveSpeed as Float = 0.0f;     // m/s
    private var _maxWaveLength as Float = 0.0f;    // meters
    private var _totalWaveTime as Number = 0;      // seconds
    private var _totalWaveDistance as Float = 0.0f;// meters
    
    // Current Wave State
    private var _currentWaveMaxSpeed as Float = 0.0f;
    private var _currentWaveDistance as Float = 0.0f;

    // New metrics
    private var _timeStillSec as Number = 0;
    private var _pathPoints as Array<Float> = [] as Array<Float>;
    private var _heartbeatCount as Number = 0;

    
    // Heart rate state
    private var _currentHR as Number? = null;
    private var _avgHR as Number? = null;
    private var _maxHR as Number? = null;

    // Adaptive GPS
    private var _isLullMode as Boolean = false;
    private var _lullStartTime as Number = 0;
    private var _lastAccelMagnitude as Float = 0.0f;

    // Smarter Wave Detection State
    private var _lastGPSAccuracy as Number = Position.QUALITY_NOT_AVAILABLE;
    private var _gpsGoodSignalSec as Number = 0;
    private var _maxMotionEnergyRecent as Float = 0.0f;
    private var _lastStoredDistance as Float = 0.0f;
    private var _lastStoredTime as Number = 0;
    private var _lastValidGPSDistance as Float = 0.0f;
    private var _lastValidGPSTime as Number = 0;



    function deinitialize() as Void {
        if (_timerRunning) {
            _timer.stop();
            _timerRunning = false;
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        Log.info("Activity", "Resources released (GPS/Timer).");
    }

    function initialize() {
        _timer = new Timer.Timer();
    }

    function startRecording() as Void {
        if (_session == null) {
            try {
                _session = ActivityRecording.createSession({
                    :name => "Surfing",
                    :sport => Activity.SPORT_SURFING,
                    :subSport => Activity.SUB_SPORT_GENERIC
                });
                
                _waveField = _session.createField("Waves Surfed", 0, FitContributor.DATA_TYPE_UINT16, {
                    :mesgType => FitContributor.MESG_TYPE_RECORD, 
                    :units => "waves"
                });
                
                _strokeField = _session.createField("Paddle Strokes", 1, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_RECORD, 
                    :units => "strokes"
                });

                // Native mapped fields for Surfing - Using general fields as workaround for 3rd party restrictions
                _waveSessionField = _session.createField("Total Waves", 2, FitContributor.DATA_TYPE_UINT16, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "waves"
                });

                _avgWaveSpeedField = _session.createField("Avg Wave Speed", 7, FitContributor.DATA_TYPE_FLOAT, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m/s"
                });

                _maxWaveSpeedField = _session.createField("Max Wave Speed", 4, FitContributor.DATA_TYPE_FLOAT, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m/s"
                });

                _totalWaveTimeField = _session.createField("Total Wave Time", 5, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "s"
                });

                _avgWaveLengthField = _session.createField("Avg Wave Length", 8, FitContributor.DATA_TYPE_FLOAT, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m"
                });

                _maxWaveLengthField = _session.createField("Max Wave Length", 6, FitContributor.DATA_TYPE_FLOAT, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m"
                });

                _totalWaveDistanceField = _session.createField("Total Wave Distance", 9, FitContributor.DATA_TYPE_FLOAT, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m"
                });

                _strokeSessionField = _session.createField("Total Strokes", 3, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "strokes"
                });
            } catch (e) {
                System.println("Failed to create session: " + e.getErrorMessage());
                _session = null;
            }
        }

        if (!_isRecording) {
            System.println("Attempting to start session...");
            _session.start();
            System.println("Session started. Attempting to start timer...");
            _timer.start(method(:onTimerTick), 1000, true);
            
            // Explicitly enable GPS to ensure location and speed data are available
            _isLullMode = false;
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            
            _isRecording = true;
            _timerRunning = true;
            
            // Initialize GPS baseline
            var info = Activity.getActivityInfo();
            if (info != null && info.elapsedDistance != null) {
                _lastValidGPSDistance = info.elapsedDistance.toFloat();
            }
            _lastValidGPSTime = Time.now().value();
            
            System.println("Activity started.");
        }
    }

    function pauseRecording() as Void {
        if (_isRecording && _session != null) {
            System.println("Attempting to stop session...");
            _session.stop();
            System.println("Session stopped. Attempting to stop timer...");
            if (_timerRunning) {
                _timer.stop();
                _timerRunning = false;
            }
            // Disable GPS when paused to save battery
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            
            // Reset wave state on pause to avoid duration/distance leakage
            _inWave = false;
            _highSpeedTime = 0;

            _isRecording = false;
            System.println("Activity paused.");
        }
    }
    
    function isRecording() as Boolean {
        return _isRecording;
    }
    
    function saveSession() as Void {
        if (_session != null) {
            if (_isRecording) {
                _session.stop();
            }
            // Final update of session metrics
            if (_waveSessionField != null) { _waveSessionField.setData(_waveCount); }
            if (_maxWaveSpeedField != null) { _maxWaveSpeedField.setData(_maxWaveSpeed); }
            if (_totalWaveTimeField != null) { _totalWaveTimeField.setData(_totalWaveTime.toNumber()); }
            if (_maxWaveLengthField != null) { _maxWaveLengthField.setData(_maxWaveLength); }
            if (_totalWaveDistanceField != null) { _totalWaveDistanceField.setData(_totalWaveDistance); }
            if (_avgWaveSpeedField != null && _totalWaveTime > 0) { _avgWaveSpeedField.setData(_totalWaveDistance / _totalWaveTime); }
            if (_avgWaveLengthField != null && _waveCount > 0) { _avgWaveLengthField.setData(_totalWaveDistance / _waveCount); }
            if (_strokeSessionField != null) { _strokeSessionField.setData(_paddleStrokes); }

            _session.save();
            System.println("Activity saved.");
            _session = null;
            _waveField = null;
            _strokeField = null;
            _waveSessionField = null;
            _strokeSessionField = null;
            _maxWaveSpeedField = null;
            _maxWaveLengthField = null;
            _totalWaveTimeField = null;
            _avgWaveSpeedField = null;
            _avgWaveLengthField = null;
            _totalWaveDistanceField = null;

            _isRecording = false;
            if (_timerRunning) {
                _timer.stop();
                _timerRunning = false;
            }
            // Ensure GPS is disabled
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            _waveCount = 0;
            _paddleStrokes = 0;
            _strokeAccumulator = 0.0f;
            _timeStillSec = 0;
            _pathPoints = [] as Array<Float>;

            _timeSinceLastWave = 10;
            _currentHR = null;
            _avgHR = null;
            _maxHR = null;

            _maxWaveSpeed = 0.0f;
            _maxWaveLength = 0.0f;
            _totalWaveTime = 0;
            _totalWaveDistance = 0.0f;
            _currentWaveMaxSpeed = 0.0f;
            _currentWaveDistance = 0.0f;
            _lastStoredDistance = 0.0f;
            _lastStoredTime = 0;
            _lastValidGPSDistance = 0.0f;
            _lastValidGPSTime = 0;


            _inWave = false;
            _highSpeedTime = 0;
        }
    }
    
    function discardSession() as Void {
        if (_session != null) {
            if (_isRecording) {
                _session.stop();
            }
            _session.discard();
            System.println("Activity discarded.");
            _session = null;
            _waveField = null;
            _strokeField = null;
            _waveSessionField = null;
            _strokeSessionField = null;
            _maxWaveSpeedField = null;
            _maxWaveLengthField = null;
            _totalWaveTimeField = null;
            _avgWaveSpeedField = null;
            _avgWaveLengthField = null;
            _totalWaveDistanceField = null;

            _isRecording = false;
            if (_timerRunning) {
                _timer.stop();
                _timerRunning = false;
            }
            // Ensure GPS is disabled
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            _waveCount = 0;
            _paddleStrokes = 0;
            _strokeAccumulator = 0.0f;
            _timeStillSec = 0;
            _pathPoints = [] as Array<Float>;

            _timeSinceLastWave = 10;
            _currentHR = null;
            _avgHR = null;
            _maxHR = null;

            _maxWaveSpeed = 0.0f;
            _maxWaveLength = 0.0f;
            _totalWaveTime = 0;
            _totalWaveDistance = 0.0f;
            _currentWaveMaxSpeed = 0.0f;
            _currentWaveDistance = 0.0f;
            _lastStoredDistance = 0.0f;
            _lastStoredTime = 0;
            _lastValidGPSDistance = 0.0f;
            _lastValidGPSTime = 0;


            _inWave = false;
            _highSpeedTime = 0;
        }
    }
    
    function getDistance() as Float {
        var info = Activity.getActivityInfo();
        if (info != null && info.elapsedDistance != null) {
            return info.elapsedDistance.toFloat();
        }
        return 0.0f;
    }
    
    function getWaveCount() as Number { return _waveCount; }
    function getPaddleStrokes() as Number { return _paddleStrokes; }
    function getTimeStillSec() as Number { return _timeStillSec; }
    function getPathPoints() as Array<Float> { return _pathPoints; }
    function getCurrentHR() as Number? { return _currentHR; }
    function getAverageHR() as Number? { return _avgHR; }
    function getMaxHR() as Number? { return _maxHR; }
    function getMaxWaveSpeed() as Float { return _maxWaveSpeed; }
    function getMaxWaveLength() as Float { return _maxWaveLength; }
    function getTotalWaveTime() as Number { return _totalWaveTime; }
    function getTotalWaveDistance() as Float { return _totalWaveDistance; }
    function getAvgWaveLength() as Float {
        if (_waveCount > 0) {
            return _totalWaveDistance / _waveCount;
        }
        return 0.0f;
    }

    function onTimerTick() as Void {
        if (!_isRecording) { return; }
        
        var info = Activity.getActivityInfo();
        if (info == null) { return; }

        _heartbeatCount++;
        if (_heartbeatCount >= 60) {
            _heartbeatCount = 0;
            var stats = System.getSystemStats();
            Log.info("Activity", Lang.format("Heartbeat - Mem: $1$/$2$, GPS: $3$, Lull: $4$", [stats.usedMemory, stats.totalMemory, info.currentLocationAccuracy, _isLullMode]));
        }
        
        // --- Motion Energy Calculation ---
        var motionEnergy = 0.0f;
        var mag = null;
        var sensorInfo = Sensor.getInfo();
        if (sensorInfo != null && sensorInfo.accel != null) {
            var accel = sensorInfo.accel as Array<Number>;
            mag = Math.sqrt(accel[0]*accel[0] + accel[1]*accel[1] + accel[2]*accel[2]).toFloat();
            // Detect if units are milli-G (~1000 per G) or m/s^2 (~9.8 per G)
            var gravityConstant = mag > 100 ? 1000.0f : 9.81f;
            motionEnergy = (mag - gravityConstant).abs();
            
            if (motionEnergy > _maxMotionEnergyRecent) {
                _maxMotionEnergyRecent = motionEnergy;
            }
        }

        // --- Wave & Speed Detection ---
        // >10km/h is approx 2.77 m/s
        var speedThreshold = 2.77f;
        var currentSpeed = info.currentSpeed != null ? info.currentSpeed : 0.0f;
        var elapsedDistance = info.elapsedDistance != null ? info.elapsedDistance : 0.0f;
        
        // GPS Reliability: Accuracy must be usable and signal stable for 5 seconds
        var currentAccuracy = info.currentLocationAccuracy != null ? info.currentLocationAccuracy : Position.QUALITY_NOT_AVAILABLE;
        var isGPSSignalingStable = (currentAccuracy >= Position.QUALITY_USABLE) && (_gpsGoodSignalSec >= 5);
        
        // --- GPS Jump Protection & Metric Updates ---
        var now = Time.now().value();
        var deltaDist = (elapsedDistance - _lastValidGPSDistance).abs();
        var deltaTime = now - _lastValidGPSTime;
        var isSaneUpdate = false;

        if (isGPSSignalingStable) {
            if (deltaTime > 0) {
                var avgSpeed = deltaDist / deltaTime;
                // Sanity check: speed must be < 25m/s (90km/h) for both instant and average
                if (avgSpeed < 25.0f && currentSpeed < 25.0f) {
                    isSaneUpdate = true;
                    if (_inWave) {
                        _currentWaveDistance += deltaDist;
                        if (currentSpeed > _currentWaveMaxSpeed) {
                            _currentWaveMaxSpeed = currentSpeed;
                        }
                        if (currentSpeed > _maxWaveSpeed) {
                            _maxWaveSpeed = currentSpeed;
                        }
                    }
                } else {
                    Log.info("Activity", Lang.format("GPS Jump suppressed: avg $1$m/s, inst $2$m/s", [avgSpeed.format("%.1f"), currentSpeed.format("%.1f")]));
                }
            }
            _lastValidGPSDistance = elapsedDistance;
            _lastValidGPSTime = now;
        }

        // Time still: < 0.5km/h (approx 0.138 m/s)
        var stillThreshold = 0.138f;
        if (currentSpeed < stillThreshold) {
            _timeStillSec++;
        }
        
        if (currentSpeed > speedThreshold && isGPSSignalingStable && isSaneUpdate) {
            _highSpeedTime++;
            
            // Motion verification: A wave takeoff should have at least 250mG or 2.5m/s^2 of "energy"
            var motionThreshold = (mag != null && mag > 100) ? 250.0f : 2.5f;
            var motionVerified = (_maxMotionEnergyRecent > motionThreshold);

            // Start wave: >10km/h for at least 3 seconds AND 10s cooldown AND motion confirmed
            if (!_inWave && _highSpeedTime >= 3 && _timeSinceLastWave >= 10 && motionVerified) {
                _inWave = true;
                _waveCount++;
                
                // Reset current wave metrics
                _currentWaveMaxSpeed = currentSpeed;
                _currentWaveDistance = 0.0f; // Reset to 0, will accumulate from next stable sample

                if (_waveField != null) {
                    _waveField.setData(_waveCount);
                }
                if (_waveSessionField != null) {
                    _waveSessionField.setData(_waveCount);
                }
                Log.info("Activity", "Wave started! Count: " + _waveCount + " (Motion Energy: " + _maxMotionEnergyRecent.format("%.1f") + ")");
            }
        } else {
            // End wave: speed drops below threshold
            if (_inWave) {
                _inWave = false;
                _timeSinceLastWave = 0; // Start cooldown
                
                // Validation: Only count if wave covered at least 10 meters
                if (_currentWaveDistance < 10.0f) {
                    Log.info("Activity", "Wave discarded: too short (" + _currentWaveDistance.format("%.1f") + "m)");
                    _waveCount--;
                    // Update fields with corrected count
                    if (_waveField != null) { _waveField.setData(_waveCount); }
                    if (_waveSessionField != null) { _waveSessionField.setData(_waveCount); }
                } else {
                    // Final update for session totals from this wave
                    _totalWaveDistance += _currentWaveDistance;
                    if (_currentWaveDistance > _maxWaveLength) {
                        _maxWaveLength = _currentWaveDistance;
                    }

                    // Push session updates
                    if (_maxWaveSpeedField != null) {
                        _maxWaveSpeedField.setData(_maxWaveSpeed);
                    }
                    if (_totalWaveTimeField != null) {
                        _totalWaveTimeField.setData(_totalWaveTime.toNumber());
                    }
                    if (_maxWaveLengthField != null) {
                        _maxWaveLengthField.setData(_maxWaveLength);
                    }
                    if (_totalWaveDistanceField != null) {
                        _totalWaveDistanceField.setData(_totalWaveDistance);
                    }
                    if (_avgWaveSpeedField != null && _totalWaveTime > 0) {
                        _avgWaveSpeedField.setData(_totalWaveDistance / _totalWaveTime);
                    }
                    if (_avgWaveLengthField != null && _waveCount > 0) {
                        _avgWaveLengthField.setData(_totalWaveDistance / _waveCount);
                    }
                    Log.info("Activity", "Wave ended. Dist: " + _currentWaveDistance.format("%.1f") + "m");
                }
            }
            _highSpeedTime = 0;
            _maxMotionEnergyRecent = 0.0f; // Reset motion peak while waiting for next potential wave
        }

        // Track metrics while in wave
        if (_inWave) {
            _totalWaveTime++; // Increment wave duration
            // Max speed and distance now handled above in the jump protection block
        }

        // Increment cooldown timer if not in a wave
        if (!_inWave) {
            _timeSinceLastWave++;
        }
        
        // --- Path Tracking (Smarter Distance-Based Sampling) ---
        if (currentAccuracy >= Position.QUALITY_USABLE && info.currentLocation != null) {
            var distMoved = (elapsedDistance - _lastStoredDistance).abs();
            var timeSinceLast = now - _lastStoredTime;

            // Store if moved > 10m OR if it's been 30s and we've moved > 2m
            if (distMoved > 10.0f || (timeSinceLast > 30 && distMoved > 2.0f)) {
                var pos = info.currentLocation.toDegrees();
                if (pos != null && pos.size() == 2) {
                    _pathPoints.add(pos[0].toFloat());
                    _pathPoints.add(pos[1].toFloat());
                    _lastStoredDistance = elapsedDistance;
                    _lastStoredTime = now;
                    
                    // Keep memory in check (soft limit of 200 points = 400 floats)
                    if (_pathPoints.size() > 400) {
                        _pathPoints = _pathPoints.slice(2, null) as Array<Float>;
                    }
                }
            }
        }

        
        // --- Heart Rate ---
        _currentHR = info.currentHeartRate;
        _avgHR = info.averageHeartRate;
        _maxHR = info.maxHeartRate;
        
        // --- Paddle Strokes ---
        var cadence = info.currentCadence != null ? info.currentCadence : 0;
        
        // Convert cadence (Strokes Per Minute) to strokes per second and multiply by 2 (for both arms)
        _strokeAccumulator += (cadence.toFloat() / 60.0f) * 2.0f;
        _paddleStrokes = _strokeAccumulator.toNumber();
        
        if (_strokeField != null) {
            _strokeField.setData(_paddleStrokes);
        }
        if (_strokeSessionField != null) {
            _strokeSessionField.setData(_paddleStrokes);
        }

        // --- Adaptive GPS Logic ---
        if (sensorInfo != null && sensorInfo.accel != null) {
            var accel = sensorInfo.accel as Array<Number>;
            mag = Math.sqrt(accel[0]*accel[0] + accel[1]*accel[1] + accel[2]*accel[2]).toFloat();
            
            // Detect burst (take-off): acceleration magnitude > 1.5G (approx 15000 in raw if unit is milli-G)
            // Monkey C raw accel units depend on device, but often it's milli-G. 
            // 1G = 1000 or 9.8 depending on API version. 
            // We'll use a relative increase check.
            if (_lastAccelMagnitude > 0 && (mag / _lastAccelMagnitude) > 1.5f && _isLullMode) {
                Log.info("Activity", "Movement burst detected! Ramping up GPS.");
                _isLullMode = false;
                Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            }
            _lastAccelMagnitude = mag;
        }

        // Enter lull mode if speed is low for 2 minutes
        if (!_isLullMode && currentSpeed < 0.5f) {
            if (_lullStartTime == 0) {
                _lullStartTime = Time.now().value();
            } else if (Time.now().value() - _lullStartTime > 120) {
                Log.info("Activity", "Entering GPS Lull Mode to save battery.");
                _isLullMode = true;
                // Use EXTENDED if available (every 5-10s), otherwise keep continuous but we've logged it
                if (Position has :LOCATION_EXTENDED) {
                    Position.enableLocationEvents(Position.LOCATION_EXTENDED, method(:onPosition));
                } else {
                    // Fallback: stay continuous but we could potentially lower frequency if API allowed
                }
            }
        } else if (currentSpeed >= 1.0f) {
            _lullStartTime = 0;
            if (_isLullMode) {
                _isLullMode = false;
                Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            }
        }
    }

    function onPosition(info as Position.Info) as Void {
        _lastGPSAccuracy = info.accuracy;
        if (_lastGPSAccuracy >= Position.QUALITY_USABLE) {
            _gpsGoodSignalSec++;
        } else {
            _gpsGoodSignalSec = 0;
        }
    }
}

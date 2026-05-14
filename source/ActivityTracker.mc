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
    private var _currentWaveStartDistance as Float = 0.0f;
    private var _currentWaveDistance as Float = 0.0f;

    // New metrics
    private var _timeStillSec as Number = 0;
    private var _pathPoints as Array<Array<Float>> = [] as Array<Array<Float>>;
    private var _lastLocationTime as Number = 0;
    
    // Heart rate state
    private var _currentHR as Number? = null;
    private var _avgHR as Number? = null;
    private var _maxHR as Number? = null;

    // Adaptive GPS
    private var _isLullMode as Boolean = false;
    private var _lullStartTime as Number = 0;
    private var _lastAccelMagnitude as Float = 0.0f;

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

                // Native mapped fields for Surfing
                _waveSessionField = _session.createField("Total Waves", 2, FitContributor.DATA_TYPE_UINT16, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "waves",
                    :nativeNum => 103
                });

                _avgWaveSpeedField = _session.createField("Avg Wave Speed", 7, FitContributor.DATA_TYPE_UINT16, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m/s",
                    :nativeNum => 104
                });

                _maxWaveSpeedField = _session.createField("Max Wave Speed", 4, FitContributor.DATA_TYPE_UINT16, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m/s",
                    :nativeNum => 105
                });

                _totalWaveTimeField = _session.createField("Total Wave Time", 5, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "s",
                    :nativeNum => 106
                });

                _avgWaveLengthField = _session.createField("Avg Wave Length", 8, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m",
                    :nativeNum => 107
                });

                _maxWaveLengthField = _session.createField("Max Wave Length", 6, FitContributor.DATA_TYPE_UINT32, {
                    :mesgType => FitContributor.MESG_TYPE_SESSION, 
                    :units => "m",
                    :nativeNum => 108
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
            _pathPoints = [] as Array<Array<Float>>;
            _lastLocationTime = 0;
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
            _currentWaveStartDistance = 0.0f;
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
            _pathPoints = [] as Array<Array<Float>>;
            _lastLocationTime = 0;
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
            _currentWaveStartDistance = 0.0f;
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
    function getPathPoints() as Array<Array<Float>> { return _pathPoints; }
    function getCurrentHR() as Number? { return _currentHR; }
    function getAverageHR() as Number? { return _avgHR; }
    function getMaxHR() as Number? { return _maxHR; }
    function getMaxWaveSpeed() as Float { return _maxWaveSpeed; }
    function getMaxWaveLength() as Float { return _maxWaveLength; }
    function getTotalWaveTime() as Number { return _totalWaveTime; }

    function onTimerTick() as Void {
        if (!_isRecording) { return; }
        
        var info = Activity.getActivityInfo();
        if (info == null) { return; }
        
        // --- Wave & Speed Detection ---
        // >10km/h is approx 2.77 m/s
        var speedThreshold = 2.77f;
        var currentSpeed = info.currentSpeed != null ? info.currentSpeed : 0.0f;
        var elapsedDistance = info.elapsedDistance != null ? info.elapsedDistance : 0.0f;
        
        // Time still: < 0.5km/h (approx 0.138 m/s)
        var stillThreshold = 0.138f;
        if (currentSpeed < stillThreshold) {
            _timeStillSec++;
        }
        
        if (currentSpeed > speedThreshold) {
            _highSpeedTime++;
            // Start wave: >10km/h for at least 2 seconds AND 10s have passed since last wave
            if (!_inWave && _highSpeedTime >= 2 && _timeSinceLastWave >= 10) {
                _inWave = true;
                _waveCount++;
                
                // Reset current wave metrics
                _currentWaveMaxSpeed = currentSpeed;
                _currentWaveStartDistance = elapsedDistance;
                _currentWaveDistance = 0.0f;

                if (_waveField != null) {
                    _waveField.setData(_waveCount);
                }
                if (_waveSessionField != null) {
                    _waveSessionField.setData(_waveCount);
                }
                Log.info("Activity", "Wave started! Count: " + _waveCount);
            }
        } else {
            // End wave: speed drops below threshold
            if (_inWave) {
                _inWave = false;
                _timeSinceLastWave = 0; // Start cooldown
                
                // Final update for session totals from this wave
                _totalWaveDistance += _currentWaveDistance;
                if (_currentWaveDistance > _maxWaveLength) {
                    _maxWaveLength = _currentWaveDistance;
                }

                // Push session updates
                if (_maxWaveSpeedField != null) {
                    _maxWaveSpeedField.setData((_maxWaveSpeed * 1000).toNumber());
                }
                if (_totalWaveTimeField != null) {
                    _totalWaveTimeField.setData((_totalWaveTime * 1000).toNumber());
                }
                if (_maxWaveLengthField != null) {
                    _maxWaveLengthField.setData((_maxWaveLength * 100).toNumber());
                }
                if (_avgWaveSpeedField != null && _totalWaveTime > 0) {
                    _avgWaveSpeedField.setData(((_totalWaveDistance / _totalWaveTime) * 1000).toNumber());
                }
                if (_avgWaveLengthField != null && _waveCount > 0) {
                    _avgWaveLengthField.setData(((_totalWaveDistance / _waveCount) * 100).toNumber());
                }

                Log.info("Activity", "Wave ended. Dist: " + _currentWaveDistance + "m");
            }
            _highSpeedTime = 0;
        }

        // Track metrics while in wave
        if (_inWave) {
            _totalWaveTime++; // Increment wave duration
            if (currentSpeed > _currentWaveMaxSpeed) {
                _currentWaveMaxSpeed = currentSpeed;
            }
            if (currentSpeed > _maxWaveSpeed) {
                _maxWaveSpeed = currentSpeed;
            }
            _currentWaveDistance = elapsedDistance - _currentWaveStartDistance;
        }

        // Increment cooldown timer if not in a wave
        if (!_inWave) {
            _timeSinceLastWave++;
        }
        
        // --- Path Tracking ---
        if (info.currentLocation != null) {
            var now = Time.now().value();
            var interval = 2; 
            var size = _pathPoints.size();
            
            if (size > 150) { interval = 8; } 
            else if (size > 100) { interval = 4; }

            if (now - _lastLocationTime >= interval) {
                var pos = info.currentLocation.toDegrees();
                if (pos != null && pos.size() == 2) {
                    _pathPoints.add([pos[0].toFloat(), pos[1].toFloat()] as Array<Float>);
                    _lastLocationTime = now;
                    
                    if (_pathPoints.size() > 200) {
                        var newPoints = [] as Array<Array<Float>>;
                        for (var i = 0; i < _pathPoints.size(); i += 2) {
                            newPoints.add(_pathPoints[i] as Array<Float>);
                        }
                        _pathPoints = newPoints;
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
        var sensorInfo = Sensor.getInfo();
        if (sensorInfo != null && sensorInfo.accel != null) {
            var accel = sensorInfo.accel as Array<Number>;
            var mag = Math.sqrt(accel[0]*accel[0] + accel[1]*accel[1] + accel[2]*accel[2]).toFloat();
            
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
        // We use Activity.getActivityInfo() in onTimerTick for consistency,
        // but this callback ensures the GPS engine stays active for the app.
    }
}

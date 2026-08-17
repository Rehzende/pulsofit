import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../services/exercise_load_history_service.dart';
import 'auth_provider.dart';

/// Represents a single set's performance data
class SetData {
  final int setNumber;
  final double? weightKg;
  final int? repsDone;

  SetData({
    required this.setNumber,
    this.weightKg,
    this.repsDone,
  });

  Map<String, dynamic> toJson() => {
    'set': setNumber,
    'weight_kg': weightKg,
    'reps_done': repsDone,
  };

  factory SetData.fromJson(Map<String, dynamic> json) => SetData(
    setNumber: (json['set'] as num).toInt(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    repsDone: (json['reps_done'] as num?)?.toInt(),
  );
}

class WorkoutSessionProvider with ChangeNotifier, WidgetsBindingObserver {
  final WorkoutService _workoutService;
  final AuthProvider _authProvider;
  final bool isTest;

  WorkoutSessionProvider(this._workoutService, this._authProvider, {this.isTest = false}) {
    // Observe app lifecycle so we can resync the timer when the user returns
    // from the background (the periodic timer is frozen by the OS meanwhile).
    if (!isTest) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (!isTest) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isSessionActive) {
      // Coming back to foreground: the Timer.periodic was frozen, so the UI
      // stopped updating. Resync elapsed time from the real start timestamp,
      // restart the ticking timer, and refresh immediately.
      if (_startTime != null) {
        _elapsedSeconds = DateTime.now()
            .difference(_startTime!)
            .inSeconds
            .clamp(0, maxWorkoutDuration);
        if (_elapsedSeconds >= maxWorkoutDuration) {
          _autoFinishWorkout();
          return;
        }
      }
      _startTimer();
      notifyListeners();
    }
  }

  static const int maxWorkoutDuration = 7200; // 2 hours in seconds

  // Session State
  Workout? _activeWorkout;
  bool _isSessionActive = false;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  double _caloriesBurned = 0.0;
  final List<Map<String, dynamic>> _heartRateData = [];
  Timer? _timer;
  String? _sessionId; // Store backend session ID

  // Exercise Progress State
  // Using a Set to track indices of completed exercises
  final Set<int> _completedExercises = {};
  // Track exercise data per set: {index: {sets: [SetData, ...], fallback_load: double}}
  // fallback_load is used for UI display when no sets are recorded
  final Map<int, Map<String, dynamic>> _exerciseData = {};

  bool _isWorkoutCompletedToday = false; // New flag
  DateTime? _lastHrUpdate;

  // Getters
  Workout? get activeWorkout => _activeWorkout;
  bool get isSessionActive => _isSessionActive;
  // Derive from wall-clock while a session is active: a Timer.periodic is
  // frozen by the OS when the app is backgrounded (screen lock / app switch),
  // so a per-tick counter undercounts the real workout duration.
  int get elapsedSeconds {
    if (_isSessionActive && _startTime != null) {
      final secs = DateTime.now().difference(_startTime!).inSeconds;
      return secs.clamp(0, maxWorkoutDuration);
    }
    return _elapsedSeconds;
  }
  double get caloriesBurned => _caloriesBurned;
  List<Map<String, dynamic>> get heartRateData => _heartRateData;
  Set<int> get completedExercises => _completedExercises;
  bool get isWorkoutCompletedToday => _isWorkoutCompletedToday; // New getter
  String? get sessionId => _sessionId;
  
  /// Returns the weight from the last recorded set, or fallback_load for UI display.
  /// Returns 0.0 if no data available.
  double getExerciseLoad(int index) {
    if (!_exerciseData.containsKey(index)) return 0.0;

    final data = _exerciseData[index]!;

    // Try to get weight from last set
    if (data['sets'] is List && (data['sets'] as List).isNotEmpty) {
      final sets = (data['sets'] as List).cast<SetData>();
      for (int i = sets.length - 1; i >= 0; i--) {
        if (sets[i].weightKg != null && sets[i].weightKg! > 0) {
          return sets[i].weightKg!;
        }
      }
    }

    // Fallback to fallback_load for backward compatibility
    return data['fallback_load'] as double? ?? 0.0;
  }

  /// Returns list of SetData for an exercise, or empty list if none recorded.
  List<SetData> getExerciseSets(int index) {
    if (!_exerciseData.containsKey(index)) return [];

    final data = _exerciseData[index]!;
    if (data['sets'] is List) {
      try {
        return (data['sets'] as List).cast<SetData>();
      } catch (e) {
        debugPrint('Error casting sets: $e');
        return [];
      }
    }
    return [];
  }

  /// Returns all loads from current session as exerciseId → kg (uses last recorded set weight)
  Map<String, double> get currentSessionLoads {
    final result = <String, double>{};
    if (_activeWorkout == null) return result;
    _exerciseData.forEach((index, data) {
      if (index < _activeWorkout!.exercises.length) {
        final exerciseId = _activeWorkout!.exercises[index].id;
        final load = getExerciseLoad(index);
        if (load > 0) result[exerciseId] = load;
      }
    });
    return result;
  }

  /// Returns all set data from current session as exerciseId → List<SetData>
  Map<String, List<SetData>> get currentSessionSets {
    final result = <String, List<SetData>>{};
    if (_activeWorkout == null) return result;
    _exerciseData.forEach((index, data) {
      if (index < _activeWorkout!.exercises.length) {
        final exerciseId = _activeWorkout!.exercises[index].id;
        final sets = getExerciseSets(index);
        if (sets.isNotEmpty) result[exerciseId] = sets;
      }
    });
    return result;
  }

  // --- Session Management ---

  void startSession(Workout workout) {
    if (_isSessionActive) return; // Already active

    _activeWorkout = workout;
    _isSessionActive = true;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _caloriesBurned = 0.0;
    _heartRateData.clear();
    _completedExercises.clear();
    _exerciseData.clear();
    _isWorkoutCompletedToday = false; // Reset on new session start
    _sessionId = null;
    _lastHrUpdate = null;
    
    if (!isTest) {
      try { WakelockPlus.enable(); } catch(_) {}
    }
    
    _startTimer();
    
    // Notify backend that session started
    _initBackendSession();
    
    _saveSessionState();
    notifyListeners();
  }

  Future<void> _initBackendSession() async {
    if (_activeWorkout != null) {
      final session = await _workoutService.startWorkout(_activeWorkout!.id);
      if (session != null) {
        _sessionId = session.id;
        _saveSessionState(); // Save session ID
      }
    }
  }

  void endSession() {
    _timer?.cancel();
    _isSessionActive = false;
    _activeWorkout = null;
    _completedExercises.clear();
    _exerciseData.clear();
    _heartRateData.clear();
    _caloriesBurned = 0.0;
    _sessionId = null;
    _lastHrUpdate = null;
    
    if (!isTest) {
      try { WakelockPlus.disable(); } catch(_) {}
    }
    
    _clearSessionState();
    notifyListeners();
  }
  
  void clearWorkoutCompletedStatus() {
    _isWorkoutCompletedToday = false;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Recompute from wall-clock so the value is correct even after the
      // timer was frozen in the background.
      _elapsedSeconds = _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : _elapsedSeconds + 1;

      // Auto-save check
      if (_elapsedSeconds >= maxWorkoutDuration) {
        _autoFinishWorkout();
      } else if (_elapsedSeconds % 10 == 0) {
        _saveSessionState();
      }
      
      notifyListeners();
    });
  }

  Future<void> _autoFinishWorkout() async {
    if (_activeWorkout == null) return;
    
    debugPrint('Auto-finishing workout due to time limit');
    
    // Cap duration
    _elapsedSeconds = maxWorkoutDuration;
    
    // Finish with 0 HR (or last known if we had access to it here easily)
    // We can calculate average from _heartRateData if available
    int avgHr = 0;
    if (_heartRateData.isNotEmpty) {
      final sum = _heartRateData.fold(0, (prev, element) => prev + (element['bpm'] as int));
      avgHr = sum ~/ _heartRateData.length;
    }

    await finishWorkout(avgHr);
    
    // Ensure session is cleared
    endSession();
  }

  // --- Heart Rate & Calories ---

  void updateHeartRate(int bpm) {
    if (!_isSessionActive) return;

    final now = DateTime.now();
    // Use real interval between BT updates (capped at 10s to avoid spikes on reconnect)
    final double intervalSeconds = _lastHrUpdate != null
        ? now.difference(_lastHrUpdate!).inMilliseconds.clamp(0, 10000) / 1000.0
        : 1.0;
    _lastHrUpdate = now;

    _heartRateData.add({'timestamp': now.toIso8601String(), 'bpm': bpm});

    // Calculate using real user data
    final double weight = _authProvider.weightKg ?? 75.0;
    final int age = _calculateAge(_authProvider.birthday) ?? 30;
    final String gender = _authProvider.gender ?? 'male';

    final double caloriesPerMinute = _calculateCaloriesPerMinute(bpm, weight, age, gender);
    if (caloriesPerMinute > 0) {
      _caloriesBurned += caloriesPerMinute / 60.0 * intervalSeconds;
    }

    notifyListeners();
  }

  int? _calculateAge(DateTime? birthday) {
    if (birthday == null) return null;
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month || (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  double _calculateCaloriesPerMinute(int bpm, double weight, int age, String gender) {
    if (gender == 'female') {
      return (-20.4022 + (0.4472 * bpm) + (0.1263 * weight) + (0.074 * age)) / 4.184;
    } else {
      return (-55.0969 + (0.6309 * bpm) + (0.1988 * weight) + (0.2017 * age)) / 4.184;
    }
  }

  // --- Progression Logic ---

  void completeExercise(int index) {
    if (!_isSessionActive || _activeWorkout == null) return;
    
    if (index >= 0 && index < _activeWorkout!.exercises.length) {
      _completedExercises.add(index);
      _saveSessionState();
      notifyListeners();
    }
  }

  void uncompleteExercise(int index) {
     if (!_isSessionActive) return;
     _completedExercises.remove(index);
     _saveSessionState();
     notifyListeners();
  }
  
  /// Records data for a single set. Called when user completes a set.
  void recordSetData(int exerciseIndex, int setNumber, double? weightKg, int? repsDone) {
    if (!_isSessionActive) return;

    if (!_exerciseData.containsKey(exerciseIndex)) {
      _exerciseData[exerciseIndex] = {'sets': []};
    }

    if (_exerciseData[exerciseIndex]!['sets'] is! List) {
      _exerciseData[exerciseIndex]!['sets'] = [];
    }

    final sets = _exerciseData[exerciseIndex]!['sets'] as List<dynamic>;

    // Find or create SetData for this set number
    final existingIndex = sets.indexWhere((s) => (s as SetData).setNumber == setNumber);
    if (existingIndex >= 0) {
      sets[existingIndex] = SetData(setNumber: setNumber, weightKg: weightKg, repsDone: repsDone);
    } else {
      sets.add(SetData(setNumber: setNumber, weightKg: weightKg, repsDone: repsDone));
    }

    _saveSessionState();
    notifyListeners();
  }

  /// Updates exercise load (fallback for old API or UI elements that don't use per-set data).
  void updateExerciseLoad(int index, double load) {
    if (!_isSessionActive) return;

    if (!_exerciseData.containsKey(index)) {
      _exerciseData[index] = {'sets': []};
    }
    _exerciseData[index]!['fallback_load'] = load;
    _saveSessionState();
    notifyListeners();
  }

  // --- API Integration ---
  
  Future<Map<String, dynamic>?> finishWorkout(int? avgHrOverride) async {
    if (_activeWorkout == null) return null;

    // Ensure the duration reflects real elapsed time (the periodic timer may
    // have been frozen while the app was backgrounded right up to finish).
    if (_startTime != null) {
      _elapsedSeconds = DateTime.now()
          .difference(_startTime!)
          .inSeconds
          .clamp(0, maxWorkoutDuration);
    }

    int avgHr = avgHrOverride ?? 0;
    
    // Calculate average from data if override is 0 or null
    if ((avgHr == 0) && _heartRateData.isNotEmpty) {
      final sum = _heartRateData.fold(0, (prev, element) => prev + (element['bpm'] as int));
      avgHr = sum ~/ _heartRateData.length;
    }
    
    // Prepare exercise data for API
    final List<Map<String, dynamic>> exercisesDataList = [];
    _exerciseData.forEach((index, data) {
      if (_activeWorkout!.exercises.length > index) {
        final exercise = _activeWorkout!.exercises[index];
        final sets = data['sets'] is List ? (data['sets'] as List).cast<SetData>() : <SetData>[];

        if (sets.isNotEmpty) {
          // Send per-set data
          exercisesDataList.add({
            'exercise_id': exercise.id,
            'sets': sets.map((s) => s.toJson()).toList(),
          });
        } else {
          // Fallback to old format if no set data (backward compatibility)
          final fallbackLoad = data['fallback_load'] as double? ?? 0.0;
          if (fallbackLoad > 0) {
            exercisesDataList.add({
              'exercise_id': exercise.id,
              'load': fallbackLoad,
            });
          }
        }
      }
    });

    // Calculate final calories with real user data
    double finalCalories = 0.0;
    final double weight = _authProvider.weightKg ?? 75.0;
    final int? ageNullable = _calculateAge(_authProvider.birthday);
    final int age = ageNullable ?? 30;
    final String gender = _authProvider.gender ?? 'male';

    if (_heartRateData.isNotEmpty) {
      // Recalculate from heart rate data using real user info
      for (int i = 0; i < _heartRateData.length; i++) {
        final int bpm = _heartRateData[i]['bpm'] as int;
        final double calPerMin = _calculateCaloriesPerMinute(bpm, weight, age, gender);

        // Calculate interval between this and next reading (or 1 second for last)
        double intervalSeconds = 1.0;
        if (i < _heartRateData.length - 1) {
          final current = DateTime.parse(_heartRateData[i]['timestamp'] as String);
          final next = DateTime.parse(_heartRateData[i + 1]['timestamp'] as String);
          intervalSeconds = next.difference(current).inMilliseconds / 1000.0;
          intervalSeconds = intervalSeconds.clamp(0, 10); // Cap to avoid spikes
        }

        if (calPerMin > 0) {
          finalCalories += calPerMin / 60.0 * intervalSeconds;
        }
      }
    } else {
      // Fallback: use duration * 5 kcal/min if no heart rate data
      finalCalories = (_elapsedSeconds / 60.0) * 5.0;
    }

    final response = await _workoutService.finishWorkout(
      _activeWorkout!.id,
      _elapsedSeconds,
      avgHr,
      caloriesBurned: finalCalories,
      heartRateData: _heartRateData,
      exercisesData: exercisesDataList,
      sessionId: _sessionId,
    );

    if (response != null) {
      _isWorkoutCompletedToday = true;
      // 💾 Persist load history for Progressive Overload feature
      final loads = currentSessionLoads;
      final sets = currentSessionSets;

      if (loads.isNotEmpty) {
        await ExerciseLoadHistoryService.saveLoads(loads);
        debugPrint('[LoadHistory] Saved ${loads.length} exercise loads');
      }

      if (sets.isNotEmpty) {
        await ExerciseLoadHistoryService.saveSessionSets(sets);
        debugPrint('[LoadHistory] Saved ${sets.length} exercises with per-set data');
      }

      endSession();
    }
    return response;
  }

  // --- Persistence ---

  Future<void> _saveSessionState() async {
    if (!_isSessionActive || _activeWorkout == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Convert int keys to string for JSON and serialize SetData objects
    final exerciseDataJson = _exerciseData.map((key, value) {
      final Map<String, dynamic> serialized = {};
      if (value['sets'] is List) {
        serialized['sets'] = (value['sets'] as List).map((s) => (s as SetData).toJson()).toList();
      }
      if (value['fallback_load'] != null) {
        serialized['fallback_load'] = value['fallback_load'];
      }
      return MapEntry(key.toString(), serialized);
    });

    final state = {
      'workout': _activeWorkout!.toJson(),
      'elapsed_seconds': _elapsedSeconds,
      'completed_exercises': _completedExercises.toList(),
      'exercise_data': exerciseDataJson,
      'start_time': _startTime?.toIso8601String(),
      'calories_burned': _caloriesBurned,
      'heart_rate_data': _heartRateData,
      'session_id': _sessionId,
    };

    await prefs.setString('current_session', jsonEncode(state));
  }

  Future<void> _clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_session');
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('current_session');
    
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr);
        _activeWorkout = Workout.fromJson(data['workout']);
        _elapsedSeconds = data['elapsed_seconds'];
        _completedExercises.addAll(List<int>.from(data['completed_exercises']));
        
        if (data['exercise_data'] != null) {
          final Map<String, dynamic> exData = data['exercise_data'];
          exData.forEach((key, value) {
            final exIdx = int.parse(key);
            final exValue = value as Map<String, dynamic>;
            final Map<String, dynamic> deserialized = {};

            if (exValue['sets'] is List) {
              deserialized['sets'] = (exValue['sets'] as List)
                  .map((s) => SetData.fromJson(s as Map<String, dynamic>))
                  .toList();
            }
            if (exValue['fallback_load'] != null) {
              deserialized['fallback_load'] = exValue['fallback_load'];
            }

            _exerciseData[exIdx] = deserialized;
          });
        }
        
        _startTime = DateTime.tryParse(data['start_time'] ?? '');
        _caloriesBurned = (data['calories_burned'] as num?)?.toDouble() ?? 0.0;
        if (data['heart_rate_data'] != null) {
          _heartRateData.addAll(List<Map<String, dynamic>>.from(data['heart_rate_data']));
        }
        _sessionId = data['session_id'];
        _isSessionActive = true;
        
        // Check if we exceeded max duration while away
        if (_startTime != null) {
          final diff = DateTime.now().difference(_startTime!).inSeconds;
          if (diff >= maxWorkoutDuration) {
            _elapsedSeconds = maxWorkoutDuration; // Cap it
            _autoFinishWorkout();
            return;
          }
        }
        
        WakelockPlus.enable();
        _startTimer();
        notifyListeners();
      } catch (e) {
        debugPrint('Error restoring session: $e');
        await _clearSessionState();
      }
    }
  }
}
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../providers/workout_session_provider.dart';

/// Persists and retrieves the last load used per exercise.
/// Supports both single loads (legacy) and per-set loads (new).
///
/// This enables the "Progressive Overload" feature:
/// the app shows the previous session's weight while the athlete trains.
class ExerciseLoadHistoryService {
  static const String _keyLoads = 'exercise_load_history';
  static const String _keySets = 'exercise_sets_history';

  /// Save a map of exerciseId → load (legacy format, single load per exercise).
  /// Kept for backward compatibility.
  static Future<void> saveLoads(Map<String, double> loads) async {
    if (loads.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getAll();
      existing.addAll(loads); // Merge: newer values overwrite older
      await prefs.setString(_keyLoads, jsonEncode(existing));
    } catch (e) {
      debugPrint('[LoadHistory] Failed to save: $e');
    }
  }

  /// Save per-set load history (new format): exerciseId → List<SetData>
  static Future<void> saveSessionSets(Map<String, List<SetData>> sets) async {
    if (sets.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getAllSets();

      // Merge: overwrite sets for exercises that have new data
      sets.forEach((exerciseId, newSets) {
        existing[exerciseId] = newSets;
      });

      final jsonStr = jsonEncode(
        existing.map(
          (key, value) => MapEntry(
            key,
            value.map((s) => s.toJson()).toList(),
          ),
        ),
      );
      await prefs.setString(_keySets, jsonStr);
    } catch (e) {
      debugPrint('[LoadHistory] Failed to save sets: $e');
    }
  }

  /// Get the last load for a specific exerciseId.
  /// Tries per-set history first (last set weight), then falls back to legacy single load.
  /// Returns null if not found.
  static Future<double?> getLoad(String exerciseId) async {
    try {
      // Try per-set history first
      final sets = await getExerciseSets(exerciseId);
      if (sets.isNotEmpty) {
        for (int i = sets.length - 1; i >= 0; i--) {
          if (sets[i].weightKg != null && sets[i].weightKg! > 0) {
            return sets[i].weightKg;
          }
        }
      }

      // Fallback to legacy single load
      final all = await getAll();
      return all[exerciseId];
    } catch (e) {
      debugPrint('[LoadHistory] Failed to get load: $e');
      return null;
    }
  }

  /// Get all saved loads as a map of exerciseId → kg (legacy format)
  static Future<Map<String, double>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyLoads);
      if (jsonStr == null) return {};
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } catch (e) {
      debugPrint('[LoadHistory] Failed to get all: $e');
      return {};
    }
  }

  /// Get per-set history for a specific exercise
  static Future<List<SetData>> getExerciseSets(String exerciseId) async {
    try {
      final all = await getAllSets();
      return all[exerciseId] ?? [];
    } catch (e) {
      debugPrint('[LoadHistory] Failed to get exercise sets: $e');
      return [];
    }
  }

  /// Get all saved per-set loads as a map of exerciseId → List<SetData>
  static Future<Map<String, List<SetData>>> getAllSets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySets);
      if (jsonStr == null) return {};

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          (value as List).map((s) => SetData.fromJson(s as Map<String, dynamic>)).toList(),
        ),
      );
    } catch (e) {
      debugPrint('[LoadHistory] Failed to get all sets: $e');
      return {};
    }
  }

  /// Clear all stored history (both legacy and per-set)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoads);
    await prefs.remove(_keySets);
  }
}

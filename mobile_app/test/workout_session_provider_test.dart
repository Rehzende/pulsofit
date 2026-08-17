import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/providers/workout_session_provider.dart';
import 'package:mobile_app/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/services/workout_service.dart';
import 'package:mobile_app/models/workout.dart';
import 'package:mobile_app/models/workout_session.dart';

class MockWorkoutService extends Mock implements WorkoutService {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutSessionProvider provider;
  late MockWorkoutService mockService;
  late MockAuthProvider mockAuthProvider;
  late Workout testWorkout;

  setUp(() {
    mockService = MockWorkoutService();
    mockAuthProvider = MockAuthProvider();

    // Mock AuthProvider values
    when(() => mockAuthProvider.weightKg).thenReturn(75.0);
    when(() => mockAuthProvider.birthday).thenReturn(DateTime(1995, 5, 15));
    when(() => mockAuthProvider.gender).thenReturn('male');

    // SharedPreferences mock
    SharedPreferences.setMockInitialValues({});

    testWorkout = Workout(
      id: 'workout-123',
      name: 'Treino Teste',
      studentId: 'student-123',
      exercises: [
        Exercise(
          id: 'ex-1',
          exerciseId: 'ex-1',
          name: 'Agachamento',
          sets: 3,
          reps: 10,
          restSeconds: 60,
          orderIndex: 0,
        ),
      ],
    );

    // Mock service calls to avoid null pointer errors
    when(() => mockService.startWorkout(any())).thenAnswer((_) async =>
      WorkoutSession(
        id: 'session-123',
        workoutId: 'workout-123',
        userId: 'u1',
        startTime: DateTime.now(),
        status: 'active'
      )
    );

    provider = WorkoutSessionProvider(mockService, mockAuthProvider, isTest: true);
  });

  tearDown(() {
    provider.endSession();
  });

  group('WorkoutSessionProvider Integrity Tests', () {
    test('startSession initializes state correctly', () async {
      provider.startSession(testWorkout);

      expect(provider.isSessionActive, true);
      expect(provider.activeWorkout, testWorkout);
      expect(provider.elapsedSeconds, 0);
      
      // Wait for backend init
      await Future.delayed(const Duration(milliseconds: 100));
      expect(provider.sessionId, 'session-123');
    });

    test('updateHeartRate integrity and calorie estimation', () {
      provider.startSession(testWorkout);
      
      provider.updateHeartRate(140); 
      expect(provider.heartRateData.length, 1);
      expect(provider.heartRateData.first['bpm'], 140);
      expect(provider.caloriesBurned > 0, true);
    });

    test('completeExercise updates local state integrity', () {
      provider.startSession(testWorkout);
      
      provider.completeExercise(0);
      expect(provider.completedExercises.contains(0), true);
    });

    test('finishWorkout persistence integrity', () async {
      // 1. Setup session
      provider.startSession(testWorkout);
      await Future.delayed(const Duration(milliseconds: 50)); // Ensure sessionId set
      
      provider.updateExerciseLoad(0, 50.0);
      
      // 2. Mock finish call
      when(() => mockService.finishWorkout(
        any(), any(), any(), 
        sessionId: any(named: 'sessionId'),
        heartRateData: any(named: 'heartRateData'),
        exercisesData: any(named: 'exercisesData')
      )).thenAnswer((_) async => {'status': 'success', 'xp_earned': 100});

      final result = await provider.finishWorkout(150);

      expect(result!['status'], 'success');
      expect(provider.isSessionActive, false);
      expect(provider.isWorkoutCompletedToday, true);
    });
  });
}

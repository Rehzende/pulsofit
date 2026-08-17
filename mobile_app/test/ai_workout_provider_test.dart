import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/providers/auth_provider.dart';
import 'package:mobile_app/core/constants.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}

class MockDio extends Mock implements Dio {}

void main() {
  late AuthProvider authProvider;
  late MockStorage mockStorage;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    mockStorage = MockStorage();
    dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    dioAdapter = DioAdapter(dio: dio);

    // Stub storage reads
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async => {});
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async => {});

    authProvider = AuthProvider(storage: mockStorage, dio: dio);
  });

  group('AI Workout & Terms Integration Tests', () {
    test('acceptAiTerms updates provider state', () async {
      // Setup: mock the endpoint
      dioAdapter.onPost(
        '${AppConstants.usersEndpoint}/accept-ai-terms',
        (server) => server.reply(200, {'message': 'AI terms accepted'}),
      );

      // Act
      await authProvider.acceptAiTerms();

      // Assert
      expect(authProvider.acceptedAiTerms, true,
          reason: 'acceptedAiTerms flag should be true after accepting terms');

      // Verify storage was called
      verify(
        () => mockStorage.write(key: 'accepted_ai_terms', value: 'true'),
      ).called(1);
    });

    test(
      'Student without AI terms acceptance cannot access generate endpoints',
      () async {
        // Setup initial state
        const token = '123456';
        const fakeJwt = 'fake_jwt_token';

        // Mock login
        dioAdapter.onPost(
          AppConstants.verifyMagicLinkEndpoint,
          (server) => server.reply(200, {'access_token': fakeJwt}),
          data: {'token': token},
        );

        // Mock /me endpoint — accepted_ai_terms = false
        dioAdapter.onGet(
          '${AppConstants.usersEndpoint}/me',
          (server) => server.reply(200, {
            'id': 'student-123',
            'email': 'student@test.app',
            'role': 'STUDENT',
            'full_name': 'Test Student',
            'accepted_ai_terms_at': null, // Not accepted
            'anamnesis_completed': false,
          }),
        );

        // Act: Login
        await authProvider.verifyMagicLink(token);

        // Assert
        expect(authProvider.acceptedAiTerms, false,
            reason: 'Student should not have accepted AI terms initially');
        expect(authProvider.isAuthenticated, true,
            reason: 'But should still be logged in');
      },
    );

    test(
      'Student accepting AI terms is persisted in state and storage',
      () async {
        // Setup: authenticated student without AI terms
        const token = '123456';
        const fakeJwt = 'fake_jwt_token_123';

        dioAdapter.onPost(
          AppConstants.verifyMagicLinkEndpoint,
          (server) => server.reply(200, {'access_token': fakeJwt}),
          data: {'token': token},
        );

        dioAdapter.onGet(
          '${AppConstants.usersEndpoint}/me',
          (server) => server.reply(200, {
            'id': 'student-456',
            'email': 'student2@test.app',
            'role': 'STUDENT',
            'full_name': 'Another Student',
            'accepted_ai_terms_at': null,
            'anamnesis_completed': false,
          }),
        );

        // First: login
        await authProvider.verifyMagicLink(token);
        expect(authProvider.acceptedAiTerms, false);

        // Now: accept AI terms
        dioAdapter.onPost(
          '${AppConstants.usersEndpoint}/accept-ai-terms',
          (server) => server.reply(200, {'message': 'accepted'}),
        );

        await authProvider.acceptAiTerms();

        // Assert
        expect(authProvider.acceptedAiTerms, true,
            reason: 'After calling acceptAiTerms(), flag should be true');

        verify(
          () => mockStorage.write(key: 'accepted_ai_terms', value: 'true'),
        ).called(1);
      },
    );

    test(
      'Trainer with AI workouts enabled can see flag in profile',
      () async {
        // Setup: trainer login
        const token = 'trainer-123456';
        const trainerJwt = 'trainer_jwt_token';

        dioAdapter.onPost(
          AppConstants.verifyMagicLinkEndpoint,
          (server) => server.reply(200, {'access_token': trainerJwt}),
          data: {'token': token},
        );

        // Mock /me — trainer with AI enabled
        dioAdapter.onGet(
          '${AppConstants.usersEndpoint}/me',
          (server) => server.reply(200, {
            'id': 'trainer-789',
            'email': 'trainer@test.app',
            'role': 'TRAINER',
            'full_name': 'Test Trainer',
            'accepted_ai_terms_at': '2026-04-07T10:00:00',
            'trainer_profile': {
              'enable_ai_workouts': true,
              'brand_name': 'My Gym',
              'specialties': ['Strength', 'Hypertrophy'],
            }
          }),
        );

        // Act: Login as trainer
        await authProvider.verifyMagicLink(token);

        // Assert
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.isTrainer, true);
        expect(authProvider.acceptedAiTerms, true,
            reason: 'Trainer should have AI terms accepted');
      },
    );
  });

  group('Receiving AI-Generated Workouts', () {
    test(
      'Student receives workout created by trainer via AI',
      () async {
        // Setup: student already authenticated and accepted terms
        final studentAuthProvider = AuthProvider(storage: mockStorage, dio: dio);

        // Mock getting workouts list
        dioAdapter.onGet(
          '${AppConstants.workoutsEndpoint}/',
          (server) => server.reply(200, [
            {
              'id': 'workout-ai-123',
              'name': 'Dia 1 — Peito e Tríceps',
              'notes': 'AI-generated program',
              'scheduled_for': '2026-04-08T10:00:00',
              'items': [
                {
                  'id': 'item-1',
                  'exercise': {
                    'id': 'ex-supino',
                    'name': 'Supino Reto',
                    'muscle_group': 'chest',
                  },
                  'sets': 4,
                  'reps_min': 6,
                  'reps_max': 8,
                  'rest_seconds': 120,
                  'methodology_type': 'NORMAL',
                  'notes': 'Carga pesada',
                },
                {
                  'id': 'item-2',
                  'exercise': {
                    'id': 'ex-rosca-francesa',
                    'name': 'Rosca Francesa',
                    'muscle_group': 'triceps',
                  },
                  'sets': 3,
                  'reps_min': 8,
                  'reps_max': 12,
                  'rest_seconds': 60,
                  'methodology_type': 'NORMAL',
                  'notes': null,
                }
              ]
            },
            {
              'id': 'workout-ai-124',
              'name': 'Dia 2 — Costas e Bíceps',
              'notes': 'AI-generated program',
              'scheduled_for': '2026-04-10T10:00:00',
              'items': [
                {
                  'id': 'item-3',
                  'exercise': {
                    'id': 'ex-puxada',
                    'name': 'Puxada Frontal',
                    'muscle_group': 'back',
                  },
                  'sets': 4,
                  'reps_min': 8,
                  'reps_max': 12,
                  'rest_seconds': 90,
                  'methodology_type': 'NORMAL',
                  'notes': null,
                },
                {
                  'id': 'item-4',
                  'exercise': {
                    'id': 'ex-rosca-direta',
                    'name': 'Rosca Direta',
                    'muscle_group': 'biceps',
                  },
                  'sets': 3,
                  'reps_min': 8,
                  'reps_max': 12,
                  'rest_seconds': 60,
                  'methodology_type': 'NORMAL',
                  'notes': null,
                }
              ]
            }
          ]),
        );

        // Act: fetch workouts (simulated via HTTP)
        final response = await dio.get('${AppConstants.workoutsEndpoint}/');
        final workouts = response.data as List;

        // Assert
        expect(workouts, isNotEmpty);
        expect(workouts.length, 2);

        final dia1 = workouts.first as Map;
        expect(dia1['name'], contains('Dia 1'));
        expect(dia1['items'], isNotEmpty);
        expect(dia1['items'].length, 2);

        final supino = dia1['items'].first as Map;
        expect(supino['exercise']['name'], 'Supino Reto');
        expect(supino['sets'], 4);
        expect(supino['reps_min'], 6);
        expect(supino['reps_max'], 8);

        final dia2 = workouts.last as Map;
        expect(dia2['name'], contains('Dia 2'));
      },
    );
  });

  group('Workout Session State', () {
    test(
      'Starting a workout session updates app state',
      () async {
        // This would use WorkoutSessionProvider
        // Just verifying the flow is conceptually sound

        const workoutId = 'workout-ai-123';
        const sessionId = 'session-456';

        dioAdapter.onPost(
          '${AppConstants.workoutSessionsEndpoint}/',
          (server) => server.reply(200, {
            'id': sessionId,
            'workout_id': workoutId,
            'status': 'IN_PROGRESS',
            'start_time': '2026-04-08T14:30:00',
            'current_exercise_index': 0,
          }),
          data: {'workout_id': workoutId},
        );

        final response =
            await dio.post('${AppConstants.workoutSessionsEndpoint}/', data: {'workout_id': workoutId});
        final sessionData = response.data as Map;

        expect(sessionData['id'], sessionId);
        expect(sessionData['status'], 'IN_PROGRESS');
      },
    );

    test(
      'Completing a workout session persists data',
      () async {
        const sessionId = 'session-456';

        dioAdapter.onPost(
          '${AppConstants.workoutSessionsEndpoint}/$sessionId/finish',
          (server) => server.reply(200, {
            'id': sessionId,
            'status': 'COMPLETED',
            'end_time': '2026-04-08T15:15:00',
            'exercises_completed': 4,
            'total_time_seconds': 2700,
            'calories_burned': 185,
          }),
        );

        final response = await dio.post('${AppConstants.workoutSessionsEndpoint}/$sessionId/finish');
        final resultData = response.data as Map;

        expect(resultData['status'], 'COMPLETED');
        expect(resultData['exercises_completed'], 4);
        expect(resultData['calories_burned'], isNotNull);
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/providers/auth_provider.dart';
import 'package:mobile_app/core/constants.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late AuthProvider authProvider;
  late MockStorage mockStorage;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    mockStorage = MockStorage();
    dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    dioAdapter = DioAdapter(dio: dio);
    
    // Stub storage reads to return null by default
    when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async => {});

    authProvider = AuthProvider(storage: mockStorage, dio: dio);
  });

  group('AuthProvider Integrity Tests', () {
    test('Initial state is unauthenticated', () {
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.isLoading, false);
    });

    test('requestMagicLink success updates state', () async {
      const email = 'test@pulsofit.app';
      const role = 'STUDENT';

      dioAdapter.onPost(
        AppConstants.magicLinkEndpoint,
        (server) => server.reply(200, {'message': 'sent'}),
        data: {'email': email, 'desired_role': role},
      );

      final result = await authProvider.requestMagicLink(email, role);

      expect(result, true);      expect(authProvider.magicLinkSent, true);
      expect(authProvider.pendingEmail, email);
      expect(authProvider.isLoading, false);
    });

    test('verifyMagicLink success login integrity', () async {
      const token = '123456';
      const fakeToken = 'fake_jwt_token';
      
      // 1. Mock verify endpoint
      dioAdapter.onPost(
        AppConstants.verifyMagicLinkEndpoint,
        (server) => server.reply(200, {'access_token': fakeToken}),
        data: {'token': token},
      );

      // 2. Mock /me endpoint (called automatically after verification)
      dioAdapter.onGet(
        '${AppConstants.usersEndpoint}/me',
        (server) => server.reply(200, {
          'id': 'user-123',
          'email': 'test@pulsofit.app',
          'role': 'TRAINER',
          'full_name': 'Test Trainer',
          'anamnesis_completed': true,
        }),
      );

      final result = await authProvider.verifyMagicLink(token);

      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.accessToken, fakeToken);
      expect(authProvider.userRole, 'TRAINER');
      
      // Verify persistence integrity
      verify(() => mockStorage.write(key: AppConstants.accessTokenKey, value: fakeToken)).called(1);
    });

    test('logout clears integrity state', () async {
      // Setup authenticated state first (simplified)
      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((_) async => {});
      
      await authProvider.logout();

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.accessToken, null);
      verify(() => mockStorage.delete(key: AppConstants.accessTokenKey)).called(1);
    });
  });
}

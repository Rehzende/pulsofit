# Mobile Tests — PULSO Flutter App

## Setup

### Instalar dependências

```bash
cd mobile_app
flutter pub get
```

## Unit Tests

Testes das providers (autenticação, workouts, etc.) com mocks de HTTP e storage.

### Executar todos os unit tests

```bash
flutter test test/
```

### Executar teste específico

```bash
# AI Workout Provider tests
flutter test test/ai_workout_provider_test.dart -v

# Auth Provider tests
flutter test test/auth_provider_test.dart -v
```

### Rodar com output detalhado

```bash
flutter test test/ai_workout_provider_test.dart -v -s
```

## Integration Tests

Testes end-to-end que rodam a aplicação completa contra um emulador/device real.

### Pré-requisitos

1. **Backend API rodando** (ver `/backend/TESTS.md`)
   ```bash
   cd backend
   source venv/bin/activate
   uvicorn app.main:app --reload --port 8000
   ```

2. **Emulador/Device conectado**
   ```bash
   flutter devices
   ```

3. **Update backend URL** (se necessário em `lib/core/constants.dart`)
   ```dart
   static const String baseUrl = 'http://localhost:8000'; // ou IP local
   ```

### Executar todos os integration tests

```bash
flutter test integration_test/
```

### Executar teste específico

```bash
# AI Workout Flow (main test)
flutter test integration_test/ai_workout_flow_test.dart -v

# App startup test
flutter test integration_test/app_test.dart -v

# Hiring flow test
flutter test integration_test/hiring_flow_test.dart -v
```

### Rodar no emulador Android

```bash
flutter drive \
  --target=integration_test/ai_workout_flow_test.dart \
  --driver=test_driver/integration_test.dart
```

### Rodar no device iOS

```bash
flutter drive \
  --target=integration_test/ai_workout_flow_test.dart \
  -d <device-id>
```

## Testes Disponíveis

### Unit Tests

#### `test/ai_workout_provider_test.dart`

**Testa:**
- ✅ Aceitar termos de IA (`acceptAiTerms()`)
- ✅ State persistence no provider
- ✅ Student sem termos não pode gerar workouts
- ✅ Trainer com AI enabled pode usar feature
- ✅ Student recebe workout criado pelo trainer
- ✅ Iniciar sesssão de treino
- ✅ Concluir sessão de treino

**Estrutura:**
```
AuthProvider
  └─ acceptAiTerms()
     └─ POST /users/accept-ai-terms
        └─ Update _acceptedAiTerms flag
        └─ Persist to flutter_secure_storage
```

#### `test/auth_provider_test.dart`

**Testa:**
- ✅ Magic link flow completo
- ✅ Logout e limpeza de state
- ✅ Persistência de tokens

### Integration Tests

#### `integration_test/ai_workout_flow_test.dart`

**Fluxo simulado:**
```
1. Student Login (Magic Link)
   └─ Enter email
   └─ Enter magic code (123456)
   └─ Redirect to home

2. Accept AI Terms (Dialog)
   └─ Check checkbox
   └─ Click "Aceitar"

3. Skip Anamnesis (Optional)
   └─ Click "Pular por enquanto"

4. Navigate to Workouts
   └─ Tap Workouts icon in bottom nav
   └─ See list of AI-generated workouts
   
5. Tap Workout (e.g., "Dia 1 — Peito e Tríceps")
   └─ See exercise details
   └─ 4x Supino Reto (6-8 reps, 120s rest)
   └─ 3x Rosca Francesa (8-12 reps, 60s rest)

6. Start Workout
   └─ Click "INICIAR TREINO"
   └─ Enter Workout Runner screen

7. Complete Exercises
   └─ Current exercise displayed
   └─ Sets x Reps shown
   └─ Click "Próximo" to advance

8. Finish Workout
   └─ Click "Finalizar Treino"
   └─ See summary (time, calories, exercises)

9. Return to Home
   └─ Workout logged as completed
   └─ Streak updated if applicable
```

**Assertions:**
- Home screen visible after login
- Workout card visible in workouts list
- Exercise details match AI generation
- Workout runner screen loads
- Summary screen shows completion stats

## Troubleshooting

### `flutter test` não encontra arquivos

```bash
# Verificar que você está na pasta mobile_app
cd mobile_app
pwd  # deve ser /path/to/mobile_app

flutter test test/
```

### Integration test timeout

Se o teste ficar preso esperando um widget:

1. Aumentar timeout em `@Timeout(Duration(minutes: 5))`
2. Verificar se backend está rodando
3. Verificar logs com `-s` flag: `flutter test -s integration_test/...`

### Widget não encontrado no integration test

Use finder helpers para debugar:

```dart
testWidgets('Debug widget tree', (tester) async {
  app.main();
  await tester.pumpAndSettle();

  // Print widget tree
  final finder = find.byType(TextFormField);
  debugPrintFinder(finder);  // or
  print(find.byType(TextFormField).evaluate().length);
});
```

### Backend API não está acessível

1. Verificar que backend está rodando: `uvicorn app.main:app --reload`
2. Verificar URL em `lib/core/constants.dart`
3. Se emulador, usar IP local da máquina (não localhost):
   ```dart
   static const String baseUrl = 'http://192.168.1.100:8000';
   ```

### Falha no Magic Link (code 123456)

O código `123456` é apenas para testes locais. Verificar `backend/app/api/endpoints/auth.py`:

```python
# Test shortcut — remove em produção
if token == "123456":
    # Valid test token
```

## Adicionando Novos Testes

### Unit Test Template

```dart
void main() {
  late MockStorage mockStorage;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    mockStorage = MockStorage();
    dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    dioAdapter = DioAdapter(dio: dio);
  });

  test('descrição do teste', () async {
    // Setup
    dioAdapter.onPost(...);
    
    // Act
    final result = await functionUnderTest();
    
    // Assert
    expect(result, expectedValue);
  });
}
```

### Integration Test Template

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('descrição do teste', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Arrange
    final finder = find.byType(SomeWidget);

    // Act
    await tester.tap(finder);
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Expected text'), findsOneWidget);
  });
}
```

## CI/CD Integration

Adicionar ao seu CI pipeline:

```bash
# Unit tests
flutter test test/

# Integration tests (against staging/test server)
flutter test integration_test/ \
  --dart-define=BACKEND_URL=https://staging-api.pulsofit.app
```

## Debug Tips

### Ver logs durante teste

```bash
flutter test -v -s test/ai_workout_provider_test.dart
```

### Debugar emulador

```bash
flutter emulators --launch Pixel_5_API_31
flutter devices  # list all devices
flutter test integration_test/ -d emulator-5554
```

### Inspecionar estado do provider

```dart
// Em um test
authProvider.addListener(() {
  print('AuthProvider changed: ${authProvider.isAuthenticated}');
});
```

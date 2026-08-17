# Testes de Integração — PULSO

## Configuração

### Instalar dependências de teste

```bash
pip install -r requirements-test.txt
```

## Executar testes

### Executar teste de integração completo

Simula um personal criando um treino via IA e cadastrando para um aluno:

```bash
pytest tests/test_ai_workout_integration.py::test_trainer_creates_ai_workout_for_student -v
```

### Executar todos os testes de integração

```bash
pytest tests/test_ai_workout_integration.py -v
```

### Executar com output detalhado

```bash
pytest tests/test_ai_workout_integration.py -v -s
```

## Testes disponíveis

### `test_trainer_creates_ai_workout_for_student`

**O que testa:**
1. ✅ Criar trainer via magic link
2. ✅ Criar student via magic link
3. ✅ Vincular student ao trainer
4. ✅ Aceitar termos de IA no trainer
5. ✅ Ativar feature de IA no TrainerProfile
6. ✅ Gerar programa de IA (com mock do Gemini)
7. ✅ Salvar programa para o student
8. ✅ Verificar que os workouts foram criados no banco
9. ✅ Student consegue ver seus workouts
10. ✅ Trainer consegue ver workouts do student

**Fluxo simulado:**
```
Trainer: "Gere um programa de força"
         ↓ (POST /ai-workouts/generate)
AI Job: PENDING → PROCESSING → DONE
         ↓
Trainer: "Salve este programa para João"
         ↓ (POST /ai-workouts/save-program)
DB: Cria 2 Workouts com 4 Exercises
    - Dia 1: Peito e Tríceps (Supino + Rosca Francesa)
    - Dia 2: Costas e Bíceps (Puxada + Rosca Direta)
```

### `test_trainer_cannot_generate_without_ai_terms`

Verifica a proteção: trainer **sem** aceitar termos não consegue gerar.
- Response: `403 Forbidden` com mensagem sobre Termos de Responsabilidade

### `test_trainer_cannot_generate_without_feature_flag`

Verifica a proteção: trainer **com** termos mas **sem** `enable_ai_workouts=true` não consegue gerar.
- Response: `403 Forbidden` com mensagem sobre funcionalidade premium

## Estrutura dos testes

Os testes usam:
- **Banco em memória**: SQLite in-memory (fixtures em `conftest.py`)
- **Mock Gemini**: Resposta mockada com estrutura realista de workout
- **Cliente HTTP**: `AsyncClient` contra a aplicação FastAPI
- **Autenticação**: Magic link flow para criar users

## Adicionando novos testes

Exemplo de estrutura:

```python
@pytest.mark.asyncio
async def test_novo_cenario(client, db):
    """Descrição do teste."""
    # Arrange: setup dados
    # Act: executar ação
    # Assert: validar resultado
```

### Fixtures disponíveis

- **`client`** — AsyncClient autenticado contra a app FastAPI
- **`db`** — AsyncSession com banco em memória
- **`mocker`** — pytest-mock para fazer patches (ex: mocks de API externas)

## Troubleshooting

### `ModuleNotFoundError: No module named 'pytest'`

```bash
pip install -r requirements-test.txt
```

### Testes param ou ficam muito lentos

SQLite em memória é rápido. Se ficar lento, pode ser:
- Muitas queries na loop sem agregação
- Falta de índices no schema

Use `-v -s` para ver logs detalhados.

### Mock Gemini não está funcionando

Verifique que o patch está correto:
```python
mocker.patch("app.api.endpoints.ai_workouts.genai.GenerativeModel")
```

Deve estar **depois** de `import app.api.endpoints.ai_workouts` para funcionar.

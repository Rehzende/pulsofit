# k6 Load Tests — Pulso App

Testes de carga para o backend (FastAPI) e observação via Grafana/Jaeger.

---

## Pré-requisitos

### 1. Instalar k6

```bash
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### 2. Subir stack de observabilidade

```bash
cd /home/rehzende/Documents/personal_ai
docker-compose up -d
```

### 3. Verificar serviços

```bash
# Todos devem estar "healthy"
docker-compose ps

# URLs úteis
open http://localhost:16686   # Jaeger — traces
open http://localhost:9090    # Prometheus
open http://localhost:3001    # Grafana — dashboards
```

---

## Testes disponíveis

| Arquivo | Tipo | Duração | VUs max | Objetivo |
|---|---|---|---|---|
| `smoke.js` | Smoke | 30s | 1 | Validar que a stack está up |
| `load_api.js` | Load | ~4m30s | 30 | Tráfego realista nos endpoints principais |
| `stress_workouts.js` | Stress | ~8m | 80 | Encontrar limites do fluxo de treinos |

---

## Rodando os testes

### Smoke test (sempre rode primeiro)

```bash
k6 run k6/tests/smoke.js
```

### Load test básico (só terminal)

```bash
k6 run k6/tests/load_api.js \
  -e TEST_EMAIL=seu@email.com \
  -e TEST_PASSWORD=suasenha
```

### Load test COM output para Grafana (recomendado)

```bash
k6 run \
  --out experimental-prometheus-rw \
  -e K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
  -e K6_PROMETHEUS_RW_PUSH_INTERVAL=5s \
  -e TEST_EMAIL=seu@email.com \
  -e TEST_PASSWORD=suasenha \
  k6/tests/load_api.js
```

### Stress test (treinos)

```bash
k6 run \
  --out experimental-prometheus-rw \
  -e K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
  -e TEST_EMAIL=seu@email.com \
  -e TEST_PASSWORD=suasenha \
  k6/tests/stress_workouts.js
```

### Apontar para URL diferente

```bash
k6 run k6/tests/load_api.js \
  -e BASE_URL=http://192.168.0.5:8000 \
  -e TEST_EMAIL=usuario@email.com \
  -e TEST_PASSWORD=senha123
```

---

## Observando no Grafana

1. Abra **http://localhost:3001**
2. Vá em **Dashboards → Pulso → Pulso — App Overview**
3. O dashboard atualiza a cada 10 segundos
4. Para ver traces individuais, clique no link **Jaeger Traces** no topo do dashboard

### Painéis disponíveis:

| Painel | Métrica |
|---|---|
| Request Rate by Route | Requisições/segundo por endpoint |
| Latency Percentiles | p50 / p95 / p99 por endpoint |
| Error Rate by Route | Taxa de 4xx+5xx por endpoint |
| Request Rate by Service | backend vs frontend |
| Request Rate by Status Code | Distribuição de status |
| Total RPS (5m avg) | Taxa global de requisições |
| Global p95 Latency | Latência p95 total |
| Global Error Rate | Taxa de erro 5xx global |

---

## Métricas customizadas do k6

Disponíveis no Prometheus após rodar com output `experimental-prometheus-rw`:

| Métrica | Descrição |
|---|---|
| `pulso_login_duration` | Latência do login |
| `pulso_workout_list_duration` | Latência de GET /workouts |
| `pulso_exercise_list_duration` | Latência de GET /exercises |
| `pulso_workout_create_duration` | Latência criação de workout |
| `pulso_error_rate` | Taxa de erros nos cenários |
| `pulso_requests_total` | Total de requests enviados |

---

## Thresholds

Os testes falham se os seguintes limites forem violados:

- `http_req_duration p(95) < 500ms` — latência geral
- `http_req_duration p(99) < 1500ms` — cauda longa
- `http_req_failed < 1%` — erros HTTP
- `pulso_login_duration p(95) < 800ms` — autenticação
- `pulso_workout_list_duration p(95) < 600ms` — listagem de treinos

---

## Interpretando resultados no terminal

```
✓ GET /workouts: 200
✓ login status is 200

checks.........................: 99.80% ✓ 4990 ✗ 10
data_received..................: 2.4 MB 10 kB/s
data_sent......................: 1.1 MB  4.5 kB/s
http_req_duration..............: avg=87ms   min=12ms  med=71ms  max=892ms  p(90)=168ms p(95)=214ms
http_req_failed................: 0.20%  ✓ 10 ✗ 4990
```

- **checks**: porcentagem de assertions passando — deve ser > 99%
- **http_req_duration p(95)**: deve ser < 500ms para load normal
- **http_req_failed**: deve ser < 1%

---

## Fluxo de observabilidade

```
k6 ──remote-write──▶ Prometheus ──▶ Grafana
Backend ──OTLP──▶ OTel Collector ──▶ Jaeger (traces)
                                 ──▶ Prometheus (metrics) ──▶ Grafana
Frontend ──OTLP──▶ OTel Collector
```

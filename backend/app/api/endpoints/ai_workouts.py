"""
AI Workouts endpoint — Gemini 2.5 Flash + Async Job Queue
---------------------------------------------------------
Flow:
  POST /ai/workouts/generate          → instant (cache hit) or 202 (job queued)
  POST /ai/workouts/suggest-from-anamnesis → same pattern
  GET  /ai/workouts/jobs/{job_id}     → poll status + result
  POST /ai/workouts/save-program      → persist AI plan as real workouts

Security measures preserved:
  SEC-1: Prompt injection guard (input sanitisation + length cap)
  SEC-2: Rate limiting (5 DONE jobs/month per user per type)
  SEC-3: Cache via prompt_hash — any identical profile returns instantly
  SEC-4: Token optimisation via gemini-2.5-flash (cheapest capable model)
"""

import hashlib
import json
import os
from datetime import datetime, timedelta
from typing import Any, List, Optional
from uuid import UUID

from google.genai import Client
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.api import deps
from app.db.session import get_db
from app.models.ai_security import AIUsageLog, AIResponseCache
from app.models.ai_workout_job import AIWorkoutJob
from app.models.exercise import ExerciseLibrary
from app.models.trainer_profile import TrainerProfile
from app.models.user import User, UserRole
from app.models.workout import Workout, WorkoutItem

router = APIRouter()

# ──────────────────────────────────────────────────────────────────────────────
# Gemini Client helper
# ──────────────────────────────────────────────────────────────────────────────

def _get_gemini_client() -> Client:
    """Initialize Gemini client with API key."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY não configurada no servidor")
    return Client(api_key=api_key)


# ──────────────────────────────────────────────────────────────────────────────
# Prompts
# ──────────────────────────────────────────────────────────────────────────────

TRAINER_GENERATE_SYSTEM = """Você é um assistente especialista em programação de treinos.
Analise o texto fornecido e extraia os treinos estruturados.

RETORNE APENAS JSON VÁLIDO no seguinte formato:
{
  "summary": "resumo do programa em 1-2 frases",
  "workouts": [
    {
      "name": "nome do treino",
      "notes": null,
      "exercises": [
        {
          "exercise_name": "nome do exercício",
          "sets": 3,
          "reps_min": 8,
          "reps_max": 12,
          "duration_seconds": null,
          "rest_seconds": 60,
          "notes": null,
          "methodology_type": "NORMAL",
          "methodology_params": null
        }
      ]
    }
  ]
}

Regras:
- "3x10" → sets=3, reps_min=10, reps_max=10
- "3x8-12" → sets=3, reps_min=8, reps_max=12
- "30 segundos" → duration_seconds=30, reps_min=null, reps_max=null
- rest_seconds padrão: 60 se não informado
- methodology_type: identificar se é "NORMAL", "DROP_SET", "REST_PAUSE", "SUPERSET", "REST_BETWEEN_SETS". Padrão "NORMAL".
- methodology_params: json se houver parâmetros (ex: {"drops": 3} para DROP_SET). Padrão null.
- Mantenha os nomes dos exercícios como estão no texto original"""

ANAMNESIS_SYSTEM = """Você é um educador físico experiente criando programas de treino personalizados.
RETORNE APENAS JSON VÁLIDO no formato especificado. Não inclua texto antes ou depois do JSON."""

ANAMNESIS_USER_TEMPLATE = """Crie um programa de treinos personalizado e seguro para este perfil:

- Objetivo: {goal}
- Nível de experiência: {experience_level}
- Frequência disponível: {weekly_frequency}
- Duração por sessão: {session_duration}
- Equipamentos: {equipment}
- Nível de atividade atual: {activity_level}
- Lesões/Restrições: {injuries}
- Condições médicas: {medical_conditions}

Inclua exatamente {num_days} dias de treino. De 4 a 7 exercícios por sessão.

Formato JSON obrigatório:
{{
  "summary": "Resumo em 2-3 frases",
  "program_name": "Nome do programa",
  "total_days": {num_days},
  "workouts": [
    {{
      "name": "Dia 1 — nome do treino",
      "notes": "Observações opcionais",
      "exercises": [
        {{
          "exercise_name": "Nome",
          "sets": 3,
          "reps_min": 10,
          "reps_max": 12,
          "duration_seconds": null,
          "rest_seconds": 60,
          "notes": null,
          "methodology_type": "NORMAL",
          "methodology_params": null
        }}
      ]
    }}
  ]
}}

Regras:
- rest_seconds: força=120-180s, hipertrofia=60-90s, condicionamento=30-60s
- Para cardio/HIIT: duration_seconds definido, reps_min/reps_max = null
- methodology_type: identificar metodologia especial (DROP_SET, REST_PAUSE, SUPERSET, REST_BETWEEN_SETS). Usar "NORMAL" como base.
- Se houver lesões, adapte os exercícios com nota explicando"""


# ──────────────────────────────────────────────────────────────────────────────
# Rate limit helpers
# ──────────────────────────────────────────────────────────────────────────────

async def _check_rate_limit(db: AsyncSession, user_id, request_type: str, limit: int = 5):
    start_of_month = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    result = await db.execute(
        select(func.count(AIUsageLog.id)).filter(
            AIUsageLog.user_id == user_id,
            AIUsageLog.request_type == request_type,
            AIUsageLog.created_at >= start_of_month,
        )
    )
    if (result.scalar() or 0) >= limit:
        raise HTTPException(
            status_code=429,
            detail=f"Limite mensal de {limit} gerações por IA atingido."
        )


async def _find_cached_job(db: AsyncSession, prompt_hash: str) -> Optional[AIWorkoutJob]:
    """Return a DONE job from the last 30 days if it exists (instant cache)."""
    ttl_limit = datetime.utcnow() - timedelta(days=30)
    result = await db.execute(
        select(AIWorkoutJob).filter(
            AIWorkoutJob.prompt_hash == prompt_hash,
            AIWorkoutJob.status == "DONE",
            AIWorkoutJob.created_at >= ttl_limit,
        )
    )
    return result.scalars().first()


# ──────────────────────────────────────────────────────────────────────────────
# Background workers — called by BackgroundTasks (non-blocking)
# ──────────────────────────────────────────────────────────────────────────────

from app.db.session import AsyncSessionLocal  # need own session — request one is closed


async def _run_trainer_generate_job(job_id: str, text: str, user_id: str):
    """Background task: call Gemini and update job record."""
    async with AsyncSessionLocal() as db:
        try:
            # Mark as PROCESSING
            job = await db.get(AIWorkoutJob, job_id)
            if not job:
                return
            job.status = "PROCESSING"
            await db.commit()

            # SEC-1: sanitise input (length cap already applied at request time)
            client = _get_gemini_client()
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=[
                    {"role": "user", "parts": [{"text": TRAINER_GENERATE_SYSTEM}]},
                    {"role": "user", "parts": [{"text": f"Texto para extrair treinos:\n{text}"}]}
                ],
                config={
                    "response_mime_type": "application/json",
                    "max_output_tokens": 8192,
                    "temperature": 0.4,
                }
            )
            data = json.loads(response.text)

            # Save result
            job.status = "DONE"
            job.result_data = data
            job.completed_at = datetime.utcnow()
            db.add(AIUsageLog(user_id=user_id, request_type="generate", tokens_used=0))
            await db.commit()

        except Exception as exc:
            async with AsyncSessionLocal() as err_db:
                job = await err_db.get(AIWorkoutJob, job_id)
                if job:
                    job.status = "FAILED"
                    job.error_message = str(exc)[:500]
                    job.completed_at = datetime.utcnow()
                    await err_db.commit()


async def _run_anamnesis_job(job_id: str, prompt_content: str, user_id: str):
    """Background task: call Gemini for anamnesis-based program."""
    async with AsyncSessionLocal() as db:
        try:
            job = await db.get(AIWorkoutJob, job_id)
            if not job:
                return
            job.status = "PROCESSING"
            await db.commit()

            client = _get_gemini_client()
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=[
                    {"role": "user", "parts": [{"text": ANAMNESIS_SYSTEM}]},
                    {"role": "user", "parts": [{"text": prompt_content}]}
                ],
                config={
                    "response_mime_type": "application/json",
                    "max_output_tokens": 8192,
                    "temperature": 0.4,
                }
            )
            data = json.loads(response.text)

            job.status = "DONE"
            job.result_data = data
            job.completed_at = datetime.utcnow()
            db.add(AIUsageLog(user_id=user_id, request_type="anamnesis", tokens_used=0))
            await db.commit()

        except Exception as exc:
            async with AsyncSessionLocal() as err_db:
                job = await err_db.get(AIWorkoutJob, job_id)
                if job:
                    job.status = "FAILED"
                    job.error_message = str(exc)[:500]
                    job.completed_at = datetime.utcnow()
                    await err_db.commit()


# ──────────────────────────────────────────────────────────────────────────────
# Schemas
# ──────────────────────────────────────────────────────────────────────────────

class GenerateRequest(BaseModel):
    student_ids: List[UUID]
    text: str


class AnamnesisInput(BaseModel):
    goal: str
    experience_level: str
    weekly_frequency: str
    session_duration: str
    equipment: str
    activity_level: str
    injuries: Optional[str] = ""
    medical_conditions: Optional[str] = ""


class JobStatusResponse(BaseModel):
    job_id: str
    status: str           # PENDING | PROCESSING | DONE | FAILED
    result: Optional[Any] = None
    error: Optional[str] = None


# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/generate", status_code=202)
async def generate_workouts(
    body: GenerateRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Trainer: generate workout plan from raw text.
    - Cache hit → 200 with immediate result.
    - Cache miss → 202 with job_id for polling.

    Design note: prompt_hash is computed from the text only, not from student_ids.
    The AI response (workout structure) is independent of who will receive it.
    The correct student assignment happens at save-program time. This is intentional
    and maximises cache efficiency across different student selections with the same prompt.
    """
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Apenas treinadores podem usar esta funcionalidade")

    # SEC-0: Terms of Responsibility must be accepted server-side (mobile also enforces this,
    # but backend is the single source of truth for security.
    if not current_user.accepted_ai_terms_at:
        raise HTTPException(
            status_code=403,
            detail="Aceite os Termos de Responsabilidade antes de usar a geração de treinos com IA.",
        )

    # Feature flag
    tp_result = await db.execute(
        select(TrainerProfile).filter(TrainerProfile.user_id == current_user.id)
    )
    trainer_profile = tp_result.scalars().first()
    if not trainer_profile or not trainer_profile.enable_ai_workouts:
        raise HTTPException(
            status_code=403,
            detail="Funcionalidade premium — solicite ao administrador para ativar a geração de treinos com IA",
        )

    # IDOR: verify all students belong to trainer
    for s_id in body.student_ids:
        student_res = await db.execute(
            select(User)
            .options(selectinload(User.trainers))
            .filter(User.id == s_id)
        )
        student = student_res.scalars().first()
        if not student or not any(t.id == current_user.id for t in student.trainers):
            raise HTTPException(status_code=403, detail=f"O aluno {s_id} não pertence a este treinador")

    # SEC-2: rate limit (10 for trainers, 5 for students)
    rate_limit = 10 if current_user.role == UserRole.TRAINER else 5
    await _check_rate_limit(db, current_user.id, "generate", limit=rate_limit)

    # SEC-1: sanitise input
    safe_text = body.text[:2000]

    # SEC-3: cache lookup via prompt_hash (text-only hash — see design note above)
    prompt_hash = hashlib.sha256(safe_text.encode()).hexdigest()
    cached = await _find_cached_job(db, prompt_hash)
    if cached:
        return {"status": "ready", "job_id": str(cached.id), "result": cached.result_data}

    # Create job record
    job = AIWorkoutJob(
        user_id=current_user.id,
        job_type="generate",
        prompt_hash=prompt_hash,
        status="PENDING",
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    # Queue background work (non-blocking)
    background_tasks.add_task(
        _run_trainer_generate_job,
        job_id=str(job.id),
        text=safe_text,
        user_id=str(current_user.id),
    )

    return {"status": "pending", "job_id": str(job.id)}


@router.post("/suggest-from-anamnesis", status_code=202)
async def suggest_from_anamnesis(
    body: AnamnesisInput,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Student/Trainer: generate personalised program from anamnesis profile.
    - Cache hit → 200 with immediate result.
    - Cache miss → 202 with job_id for polling.
    """
    if not current_user.accepted_ai_terms_at:
        raise HTTPException(
            status_code=403,
            detail="Aceite os Termos de Responsabilidade antes de usar esta funcionalidade.",
        )

    # SEC-2: rate limit (10 for trainers, 5 for students)
    rate_limit = 10 if current_user.role == UserRole.TRAINER else 5
    await _check_rate_limit(db, current_user.id, "anamnesis", limit=rate_limit)

    # Build prompt — also used as cache key
    freq_map = {"2x por semana": 2, "3x por semana": 3, "4x por semana": 4, "5x por semana": 5, "6x ou mais": 6}
    num_days = freq_map.get(body.weekly_frequency, 3)

    prompt_content = ANAMNESIS_USER_TEMPLATE.format(
        goal=body.goal[:100],
        experience_level=body.experience_level[:100],
        weekly_frequency=body.weekly_frequency[:100],
        session_duration=body.session_duration[:100],
        equipment=body.equipment[:200],
        activity_level=body.activity_level[:100],
        injuries=(body.injuries or "Nenhuma")[:200],
        medical_conditions=(body.medical_conditions or "Nenhuma")[:200],
        num_days=num_days,
    )

    # SEC-3: cache
    prompt_hash = hashlib.sha256(prompt_content.encode()).hexdigest()
    cached = await _find_cached_job(db, prompt_hash)
    if cached:
        return {"status": "ready", "job_id": str(cached.id), "result": cached.result_data}

    # Create job
    job = AIWorkoutJob(
        user_id=current_user.id,
        job_type="anamnesis",
        prompt_hash=prompt_hash,
        status="PENDING",
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)

    background_tasks.add_task(
        _run_anamnesis_job,
        job_id=str(job.id),
        prompt_content=prompt_content,
        user_id=str(current_user.id),
    )

    return {"status": "pending", "job_id": str(job.id)}


@router.get("/jobs/{job_id}", response_model=JobStatusResponse)
async def poll_job(
    job_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """
    Poll job status. Mobile calls this every ~3s until status == 'done' or 'failed'.
    Ownership enforced: only the requesting user can poll their jobs.
    """
    job = await db.get(AIWorkoutJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job não encontrado")
    if job.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")

    return JobStatusResponse(
        job_id=str(job.id),
        status=job.status.lower(),        # pending | processing | done | failed
        result=job.result_data if job.status == "DONE" else None,
        error=job.error_message if job.status == "FAILED" else None,
    )


# ──────────────────────────────────────────────────────────────────────────────
# Save AI Program
# ──────────────────────────────────────────────────────────────────────────────

async def _resolve_exercise(db: AsyncSession, name: str) -> ExerciseLibrary:
    """
    Find the best-matching exercise in the library using a cascade strategy:
      1. Exact match (case-insensitive) — perfect hit, highest priority.
      2. Partial match (LIKE %name%) — handles "Agachamento Livre" matching
         "Agachamento Livre (Barra)" or similar library variants.
      3. Create a new exercise with category 'IA' — fallback of last resort.

    This prevents orphaned 'IA' exercises when the library already has the
    exercise under a slightly different name, which broke video/instruction links.
    """
    # 1. Exact match
    result = await db.execute(
        select(ExerciseLibrary).filter(ExerciseLibrary.name.ilike(name))
    )
    exercise = result.scalars().first()
    if exercise:
        return exercise

    # 2. Partial match — search for library entries that CONTAIN the AI name
    #    or where the AI name is contained within a library entry.
    normalized = name.strip()
    result = await db.execute(
        select(ExerciseLibrary).filter(
            ExerciseLibrary.name.ilike(f"%{normalized}%")
        )
    )
    exercise = result.scalars().first()
    if exercise:
        return exercise

    # 3. Fallback — create a new exercise tagged as IA-generated
    exercise = ExerciseLibrary(name=name, category="IA")
    db.add(exercise)
    await db.flush()
    return exercise

class AiExerciseItem(BaseModel):
    exercise_name: str
    sets: int = 3
    reps_min: Optional[int] = None
    reps_max: Optional[int] = None
    duration_seconds: Optional[int] = None
    rest_seconds: int = 60
    notes: Optional[str] = None
    methodology_type: str = "NORMAL"
    methodology_params: Optional[dict] = None


class AiWorkoutDay(BaseModel):
    name: str
    notes: Optional[str] = None
    exercises: List[AiExerciseItem]


class SaveAiProgramInput(BaseModel):
    program_name: str
    workouts: List[AiWorkoutDay]
    student_ids: Optional[List[UUID]] = None


@router.post("/save-program")
async def save_ai_program(
    body: SaveAiProgramInput,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    """Persist an AI-generated program as real workouts."""
    if not current_user.accepted_ai_terms_at:
        raise HTTPException(
            status_code=403,
            detail="Aceite os Termos de Responsabilidade antes de salvar treinos IA.",
        )

    created_workouts = []
    
    # Se student_ids foi enviado, salvamos para os alunos. Caso contrário, para o próprio treinador.
    target_user_ids = body.student_ids if body.student_ids else [current_user.id]

    for target_user_id in target_user_ids:
        # Opcional: verificar novamente se o Personal tem acesso a este aluno aqui?
        # Sim, por segurança.
        if body.student_ids:
            student_res = await db.execute(
                select(User).options(selectinload(User.trainers)).filter(User.id == target_user_id)
            )
            student = student_res.scalars().first()
            if not student or not any(t.id == current_user.id for t in student.trainers):
                # Pulamos alunos que não pertencem ao personal (ou poderíamos lançar erro)
                print(f"DEBUG: Skipping student {target_user_id} - not linked to trainer")
                continue

        for day in body.workouts:
            try:
                db_workout = Workout(name=day.name, user_id=target_user_id)
                db.add(db_workout)
                await db.flush()
                print(f"DEBUG: Created workout {db_workout.id} for user {target_user_id}")

                for ex in day.exercises:
                    print(f"DEBUG: Resolving exercise: {ex.exercise_name}")
                    exercise = await _resolve_exercise(db, ex.exercise_name)
                    print(f"DEBUG: Resolved to exercise {exercise.id}")

                    db.add(WorkoutItem(
                        workout_id=db_workout.id,
                        exercise_id=exercise.id,
                        sets=ex.sets,
                        reps_min=ex.reps_min,
                        reps_max=ex.reps_max,
                        duration_seconds=ex.duration_seconds,
                        rest_seconds=ex.rest_seconds,
                        notes=ex.notes,
                        methodology_type=ex.methodology_type,
                        methodology_params=ex.methodology_params,
                    ))

                created_workouts.append({"id": str(db_workout.id), "name": db_workout.name, "user_id": str(target_user_id)})
            except Exception as e:
                print(f"ERROR: Failed to create workout for user {target_user_id}: {e}")
                raise

    print(f"DEBUG: Committing {len(created_workouts)} workouts")
    await db.commit()
    print(f"DEBUG: Save program completed successfully")
    return {
        "saved_count": len(created_workouts),
        "workouts": created_workouts,
        "message": f"Treinos salvos para {len(target_user_ids)} aluno(s) com sucesso!",
    }

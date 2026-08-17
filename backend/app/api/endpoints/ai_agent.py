import os
import uuid
import logging
import asyncio
from datetime import datetime
from typing import List, Optional, Any
from uuid import UUID

from google.genai import Client, types as genai_types
from google.protobuf.json_format import MessageToDict
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, or_, and_, exists
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api import deps
from app.db.session import get_db
from app.models.ai_agent import AgentSession, AgentMessage, AgentActionStatus
from app.models.user import User, UserRole
from app.schemas import ai_agent as schemas
from app.models.workout_group import WorkoutGroup
from app.models.exercise import ExerciseLibrary
from app.models.workout_template import WorkoutTemplate, WorkoutTemplateItem
from app.models.notification import NotificationType
from app.services.notification_service import create_notification
from app.models.workout import Workout, WorkoutItem, MethodologyType

router = APIRouter()
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────────────
# Protobuf to JSON Converter (Fixed: Use MessageToDict for proper handling)
# ──────────────────────────────────────────────────────────────────────────────

def _protobuf_to_dict(obj: Any) -> Any:
    """Convert protobuf objects to JSON-serializable dicts using proper protobuf utilities."""
    try:
        # Check if this is a protobuf message object
        if hasattr(obj, 'DESCRIPTOR'):
            # Use MessageToDict which properly handles repeated fields as lists
            result = MessageToDict(obj, preserving_proto_field_name=True)
            # Recursively ensure nested values are also properly converted
            return _ensure_serializable(result)
        # If it's a dict-like object, recurse into values
        elif isinstance(obj, dict):
            return {k: _protobuf_to_dict(v) for k, v in obj.items()}
        # If it's a list, recurse into items
        elif isinstance(obj, (list, tuple)):
            return [_protobuf_to_dict(item) for item in obj]
        # For anything else, try to ensure it's serializable (handles MapComposite, etc.)
        else:
            return _ensure_serializable(obj)
    except Exception as e:
        logger.warning(f"Error converting protobuf to dict: {e}, falling back to raw object")
        return obj

def _ensure_serializable(obj: Any) -> Any:
    """Recursively ensure all values are JSON-serializable."""
    # Handle protobuf-plus MapComposite and similar containers
    if type(obj).__name__ in ('MapComposite', 'RepeatedComposite'):
        # Convert map/repeated containers to dict/list
        if hasattr(obj, 'items'):
            return {k: _ensure_serializable(v) for k, v in obj.items()}
        elif hasattr(obj, '__iter__') and not isinstance(obj, str):
            return [_ensure_serializable(item) for item in obj]

    if isinstance(obj, dict):
        return {k: _ensure_serializable(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_ensure_serializable(item) for item in obj]
    elif hasattr(obj, '__dict__') and not isinstance(obj, type):
        # For any remaining protobuf-like objects with __dict__
        try:
            return {k: _ensure_serializable(v) for k, v in obj.__dict__.items() if not k.startswith('_')}
        except:
            return str(obj)
    elif isinstance(obj, (str, int, float, bool, type(None))):
        return obj
    else:
        # Fallback for non-serializable types
        try:
            # Try converting to string representation
            import json
            json.dumps(obj)  # Test if serializable
            return obj
        except (TypeError, ValueError):
            return str(obj)

# ──────────────────────────────────────────────────────────────────────────────
# Gemini Client Helper
# ──────────────────────────────────────────────────────────────────────────────

def _get_agent_client() -> Client:
    """Initialize Gemini client with API key."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY não configurada")
    return Client(api_key=api_key)

def _build_system_instruction(instructions_override: str = "") -> str:
    """Build system instruction for the agent."""
    system_instruction = (
        "Você é o Agente Pulso, um assistente de execução para treinadores de fitness. "
        "Seu objetivo é EXECUTAR tarefas de organização de forma assertiva. "
        "DIRETRIZES RÍGIDAS:\n"
        "1. MEMÓRIA DE DADOS: Se o treinador já disse o nome da pasta ou do treino, NÃO PERGUNTE NOVAMENTE.\n"
        "2. IDENTIFICAÇÃO DE ALUNO: Use 'search_students' para encontrar IDs reais.\n"
        "3. BATCH ACTIONS: Você pode chamar múltiplas ferramentas se necessário.\n"
        "4. PROPOSTA DE AÇÃO: NÃO peça permissão para prosseguir. Resuma detalhadamente o que fará (use Markdown com títulos e listas para descrever o treino, exercícios, séries e repetições) e CHAME a ferramenta IMEDIATAMENTE na mesma resposta. Isso mostrará uma prévia para o usuário com um botão de confirmação seguro para ele revisar e aprovar.\n"
        "5. Responda em Português do Brasil."
    )

    if instructions_override:
        system_instruction += instructions_override

    return system_instruction

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

async def _internal_search_students(db: AsyncSession, trainer_id: UUID, name_query: str):
    from app.models.user import student_trainer_association
    stmt = select(User).where(
        and_(
            User.role == UserRole.STUDENT,
            User.full_name.ilike(f"%{name_query}%"),
            exists(
                select(1).select_from(student_trainer_association)
                .where(and_(student_trainer_association.c.student_id == User.id, student_trainer_association.c.trainer_id == trainer_id))
            )
        )
    )
    result = await db.execute(stmt)
    my_students = result.scalars().all()
    
    if not my_students:
        return {"result": [], "error": f"Nenhum aluno encontrado com o nome '{name_query}'"}
    
    return {"result": [{"id": str(s.id), "name": s.full_name} for s in my_students]}

def _validate_payload(action_type: str, payload: dict):
    """Validação rigorosa de campos obrigatórios (Fix #6)."""
    required = {
        "prepare_folder": [["folder_name"], ["student_id"]],
        "prepare_workout": [["workout_name"], ["student_ids", "student_id"], ["exercises"]],
        "prepare_template": [["template_name"], ["exercises"]],
    }
    
    missing = []
    for field_options in required.get(action_type, []):
        if not any(f in payload for f in field_options):
            missing.append(field_options[0])
            
    if missing: raise ValueError(f"Campos obrigatórios faltando: {missing}")

async def _internal_execute_actions(db: AsyncSession, current_user: User, actions: List[dict]) -> List[str]:
    """Lógica central de execução compartilhada entre chat automático e manual."""
    print(f"DEBUG Pulso: Executing {len(actions)} actions for trainer {current_user.full_name}")
    logger.info(f"AI Agent: Executing {len(actions)} actions, actions={actions}")
    results = []
    seen_keys = set()

    # Cache para evitar buscas repetidas
    exercise_cache = {}

    for action in actions:
        action_type = action.get("type")
        payload = action.get("payload", {})
        logger.info(f"AI Agent: Processing action type={action_type}, payload keys={list(payload.keys())}")
        if not action_type:
            logger.warning(f"AI Agent: Skipping action without type: {action}")
            continue
        
        # Idempotência
        action_key = (action_type, str(payload))
        if action_key in seen_keys:
            logger.info(f"AI Agent: Skipping duplicate action: {action_type}")
            continue
        seen_keys.add(action_key)

        # Validação
        try:
            _validate_payload(action_type, payload)
            logger.info(f"AI Agent: Validation passed for {action_type}")
        except ValueError as e:
            logger.error(f"AI Agent: Validation failed for {action_type}: {e}")
            raise

        if action_type == "prepare_folder":
            logger.info(f"AI Agent: Executing prepare_folder action")
            student_id = UUID(str(payload["student_id"]))
            stmt = select(User).where(User.id == student_id, User.role == UserRole.STUDENT).options(selectinload(User.trainers))
            student = (await db.execute(stmt)).scalar_one_or_none()
            if not student or not any(t.id == current_user.id for t in student.trainers):
                raise HTTPException(status_code=403, detail="Acesso negado ao aluno")

            new_group = WorkoutGroup(name=payload["folder_name"], student_id=student_id, trainer_id=current_user.id, is_active=True)
            db.add(new_group)
            await db.flush()
            result_msg = f"Pasta '{payload['folder_name']}'"
            logger.info(f"AI Agent: prepare_folder succeeded - {result_msg}")
            results.append(result_msg)

        elif action_type == "prepare_workout":
            logger.info(f"AI Agent: Executing prepare_workout action")
            # Cache de exercícios para o batch
            exercise_names = [ex["name"] for ex in payload.get("exercises", [])]
            if exercise_names:
                filters = [ExerciseLibrary.name.ilike(f"%{name}%") for name in exercise_names]
                stmt = select(ExerciseLibrary).where(or_(*filters))
                found_exercises = (await db.execute(stmt)).scalars().all()
                for name in exercise_names:
                    if name in exercise_cache: continue
                    match = next((fe for fe in found_exercises if name.lower() == fe.name.lower()), None)
                    if not match: match = next((fe for fe in found_exercises if fe.name.lower().startswith(name.lower())), None)
                    if not match: match = next((fe for fe in found_exercises if name.lower() in fe.name.lower()), None)
                    if match: exercise_cache[name] = match.id

            s_ids = payload.get("student_ids", [])
            if not s_ids and "student_id" in payload:
                val = payload["student_id"]
                s_ids = [val] if isinstance(val, str) else val

            logger.info(f"AI Agent: Resolved s_ids={s_ids}, from payload keys={list(payload.keys())}")
            if not s_ids:
                logger.error(f"AI Agent: No student_ids found in payload: {payload}")
                continue

            workout_count = 0
            logger.info(f"AI Agent: Processing {len(s_ids)} student(s) for workout")
            for s_id in s_ids:
                logger.info(f"AI Agent: Processing student_id={s_id}")
                sid_uuid = UUID(str(s_id))
                stmt = select(User).where(User.id == sid_uuid).options(selectinload(User.trainers))
                student = (await db.execute(stmt)).scalar_one_or_none()
                if not student:
                    logger.warning(f"AI Agent: Student {s_id} not found")
                    continue
                if not any(t.id == current_user.id for t in student.trainers):
                    logger.warning(f"AI Agent: Trainer {current_user.id} not associated with student {s_id} (trainers: {[str(t.id) for t in student.trainers]})")
                    continue
                logger.info(f"AI Agent: Student {s_id} validated, creating workout")

                # Smart Grouping: Se o aluno tiver apenas UM grupo ativo, associar automaticamente
                target_group_id = None
                groups_stmt = select(WorkoutGroup).where(WorkoutGroup.student_id == sid_uuid, WorkoutGroup.is_active == True)
                active_groups = (await db.execute(groups_stmt)).scalars().all()
                if len(active_groups) == 1:
                    target_group_id = active_groups[0].id
                    print(f"DEBUG Pulso: Auto-associando treino ao grupo '{active_groups[0].name}'")

                workout = Workout(
                    name=payload["workout_name"], 
                    user_id=sid_uuid,
                    scheduled_for=datetime.utcnow(),
                    group_id=target_group_id
                )
                db.add(workout)
                await db.flush()

                for ex_data in payload.get("exercises", []):
                    ex_name = ex_data.get('name', 'Exercício')
                    ex_id = exercise_cache.get(ex_name)
                    if not ex_id:
                        new_ex = ExerciseLibrary(name=ex_name, category="Geral", created_by_id=current_user.id)
                        db.add(new_ex)
                        await db.flush()
                        ex_id = new_ex.id
                        exercise_cache[ex_name] = ex_id
                        
                    # Reps parsing logic
                    reps_str = str(ex_data.get('reps', '12'))
                    reps_min = reps_max = 12
                    if '-' in reps_str:
                        try:
                            low, high = reps_str.split('-')
                            reps_min, reps_max = int(low.strip()), int(high.strip())
                        except: pass
                    else:
                        try: reps_min = reps_max = int(reps_str)
                        except: pass

                    item = WorkoutItem(
                        workout_id=workout.id,
                        exercise_id=ex_id,
                        sets=int(ex_data.get('sets', 3)),
                        reps_min=reps_min,
                        reps_max=reps_max,
                        rest_seconds=int(ex_data.get('rest', 60)),
                        notes=ex_data.get("notes", f"{ex_data.get('sets', 3)}x{reps_str}"),
                        methodology_type=MethodologyType.NORMAL
                    )
                    db.add(item)

                # Flush after all items added to detect any constraint errors early
                await db.flush()
                workout_count += 1

                # Notificar o aluno (comportamento padrão de criação de treino)
                await create_notification(
                    db=db,
                    user_id=sid_uuid,
                    type=NotificationType.NEW_WORKOUT,
                    title="Novo Treino",
                    body=f"Seu treinador {current_user.full_name} te enviou um novo treino via Agente Pulso: {payload['workout_name']}",
                    data={"workout_id": str(workout.id), "trainer_id": str(current_user.id)}
                )
            
            if workout_count > 0:
                result_msg = f"Treino '{payload['workout_name']}' ({workout_count} aluno{'s' if workout_count > 1 else ''})"
                logger.info(f"AI Agent: prepare_workout succeeded - {result_msg}")
                results.append(result_msg)
            else:
                logger.warning(f"AI Agent: prepare_workout had 0 workouts created. student_ids={s_ids}, processed count={len(s_ids)}")

        elif action_type == "prepare_template":
            logger.info(f"AI Agent: Executing prepare_template action")
            new_template = WorkoutTemplate(name=payload["template_name"], trainer_id=current_user.id)
            db.add(new_template)
            await db.flush()
            
            # Persistir itens do template
            for idx, ex_data in enumerate(payload.get("exercises", [])):
                ex_name = ex_data.get('name', 'Exercício')
                ex_id = exercise_cache.get(ex_name)
                if not ex_id:
                    # Look up or create exercise
                    stmt = select(ExerciseLibrary).where(ExerciseLibrary.name.ilike(ex_name))
                    fe = (await db.execute(stmt)).scalar_one_or_none()
                    if fe:
                        ex_id = fe.id
                    else:
                        new_ex = ExerciseLibrary(name=ex_name, category="Geral", created_by_id=current_user.id)
                        db.add(new_ex)
                        await db.flush()
                        ex_id = new_ex.id
                    exercise_cache[ex_name] = ex_id
                
                # Reps parsing
                reps_str = str(ex_data.get('reps', '12'))
                reps_min = reps_max = 12
                if '-' in reps_str:
                    try:
                        low, high = reps_str.split('-')
                        reps_min, reps_max = int(low.strip()), int(high.strip())
                    except: pass
                else:
                    try: reps_min = reps_max = int(reps_str)
                    except: pass

                t_item = WorkoutTemplateItem(
                    template_id=new_template.id,
                    exercise_id=ex_id,
                    exercise_name=ex_name,
                    sets=int(ex_data.get('sets', 3)),
                    reps_min=reps_min,
                    reps_max=reps_max,
                    order_index=idx,
                    rest_seconds=int(ex_data.get('rest', 60)),
                    notes=ex_data.get("notes"),
                    methodology_type=MethodologyType.NORMAL
                )
                db.add(t_item)
            
            result_msg = f"Template '{payload['template_name']}'"
            logger.info(f"AI Agent: prepare_template succeeded - {result_msg}")
            results.append(result_msg)
        else:
            logger.warning(f"AI Agent: Unknown action type: {action_type}")

    logger.info(f"AI Agent: Execution complete. Results: {results}")
    if not results:
        logger.warning(f"AI Agent: No results generated from {len(actions)} actions")
    return results

# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/sessions", response_model=List[schemas.AgentSession])
async def list_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """Lista todas as sessões de chat do treinador."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Apenas treinadores podem acessar o histórico")
    
    stmt = select(AgentSession).where(
        AgentSession.trainer_id == current_user.id
    ).options(selectinload(AgentSession.messages)).order_by(AgentSession.updated_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()

@router.get("/session/{session_id}", response_model=schemas.AgentSession)
async def get_session(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """Busca uma sessão específica com suas mensagens."""
    stmt = select(AgentSession).where(
        AgentSession.id == session_id, 
        AgentSession.trainer_id == current_user.id
    ).options(selectinload(AgentSession.messages))
    
    result = await db.execute(stmt)
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")
    return session

@router.post("/session", response_model=schemas.AgentSession)
async def create_or_get_session(
    force_new: bool = False,
    student_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """Cria uma nova sessão de chat para o treinador ou recupera a última ativa."""
    if current_user.role != UserRole.TRAINER:
        raise HTTPException(status_code=403, detail="Apenas treinadores podem usar o Agente")
    
    session = None
    if not force_new:
        # Tenta pegar a última sessão ativa (filtrando estritamente pelo estudante ou geral)
        stmt = select(AgentSession).where(AgentSession.trainer_id == current_user.id)
        if student_id:
            stmt = stmt.where(AgentSession.student_id == student_id)
        else:
            # Sessão GERAL: Onde student_id é NULL
            stmt = stmt.where(AgentSession.student_id == None)

        stmt = stmt.order_by(AgentSession.updated_at.desc()).limit(1)
        result = await db.execute(stmt)
        session = result.scalar_one_or_none()
    
    if not session:
        now_str = datetime.utcnow().strftime('%d/%m %H:%M')
        title = f"Conversa {now_str}"
        if student_id:
            student_res = await db.execute(select(User).where(User.id == student_id))
            student_obj = student_res.scalar_one_or_none()
            if student_obj:
                title = f"Treino: {student_obj.full_name}"
        else:
            title = f"Agente Pulso (IA) {now_str}"

        session = AgentSession(trainer_id=current_user.id, student_id=student_id, title=title)
        db.add(session)
        await db.commit()
        await db.refresh(session)
    
    # Recarregar com mensagens para evitar erro de lazy loading na serialização
    stmt = select(AgentSession).where(AgentSession.id == session.id).options(selectinload(AgentSession.messages))
    result = await db.execute(stmt)
    return result.scalar_one()

@router.post("/chat", response_model=schemas.AgentMessage)
async def chat_with_agent(
    request: schemas.AgentChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """Envia uma mensagem para o agente e recebe a resposta (com tool calls automáticos)."""
    if not request.session_id:
        raise HTTPException(status_code=400, detail="session_id é obrigatório")

    # Lock de linha para evitar Race Condition (Fix #1)
    stmt = select(AgentSession).where(
        AgentSession.id == request.session_id, 
        AgentSession.trainer_id == current_user.id
    ).with_for_update()
    
    result = await db.execute(stmt)
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")

    try:
        user_msg = AgentMessage(session_id=session.id, role="user", content=request.message)
        db.add(user_msg)
        await db.flush()
        
        # Ordering fix (Fix #11)
        stmt = select(AgentMessage).where(AgentMessage.session_id == session.id).order_by(AgentMessage.created_at.asc(), AgentMessage.id.asc())
        result = await db.execute(stmt)
        history_objs = result.scalars().all()
        
        gemini_history = []
        for m in history_objs[:-1]:
            role = "user" if m.role == "user" else "model"
            parts = []
            if m.content:
                parts.append(m.content)
            if m.tool_calls:
                for tc in m.tool_calls:
                    parts.append({"function_call": {"name": tc["name"], "args": tc["args"]}})
            if parts:
                gemini_history.append({"role": role, "parts": parts})
        
        # Injetar instrução de contexto se houver um aluno vinculado (Fix #Context)
        instructions = ""
        if session.student_id:
            student_res = await db.execute(select(User).where(User.id == session.student_id))
            student_obj = student_res.scalar_one_or_none()
            if student_obj:
                instructions = f"\nIMPORTANTE: Esta conversa é focada exclusivamente no aluno(a) {student_obj.full_name}. Ao criar ferramentas, use sempre este aluno."

        system_instruction = _build_system_instruction(instructions_override=instructions)
        client = _get_agent_client()

        # Define function tools for google.genai
        tools = [
            genai_types.Tool(
                function_declarations=[
                    genai_types.FunctionDeclaration(
                        name="search_students",
                        description="Busca alunos pelo nome",
                        parameters=genai_types.Schema(
                            type=genai_types.Type.OBJECT,
                            properties={
                                "name_query": genai_types.Schema(
                                    type=genai_types.Type.STRING,
                                    description="Nome ou parte do nome do aluno"
                                )
                            },
                            required=["name_query"]
                        )
                    ),
                    genai_types.FunctionDeclaration(
                        name="prepare_workout",
                        description="Prepara um treino para um ou mais alunos",
                        parameters=genai_types.Schema(
                            type=genai_types.Type.OBJECT,
                            properties={
                                "workout_name": genai_types.Schema(type=genai_types.Type.STRING),
                                "exercises": genai_types.Schema(type=genai_types.Type.ARRAY),
                                "student_ids": genai_types.Schema(type=genai_types.Type.ARRAY)
                            },
                            required=["workout_name", "exercises", "student_ids"]
                        )
                    ),
                    genai_types.FunctionDeclaration(
                        name="prepare_template",
                        description="Prepara um template de treino",
                        parameters=genai_types.Schema(
                            type=genai_types.Type.OBJECT,
                            properties={
                                "template_name": genai_types.Schema(type=genai_types.Type.STRING),
                                "exercises": genai_types.Schema(type=genai_types.Type.ARRAY)
                            },
                            required=["template_name", "exercises"]
                        )
                    ),
                    genai_types.FunctionDeclaration(
                        name="prepare_folder",
                        description="Prepara uma pasta de treinos para um aluno",
                        parameters=genai_types.Schema(
                            type=genai_types.Type.OBJECT,
                            properties={
                                "folder_name": genai_types.Schema(type=genai_types.Type.STRING),
                                "student_id": genai_types.Schema(type=genai_types.Type.STRING)
                            },
                            required=["folder_name", "student_id"]
                        )
                    )
                ]
            )
        ]

        # Timeout fix (Fix #5) - send message with full history
        async def _send_with_timeout():
            return await asyncio.to_thread(
                lambda: client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=gemini_history + [{"role": "user", "parts": [{"text": request.message}]}],
                    tools=tools,
                    config={
                        "temperature": 0.2,
                        "system_instruction": system_instruction
                    }
                )
            )

        try:
            response = await asyncio.wait_for(_send_with_timeout(), timeout=30.0)
        except asyncio.TimeoutError:
            raise HTTPException(status_code=504, detail="IA demorou muito para responder")

        # Loop de Tool Calling com proteção (Fix #7, #9)
        max_iterations = 5
        current_history = gemini_history + [{"role": "user", "parts": [{"text": request.message}]}]

        for iteration in range(max_iterations):
            if not response.candidates or not response.candidates[0].content.parts:
                break

            fc = next((p.function_call for p in response.candidates[0].content.parts if hasattr(p, 'function_call') and p.function_call), None)
            if not fc:
                break

            try:
                if fc.name == "search_students":
                    tool_result = await _internal_search_students(db, current_user.id, fc.args['name_query'])
                    # Add model response with tool call to history
                    current_history.append({"role": "model", "parts": [{"function_call": {"name": fc.name, "args": fc.args}}]})
                    # Add tool response to history
                    current_history.append({"role": "user", "parts": [{"function_response": {"name": fc.name, "response": tool_result}}]})
                    # Continue conversation
                    response = await asyncio.to_thread(
                        lambda: client.models.generate_content(
                            model="gemini-2.5-flash",
                            contents=current_history,
                            tools=tools,
                            config={"temperature": 0.2, "system_instruction": system_instruction}
                        )
                    )
                else:
                    # Interrompe o loop para ferramentas de criação (prepare_*)
                    # Assim o agente envia a proposta com o tool_call para o usuário confirmar
                    break
            except Exception as tool_err:
                logger.error(f"Tool error: {tool_err}")
                # Add error response to history and continue
                current_history.append({"role": "model", "parts": [{"function_call": {"name": fc.name, "args": fc.args}}]})
                current_history.append({"role": "user", "parts": [{"function_response": {"name": fc.name, "response": {"error": str(tool_err)}}}]})
                response = await asyncio.to_thread(
                    lambda: client.models.generate_content(
                        model="gemini-2.5-flash",
                        contents=current_history,
                        tools=tools,
                        config={"temperature": 0.2, "system_instruction": system_instruction}
                    )
                )
                if iteration > 2:
                    break

        if not response.candidates or not response.candidates[0].content.parts:
            raise HTTPException(status_code=500, detail="A IA não conseguiu gerar uma resposta.")

        content_parts = response.candidates[0].content.parts

        # Extract text and tool calls from response
        text_parts = [p.text for p in content_parts if hasattr(p, 'text') and p.text]
        response_text = " ".join(text_parts) if text_parts else None

        tool_calls = [p.function_call for p in content_parts if hasattr(p, 'function_call') and p.function_call]

        # Create AI message with both text content AND action data in ONE message
        ai_msg = AgentMessage(
            session_id=session.id,
            role="model",
            content=response_text  # Always include the text explanation
        )

        if tool_calls:
            ai_msg.tool_calls = [{"name": tc.name, "args": _protobuf_to_dict(tc.args)} for tc in tool_calls]
            ai_msg.action_status = AgentActionStatus.PENDING
            # Batch actions support - combine all tool calls into one action
            ai_msg.action_data = {
                "type": "batch",
                "actions": [{"type": tc.name, "payload": _protobuf_to_dict(tc.args)} for tc in tool_calls]
            }

        db.add(ai_msg)
        session.updated_at = datetime.utcnow()

        await db.commit()
        await db.refresh(ai_msg)
        return ai_msg

    except Exception as e:
        await db.rollback()
        logger.error(f"Chat Error: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro no chat: {str(e)}")

@router.post("/execute-action", response_model=schemas.AgentMessage)
async def execute_agent_action(
    request: schemas.AgentActionExecuteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_active_user)
):
    """Executa a ação real no banco de dados."""
    stmt = select(AgentMessage).where(
        AgentMessage.id == request.message_id
    ).options(selectinload(AgentMessage.session)).with_for_update()
    
    result = await db.execute(stmt)
    msg = result.scalar_one_or_none()
    
    if not msg or msg.session.trainer_id != current_user.id:
        raise HTTPException(status_code=404, detail="Mensagem não encontrada")
    
    if msg.action_status != AgentActionStatus.PENDING:
        raise HTTPException(status_code=400, detail="Esta ação não está pendente")

    if not msg.action_data or not isinstance(msg.action_data, dict):
        raise HTTPException(status_code=400, detail="Dados de ação inválidos")

    if request.action == "reject":
        msg.action_status = AgentActionStatus.REJECTED
        await db.commit()
        return msg

    # Processador de Actions (Batch ou Single)
    actions = []
    if not msg.action_data:
        logger.warning(f"AI Agent: Message {msg.id} has no action_data")
        raise HTTPException(status_code=400, detail="Mensagem não contém dados de ação")

    logger.info(f"AI Agent: Processing action_data: {msg.action_data}")
    if msg.action_data.get("type") == "batch":
        actions = msg.action_data.get("actions", [])
        logger.info(f"AI Agent: Batch mode with {len(actions)} actions")
    else:
        actions = [{"type": msg.action_data.get("type"), "payload": msg.action_data.get("payload", {})}]
        logger.info(f"AI Agent: Single action mode: {actions[0].get('type')}")

    try:
        # Se a sessão for geral, tentar vincular ao primeiro aluno detectado nas ações
        session = msg.session
        if not session.student_id:
            for action in actions:
                payload = action.get("payload", {})
                s_id = payload.get("student_id") or (payload.get("student_ids") and payload.get("student_ids")[0])
                if s_id:
                    try:
                        sid_uuid = UUID(str(s_id))
                        session.student_id = sid_uuid
                        # Atualizar título
                        student_res = await db.execute(select(User).where(User.id == sid_uuid))
                        student_obj = student_res.scalar_one_or_none()
                        if student_obj:
                            session.title = f"Treino: {student_obj.full_name}"
                        break
                    except: pass

        results = await _internal_execute_actions(db, current_user, actions)
        
        # Mark original message as executed BEFORE creating confirmation
        msg.action_status = AgentActionStatus.EXECUTED
        await db.commit()

        # Only create confirmation message AFTER successful commit
        success_msg = "✅ Executado com sucesso: " + ", ".join(results)
        confirm_msg = AgentMessage(session_id=msg.session_id, role="model", content=success_msg)
        db.add(confirm_msg)
        await db.commit()
        await db.refresh(confirm_msg)
        return confirm_msg

    except Exception as e:
        await db.rollback()
        logger.error(f"Execution Error: {e}")
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=500, detail=f"Erro ao executar: {str(e)}")

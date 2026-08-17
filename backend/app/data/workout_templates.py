"""
Workout Templates — Pre-defined workout programs.
Seeded directly (no table needed — statically defined in code).
"""

from typing import List, Dict, Any

WORKOUT_TEMPLATES: List[Dict[str, Any]] = [
    {
        "id": "ppl-push",
        "program": "PPL",
        "name": "Push — Peito, Ombros e Tríceps",
        "description": "Treino de empurrar do programa Push/Pull/Legs. Foco em desenvolvimento de peito, ombros e tríceps.",
        "level": "Intermediário",
        "duration_minutes": 60,
        "frequency": "3x por semana (alternado com Pull e Legs)",
        "equipment": "Academia completa",
        "goal": "Hipertrofia",
        "exercises": [
            {"name": "Supino Reto com Barra", "sets": 4, "reps_min": 8, "reps_max": 10, "rest_seconds": 90, "notes": "Desça até o peito tocar levemente"},
            {"name": "Supino Inclinado com Halteres", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Desenvolvimento com Halteres", "sets": 4, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Elevação Lateral", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
            {"name": "Elevação Frontal com Halteres", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
            {"name": "Tríceps Pulley", "sets": 4, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
            {"name": "Mergulho entre Bancos", "sets": 3, "reps_min": 10, "reps_max": 15, "rest_seconds": 60},
        ],
    },
    {
        "id": "ppl-pull",
        "program": "PPL",
        "name": "Pull — Costas e Bíceps",
        "description": "Treino de puxar do programa Push/Pull/Legs. Foco em desenvolvimento de costas e bíceps.",
        "level": "Intermediário",
        "duration_minutes": 60,
        "frequency": "3x por semana",
        "equipment": "Academia completa",
        "goal": "Hipertrofia",
        "exercises": [
            {"name": "Puxada Frontal", "sets": 4, "reps_min": 8, "reps_max": 10, "rest_seconds": 90},
            {"name": "Remada Curvada com Barra", "sets": 4, "reps_min": 8, "reps_max": 10, "rest_seconds": 90},
            {"name": "Remada Unilateral com Haltere", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Facepull", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
            {"name": "Rosca Direta com Barra", "sets": 4, "reps_min": 10, "reps_max": 12, "rest_seconds": 60},
            {"name": "Rosca Concentrada", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
        ],
    },
    {
        "id": "ppl-legs",
        "program": "PPL",
        "name": "Legs — Pernas e Glúteos",
        "description": "Treino de pernas do programa Push/Pull/Legs. Foco em quadríceps, posteriores e glúteos.",
        "level": "Intermediário",
        "duration_minutes": 70,
        "frequency": "3x por semana",
        "equipment": "Academia completa",
        "goal": "Hipertrofia",
        "exercises": [
            {"name": "Agachamento com Barra", "sets": 4, "reps_min": 6, "reps_max": 8, "rest_seconds": 120, "notes": "Desça até 90 graus ou abaixo"},
            {"name": "Leg Press 45°", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 90},
            {"name": "Extensão de Joelhos", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 75},
            {"name": "Mesa Flexora", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Elevação Pélvica / Hip Thrust", "sets": 4, "reps_min": 12, "reps_max": 15, "rest_seconds": 75},
            {"name": "Panturrilha em Pé", "sets": 4, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
        ],
    },
    {
        "id": "fullbody-a",
        "program": "Full Body Iniciante",
        "name": "Full Body A",
        "description": "Treino corpo inteiro para iniciantes. Alterna com Full Body B. Ótimo para adaptar o corpo à musculação.",
        "level": "Iniciante",
        "duration_minutes": 45,
        "frequency": "3x por semana (A/B/A - B/A/B)",
        "equipment": "Academia completa",
        "goal": "Condicionamento",
        "exercises": [
            {"name": "Agachamento com Body Weight ou Barra", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 90},
            {"name": "Supino Reto com Halteres", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Puxada Frontal", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Rosca Direta", "sets": 2, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
            {"name": "Tríceps Corda", "sets": 2, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
        ],
    },
    {
        "id": "fullbody-b",
        "program": "Full Body Iniciante",
        "name": "Full Body B",
        "description": "Versão B do treino corpo inteiro para iniciantes com exercícios complementares.",
        "level": "Iniciante",
        "duration_minutes": 45,
        "frequency": "3x por semana",
        "equipment": "Academia completa",
        "goal": "Condicionamento",
        "exercises": [
            {"name": "Leg Press 45°", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 90},
            {"name": "Supino Inclinado com Halteres", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Remada com Haltere", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 75},
            {"name": "Elevação Lateral", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 60},
            {"name": "Abdominais Crunch", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
            {"name": "Panturrilha Sentado", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
        ],
    },
    {
        "id": "hiit-3x",
        "program": "HIIT 3x Semana",
        "name": "HIIT Metabólico",
        "description": "Treino intervalado de alta intensidade. Máxima queima calórica em menos tempo. Ideal para emagrecimento.",
        "level": "Intermediário",
        "duration_minutes": 35,
        "frequency": "3x por semana com pelo menos 1 dia de descanso entre",
        "equipment": "Sem equipamento (peso corporal)",
        "goal": "Emagrecimento",
        "exercises": [
            {"name": "Burpee", "sets": 4, "duration_seconds": 30, "rest_seconds": 30, "notes": "Máxima velocidade"},
            {"name": "Mountain Climber", "sets": 4, "duration_seconds": 30, "rest_seconds": 30},
            {"name": "Agachamento com Salto", "sets": 4, "duration_seconds": 30, "rest_seconds": 30},
            {"name": "Flexão de Braços", "sets": 4, "duration_seconds": 30, "rest_seconds": 30},
            {"name": "Jumping Jack", "sets": 4, "duration_seconds": 30, "rest_seconds": 30},
            {"name": "Prancha Abdominal", "sets": 4, "duration_seconds": 40, "rest_seconds": 20, "notes": "Mantenha core ativado"},
        ],
    },
    {
        "id": "home-noequip",
        "program": "Treino em Casa",
        "name": "Corpo Inteiro — Sem Equipamento",
        "description": "Treino completo usando apenas o peso do corpo. Pode ser feito em qualquer lugar, a qualquer hora.",
        "level": "Iniciante",
        "duration_minutes": 40,
        "frequency": "3-4x por semana",
        "equipment": "Sem equipamento",
        "goal": "Saúde Geral",
        "exercises": [
            {"name": "Flexão de Braços", "sets": 3, "reps_min": 8, "reps_max": 15, "rest_seconds": 75, "notes": "Adapte: apoio nos joelhos se necessário"},
            {"name": "Agachamento com Peso Corporal", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
            {"name": "Afundo Alternado", "sets": 3, "reps_min": 10, "reps_max": 12, "rest_seconds": 60, "notes": "10-12 repetições por perna"},
            {"name": "Prancha Abdominal", "sets": 3, "duration_seconds": 30, "rest_seconds": 45},
            {"name": "Elevação de Quadril (Hip Bridge)", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 60},
            {"name": "Abdominal Crunch", "sets": 3, "reps_min": 15, "reps_max": 20, "rest_seconds": 45},
            {"name": "Superman (extensão de tronco)", "sets": 3, "reps_min": 12, "reps_max": 15, "rest_seconds": 45},
        ],
    },
    {
        "id": "stronglifts-a",
        "program": "StrongLifts 5x5",
        "name": "StrongLifts A — Força",
        "description": "Treino de força comprovado. Progressão linear de carga a cada sessão. Ideal para ganho de força.",
        "level": "Iniciante",
        "duration_minutes": 45,
        "frequency": "3x por semana (A/B/A - B/A/B)",
        "equipment": "Academia completa",
        "goal": "Força",
        "exercises": [
            {"name": "Agachamento com Barra", "sets": 5, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "Adicione 2.5kg a cada sessão"},
            {"name": "Supino Reto com Barra", "sets": 5, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "Adicione 2.5kg a cada sessão"},
            {"name": "Remada Curvada com Barra", "sets": 5, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "Adicione 2.5kg a cada sessão"},
        ],
    },
    {
        "id": "stronglifts-b",
        "program": "StrongLifts 5x5",
        "name": "StrongLifts B — Força",
        "description": "Versão B do StrongLifts 5x5 com exercícios complementares de força.",
        "level": "Iniciante",
        "duration_minutes": 45,
        "frequency": "3x por semana",
        "equipment": "Academia completa",
        "goal": "Força",
        "exercises": [
            {"name": "Agachamento com Barra", "sets": 5, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "Adicione 2.5kg a cada sessão"},
            {"name": "Desenvolvimento com Barra", "sets": 5, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "Adicione 2.5kg a cada sessão"},
            {"name": "Levantamento Terra", "sets": 1, "reps_min": 5, "reps_max": 5, "rest_seconds": 180, "notes": "1 série pesada. Adicione 5kg a cada sessão"},
        ],
    },
]


def get_all_templates() -> List[Dict[str, Any]]:
    return WORKOUT_TEMPLATES


def get_template_by_id(template_id: str) -> Dict[str, Any] | None:
    return next((t for t in WORKOUT_TEMPLATES if t["id"] == template_id), None)


def get_templates_by_program() -> Dict[str, List[Dict[str, Any]]]:
    programs: Dict[str, List[Dict[str, Any]]] = {}
    for t in WORKOUT_TEMPLATES:
        prog = t["program"]
        programs.setdefault(prog, []).append(t)
    return programs

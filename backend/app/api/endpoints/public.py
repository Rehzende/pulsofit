from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.future import select
from sqlalchemy.orm import contains_eager
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.models.user import User, UserRole
from app.models.trainer_profile import TrainerProfile
from app.schemas.marketplace import TrainerMarketplaceItem
import uuid as uuid_lib

router = APIRouter()


@router.get("/policy")
async def get_privacy_policy():
    """Retorna a política de privacidade e termos de uso do Pulso."""
    return {
        "app_name": "Pulso",
        "last_updated": "2025-01-01",
        "contact_email": "contato@pulsofit.com.br",
        "sections": [
            {
                "title": "Dados Coletados",
                "content": (
                    "Coletamos os seguintes dados para fornecer nossos serviços: "
                    "nome, e-mail, data de nascimento, informações de saúde e condicionamento físico "
                    "(anamnese, histórico médico, frequência cardíaca), dados de treino e sessões, "
                    "fotos de avaliação corporal, e token de dispositivo para notificações push."
                ),
            },
            {
                "title": "Finalidade do Uso",
                "content": (
                    "Seus dados são utilizados para: personalizar treinos e recomendações de IA, "
                    "calcular métricas de desempenho (XP, streak, nível), conectar alunos com treinadores, "
                    "enviar notificações relevantes sobre seus treinos, e melhorar a plataforma."
                ),
            },
            {
                "title": "Compartilhamento de Dados",
                "content": (
                    "Seus dados pessoais NÃO são vendidos a terceiros. "
                    "Dados de perfil público do treinador (nome, foto, bio, especialidades) são visíveis "
                    "na vitrine pública da plataforma. Dados de alunos são acessíveis apenas ao treinador "
                    "vinculado."
                ),
            },
            {
                "title": "Retenção de Dados",
                "content": (
                    "Seus dados são mantidos enquanto sua conta estiver ativa. "
                    "Ao solicitar a exclusão da conta, todos os seus dados pessoais são permanentemente "
                    "removidos de nossos sistemas em até 30 dias."
                ),
            },
            {
                "title": "Seus Direitos",
                "content": (
                    "Você tem direito a: acessar seus dados (GET /api/v1/users/me), "
                    "corrigir informações (PUT /api/v1/users/me), e excluir permanentemente sua conta "
                    "e todos os dados associados (DELETE /api/v1/users/me). "
                    "Para dúvidas, entre em contato pelo e-mail contato@pulsofit.com.br."
                ),
            },
            {
                "title": "Segurança",
                "content": (
                    "Utilizamos criptografia em trânsito (HTTPS/TLS) e autenticação segura via JWT "
                    "com tokens de curta duração. Senhas não são armazenadas em texto simples."
                ),
            },
            {
                "title": "Contato",
                "content": "Para exercer seus direitos ou esclarecer dúvidas: contato@pulsofit.com.br",
            },
        ],
    }


@router.get("/trainers/{slug}", response_model=TrainerMarketplaceItem)
async def get_public_trainer_profile(
    slug: str,
    db: AsyncSession = Depends(get_db),
):
    """Public trainer profile. Accepts slug (e.g. 'joao-silva') or UUID as fallback."""

    # Try to parse as UUID first (backward compat with old QR code links)
    try:
        trainer_id = uuid_lib.UUID(slug)
        query = (
            select(User)
            .join(TrainerProfile)
            .options(contains_eager(User.trainer_profile))
            .filter(User.id == trainer_id, User.role == UserRole.TRAINER)
        )
    except ValueError:
        # It's a slug
        query = (
            select(User)
            .join(TrainerProfile)
            .options(contains_eager(User.trainer_profile))
            .filter(TrainerProfile.slug == slug, User.role == UserRole.TRAINER)
        )

    result = await db.execute(query)
    user = result.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="Trainer not found")

    profile = user.trainer_profile

    return TrainerMarketplaceItem(
        user_id=user.id,
        full_name=user.full_name or "Trainer",
        photo_url=user.photo_url,
        brand_name=profile.brand_name if profile else None,
        logo_url=profile.logo_url if profile else None,
        bio=profile.bio if profile else None,
        specialties=profile.specialties if profile else None,
        hourly_rate=profile.hourly_rate if profile else None,
        whatsapp_number=(user.whatsapp_number or (profile.whatsapp_number if profile else None)),
        request_status="NONE",
    )

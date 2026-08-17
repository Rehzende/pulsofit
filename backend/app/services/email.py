import asyncio
from datetime import datetime
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
import resend
from app.core.config import settings

_template_dir = Path(__file__).parent.parent / "templates"
_jinja_env = Environment(loader=FileSystemLoader(str(_template_dir)), autoescape=True)


def _render(template_name: str, context: dict) -> str:
    return _jinja_env.get_template(template_name).render(**context)


def _send_sync(to_email: str, subject: str, html_content: str) -> None:
    if not settings.RESEND_API_KEY:
        raise RuntimeError("RESEND_API_KEY não configurada")
    resend.api_key = settings.RESEND_API_KEY
    resend.Emails.send({
        "from": f"{settings.MAIL_FROM_NAME} <{settings.MAIL_FROM}>",
        "to": [to_email],
        "subject": subject,
        "html": html_content,
    })


class EmailService:
    async def send_welcome_email(self, email_to: str, username: str, user_role: str, trainer_email: str = None):
        context = {
            "username": username,
            "project_name": settings.PROJECT_NAME,
            "email": email_to,
            "user_role": user_role,
        }
        if trainer_email:
            context["trainer_email"] = trainer_email

        html = _render("welcome.html", context)
        await asyncio.to_thread(_send_sync, email_to, "Bem-vindo ao PULSO!", html)

    async def send_invite_email(self, email_to: str, invite_link: str, trainer_name: str = None):
        context = {
            "project_name": settings.PROJECT_NAME,
            "invite_link": invite_link,
            "trainer_name": trainer_name,
        }
        html = _render("invite.html", context)
        await asyncio.to_thread(_send_sync, email_to, "Você foi convidado para o PULSO!", html)

    async def send_magic_link_email(self, email_to: str, magic_link_url: str, plain_token: str, short_code: str):
        context = {
            "project_name": settings.PROJECT_NAME,
            "magic_link_url": magic_link_url,
            "code": short_code,
        }
        html = _render("magic_link.html", context)
        await asyncio.to_thread(_send_sync, email_to, "Seu link mágico para o PULSO", html)

    async def send_account_deletion_email(self, email_to: str, username: str):
        context = {
            "username": username,
            "project_name": settings.PROJECT_NAME,
            "deletion_date": datetime.utcnow().strftime("%d/%m/%Y"),
        }
        html = _render("account_deletion.html", context)
        await asyncio.to_thread(_send_sync, email_to, f"Sua conta {settings.PROJECT_NAME} foi excluída", html)

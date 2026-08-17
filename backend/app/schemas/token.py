from pydantic import BaseModel, EmailStr
from typing import Optional

class Token(BaseModel):
    access_token: str
    token_type: str
    refresh_token: Optional[str] = None

class TokenPayload(BaseModel):
    sub: Optional[str] = None

# ── Magic Link Schemas ──────────────────────────────────
class MagicLinkRequest(BaseModel):
    email: EmailStr
    desired_role: Optional[str] = None  # 'TRAINER' or 'STUDENT'; ignored if user exists

class MagicLinkVerify(BaseModel):
    token: str
    email: Optional[EmailStr] = None

class MagicLinkResponse(BaseModel):
    message: str

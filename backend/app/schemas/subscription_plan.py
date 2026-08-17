from typing import Optional, Any
from pydantic import BaseModel
from uuid import UUID
from decimal import Decimal

class SubscriptionPlanBase(BaseModel):
    name: str
    price: Decimal
    max_students: int
    features: Optional[Any] = None
    is_active: Optional[bool] = True

class SubscriptionPlanCreate(SubscriptionPlanBase):
    pass

class SubscriptionPlanUpdate(SubscriptionPlanBase):
    name: Optional[str] = None
    price: Optional[Decimal] = None
    max_students: Optional[int] = None

class SubscriptionPlan(SubscriptionPlanBase):
    id: UUID

    class Config:
        from_attributes = True

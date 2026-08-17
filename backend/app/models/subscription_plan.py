import uuid
from sqlalchemy import Column, String, Integer, Boolean, Numeric, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from app.db.session import Base

class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    max_students = Column(Integer, nullable=False)
    features = Column(JSONB, nullable=True) # e.g. {"iot_enabled": true}
    is_active = Column(Boolean, default=True)

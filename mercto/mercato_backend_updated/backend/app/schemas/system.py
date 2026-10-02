import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr

from app.models.tenant import TenantRole


class NotificationOut(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str
    read_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TeamInviteRequest(BaseModel):
    email: EmailStr
    name: str
    password: str
    role: TenantRole = TenantRole.ADMIN_TENANT


class TeamMemberOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    role: TenantRole
    email: str
    name: str

    class Config:
        from_attributes = True

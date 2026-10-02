import uuid
from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.models.tenant import ContractStatus, TenantStatus


class TenantCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    slug: str = Field(min_length=2, max_length=64, pattern=r"^[a-z0-9-]+$")
    owner_email: EmailStr
    owner_name: str
    owner_password: str = Field(min_length=8)
    plan_id: uuid.UUID


class TenantOut(BaseModel):
    id: uuid.UUID
    code: str
    slug: str
    name: str
    status: TenantStatus
    logo_url: Optional[str] = None

    class Config:
        from_attributes = True


class TenantStatusUpdate(BaseModel):
    status: TenantStatus


class PlanCreateRequest(BaseModel):
    name: str
    max_products: int
    max_admins: int
    storage_limit_mb: int
    features_json: dict = {}


class PlanOut(BaseModel):
    id: uuid.UUID
    name: str
    max_products: int
    max_admins: int
    storage_limit_mb: int
    features_json: dict

    class Config:
        from_attributes = True


class ContractOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    plan_id: uuid.UUID
    status: ContractStatus
    version: int
    start_at: str
    end_at: Optional[str] = None

    class Config:
        from_attributes = True


class ThemeUpdateRequest(BaseModel):
    primary_color: Optional[str] = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    secondary_color: Optional[str] = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    background_color: Optional[str] = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    text_color: Optional[str] = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    logo_url: Optional[str] = None
    banner_url: Optional[str] = None
    font_family: Optional[str] = None


class ThemeOut(BaseModel):
    primary_color: str
    secondary_color: str
    background_color: str
    text_color: str
    logo_url: Optional[str] = None
    banner_url: Optional[str] = None
    font_family: Optional[str] = None

    class Config:
        from_attributes = True

import uuid
from typing import Optional

from pydantic import BaseModel, Field

from app.models.catalog import CategoryStatus, ProductStatus


class CategoryCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    slug: str = Field(min_length=1, max_length=150, pattern=r"^[a-z0-9-]+$")


class CategoryOut(BaseModel):
    id: uuid.UUID
    name: str
    slug: str
    status: CategoryStatus

    class Config:
        from_attributes = True


class ProductCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: Optional[str] = None
    price: float = Field(gt=0)
    stock: int = Field(ge=0, default=0)
    sku: str = Field(min_length=1, max_length=64)
    category_id: Optional[uuid.UUID] = None
    status: ProductStatus = ProductStatus.DRAFT


class ProductUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = Field(default=None, gt=0)
    stock: Optional[int] = Field(default=None, ge=0)
    category_id: Optional[uuid.UUID] = None
    status: Optional[ProductStatus] = None


class ProductOut(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str] = None
    price: float
    stock: int
    sku: str
    status: ProductStatus
    category_id: Optional[uuid.UUID] = None

    class Config:
        from_attributes = True

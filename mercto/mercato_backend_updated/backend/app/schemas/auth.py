import uuid

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=10)


class FacebookLoginRequest(BaseModel):
    access_token: str = Field(min_length=10)


class RegisterCustomerRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = Field(min_length=2, max_length=200)


class UserOut(BaseModel):
    id: uuid.UUID
    email: EmailStr
    name: str
    is_super_admin: bool

    class Config:
        from_attributes = True

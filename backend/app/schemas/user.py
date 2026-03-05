from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr

from app.models.enums import UserRole


class UserMeResponse(BaseModel):
    id: UUID
    email: EmailStr
    role: UserRole
    created_at: datetime

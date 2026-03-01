import os

os.environ["DATABASE_URL"] = "postgresql+psycopg://resol:resol@localhost:5432/resol_backend"
os.environ["REDIS_URL"] = "redis://localhost:6379/0"
os.environ["JWT_SECRET"] = "unit-test-secret-value-that-is-longer-than-32-chars"
os.environ["R2_ENDPOINT"] = "https://example.r2.cloudflarestorage.com"
os.environ["R2_BUCKET"] = "resol-private-bucket"
os.environ["R2_ACCESS_KEY_ID"] = "unit-test-access-key-id"
os.environ["R2_SECRET_ACCESS_KEY"] = "unit-test-secret-access-key"

from app.core.config import get_settings

get_settings.cache_clear()

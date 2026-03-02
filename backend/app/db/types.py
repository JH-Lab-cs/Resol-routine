from sqlalchemy import JSON, Text
from sqlalchemy.dialects.postgresql import JSONB

JSON_TYPE = JSON().with_variant(JSONB(astext_type=Text()), "postgresql")

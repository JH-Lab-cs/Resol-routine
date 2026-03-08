from enum import StrEnum


class ContentSyncEventType(StrEnum):
    UPSERT = "UPSERT"
    DELETE = "DELETE"


class ContentSyncEventReason(StrEnum):
    PUBLISHED = "PUBLISHED"
    ARCHIVED = "ARCHIVED"
    REPLACED = "REPLACED"
    UNPUBLISHED = "UNPUBLISHED"

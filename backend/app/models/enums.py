from enum import Enum


class UserRole(str, Enum):
    STUDENT = "STUDENT"
    PARENT = "PARENT"


class Track(str, Enum):
    M3 = "M3"
    H1 = "H1"
    H2 = "H2"
    H3 = "H3"


class Skill(str, Enum):
    LISTENING = "LISTENING"
    READING = "READING"


class MockExamType(str, Enum):
    WEEKLY = "WEEKLY"
    MONTHLY = "MONTHLY"


class WrongReasonTag(str, Enum):
    VOCAB = "VOCAB"
    EVIDENCE = "EVIDENCE"
    INFERENCE = "INFERENCE"
    CARELESS = "CARELESS"
    TIME = "TIME"


class AIGenerationJobType(str, Enum):
    MOCK_EXAM_REVISION_DRAFT_GENERATION = "MOCK_EXAM_REVISION_DRAFT_GENERATION"


class AIGenerationJobStatus(str, Enum):
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCEEDED = "SUCCEEDED"
    FAILED = "FAILED"


class SubscriptionFeatureCode(str, Enum):
    CHILD_REPORTS = "CHILD_REPORTS"
    WEEKLY_MOCK_EXAMS = "WEEKLY_MOCK_EXAMS"
    MONTHLY_MOCK_EXAMS = "MONTHLY_MOCK_EXAMS"


class SubscriptionPlanStatus(str, Enum):
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"


class UserSubscriptionStatus(str, Enum):
    TRIALING = "TRIALING"
    ACTIVE = "ACTIVE"
    GRACE = "GRACE"
    CANCELED = "CANCELED"
    EXPIRED = "EXPIRED"

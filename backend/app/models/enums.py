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


class ContentTypeTag(str, Enum):
    L_GIST = "L_GIST"
    L_DETAIL = "L_DETAIL"
    L_INTENT = "L_INTENT"
    L_RESPONSE = "L_RESPONSE"
    L_SITUATION = "L_SITUATION"
    L_LONG_TALK = "L_LONG_TALK"
    R_MAIN_IDEA = "R_MAIN_IDEA"
    R_DETAIL = "R_DETAIL"
    R_INFERENCE = "R_INFERENCE"
    R_BLANK = "R_BLANK"
    R_ORDER = "R_ORDER"
    R_INSERTION = "R_INSERTION"
    R_SUMMARY = "R_SUMMARY"
    R_VOCAB = "R_VOCAB"


class ContentSourcePolicy(str, Enum):
    AI_ORIGINAL = "AI_ORIGINAL"


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
    DEAD_LETTER = "DEAD_LETTER"


class AIContentGenerationCandidateStatus(str, Enum):
    VALID = "VALID"
    INVALID = "INVALID"
    MATERIALIZED = "MATERIALIZED"


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


class BillingProvider(str, Enum):
    STRIPE = "STRIPE"
    APP_STORE = "APP_STORE"


class BillingWebhookStatus(str, Enum):
    PROCESSED = "PROCESSED"
    IGNORED = "IGNORED"
    FAILED = "FAILED"


class BillingReceiptVerificationStatus(str, Enum):
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"
    ERROR = "ERROR"

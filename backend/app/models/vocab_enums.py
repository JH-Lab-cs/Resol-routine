from enum import Enum


class VocabSourceTag(str, Enum):  # noqa: UP042
    CSAT = "CSAT"
    SCHOOL_CORE = "SCHOOL_CORE"
    USER_CUSTOM = "USER_CUSTOM"

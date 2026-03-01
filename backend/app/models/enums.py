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

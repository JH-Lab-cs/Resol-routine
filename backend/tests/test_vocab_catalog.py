from __future__ import annotations

from sqlalchemy import inspect, select

from app.models.vocab_catalog_entry import VocabCatalogEntry
from app.services.vocab_catalog_service import (
    VocabCatalogImportRow,
    build_vocab_catalog_key,
    load_backend_catalog_seed_import_rows,
    seed_vocab_catalog,
)
from app.services.vocab_readiness_service import VocabReadinessRow, build_vocab_readiness_report


def test_vocab_catalog_table_has_unique_catalog_key(db_session_factory) -> None:
    with db_session_factory() as db:
        inspector = inspect(db.bind)
        table_names = inspector.get_table_names()
        assert "vocab_catalog_entries" in table_names
        unique_constraints = inspector.get_unique_constraints("vocab_catalog_entries")

    assert any(constraint["column_names"] == ["catalog_key"] for constraint in unique_constraints)


def test_vocab_catalog_key_is_deterministic() -> None:
    first = build_vocab_catalog_key(
        lemma=" Sell Out ",
        pos=" verb ",
        meaning="to have no more of something to sell",
    )
    second = build_vocab_catalog_key(
        lemma="sell   out",
        pos="verb",
        meaning="To have no more of something to sell",
    )

    assert first == second


def test_seed_vocab_catalog_is_idempotent(db_session_factory) -> None:
    seed_rows = load_backend_catalog_seed_import_rows()
    expected_catalog_count = len(
        {
            build_vocab_catalog_key(lemma=row.lemma, pos=row.pos, meaning=row.meaning)
            for row in seed_rows
            if row.source_tag != "USER_CUSTOM"
        }
    )

    with db_session_factory() as db:
        dry_run_result = seed_vocab_catalog(db, dry_run=True)
        assert dry_run_result["inserted"] == expected_catalog_count
        assert dry_run_result["sourceRowCount"] == len(seed_rows)
        assert db.execute(select(VocabCatalogEntry)).scalars().all() == []

    with db_session_factory() as db:
        first_result = seed_vocab_catalog(db, dry_run=False)
        db.commit()

    assert first_result["inserted"] == expected_catalog_count
    assert first_result["updated"] == 0
    assert first_result["invalid"] == 0

    with db_session_factory() as db:
        count = db.execute(select(VocabCatalogEntry)).scalars().all()
        assert len(count) == expected_catalog_count
        second_result = seed_vocab_catalog(db, dry_run=False)
        db.commit()

    assert second_result["inserted"] == 0
    assert second_result["updated"] == 0
    assert second_result["skipped"] == expected_catalog_count

    with db_session_factory() as db:
        count = db.execute(select(VocabCatalogEntry)).scalars().all()
        assert len(count) == expected_catalog_count


def test_seed_vocab_catalog_rejects_invalid_rows(db_session_factory) -> None:
    rows = [
        VocabCatalogImportRow(
            source_row_id="bad-source",
            lemma="register",
            pos="verb",
            meaning="to sign up",
            example="Students register online.",
            ipa="/x/",
            source_tag="BAD",
            target_min_track="M3",
            target_max_track="H1",
            difficulty_band=1,
            frequency_tier=1,
        ),
        VocabCatalogImportRow(
            source_row_id="bad-order",
            lemma="advanced",
            pos="adjective",
            meaning="far along in progress",
            example="She is advanced for her age.",
            ipa="/x/",
            source_tag="CSAT",
            target_min_track="H2",
            target_max_track="H1",
            difficulty_band=3,
            frequency_tier=2,
        ),
        VocabCatalogImportRow(
            source_row_id="user-custom",
            lemma="custom",
            pos="noun",
            meaning="a usual way of behaving",
            example="This is local custom.",
            ipa="/x/",
            source_tag="USER_CUSTOM",
            target_min_track="M3",
            target_max_track="H3",
            difficulty_band=2,
            frequency_tier=1,
        ),
    ]

    with db_session_factory() as db:
        result = seed_vocab_catalog(db, rows=rows, dry_run=False)
        db.commit()
        entries = db.execute(select(VocabCatalogEntry)).scalars().all()

    assert result["inserted"] == 0
    assert result["invalid"] == 2
    assert result["skipped"] == 1
    assert entries == []


def test_vocab_readiness_report_uses_backend_catalog_when_seeded(db_session_factory) -> None:
    with db_session_factory() as db:
        seed_vocab_catalog(db, dry_run=False)
        db.commit()

    with db_session_factory() as db:
        report = build_vocab_readiness_report(db)

    assert report["backendCatalogPresent"] is True
    assert report["sourceOfTruth"] == "BACKEND_CATALOG"
    assert report["serviceReadiness"] == "READY"
    assert report["tracks"]["M3"]["eligibleCount"] == 24
    assert report["tracks"]["H1"]["eligibleCount"] == 31
    assert report["tracks"]["H2"]["eligibleCount"] == 30
    assert report["tracks"]["H3"]["eligibleCount"] == 23
    assert report["metadataCoverage"]["sourceTagCounts"] == {"CSAT": 15, "SCHOOL_CORE": 16}
    assert report["metadataCoverage"]["difficultyBandCounts"] == {
        "1": 7,
        "2": 10,
        "3": 9,
        "4": 4,
        "5": 1,
    }


def test_vocab_readiness_report_marks_missing_metadata_not_ready(db_session_factory) -> None:
    compatibility_rows = [
        VocabReadinessRow(
            row_id="missing-band",
            source_tag="CSAT",
            target_min_track="M3",
            target_max_track="H1",
            difficulty_band=None,
            frequency_tier=1,
        )
    ]

    with db_session_factory() as db:
        report = build_vocab_readiness_report(db, compatibility_rows=compatibility_rows)

    assert report["backendCatalogPresent"] is False
    assert report["serviceReadiness"] == "NOT_READY"
    assert report["metadataCoverage"]["missingMetadataIds"] == ["missing-band"]

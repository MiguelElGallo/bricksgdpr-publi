"""Generate deterministic synthetic source extracts for the dbt demo."""

from __future__ import annotations

import csv
from datetime import date, datetime, timedelta
from pathlib import Path

RowValue = str | int | float | bool
Row = dict[str, RowValue]

SEED_DIR = Path(__file__).resolve().parents[1] / "seeds"
ACTIVE_CUSTOMERS = range(1, 15)
INACTIVE_CUSTOMER_NUMBER = 15
UNCONFIRMED_DELETION_CUSTOMER_NUMBER = 95
PENDING_DELETION_CUSTOMER_NUMBER = 97
LATE_CUSTOMER_NUMBER = 98
DELETED_CUSTOMER_NUMBER = 99
DELETED_CUSTOMER_HISTORICAL_SSN_NUMBER = 199

FIRST_NAMES = (
    "Aino",
    "Elias",
    "Sofia",
    "Leo",
    "Ella",
    "Oliver",
    "Emilia",
    "Noel",
    "Linnea",
    "Onni",
    "Helmi",
    "Eino",
    "Venla",
    "Miro",
)
LAST_NAMES = (
    "Demo",
    "Example",
    "Sample",
    "North",
    "Lake",
    "Forest",
    "Stone",
    "River",
    "Aurora",
    "Harbor",
    "Meadow",
    "Winter",
    "Summer",
    "Cloud",
)
CITIES = ("Helsinki", "Espoo", "Vantaa", "Tampere", "Turku", "Oulu", "Lahti")


def ssn(number: int) -> str:
    """Return a deliberately impossible demonstration SSN."""
    return f"900-00-{number:04d}"


def customer_id(number: int) -> str:
    return f"CUST-{number:04d}"


def service_id(number: int, suffix: str = "A") -> str:
    return f"SVC-{number:04d}-{suffix}"


def timestamp(day: int, hour: int = 9) -> str:
    safe_day = (day - 1) % 28 + 1
    return datetime(2026, 1, safe_day, hour).isoformat(timespec="seconds")


def write_seed(name: str, fieldnames: tuple[str, ...], rows: list[Row]) -> None:
    """Write one stable CSV with Unix newlines."""
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    with (SEED_DIR / f"{name}.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def active_customer_row(number: int) -> Row:
    index = (number - 1) % len(FIRST_NAMES)
    month = number % 12 + 1
    day = number % 27 + 1
    return {
        "customer_change_id": f"CCHG-{number:04d}-U",
        "customer_pk": number,
        "customer_id": customer_id(number),
        "customer_ssn": ssn(number),
        "first_name": FIRST_NAMES[index],
        "last_name": LAST_NAMES[index],
        "email": f"customer{number:02d}@example.invalid",
        "phone": f"+358-555-01{number:02d}",
        "birth_date": f"198{number % 10}-{month:02d}-{day:02d}",
        "address_line1": f"{100 + number} Demo Street",
        "address_line2": "",
        "city": CITIES[index % len(CITIES)],
        "postal_code": f"{number:05d}",
        "country_code": "FI",
        "customer_segment": ("household", "small_business", "enterprise")[number % 3],
        "is_active": True,
        "source_operation": "UPSERT",
        "source_updated_at": timestamp(number),
    }


def customer_rows() -> list[Row]:
    rows = [active_customer_row(number) for number in ACTIVE_CUSTOMERS]

    inactive_customer = active_customer_row(INACTIVE_CUSTOMER_NUMBER)
    inactive_customer["is_active"] = False
    rows.append(inactive_customer)

    rows.append(
        {
            "customer_change_id": "CCHG-0095-D",
            "customer_pk": UNCONFIRMED_DELETION_CUSTOMER_NUMBER,
            "customer_id": customer_id(UNCONFIRMED_DELETION_CUSTOMER_NUMBER),
            "customer_ssn": ssn(UNCONFIRMED_DELETION_CUSTOMER_NUMBER),
            "first_name": "",
            "last_name": "",
            "email": "",
            "phone": "",
            "birth_date": "",
            "address_line1": "",
            "address_line2": "",
            "city": "",
            "postal_code": "",
            "country_code": "",
            "customer_segment": "",
            "is_active": False,
            "source_operation": "DELETE",
            "source_updated_at": "2026-01-08T12:00:00",
        }
    )

    unconfirmed_upsert = active_customer_row(UNCONFIRMED_DELETION_CUSTOMER_NUMBER)
    unconfirmed_upsert.update(
        {
            "customer_change_id": "CCHG-0095-U",
            "first_name": "Unconfirmed",
            "last_name": "Request",
            "email": "unconfirmed.request@example.invalid",
            "source_updated_at": "2026-02-22T12:00:00",
        }
    )
    rows.append(unconfirmed_upsert)

    pending_delete: Row = {
        "customer_change_id": "CCHG-0097-D",
        "customer_pk": PENDING_DELETION_CUSTOMER_NUMBER,
        "customer_id": customer_id(PENDING_DELETION_CUSTOMER_NUMBER),
        "customer_ssn": ssn(PENDING_DELETION_CUSTOMER_NUMBER),
        "first_name": "",
        "last_name": "",
        "email": "",
        "phone": "",
        "birth_date": "",
        "address_line1": "",
        "address_line2": "",
        "city": "",
        "postal_code": "",
        "country_code": "",
        "customer_segment": "",
        "is_active": False,
        "source_operation": "DELETE",
        "source_updated_at": "2026-01-10T12:00:00",
    }
    rows.append(pending_delete)

    post_delete_upsert = active_customer_row(PENDING_DELETION_CUSTOMER_NUMBER)
    post_delete_upsert.update(
        {
            "customer_change_id": "CCHG-0097-U",
            "first_name": "Pending",
            "last_name": "Review",
            "email": "pending.review@example.invalid",
            "source_updated_at": "2026-02-20T12:00:00",
        }
    )
    rows.append(post_delete_upsert)

    deleted_upsert = active_customer_row(DELETED_CUSTOMER_NUMBER)
    deleted_upsert.update(
        {
            "customer_change_id": "CCHG-0099-U",
            "customer_ssn": ssn(DELETED_CUSTOMER_HISTORICAL_SSN_NUMBER),
            "first_name": "Deleted",
            "last_name": "Demonstration",
            "email": "deleted.customer@example.invalid",
            "phone": "+358-555-0199",
            "birth_date": "1975-09-09",
            "address_line1": "999 Erasure Avenue",
            "city": "Helsinki",
            "postal_code": "00999",
            "source_updated_at": "2026-01-05T09:00:00",
        }
    )
    rows.append(deleted_upsert)
    rows.append(
        {
            "customer_change_id": "CCHG-0099-D",
            "customer_pk": DELETED_CUSTOMER_NUMBER,
            "customer_id": customer_id(DELETED_CUSTOMER_NUMBER),
            "customer_ssn": ssn(DELETED_CUSTOMER_NUMBER),
            "first_name": "",
            "last_name": "",
            "email": "",
            "phone": "",
            "birth_date": "",
            "address_line1": "",
            "address_line2": "",
            "city": "",
            "postal_code": "",
            "country_code": "",
            "customer_segment": "",
            "is_active": False,
            "source_operation": "DELETE",
            "source_updated_at": "2026-02-15T12:00:00",
        }
    )
    return rows


def event_rows() -> list[Row]:
    rows: list[Row] = []
    event_number = 1
    for number in ACTIVE_CUSTOMERS:
        for offset, event_type in enumerate(("USAGE", "SUPPORT")):
            rows.append(
                {
                    "event_id": f"EVT-{event_number:04d}",
                    "customer_ssn": ssn(number),
                    "event_type": event_type,
                    "occurred_at": timestamp((number + offset) % 28 + 1, 10 + offset),
                    "measure_value": round(number * (1.25 + offset), 2),
                    "measure_unit": "GB" if event_type == "USAGE" else "MINUTES",
                    "source_updated_at": timestamp((number + offset) % 28 + 1, 13),
                }
            )
            event_number += 1
    for ssn_number, event_id in (
        (UNCONFIRMED_DELETION_CUSTOMER_NUMBER, "EVT-0095"),
        (PENDING_DELETION_CUSTOMER_NUMBER, "EVT-0097"),
        (LATE_CUSTOMER_NUMBER, "EVT-0098"),
        (DELETED_CUSTOMER_HISTORICAL_SSN_NUMBER, "EVT-0099"),
    ):
        rows.append(
            {
                "event_id": event_id,
                "customer_ssn": ssn(ssn_number),
                "event_type": "USAGE",
                "occurred_at": "2026-02-20T08:00:00",
                "measure_value": 9.5,
                "measure_unit": "GB",
                "source_updated_at": "2026-02-20T09:00:00",
            }
        )
    return rows


def service_row(number: int, suffix: str = "A") -> Row:
    valid_from = date(2025, 1, 1) + timedelta(days=number)
    valid_to = date(2027, 12, 31)
    if number == 14:
        valid_to = date(2024, 12, 31)
    return {
        "service_id": service_id(number, suffix),
        "customer_ssn": ssn(number),
        "service_type": "INTERNET" if suffix == "A" else "MOBILE",
        "installation_address_line1": f"{200 + number} Installation Road",
        "installation_address_line2": f"Unit {suffix}" if suffix != "A" else "",
        "installation_city": CITIES[(number + 2) % len(CITIES)],
        "installation_postal_code": f"{20000 + number}",
        "installation_country_code": "FI",
        "is_valid": True,
        "valid_from": valid_from.isoformat(),
        "valid_to": valid_to.isoformat(),
        "source_updated_at": "2026-02-01T10:00:00",
    }


def service_rows() -> list[Row]:
    rows = [service_row(number) for number in ACTIVE_CUSTOMERS]
    rows.extend(service_row(number, "B") for number in (1, 2, 3))
    invalid_flag = service_row(13, "B")
    invalid_flag["is_valid"] = False
    rows.append(invalid_flag)
    rows.append(service_row(UNCONFIRMED_DELETION_CUSTOMER_NUMBER))
    rows.append(service_row(PENDING_DELETION_CUSTOMER_NUMBER))
    rows.append(service_row(LATE_CUSTOMER_NUMBER))
    deleted_service = service_row(DELETED_CUSTOMER_NUMBER)
    deleted_service["customer_ssn"] = ssn(DELETED_CUSTOMER_HISTORICAL_SSN_NUMBER)
    rows.append(deleted_service)
    return rows


def invoice_rows() -> list[Row]:
    rows: list[Row] = []
    invoice_number = 1
    for number in ACTIVE_CUSTOMERS:
        for sequence in (1, 2):
            issue_date = date(2026, sequence, min(number, 27))
            if number == 1 and sequence == 2:
                issue_date = date(2026, 1, 1)
            due_date = issue_date + timedelta(days=30)
            is_paid = sequence == 1 or number % 4 == 0
            paid_at = (issue_date + timedelta(days=10)).isoformat() if is_paid else ""
            if number == 13 and sequence == 2:
                paid_at = (issue_date + timedelta(days=5)).isoformat()
            rows.append(
                {
                    "invoice_id": f"INV-{invoice_number:04d}",
                    "customer_ssn": ssn(number),
                    "service_id": service_id(number),
                    "amount": round(45.0 + number * 3.25 + sequence, 2),
                    "currency_code": "EUR",
                    "issued_date": issue_date.isoformat(),
                    "due_date": due_date.isoformat(),
                    "is_paid": is_paid,
                    "paid_at": paid_at,
                    "is_due": not is_paid and due_date < date(2026, 3, 1),
                    "source_updated_at": "2026-02-28T18:00:00",
                }
            )
            invoice_number += 1

    rows.extend(
        [
            {
                "invoice_id": "INV-0101",
                "customer_ssn": ssn(12),
                "service_id": service_id(12),
                "amount": 88.0,
                "currency_code": "EUR",
                "issued_date": "2026-01-05",
                "due_date": "2026-02-04",
                "is_paid": True,
                "paid_at": "",
                "is_due": False,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0102",
                "customer_ssn": ssn(11),
                "service_id": service_id(11),
                "amount": 77.0,
                "currency_code": "EUR",
                "issued_date": "2026-02-10",
                "due_date": "2026-02-01",
                "is_paid": False,
                "paid_at": "",
                "is_due": True,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0103",
                "customer_ssn": ssn(10),
                "service_id": service_id(10),
                "amount": 66.0,
                "currency_code": "EUR",
                "issued_date": "2026-01-10",
                "due_date": "2026-02-09",
                "is_paid": True,
                "paid_at": "2026-01-05",
                "is_due": False,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0104",
                "customer_ssn": ssn(1),
                "service_id": service_id(2),
                "amount": 55.0,
                "currency_code": "EUR",
                "issued_date": "2026-01-10",
                "due_date": "2026-02-09",
                "is_paid": False,
                "paid_at": "",
                "is_due": True,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0105",
                "customer_ssn": ssn(1),
                "service_id": "SVC-7777-A",
                "amount": 44.0,
                "currency_code": "EUR",
                "issued_date": "2026-01-10",
                "due_date": "2026-02-09",
                "is_paid": False,
                "paid_at": "",
                "is_due": True,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0106",
                "customer_ssn": ssn(1),
                "service_id": service_id(1),
                "amount": 33.0,
                "currency_code": "EUR",
                "issued_date": "2028-01-05",
                "due_date": "2028-02-04",
                "is_paid": False,
                "paid_at": "",
                "is_due": False,
                "source_updated_at": "2026-02-28T18:00:00",
            },
            {
                "invoice_id": "INV-0107",
                "customer_ssn": ssn(1),
                "service_id": service_id(DELETED_CUSTOMER_NUMBER),
                "amount": 22.0,
                "currency_code": "EUR",
                "issued_date": "2026-01-10",
                "due_date": "2026-02-09",
                "is_paid": False,
                "paid_at": "",
                "is_due": True,
                "source_updated_at": "2026-02-28T18:00:00",
            },
        ]
    )
    for number, source_ssn_number, invoice_id in (
        (
            UNCONFIRMED_DELETION_CUSTOMER_NUMBER,
            UNCONFIRMED_DELETION_CUSTOMER_NUMBER,
            "INV-0095",
        ),
        (
            PENDING_DELETION_CUSTOMER_NUMBER,
            PENDING_DELETION_CUSTOMER_NUMBER,
            "INV-0097",
        ),
        (LATE_CUSTOMER_NUMBER, LATE_CUSTOMER_NUMBER, "INV-0098"),
        (
            DELETED_CUSTOMER_NUMBER,
            DELETED_CUSTOMER_HISTORICAL_SSN_NUMBER,
            "INV-0099",
        ),
    ):
        rows.append(
            {
                "invoice_id": invoice_id,
                "customer_ssn": ssn(source_ssn_number),
                "service_id": service_id(number),
                "amount": 99.0,
                "currency_code": "EUR",
                "issued_date": "2026-02-01",
                "due_date": "2026-03-03",
                "is_paid": False,
                "paid_at": "",
                "is_due": False,
                "source_updated_at": "2026-02-28T18:00:00",
            }
        )
    return rows


def main() -> None:
    write_seed(
        "customer",
        (
            "customer_change_id",
            "customer_pk",
            "customer_id",
            "customer_ssn",
            "first_name",
            "last_name",
            "email",
            "phone",
            "birth_date",
            "address_line1",
            "address_line2",
            "city",
            "postal_code",
            "country_code",
            "customer_segment",
            "is_active",
            "source_operation",
            "source_updated_at",
        ),
        customer_rows(),
    )
    write_seed(
        "customer_events",
        (
            "event_id",
            "customer_ssn",
            "event_type",
            "occurred_at",
            "measure_value",
            "measure_unit",
            "source_updated_at",
        ),
        event_rows(),
    )
    write_seed(
        "customer_services",
        (
            "service_id",
            "customer_ssn",
            "service_type",
            "installation_address_line1",
            "installation_address_line2",
            "installation_city",
            "installation_postal_code",
            "installation_country_code",
            "is_valid",
            "valid_from",
            "valid_to",
            "source_updated_at",
        ),
        service_rows(),
    )
    write_seed(
        "invoices",
        (
            "invoice_id",
            "customer_ssn",
            "service_id",
            "amount",
            "currency_code",
            "issued_date",
            "due_date",
            "is_paid",
            "paid_at",
            "is_due",
            "source_updated_at",
        ),
        invoice_rows(),
    )


if __name__ == "__main__":
    main()

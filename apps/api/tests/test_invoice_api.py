"""Rechnungsprüfung über die HTTP-Schnittstelle – so wie eine Automatisierung sie benutzt."""

from __future__ import annotations

from fastapi.testclient import TestClient
from test_tibber_invoice import build_invoice, minimal_pdf

MAY = dict(
    number="4957137",
    month="Mai 2026",
    issued="4. Juni 2026",
    start="1. Mai 2026",
    end="31. Mai 2026",
    kwh=305.05,
    meter_start=59959.45,
    days=31,
)


def upload(client: TestClient, text: str, name: str = "Rechnung.pdf") -> dict:
    r = client.post(
        f"/api/v1/import/tibber-invoice?file_name={name}",
        content=minimal_pdf(text.splitlines()),
        headers={"content-type": "application/pdf"},
    )
    assert r.status_code == 200, r.text
    return r.json()


def test_upload_check_list_and_detail(client: TestClient) -> None:
    report = upload(client, build_invoice())
    assert report["invoice"]["number"] == "5085697"
    assert report["verdict"] in ("ok", "info", "warning")
    assert report["already_known"] is False
    assert report["file_name"] == "Rechnung.pdf"
    codes = {f["code"] for f in report["findings"]}
    assert {"positions_sum", "total_gross", "vat", "meter_delta"} <= codes
    assert all(f["severity"] != "error" for f in report["findings"])
    # der Abgleich mit eigenen Daten ist immer dabei – mit Vergleichswert oder als klarer Hinweis
    assert {"measured_kwh", "no_measurement"} & codes

    listing = client.get("/api/v1/import/tibber-invoices").json()
    assert [i["number"] for i in listing] == ["5085697"]
    assert listing[0]["period_label"] == "Juni 2026" and listing[0]["problems"] >= 0

    detail = client.get("/api/v1/import/tibber-invoices/5085697").json()
    assert detail["invoice"]["kwh"] == report["invoice"]["kwh"]
    assert client.get("/api/v1/import/tibber-invoices/999").status_code == 404


def test_repeated_upload_is_idempotent(client: TestClient) -> None:
    upload(client, build_invoice())
    again = upload(client, build_invoice())
    assert again["already_known"] is True
    assert len(client.get("/api/v1/import/tibber-invoices").json()) == 1


def test_meter_chain_across_two_invoices(client: TestClient) -> None:
    upload(client, build_invoice(**MAY))
    june = upload(client, build_invoice())
    chain = next(f for f in june["findings"] if f["code"] == "meter_chain")
    assert chain["severity"] == "ok" and chain["expected"] == 60264.50
    assert len(client.get("/api/v1/import/tibber-invoices").json()) == 2


def test_manipulated_invoice_is_rejected_as_error(client: TestClient) -> None:
    report = upload(client, build_invoice(amounts={"Stromsteuer": 15.15}, energy_net=72.32))
    assert report["verdict"] == "error"
    bad = [f for f in report["findings"] if f["severity"] == "error"]
    assert {f["code"] for f in bad} >= {"position:Stromsteuer", "positions_sum"}
    assert bad[0]["delta"] is not None


def test_unreadable_upload_gives_a_clear_error(client: TestClient) -> None:
    r = client.post(
        "/api/v1/import/tibber-invoice",
        content=minimal_pdf(["Stadtwerke Musterstadt", "Betrag 100 EUR"]),
        headers={"content-type": "application/pdf"},
    )
    assert r.status_code == 422 and "Tibber" in r.json()["error"]["message"]
    empty = client.post("/api/v1/import/tibber-invoice", content=b"")
    assert empty.status_code == 400

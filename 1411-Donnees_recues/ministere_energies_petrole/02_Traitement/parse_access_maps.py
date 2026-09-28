#!/usr/bin/env python3
"""Extract printed 2024 electricity-access indicators from regional maps."""

from __future__ import annotations

import csv
import json
import re
import unicodedata
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parents[3]
SOURCE_DIR = ROOT / "1411-Donnees_recues/ministere_energies_petrole/00_original/cartes_documents_pdf"
OUTPUT_DIR = ROOT / "1411-Donnees_recues/ministere_energies_petrole/03_valide"
METADATA_DIR = ROOT / "1411-Donnees_recues/ministere_energies_petrole/04_metadonnees"
BOUNDARIES_PATH = ROOT / "GeoJson/wilaya_boundaries_from_docs.geojson"
CSV_PATH = OUTPUT_DIR / "indicateurs_acces_electricite_wilaya_2024.csv"
GEOJSON_PATH = OUTPUT_DIR / "acces_electricite_wilaya_2024.geojson"
REPORT_PATH = METADATA_DIR / "extraction_acces_electricite_2024.json"

PDF_AREAS = {
    "ADRAR": "MR07", "ASSABA": "MR03", "BRAKNA": "MR05",
    "DAKHLET NOUADHIBOU": "MR08", "GORGOL": "MR04",
    "GUIDIMAGHA": "MR10", "HODH CHARGUI": "MR01",
    "HODH GHARBY": "MR02", "INCHIRI": "MR12", "TAGANT": "MR09",
    "TIRIS": "MR11", "TRARZA": "MR06",
}
CSV_FIELDS = [
    "id_object", "admin_code", "wilaya_name", "reference_year", "population", "subscribers",
    "access_rate_pct", "electrified_localities", "total_localities",
    "localities_population_over_300", "localities_population_over_500",
    "localities_population_over_1000", "geometry_wkt", "source", "source_page",
    "extraction_method", "validation_status", "date_saisie", "notes",
]
GEOJSON_FIELDS = tuple(field for field in CSV_FIELDS if field != "geometry_wkt")
OPTIONAL_FIELDS = (
    "electrified_localities", "localities_population_over_300",
    "localities_population_over_500", "localities_population_over_1000",
)


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    return " ".join(text.encode("ascii", "ignore").decode("ascii").upper().split())


def find_integer(text: str, pattern: str) -> int | None:
    match = re.search(pattern, text)
    return int(match.group(1).replace(" ", "")) if match else None


def polygon_to_wkt(geometry: dict) -> str:
    if geometry["type"] != "Polygon":
        raise ValueError(f"Expected Polygon boundary, got {geometry['type']}")
    rings = []
    for ring in geometry["coordinates"]:
        points = ", ".join(
            f"{longitude:.8f} {latitude:.8f}"
            for longitude, latitude, *_ in ring
        )
        rings.append(f"({points})")
    return "POLYGON(" + ", ".join(rings) + ")"


def extract_indicators(text: str) -> dict[str, int | float | None]:
    text = normalize(text)
    rates = re.findall(r"([0-9]+(?:[,.][0-9]+)?)\s*%", text)
    if len(rates) != 1:
        raise ValueError(f"Expected one access-rate percentage, found {rates!r}")
    values = {
        "population": find_integer(text, r"POPULATION\s+([0-9 ]+?)\s*HAB"),
        "subscribers": find_integer(text, r"ABONNES\s+([0-9 ]+?)\s*AB"),
        "access_rate_pct": float(rates[0].replace(",", ".")),
        "electrified_localities": find_integer(text, r"LOCALITES\s+ELECTRIFIEES\s+([0-9]+)"),
        "total_localities": find_integer(text, r"NOMBRE TOTAL DE LOCALITES\s+([0-9 ]+?)\s*LOC"),
        "localities_population_over_300": find_integer(text, r"LOCALITES DE PLUS DE 300 HABITANTS\s+([0-9]+)"),
        "localities_population_over_500": find_integer(text, r"LOCALITES DE PLUS DE 500 HABITANTS\s+([0-9]+)"),
        "localities_population_over_1000": find_integer(text, r"LOCALITES DE PLUS DE 1000 HABITANTS\s+([0-9]+)"),
    }
    required = ("population", "subscribers", "access_rate_pct", "total_localities")
    missing = [field for field in required if values[field] is None]
    if missing:
        raise ValueError(f"Missing required indicators: {', '.join(missing)}")
    if not 0 <= values["access_rate_pct"] <= 100:
        raise ValueError(f"Access rate outside 0-100: {values['access_rate_pct']}")
    if values["electrified_localities"] is not None and values["electrified_localities"] > values["total_localities"]:
        raise ValueError("Electrified localities exceed total localities")
    return values


def main() -> None:
    boundary_data = json.loads(BOUNDARIES_PATH.read_text(encoding="utf-8"))
    boundaries = {feature["properties"]["id"]: feature for feature in boundary_data["features"]}
    expected_codes = {f"MR{number:02d}" for number in range(1, 16)}
    if set(boundaries) != expected_codes:
        raise ValueError("Administrative boundary codes do not match MR01-MR15")
    source_files = sorted(SOURCE_DIR.glob("*.pdf"))
    if len(source_files) != len(PDF_AREAS):
        raise ValueError(f"Expected {len(PDF_AREAS)} PDFs, found {len(source_files)}")

    rows = []
    source_documents = []
    seen_codes = set()
    date_saisie = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    for source_path in source_files:
        pdf_name = re.sub(r"\s+2024(?:\s+\(\d+\))?$", "", normalize(source_path.stem))
        area_code = PDF_AREAS.get(pdf_name)
        if area_code is None or area_code in seen_codes:
            raise ValueError(f"Unmapped or duplicate PDF: {source_path.name}")
        document = pymupdf.open(source_path)
        if len(document) != 1:
            raise ValueError(f"Expected one-page regional map: {source_path.name}")
        page_text = document[0].get_text()
        if len(page_text.strip()) < 300:
            raise ValueError(f"Insufficient text layer: {source_path.name}")
        values = extract_indicators(page_text)
        area_name = boundaries[area_code]["properties"]["name"]
        missing_optional = [field for field in OPTIONAL_FIELDS if values[field] is None]
        notes = ["Source does not define the access-rate denominator"]
        if missing_optional:
            notes.append("Source does not expose: " + ", ".join(missing_optional))
        rows.append({
            "id_object": f"{area_code}-2024",
            "admin_code": area_code, "wilaya_name": area_name, "reference_year": 2024,
            **values,
            "geometry_wkt": polygon_to_wkt(boundaries[area_code]["geometry"]),
            "source": f"00_original/cartes_documents_pdf/{source_path.name}",
            "source_page": 1,
            "extraction_method": "pymupdf_text_layer",
            "validation_status": "automatically_extracted_needs_visual_review",
            "date_saisie": date_saisie, "notes": "; ".join(notes),
        })
        seen_codes.add(area_code)
        source_documents.append({
            "source_pdf": source_path.name, "admin_code": area_code,
            "wilaya_name": area_name, "page_count": len(document),
            "text_characters": len(page_text), "text_layer_present": True,
            "extraction_method": "pymupdf_text_layer", "fields_missing": missing_optional,
        })

    missing_codes = sorted(expected_codes - seen_codes)
    missing_rows = [{
        "id_object": f"{code}-2024",
        "admin_code": code,
        "wilaya_name": boundaries[code]["properties"]["name"],
        "reference_year": 2024,
        **{field: None for field in (
            "population", "subscribers", "access_rate_pct", "electrified_localities",
            "total_localities", "localities_population_over_300",
            "localities_population_over_500", "localities_population_over_1000",
        )},
        "geometry_wkt": polygon_to_wkt(boundaries[code]["geometry"]),
        "source": None,
        "source_page": None,
        "extraction_method": None,
        "validation_status": "source_document_missing",
        "date_saisie": date_saisie,
        "notes": "No regional 2024 PDF was present in the supplied folder",
    } for code in missing_codes]
    all_rows = sorted(rows + missing_rows, key=lambda row: row["admin_code"])
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    METADATA_DIR.mkdir(parents=True, exist_ok=True)
    with CSV_PATH.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(all_rows)

    features = [{
        "type": "Feature", "id": row["admin_code"],
        "geometry": deepcopy(boundaries[row["admin_code"]]["geometry"]),
        "properties": {field: row[field] for field in GEOJSON_FIELDS},
    } for row in all_rows]
    access_geojson = {
        "type": "FeatureCollection",
        "metadata": {
            "title": "Accès à l'électricité par wilaya, 2024",
            "source_organization": "DGENER, Ministère du Pétrole, des Mines et de l'Energie",
            "source_directory": "00_original/cartes_documents_pdf",
            "coordinate_reference": "EPSG:4326 (longitude, latitude)",
            "geometry_source": "GeoJson/wilaya_boundaries_from_docs.geojson",
            "join_key": "properties.admin_code",
            "notes": [
                "Valeurs issues des libellés imprimés, sans numériser les symboles de la carte.",
                "Le dénominateur du taux d'accès n'est pas défini dans les PDF.",
                "Les wilayas sans PDF sont présentes avec des mesures nulles.",
            ],
        },
        "features": features,
    }
    GEOJSON_PATH.write_text(json.dumps(access_geojson, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = {
        "title": "Extraction des indicateurs d'accès à l'électricité par wilaya",
        "reference_year": 2024,
        "date_saisie": date_saisie,
        "source_organization": "DGENER, Ministère du Pétrole, des Mines et de l'Energie",
        "extraction_method": "PyMuPDF text layer; OCR not required",
        "source_pdf_count": len(source_documents), "wilaya_count": len(expected_codes),
        "covered_admin_codes": sorted(seen_codes), "missing_admin_codes": missing_codes,
        "field_semantics": {
            "id_object": "Stable identifier composed from administrative code and reference year.",
            "access_rate_pct": "Printed access rate; denominator not stated by source.",
            "electrified_localities": "Printed count; null when the map has no count.",
            "localities_population_over_300": "Count of localities over 300 inhabitants.",
            "localities_population_over_500": "Count of localities over 500 inhabitants.",
            "localities_population_over_1000": "Count of localities over 1000 inhabitants.",
            "geometry_wkt": "Polygon copied from the administrative boundary source, EPSG:4326.",
            "source": "Relative PDF path; null when no regional PDF was supplied.",
            "date_saisie": "UTC timestamp at which this extraction was generated.",
        },
        "quality_notes": [
            "All 12 supplied PDFs are one-page maps with extractable text.",
            "Extracted figures require visual review against their source page.",
            "Three Nouakchott wilayas have no corresponding PDF in the supplied folder.",
        ],
        "source_documents": source_documents,
        "outputs": [str(CSV_PATH.relative_to(ROOT)).replace("\\", "/"), str(GEOJSON_PATH.relative_to(ROOT)).replace("\\", "/")],
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(rows)} wilayas; {len(missing_codes)} source gaps; wrote the CSV, GeoJSON, and metadata report")


if __name__ == "__main__":
    main()
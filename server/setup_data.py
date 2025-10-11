#!/usr/bin/env python3
import csv
import json
import re
import uuid
import time
from pathlib import Path
from datetime import datetime

RAW_CSV_PATH = Path("./rawdata.csv")
OUTPUT_ROOT  = Path.home() / "money_note"

DATE_RE = re.compile(r"^'?(?P<yy>\d{2})\s+(?P<m>\d{1,2})/(?P<d>\d{1,2})")

def parse_date(date_str: str) -> datetime:
    s = (date_str or "").strip()
    m = DATE_RE.match(s)
    if not m:
        raise ValueError(f"날짜 파싱 실패: {date_str!r}")
    yy = int(m.group("yy"))
    year = 2000 + yy if yy <= 69 else 1900 + yy
    month = int(m.group("m"))
    day = int(m.group("d"))
    return datetime(year, month, day, 0, 0, 0, 0)

def clean_number(s: str) -> str:
    if s is None:
        return ""
    s = s.strip().replace(",", "").replace('"', '').replace("'", "")
    return s if s else ""

def detect_kind_and_amount(col5: str, col6: str):
    n5 = clean_number(col5)
    n6 = clean_number(col6)
    has5 = n5.isdigit() or (n5.startswith("-") and n5[1:].isdigit())
    has6 = n6.isdigit() or (n6.startswith("-") and n6[1:].isdigit())

    if has5 and has6:
        raise ValueError(f"수입(5열)과 지출(6열) 둘 다 숫자값 존재: {col5!r}, {col6!r}")
    if has5:
        return 0, n5
    if has6:
        return 1, n6
    return None, None

def build_record(row):
    """CSV 한 행을 변환"""
    date_str = row[0] if len(row) > 0 else ""
    dt = parse_date(date_str)

    try:
        kind, amount = detect_kind_and_amount(
            row[4] if len(row) > 4 else "",
            row[5] if len(row) > 5 else ""
        )
    except ValueError as e:
        print(f"[경고] {e}  → 행 스킵 ({row})")
        return None

    if kind is None or amount is None:
        return None

    content = (row[6] if len(row) > 6 else "").strip()

    rec = {
        "id": str(uuid.uuid4()),
        "dateTime": dt.strftime("%Y-%m-%dT00:00:00.000"),
        "kind": int(kind),
        "budget": "none",
        "amount": amount,
        "content": content,
        "memo": ""
    }
    return rec, dt.strftime("%Y%m")

def read_csv_rows(csv_path: Path):
    """CSV 행 읽기"""
    for enc in ("utf-8-sig", "utf-8", "cp949"):
        try:
            with csv_path.open("r", encoding=enc, newline="") as f:
                reader = csv.reader(f)
                for row in reader:
                    yield row
            break
        except UnicodeDecodeError:
            continue

def main():
    if not RAW_CSV_PATH.exists():
        raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {RAW_CSV_PATH}")

    by_month = {}
    for row in read_csv_rows(RAW_CSV_PATH):
        if not row or all((c.strip() == "" for c in row)):
            continue
        try:
            out = build_record(row)
        except Exception as e:
            print(f"[오류] {e} → 행 스킵 ({row})")
            continue

        if out is None:
            continue
        record, month_key = out
        by_month.setdefault(month_key, []).append(record)

    now_ms = int(time.time() * 1000)
    for month_key, records in by_month.items():
        out_dir = OUTPUT_ROOT / month_key
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{now_ms}.json"

        payload = {"records": records}
        with out_path.open("w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        print(f"✅ 저장 완료: {out_path}")

if __name__ == "__main__":
    main()

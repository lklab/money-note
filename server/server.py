import os
import json
import time
import uuid
from pathlib import Path
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
import uvicorn
from threading import Lock

# -----------------------------
# 경로/상수
# -----------------------------
HOME_DIR = Path.home()
ROOT_DIR = HOME_DIR / "money_note"
CONFIG_DIR = Path(".") / ".config"            # 서버 '실행 위치' 기준
KEY_FILE = CONFIG_DIR / "key.json"
PORT = 37265

# 동시성 보호
month_locks: Dict[str, Lock] = {}
key_lock = Lock()

# -----------------------------
# 유틸
# -----------------------------
def ensure_dirs():
    ROOT_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

def load_or_create_keys() -> List[str]:
    ensure_dirs()
    if not KEY_FILE.exists():
        rand_key = uuid.uuid4().hex + uuid.uuid4().hex  # 64 hex chars
        data = {"keys": [rand_key]}
        KEY_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        return [rand_key]
    else:
        try:
            data = json.loads(KEY_FILE.read_text(encoding="utf-8"))
            keys = data.get("keys", [])
            if not isinstance(keys, list) or not keys or not all(isinstance(k, str) for k in keys):
                raise ValueError("invalid key.json format")
            return keys
        except Exception:
            rand_key = uuid.uuid4().hex + uuid.uuid4().hex
            data = {"keys": [rand_key]}
            KEY_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            return [rand_key]

def check_auth_header(x_api_key: Optional[str]):
    keys = load_or_create_keys()
    if not x_api_key or x_api_key not in keys:
        raise HTTPException(status_code=401, detail="invalid key")

def month_dir_name(month: int) -> str:
    m = str(month)
    if len(m) != 6 or not m.isdigit():
        raise HTTPException(status_code=400, detail="month must be in yyyyMM integer format")
    return m

def get_month_dir(month: int) -> Path:
    d = ROOT_DIR / month_dir_name(month)
    d.mkdir(parents=True, exist_ok=True)
    return d

def now_epoch_ms() -> int:
    return int(time.time() * 1000)

def parse_ts_from_filename(name: str) -> Optional[int]:
    try:
        stem = Path(name).stem
        ts = int(stem)
        if ts > 10**12:
            return ts               # ms
        elif ts > 10**8:
            return ts * 1000        # s -> ms
        else:
            return None
    except Exception:
        return None

def list_month_files(month: int) -> List[Path]:
    d = ROOT_DIR / month_dir_name(month)
    if not d.exists():
        return []
    return sorted([p for p in d.glob("*.json") if p.is_file()],
                  key=lambda p: (parse_ts_from_filename(p.name) or 0))

def read_json_safely(path: Path) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None

PRUNE_WINDOW_MS = 24 * 3600 * 1000

def prune_files_within_24h_for_month(month: int, new_file_ts_ms: int, new_file_path: Path):
    """new_file_ts_ms 기준으로 지난 24시간 내(포함)의 기존 파일들을 모두 삭제 (신규 파일 제외)"""
    files = list_month_files(month)
    cutoff_ms = new_file_ts_ms - PRUNE_WINDOW_MS
    for f in files:
        if f == new_file_path:
            continue
        ts_ms = parse_ts_from_filename(f.name)
        if ts_ms is None:
            continue

        if cutoff_ms <= ts_ms < new_file_ts_ms:
            try:
                f.unlink(missing_ok=True)
            except Exception:
                pass

# -----------------------------
# 스키마(Pydantic)
# -----------------------------
class RecordItem(BaseModel):
    id: str
    dateTime: str
    kind: int
    budget: str
    amount: str
    content: str
    memo: str

class PostRecordBody(BaseModel):
    month: int
    records: List[RecordItem]

# -----------------------------
# FastAPI 앱
# -----------------------------
app = FastAPI(title="Money Note API", version="1.2.0")  # [CHANGED] 버전 업데이트

@app.on_event("startup")
def _startup():
    ensure_dirs()
    load_or_create_keys()

def get_month_lock(mstr: str) -> Lock:
    if mstr not in month_locks:
        month_locks[mstr] = Lock()
    return month_locks[mstr]

@app.get("/records")
def get_records(x_api_key: Optional[str] = Header(None, alias="X-API-Key")):
    """
    모든 월 폴더에서 '가장 최신' 파일을 하나씩 읽고, records를 합쳐서 반환
    인증: X-API-Key 헤더
    """
    check_auth_header(x_api_key)

    if not ROOT_DIR.exists():
        return {"records": []}

    merged: List[Dict[str, Any]] = []
    for child in ROOT_DIR.iterdir():
        if not child.is_dir():
            continue
        if len(child.name) == 6 and child.name.isdigit():
            files = sorted(
                [p for p in child.glob("*.json") if p.is_file()],
                key=lambda p: (parse_ts_from_filename(p.name) or 0)
            )
            if not files:
                continue
            latest = files[-1]
            data = read_json_safely(latest)
            if not data:
                continue
            recs = data.get("records", [])
            if isinstance(recs, list):
                for r in recs:
                    if isinstance(r, dict):
                        v = r.get("amount")
                        if isinstance(v, int):
                            r["amount"] = str(v)
                        elif not isinstance(v, str):
                            r["amount"] = str(v)
                        merged.append(r)

    return {"records": merged}

@app.post("/record")
def post_record(
    body: PostRecordBody,
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    """
    ~/money_note/{yyyyMM}/{timestamp}.json 생성 후 '24시간 이내 파일 삭제' 정책 적용
    인증: X-API-Key 헤더
    """
    check_auth_header(x_api_key)

    now = datetime.now()
    this_month = now.year * 100 + now.month

    current_year = this_month // 100
    current_month = this_month % 100

    def add_months(y, m, delta):
        y += (m + delta - 1) // 12
        m = (m + delta - 1) % 12 + 1
        return y * 100 + m

    min_month = add_months(current_year, current_month, -12)
    max_month = add_months(current_year, current_month, +1)

    if not (min_month <= body.month <= max_month):
        raise HTTPException(
            status_code=400,
            detail=f"month {body.month} out of allowed range ({min_month} ~ {max_month})"
        )

    if len(body.records) > 999:
        raise HTTPException(status_code=413, detail="too many records (max 999)")

    for idx, r in enumerate(body.records):
        for field_name, value in r.model_dump().items():
            if isinstance(value, str) and len(value) > 255:
                raise HTTPException(
                    status_code=422,
                    detail=f"record[{idx}].{field_name} exceeds 255 characters"
                )

    mname = month_dir_name(body.month)
    lock = get_month_lock(mname)

    with lock:
        month_path = get_month_dir(body.month)
        ts_ms = now_epoch_ms()
        out_file = month_path / f"{ts_ms}.json"

        to_save = {
            "records": [
                {
                    "id": r.id,
                    "dateTime": r.dateTime,
                    "kind": r.kind,
                    "budget": r.budget,
                    "amount": str(r.amount),
                    "content": r.content,
                    "memo": r.memo,
                }
                for r in body.records
            ]
        }

        out_file.write_text(json.dumps(to_save, ensure_ascii=False, indent=2), encoding="utf-8")
        prune_files_within_24h_for_month(body.month, ts_ms, out_file)

    return {"status": "ok", "saved": len(body.records)}

@app.get("/refresh")
def refresh_key(x_api_key: Optional[str] = Header(None, alias="X-API-Key")):
    if not x_api_key:
        raise HTTPException(status_code=401, detail="invalid key")

    with key_lock:
        keys = load_or_create_keys()
        if x_api_key not in keys:
            raise HTTPException(status_code=401, detail="invalid key")

        new_key = uuid.uuid4().hex + uuid.uuid4().hex
        new_keys = [new_key if k == x_api_key else k for k in keys]

        try:
            KEY_FILE.write_text(json.dumps({"keys": new_keys}, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"failed to update key file: {e}")

    return {"key": new_key}

if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=PORT, reload=False)

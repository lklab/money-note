import os
import json
import time
import uuid
from pathlib import Path
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, Field
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

class BudgetItem(BaseModel):
    id: str
    name: str
    kind: int          # 0: income, 1: expense
    assetType: int     # 0: cash, 1: capital
    amount: str

class BudgetGroupItem(BaseModel):
    id: str
    name: str
    budgets: List[BudgetItem]

class MonthlyBudgetItem(BaseModel):
    monthKey: int      # yyyyMM
    groups: List[BudgetGroupItem]

class PostBackupDataBody(BaseModel):
    month: int
    records: List[RecordItem] = Field(default_factory=list)
    monthlyBudgets: List[MonthlyBudgetItem] = Field(default_factory=list)

def _validate_string_lengths_in_dict(d: Any, path: str = ""):
    """
    dict/list 안의 모든 str 필드가 255자를 넘지 않는지 확인.
    256자 이상이면 422.
    """
    if isinstance(d, dict):
        for k, v in d.items():
            _validate_string_lengths_in_dict(v, f"{path}.{k}" if path else k)
    elif isinstance(d, list):
        for i, v in enumerate(d):
            _validate_string_lengths_in_dict(v, f"{path}[{i}]")
    else:
        if isinstance(d, str) and len(d) > 255:
            raise HTTPException(
                status_code=422,
                detail=f"field '{path}' exceeds 255 characters"
            )

def _ensure_amount_str(obj: Any, key: str = "amount"):
    """
    obj[key]가 존재한다면 문자열로 강제 변환.
    """
    if isinstance(obj, dict) and key in obj:
        v = obj[key]
        obj[key] = str(v)

def _normalize_backupdata_payload(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    GET 응답 병합 및 POST 저장 직전에 amount류를 문자열로 강제.
    """
    # records
    recs = data.get("records", [])
    if isinstance(recs, list):
        for r in recs:
            if isinstance(r, dict):
                _ensure_amount_str(r, "amount")

    # monthlyBudgets -> groups -> budgets -> amount
    mbs = data.get("monthlyBudgets", [])
    if isinstance(mbs, list):
        for mb in mbs:
            if not isinstance(mb, dict):
                continue
            groups = mb.get("groups", [])
            if isinstance(groups, list):
                for g in groups:
                    if not isinstance(g, dict):
                        continue
                    budgets = g.get("budgets", [])
                    if isinstance(budgets, list):
                        for b in budgets:
                            if isinstance(b, dict):
                                _ensure_amount_str(b, "amount")

    return data

def _add_months(year: int, month: int, delta: int) -> int:
    y = year + (month + delta - 1) // 12
    m = (month + delta - 1) % 12 + 1
    return y * 100 + m

def _check_month_range_or_400(month_yyyymm: int):
    now = datetime.now()
    this_month = now.year * 100 + now.month
    cur_y, cur_m = this_month // 100, this_month % 100
    min_month = _add_months(cur_y, cur_m, -12)
    max_month = _add_months(cur_y, cur_m, +1)
    if not (min_month <= month_yyyymm <= max_month):
        raise HTTPException(
            status_code=400,
            detail=f"month {month_yyyymm} out of allowed range ({min_month} ~ {max_month})"
        )

def _check_array_limits_or_error(body: PostBackupDataBody):
    """
    모든 최상위 배열( records, monthlyBudgets )은 999개까지 허용.
    또한 monthlyBudgets 내부 groups/budgets도 999개까지 허용(안전한 상한선).
    """
    if len(body.records) > 999:
        raise HTTPException(status_code=413, detail="too many records (max 999)")
    if len(body.monthlyBudgets) > 999:
        raise HTTPException(status_code=413, detail="too many monthlyBudgets (max 999)")
    for i, mb in enumerate(body.monthlyBudgets):
        if len(mb.groups) > 999:
            raise HTTPException(status_code=413, detail=f"monthlyBudgets[{i}].groups exceeds 999")
        for j, g in enumerate(mb.groups):
            if len(g.budgets) > 999:
                raise HTTPException(status_code=413, detail=f"monthlyBudgets[{i}].groups[{j}].budgets exceeds 999")

def _check_string_lengths_backupdata_or_422(body: PostBackupDataBody):
    """
    body 전체를 dict로 변환해 255 초과 문자열이 있는지 검사.
    """
    body_dict = json.loads(body.model_dump_json())
    _validate_string_lengths_in_dict(body_dict)

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

@app.get("/backupdata")
def get_backupdata(x_api_key: Optional[str] = Header(None, alias="X-API-Key")):
    check_auth_header(x_api_key)

    merged_records: List[Dict[str, Any]] = []
    merged_monthly_budgets: List[Dict[str, Any]] = []

    if ROOT_DIR.exists():
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

                # normalize amounts => string
                data = _normalize_backupdata_payload(data)

                # records
                recs = data.get("records", [])
                if isinstance(recs, list):
                    for r in recs:
                        if isinstance(r, dict):
                            merged_records.append(r)

                # monthlyBudgets
                mbs = data.get("monthlyBudgets", [])
                if isinstance(mbs, list):
                    for mb in mbs:
                        if isinstance(mb, dict):
                            merged_monthly_budgets.append(mb)

    return {
        "records": merged_records,
        "monthlyBudgets": merged_monthly_budgets,
    }

# [ADD] ===== POST /backupdata =====
@app.post("/backupdata")
def post_backupdata(
    body: PostBackupDataBody,
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
):
    check_auth_header(x_api_key)

    # 월 범위 검사
    _check_month_range_or_400(body.month)

    # 배열 상한 검사
    _check_array_limits_or_error(body)

    # 문자열 길이 검사
    _check_string_lengths_backupdata_or_422(body)

    # 동시성 잠금
    mname = month_dir_name(body.month)
    lock = get_month_lock(mname)

    with lock:
        month_path = get_month_dir(body.month)
        ts_ms = now_epoch_ms()
        out_file = month_path / f"{ts_ms}.json"

        # dict 변환 + amount 문자열화
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
            ],
            "monthlyBudgets": [
                {
                    "monthKey": mb.monthKey,
                    "groups": [
                        {
                            "id": g.id,
                            "name": g.name,
                            "budgets": [
                                {
                                    "id": b.id,
                                    "name": b.name,
                                    "kind": b.kind,
                                    "assetType": b.assetType,
                                    "amount": str(b.amount),
                                }
                                for b in g.budgets
                            ],
                        }
                        for g in mb.groups
                    ],
                }
                for mb in body.monthlyBudgets
            ],
        }

        # amount를 안전하게 문자열로 통일
        to_save = _normalize_backupdata_payload(to_save)

        out_file.write_text(json.dumps(to_save, ensure_ascii=False, indent=2), encoding="utf-8")
        prune_files_within_24h_for_month(body.month, ts_ms, out_file)

    saved_rec_count = len(body.records)
    saved_mb_count = len(body.monthlyBudgets)
    return {"status": "ok", "saved": {"records": saved_rec_count, "monthlyBudgets": saved_mb_count}}

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

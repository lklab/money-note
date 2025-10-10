import os
import json
import time
import uuid
import random
import string
from pathlib import Path
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, Body, HTTPException
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
MIN_KEEP_FILES = 5
PRUNE_OLDER_THAN_SECS = 48 * 3600  # 48 hours

# 동시성 보호(월별)
month_locks: Dict[str, Lock] = {}

# -----------------------------
# 유틸
# -----------------------------
def ensure_dirs():
    ROOT_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

def load_or_create_keys() -> List[str]:
    """
    ./.config/key.json 을 읽고 없으면 생성.
    {"keys":["<랜덤키>"]} 구조.
    """
    ensure_dirs()
    if not KEY_FILE.exists():
        # 충분히 긴 랜덤 문자열 생성 (64자 url-safe)
        rand_key = uuid.uuid4().hex + uuid.uuid4().hex  # 64 hex chars
        data = {"keys": [rand_key]}
        KEY_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        return [rand_key]
    else:
        try:
            data = json.loads(KEY_FILE.read_text(encoding="utf-8"))
            keys = data.get("keys", [])
            if not isinstance(keys, list) or not all(isinstance(k, str) for k in keys) or not keys:
                raise ValueError("invalid key.json format")
            return keys
        except Exception:
            # 손상 시 새로 생성
            rand_key = uuid.uuid4().hex + uuid.uuid4().hex
            data = {"keys": [rand_key]}
            KEY_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            return [rand_key]

def check_auth(key: Optional[str]):
    keys = load_or_create_keys()
    if key not in keys:
        raise HTTPException(status_code=401, detail="invalid key")

def month_dir_name(month: int) -> str:
    # 202510 -> "202510"
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
    """
    파일명 '1234567890.json' 또는 '1234567890123.json' 등에서 정수부를 추출해 epoch 밀리초로 반환.
    초 단위로 보이는 숫자는 ms로 변환.
    """
    try:
        stem = Path(name).stem
        ts = int(stem)
        # 자릿수 판별: 13자리 이상이면 ms, 10자리 전후면 s 로 보고 변환
        if ts > 10**12:   # >= ~2001년 이후 ms 가능
            return ts
        elif ts > 10**8:  # 초로 보임 → ms 변환
            return ts * 1000
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

def prune_old_files_for_month(month: int):
    """
    규칙:
      - 48시간 이전 파일만 후보
      - 오래된 것부터 삭제
      - 단, 항상 최소 MIN_KEEP_FILES(=5)개는 남긴다
    """
    files = list_month_files(month)
    if len(files) <= MIN_KEEP_FILES:
        return

    cutoff_ms = now_epoch_ms() - (PRUNE_OLDER_THAN_SECS * 1000)
    # 오래된(파일명 타임스탬프 기준) 것부터 순회
    kept = len(files)
    for f in files:
        if kept <= MIN_KEEP_FILES:
            break
        ts_ms = parse_ts_from_filename(f.name)
        if ts_ms is None:
            # 이름이 이상하면 과감히 건너뜀 (보존)
            continue
        if ts_ms <= cutoff_ms:
            try:
                f.unlink(missing_ok=True)
                kept -= 1
            except Exception:
                # 삭제 실패 시 무시하고 진행(보존으로 간주)
                pass

def read_json_safely(path: Path) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None

# -----------------------------
# 스키마(Pydantic)
# -----------------------------
class AuthBody(BaseModel):
    key: str

class GetRecordsBody(AuthBody):
    pass  # GET에서도 body를 사용(요구사항 준수)

class RecordItem(BaseModel):
    id: str
    dateTime: str
    kind: int
    budget: str
    amount: str  # 64비트 정수도 문자열로 저장
    content: str
    memo: str

class PostRecordBody(AuthBody):
    month: int
    records: List[RecordItem]

# -----------------------------
# FastAPI 앱
# -----------------------------
app = FastAPI(title="Money Note API", version="1.0.0")

@app.on_event("startup")
def _startup():
    ensure_dirs()
    load_or_create_keys()

def get_month_lock(mstr: str) -> Lock:
    if mstr not in month_locks:
        month_locks[mstr] = Lock()
    return month_locks[mstr]

@app.get("/records")
def get_records(body: GetRecordsBody = Body(...)):
    """
    모든 월 폴더에서 '가장 최신' 파일을 하나씩 읽고, records를 합쳐서 반환
    """
    check_auth(body.key)
    # 모든 yyyyMM 디렉터리 순회
    if not ROOT_DIR.exists():
        return {"records": []}

    merged: List[Dict[str, Any]] = []
    for child in ROOT_DIR.iterdir():
        if not child.is_dir():
            continue
        # yyyyMM 형식만
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
                # amount는 문자열로 보장되도록 가볍게 정규화
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
def post_record(body: PostRecordBody):
    """
    특정 월의 records를 저장:
      - ~/money_note/{yyyyMM}/{timestamp}.json 생성
      - 저장 후 보존 규칙 적용
      - 응답: {}
    """
    check_auth(body.key)

    mname = month_dir_name(body.month)
    lock = get_month_lock(mname)

    with lock:
        month_path = get_month_dir(body.month)
        ts_ms = now_epoch_ms()
        out_file = month_path / f"{ts_ms}.json"

        # 저장 데이터 구성 (64비트 숫자는 문자열)
        to_save = {
            "records": [
                {
                    "id": r.id,
                    "dateTime": r.dateTime,
                    "kind": r.kind,
                    "budget": r.budget,
                    "amount": str(r.amount),  # 혹시 숫자 들어와도 문자열화
                    "content": r.content,
                    "memo": r.memo,
                }
                for r in body.records
            ]
        }

        out_file.write_text(json.dumps(to_save, ensure_ascii=False, indent=2), encoding="utf-8")

        # 보존 규칙 적용
        prune_old_files_for_month(body.month)

    return {}

# -----------------------------
# 메인
# -----------------------------
if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=PORT, reload=False)

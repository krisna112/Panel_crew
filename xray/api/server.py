import os, subprocess, json, uuid
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

XRAY_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
UTILS = os.path.join(XRAY_DIR, 'utils.sh')
GEN_REALITY = os.path.join(XRAY_DIR, 'gen_vless_reality.sh')
GEN_VMESS = os.path.join(XRAY_DIR, 'gen_vmess_ws_tls.sh')

app = FastAPI(title="Panel Crew – Xray API", version="1.0")

class VlessRealityReq(BaseModel):
    port: int = Field(443, ge=1, le=65535)
    server_name: str = Field("www.cloudflare.com", min_length=3)
    uuid_str: str | None = None

class VmessWSReq(BaseModel):
    domain: str
    port: int = 443
    uuid_str: str | None = None
    ws_path: str = "/ws"

@app.get("/health")
def health():
    return {"ok": True}

@app.post("/generate/vless-reality")
def gen_vless_reality(req: VlessRealityReq):
    uuid_str = req.uuid_str or str(uuid.uuid4())
    cmd = ["bash", GEN_REALITY, str(req.port), req.server_name, uuid_str]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return {"ok": True, "uuid": uuid_str, "log": out}
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=400, detail=e.output)

@app.post("/generate/vmess-ws")
def gen_vmess_ws(req: VmessWSReq):
    uuid_str = req.uuid_str or str(uuid.uuid4())
    cmd = ["bash", GEN_VMESS, req.domain, str(req.port), uuid_str, req.ws_path]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return {"ok": True, "uuid": uuid_str, "log": out}
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=400, detail=e.output)

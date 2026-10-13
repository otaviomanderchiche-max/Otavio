"""EcoMonitor Desktop: painel local Windows para sensores ESP32.

O site e a API local rodam em 127.0.0.1 (sem nuvem). A janela e renderizada
por Microsoft Edge WebView2 usando pywebview. Este arquivo e empacotado como EXE.
"""
from __future__ import annotations

import argparse
import json
import locale
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import threading
import time
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import urlopen
import webbrowser

APP_NAME = "EcoMonitor"
ESP32_SSID = "EcoMonitor-ESP32"
ESP32_PASSWORD = "EcoMonitor2026"
ESP32_HOST = "http://192.168.4.1"
APP_TOKEN = secrets.token_urlsafe(28)
ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).parent))
ASSETS = ROOT / "assets"


def _run_netsh(*args: str) -> tuple[int, str]:
    if os.name != "nt":
        return 1, "A conexao automatica so funciona no Windows."
    try:
        flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        proc = subprocess.run(
            ["netsh", "wlan", *args], capture_output=True, timeout=14,
            creationflags=flags,
        )
        encoding = "mbcs" if os.name == "nt" else locale.getpreferredencoding(False)
        text = (proc.stdout + b"\n" + proc.stderr).decode(encoding, errors="replace")
        return proc.returncode, text.strip()
    except Exception as exc:
        return 1, str(exc)


def current_ssid() -> str | None:
    _, output = _run_netsh("show", "interfaces")
    matches = re.findall(r"^\s*SSID\s*:\s*(.+?)\s*$", output, re.M | re.I)
    return matches[0].strip() if matches else None


def available_networks() -> list[dict]:
    rc, output = _run_netsh("show", "networks", "mode=bssid")
    if rc != 0:
        return []
    lines = output.splitlines()
    found = {}
    current = None
    for line in lines:
        match = re.match(r"\s*SSID\s+\d+\s*:\s*(.*?)\s*$", line, re.I)
        if match:
            current = match.group(1)
            if current:
                found.setdefault(current, {"ssid": current, "signal": None})
            continue
        if current:
            signal = re.match(r"\s*(?:Sinal|Signal|Señal)\s*:\s*(\d+)%", line, re.I)
            if signal:
                percentage = int(signal.group(1))
                prior = found[current]["signal"]
                found[current]["signal"] = max(prior or 0, percentage)
    return sorted(found.values(), key=lambda item: (item["ssid"] != ESP32_SSID, -(item["signal"] or 0)))


def esp_get(endpoint: str, timeout: float = 2.5) -> dict:
    # Apenas endpoints predeterminados, sem redirecionamento arbitrario do usuario.
    if endpoint not in {"/api/status", "/api/readings"}:
        raise ValueError("Endpoint nao autorizado")
    with urlopen(ESP32_HOST + endpoint, timeout=timeout) as reply:
        if reply.status != 200:
            raise ValueError("ESP32 retornou HTTP " + str(reply.status))
        data = reply.read(16384)
    parsed = json.loads(data)
    if not isinstance(parsed, dict):
        raise ValueError("Resposta inesperada do ESP32")
    return parsed


def connect_wifi() -> dict:
    if os.name != "nt":
        return {"ok": False, "message": "Esta versao e destinada ao Windows 10/11."}
    if current_ssid() == ESP32_SSID:
        try:
            esp_get("/api/status", timeout=3)
            return {"ok": True, "message": "ESP32 ja conectado."}
        except Exception:
            pass
    # Apenas cria/usa o perfil do ESP32 apos o usuario clicar em Conectar.
    profile = f'''<?xml version="1.0" encoding="utf-8"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
<name>{escape(ESP32_SSID)}</name>
<SSIDConfig><SSID><name>{escape(ESP32_SSID)}</name></SSID></SSIDConfig>
<connectionType>ESS</connectionType><connectionMode>manual</connectionMode>
<MSM><security><authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
<sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>{escape(ESP32_PASSWORD)}</keyMaterial></sharedKey>
</security></MSM>
</WLANProfile>'''
    path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8-sig", suffix=".xml", delete=False) as f:
            f.write(profile)
            path = f.name
        rc, details = _run_netsh("add", "profile", "filename=" + path, "user=current")
        if rc != 0:
            return {"ok": False, "message": "Nao consegui configurar o Wi-Fi: " + details[:300]}
        rc, details = _run_netsh("connect", "name=" + ESP32_SSID, "ssid=" + ESP32_SSID)
        if rc != 0:
            return {"ok": False, "message": "Falha ao iniciar conexao: " + details[:300]}
        for _ in range(18):
            time.sleep(1.3)
            if current_ssid() == ESP32_SSID:
                try:
                    esp_get("/api/status", timeout=1.7)
                    return {"ok": True, "message": "Conectado. Painel recebendo leituras reais."}
                except Exception:
                    continue
        return {"ok": False, "message": "A rede foi solicitada, mas o ESP32 nao respondeu. Verifique a conexao Wi-Fi e tente novamente."}
    finally:
        if path:
            try:
                os.unlink(path)
            except OSError:
                pass


class EcoHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        return

    def _reply(self, code: int, payload: bytes, content_type: str = "application/json; charset=utf-8") -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self' http://192.168.4.1; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data: http://192.168.4.1; connect-src 'self'; frame-src http://192.168.4.1;")
        self.end_headers()
        try:
            self.wfile.write(payload)
        except BrokenPipeError:
            pass

    def _json(self, code: int, obj: dict | list) -> None:
        self._reply(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"))

    def _authorized(self) -> bool:
        return self.headers.get("X-EcoMonitor-Token") == APP_TOKEN

    def do_GET(self):
        uri = self.path.split("?", 1)[0]
        if uri == "/":
            # Segredo embutido apenas na resposta de origem local, nao em URL compartilhada.
            html = (ASSETS / "index.html").read_text(encoding="utf-8")
            html = html.replace("__APP_TOKEN__", APP_TOKEN)
            self._reply(200, html.encode("utf-8"), "text/html; charset=utf-8")
            return
        if uri == "/assets/forest.jpg":
            self._reply(200, (ASSETS / "forest.jpg").read_bytes(), "image/jpeg")
            return
        if uri == "/favicon.ico":
            self._reply(204, b"", "image/x-icon")
            return
        if not self._authorized():
            return self._json(403, {"ok": False, "message": "Sessao nao autorizada"})
        if uri == "/api/scan":
            return self._json(200, {"networks": available_networks(), "ssid": current_ssid()})
        if uri == "/api/health":
            ssid = current_ssid()
            try:
                esp_get("/api/status", timeout=1.5)
                online = True
            except Exception:
                online = False
            return self._json(200, {"online": online, "ssid": ssid, "device": ESP32_SSID, "url": ESP32_HOST})
        if uri == "/api/readings":
            try:
                readings = esp_get("/api/readings", timeout=2.2)
                return self._json(200, {"online": True, "readings": readings})
            except Exception as exc:
                return self._json(200, {"online": False, "message": str(exc)[:160]})
        self._json(404, {"message": "Nao encontrado"})

    def do_POST(self):
        uri = self.path.split("?", 1)[0]
        if not self._authorized():
            return self._json(403, {"ok": False, "message": "Sessao nao autorizada"})
        if uri == "/api/connect":
            return self._json(200, connect_wifi())
        if uri == "/api/open-settings":
            if os.name == "nt":
                try:
                    os.startfile("ms-settings:network-wifi")
                    return self._json(200, {"ok": True})
                except Exception as exc:
                    return self._json(200, {"ok": False, "message": str(exc)})
            return self._json(200, {"ok": False, "message": "Somente Windows"})
        self._json(404, {"message": "Nao encontrado"})


def start_server() -> ThreadingHTTPServer:
    server = ThreadingHTTPServer(("127.0.0.1", 0), EcoHandler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True, name="EcoMonitor local API").start()
    return server


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", action="store_true", help="Abrir como site no navegador (modo desenvolvimento)")
    args = parser.parse_args()
    server = start_server()
    home = "http://127.0.0.1:" + str(server.server_port) + "/"
    try:
        if args.browser:
            webbrowser.open(home)
            print(home, flush=True)
            while True:
                time.sleep(1)
        else:
            import webview
            webview.create_window(
                "EcoMonitor | Blue Birds", home,
                width=1260, height=840, min_size=(960, 630),
                background_color="#F5F7F5", text_select=True,
            )
            webview.start(gui="edgechromium", debug=False)
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
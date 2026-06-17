#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import http.client
import ssl
import json
import logging
import socket
import sys
import time
from pathlib import Path
from urllib import parse, request
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = BASE_DIR / "config.json"


def setup_logging(verbose: bool, log_file: Path) -> None:
    handlers = [logging.FileHandler(log_file, encoding="utf-8")]
    if verbose:
        handlers.append(logging.StreamHandler(sys.stdout))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=handlers,
    )


def load_config(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"找不到配置文件: {path}")

    with path.open("r", encoding="utf-8-sig") as f:
        config = json.load(f)

    required = ["login_url", "method", "username", "password", "fields"]
    missing = [key for key in required if key not in config]
    if missing:
        raise ValueError(f"配置缺少字段: {', '.join(missing)}")

    return config


def tcp_check(host: str, port: int, timeout: float) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def http_check(url: str, timeout: float, expect_status: int | None, expect_text: str | None) -> bool:
    try:
        req = request.Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 campus-auto-login connectivity-check",
                "Cache-Control": "no-cache",
            },
            method="GET",
        )
        with request.urlopen(req, timeout=timeout) as resp:
            text = resp.read(200).decode("utf-8", errors="replace")
            if expect_status is not None and resp.status != expect_status:
                return False
            if expect_text is not None and expect_text not in text:
                return False
            return True
    except Exception:
        return False


def is_online(config: dict) -> bool:
    http_checks = config.get("online_http_checks") or []
    if http_checks:
        for item in http_checks:
            if http_check(
                item["url"],
                float(item.get("timeout", 3)),
                item.get("expect_status"),
                item.get("expect_text"),
            ):
                return True
        return False

    checks = config.get("online_checks") or [
        {"host": "223.5.5.5", "port": 53, "timeout": 2},
        {"host": "114.114.114.114", "port": 53, "timeout": 2},
    ]

    for item in checks:
        if tcp_check(item["host"], int(item.get("port", 53)), float(item.get("timeout", 2))):
            return True
    return False


def get_local_ip(config: dict) -> str:
    target_host = config.get("connect_host") or urlsplit(config["login_url"]).hostname
    target_port = int(config.get("connect_port", 80))
    if not target_host:
        return ""

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect((target_host, target_port))
        return sock.getsockname()[0]
    except OSError:
        return ""
    finally:
        sock.close()


def build_fields(config: dict) -> dict:
    fields = {}
    local_ip = None
    for key, value in config["fields"].items():
        if isinstance(value, str):
            if "{local_ip}" in value and local_ip is None:
                local_ip = get_local_ip(config)
            fields[key] = (
                value
                .replace("{username}", config["username"])
                .replace("{password}", config["password"])
                .replace("{local_ip}", local_ip or "")
            )
        elif value == "{username}":
            fields[key] = config["username"]
        elif value == "{password}":
            fields[key] = config["password"]
        else:
            fields[key] = value
    return fields


def http_call(config: dict) -> tuple[int, str]:
    method = config["method"].upper()
    headers = {
        "User-Agent": config.get(
            "user_agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) campus-auto-login/1.0",
        )
    }
    headers.update(config.get("headers", {}))

    fields = build_fields(config)
    timeout = float(config.get("timeout", 10))
    login_url = config["login_url"]

    connect_host = config.get("connect_host")
    if connect_host:
        return http_call_with_connect_host(config, fields, headers)

    if method == "GET":
        query = parse.urlencode(fields)
        separator = "&" if "?" in login_url else "?"
        url = f"{login_url}{separator}{query}" if query else login_url
        req = request.Request(url, headers=headers, method="GET")
    elif method == "POST":
        body = parse.urlencode(fields).encode("utf-8")
        headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
        req = request.Request(login_url, data=body, headers=headers, method="POST")
    else:
        raise ValueError("method 只支持 GET 或 POST")

    try:
        with request.urlopen(req, timeout=timeout) as resp:
            text = resp.read().decode(config.get("response_encoding", "utf-8"), errors="replace")
            return resp.status, text
    except HTTPError as e:
        text = e.read().decode(config.get("response_encoding", "utf-8"), errors="replace")
        return e.code, text
    except URLError as e:
        raise RuntimeError(f"请求登录接口失败: {e}") from e


def http_call_with_connect_host(config: dict, fields: dict, headers: dict) -> tuple[int, str]:
    method = config["method"].upper()
    timeout = float(config.get("timeout", 10))
    parsed = urlsplit(config["login_url"])
    if parsed.scheme not in ("http", "https"):
        raise ValueError("connect_host 只支持 http/https URL")

    host = parsed.hostname
    if not host:
        raise ValueError("login_url 缺少主机名")

    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    connect_host = config["connect_host"]
    connect_port = int(config.get("connect_port", port))

    headers = dict(headers)
    headers["Host"] = host if parsed.port is None else f"{host}:{port}"

    path = parsed.path or "/"
    if parsed.query:
        path += "?" + parsed.query

    body = None
    if method == "GET":
        query = parse.urlencode(fields)
        if query:
            path += ("&" if "?" in path else "?") + query
    elif method == "POST":
        body = parse.urlencode(fields).encode("utf-8")
        headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
    else:
        raise ValueError("method 只支持 GET 或 POST")

    if parsed.scheme == "https":
        context = ssl.create_default_context()
        sock = socket.create_connection((connect_host, connect_port), timeout=timeout)
        tls_sock = context.wrap_socket(sock, server_hostname=host)
        conn = http.client.HTTPSConnection(host, port=port, timeout=timeout)
        conn.sock = tls_sock
    else:
        conn = http.client.HTTPConnection(connect_host, port=connect_port, timeout=timeout)

    try:
        conn.request(method, path, body=body, headers=headers)
        resp = conn.getresponse()
        raw = resp.read()
        text = raw.decode(config.get("response_encoding", "utf-8"), errors="replace")
        return resp.status, text
    finally:
        conn.close()


def response_success(config: dict, status: int, text: str) -> bool:
    if status not in config.get("success_status", [200]):
        return False

    success_keywords = config.get("success_keywords", [])
    failure_keywords = config.get("failure_keywords", [])

    if any(word in text for word in failure_keywords):
        return False
    if success_keywords:
        return any(word in text for word in success_keywords)

    return True


def login_once(config: dict) -> bool:
    if is_online(config):
        logging.info("网络已连通，跳过登录。")
        return True

    wait_seconds = int(config.get("wait_before_login", 3))
    if wait_seconds > 0:
        logging.info("检测到未联网，等待 %s 秒后尝试登录。", wait_seconds)
        time.sleep(wait_seconds)

    status, text = http_call(config)
    logging.info("登录接口返回 HTTP %s，响应前 500 字: %s", status, text[:500].replace("\n", " "))

    if response_success(config, status, text):
        logging.info("登录请求看起来已成功。")
        verify_wait = int(config.get("post_login_wait", 12))
        verify_attempts = int(config.get("post_login_verify_attempts", 3))
        verify_interval = int(config.get("post_login_verify_interval", 5))

        if verify_wait > 0:
            logging.info("等待 %s 秒，让 AC 放通网络。", verify_wait)
            time.sleep(verify_wait)

        for attempt in range(1, verify_attempts + 1):
            if is_online(config):
                logging.info("外网连通验证成功。")
                return True
            logging.warning("Portal 已返回成功，但第 %s/%s 次外网验证仍未连通。", attempt, verify_attempts)
            if attempt < verify_attempts:
                time.sleep(verify_interval)

        logging.warning("Portal 已返回成功，但外网仍不可达。可能是 AC 放通延迟、DNS/网关异常或账号策略限制。")
        return False

    logging.warning("登录请求未匹配成功条件。")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="校园网自动登录脚本")
    parser.add_argument("-c", "--config", default=str(DEFAULT_CONFIG), help="配置文件路径")
    parser.add_argument("-v", "--verbose", action="store_true", help="同时输出日志到终端")
    args = parser.parse_args()

    config_path = Path(args.config).resolve()
    setup_logging(args.verbose, config_path.parent / "login.log")

    try:
        config = load_config(config_path)
        retries = int(config.get("retries", 3))
        interval = int(config.get("retry_interval", 5))

        for attempt in range(1, retries + 1):
            logging.info("开始第 %s/%s 次登录检测。", attempt, retries)
            if login_once(config):
                return 0
            if attempt < retries:
                time.sleep(interval)

        return 1
    except Exception as e:
        logging.exception("自动登录失败: %s", e)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

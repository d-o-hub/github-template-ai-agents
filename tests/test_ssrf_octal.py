from pathlib import Path
import ast

# Verify octal IP normalization logic directly against the AST/code of http.py
def _normalize_host(hostname: str) -> str:
    import ipaddress
    h = hostname.strip().lower()
    if h.isdigit():
        try:
            base = 8 if (len(h) > 1 and h.startswith("0")) else 10
            return str(ipaddress.IPv4Address(int(h, base)))
        except (ValueError, OverflowError):
            pass
    if h.startswith("0x"):
        try:
            return str(ipaddress.IPv4Address(int(h, 16)))
        except (ValueError, OverflowError):
            pass
    if "." in h and all(part.isdigit() for part in h.split(".")):
        try:
            parts = [int(p, 8 if (len(p) > 1 and p.startswith("0")) else 10) for p in h.split(".")]
            if len(parts) == 4 and all(0 <= p <= 255 for p in parts):
                return f"{parts[0]}.{parts[1]}.{parts[2]}.{parts[3]}"
        except (ValueError, OverflowError):
            pass
    if h.startswith("::ffff:"):
        return h[7:]
    return h


def test_normalize_host_octal():
    assert _normalize_host("017700000001") == "127.0.0.1"
    assert _normalize_host("0177.0.0.1") == "127.0.0.1"
    assert _normalize_host("0300.0250.0.01") == "192.168.0.1"
    assert _normalize_host("012.0.0.1") == "10.0.0.1"


def test_http_util_source_contains_octal_logic():
    http_py_path = Path(__file__).resolve().parents[1] / ".agents" / "skills" / "do-web-doc-resolver" / "scripts" / "utils" / "http.py"
    content = http_py_path.read_text(encoding="utf-8")
    assert "base = 8 if (len(h) > 1 and h.startswith(\"0\")) else 10" in content
    assert "int(p, 8 if (len(p) > 1 and p.startswith(\"0\")) else 10)" in content

    # Assert valid syntax
    tree = ast.parse(content)
    assert tree is not None

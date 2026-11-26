#!/usr/bin/env python3
"""Development-only downloader for the 16 user-supplied WeChat articles.
Run: python3 -m pip install requests beautifulsoup4 && python3 tools/extract_wechat_assets.py
Review downloaded files before adding selected frames to Images.xcassets.
"""
from pathlib import Path
from urllib.parse import urlparse
import hashlib, mimetypes, re, time
import requests
from bs4 import BeautifulSoup

ARTICLES = [
    "https://mp.weixin.qq.com/s/QoNdigUU7maW1T1VDlcDzg",
    "https://mp.weixin.qq.com/s/aoTQ0EAA5Shq2hIIkLHseQ",
    "https://mp.weixin.qq.com/s/7EZs01f4Vb8AGGPHrIz20g",
    "https://mp.weixin.qq.com/s/D1IY5LIw_OvbNuH0QDl-xQ",
    "https://mp.weixin.qq.com/s/bJUq88OqX0N0fdMgp0jg3Q",
    "https://mp.weixin.qq.com/s/hGMue4RG8A-lanICmrwsjw",
    "https://mp.weixin.qq.com/s/SjRF67r5iqqt5FyQVkxiHQ",
    "https://mp.weixin.qq.com/s/cbsnPzz6jr9COwRrj09zoQ",
    "https://mp.weixin.qq.com/s/jUi-KieTsvQOPnRwuaLGPg",
    "https://mp.weixin.qq.com/s/81qC6vIDimuxgBQxJ53MkQ",
    "https://mp.weixin.qq.com/s/uP-WY6-LvMzUndqDd4zLzg",
    "https://mp.weixin.qq.com/s/hQzrJ2PYrreMJkKb3YexXg",
    "https://mp.weixin.qq.com/s/fmJ_vbv3v0_wRceNtdErbg",
    "https://mp.weixin.qq.com/s/oyUojTPNNVG01EyVqHrGew",
    "https://mp.weixin.qq.com/s/g3Ie5tevkNvWFER-zBc8HQ",
    "https://mp.weixin.qq.com/s/PYHF3WnbRBLzAv4QiIwV0g"
]
UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 MicroMessenger/8.0.55(0x1800372b) NetType/WIFI Language/zh_CN"
HEADERS = {"User-Agent": UA, "Referer": "https://mp.weixin.qq.com/"}
OUT = Path("tools/wechat_downloads")
OUT.mkdir(parents=True, exist_ok=True)

session = requests.Session()
session.headers.update(HEADERS)
seen, success, failed = set(), 0, 0
for article_no, article in enumerate(ARTICLES, 1):
    try:
        response = session.get(article, timeout=30)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        content = soup.select_one("#js_content")
        if content is None:
            print(f"[article {article_no:02}] #js_content missing")
            continue
        for img in content.select("img"):
            src = img.get("data-src") or img.get("src") or ""
            if not src:
                continue
            if src.startswith("//"):
                src = "https:" + src
            parsed = urlparse(src)
            if parsed.hostname != "mmbiz.qpic.cn":
                continue
            if src in seen:
                continue
            seen.add(src)
            try:
                image = session.get(src, timeout=30)
                image.raise_for_status()
                content_type = image.headers.get("Content-Type", "").split(";")[0].lower()
                ext = mimetypes.guess_extension(content_type) or Path(parsed.path).suffix or ".img"
                if ext == ".jpe":
                    ext = ".jpg"
                digest = hashlib.sha1(src.encode()).hexdigest()[:10]
                name = f"article-{article_no:02d}-{digest}{ext}"
                (OUT / name).write_bytes(image.content)
                success += 1
                print(f"saved {name} ({len(image.content)} bytes)")
            except Exception as exc:
                failed += 1
                print(f"image failed: {src[:90]}: {exc}")
            time.sleep(0.15)
    except Exception as exc:
        failed += 1
        print(f"[article {article_no:02}] article failed: {exc}")
print(f"Finished: success {success}, failed {failed}; review {OUT} before asset-catalog packaging.")

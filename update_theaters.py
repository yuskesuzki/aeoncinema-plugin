#!/usr/bin/env python3
"""
https://www.aeoncinema.com/theater/ から全国のイオンシネマ劇場一覧をスクレイピングし、
theater.json を生成するスクリプト。
"""

import json
import re
import urllib.request
from typing import Any, Dict, List


THEATER_LIST_URL = "https://www.aeoncinema.com/theater/"


def fetch_theater_list() -> List[Dict[str, Any]]:
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }
    req = urllib.request.Request(THEATER_LIST_URL, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        html = resp.read().decode("utf-8")

    # 都道府県ごとのセクションを抽出
    h2_matches = list(re.finditer(r'<h2 class="c-area__name">(.*?)</h2>', html))
    theaters = []
    seen_ids = set()

    for i, m in enumerate(h2_matches):
        start = m.end()
        end = h2_matches[i + 1].start() if i + 1 < len(h2_matches) else len(html)
        area_name = re.sub(r"<[^>]+>", "", m.group(1)).strip()
        sec_html = html[start:end]

        pattern = (
            r'data-theater-id=["\']([^"\']+)["\']\s+'
            r'data-theater-name=["\']([^"\']+)["\'][^>]*>.*?<h3>(.*?)</h3>'
        )
        matches = re.findall(pattern, sec_html, re.DOTALL)

        for tid, tname, tjp in matches:
            clean_name = re.sub(r"<[^>]+>", "", tjp).strip()
            if tname not in seen_ids:
                seen_ids.add(tname)
                theaters.append({
                    "id": tname,
                    "name": clean_name,
                    "theater_id": tid,
                    "area": area_name,
                    "url": f"https://theater.aeoncinema.com/theaters/{tname}/",
                })

    return theaters


def generate_theater_json(output_path: str = "theater.json") -> List[Dict[str, Any]]:
    print(f"劇場一覧を取得中: {THEATER_LIST_URL} ...")
    theaters = fetch_theater_list()
    print(f"取得完了: {len(theaters)} 劇場")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(theaters, f, ensure_ascii=False, indent=2)

    print(f"'{output_path}' に保存しました。")
    return theaters


if __name__ == "__main__":
    generate_theater_json()

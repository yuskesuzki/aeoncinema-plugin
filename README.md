# イオンシネマ 上映スケジュールスクレイパー

イオンシネマ（江別など各劇場）の上映スケジュールをスクレイピングし、映画タイトルと上映時間の一覧を取得するPythonスクリプトです。

イオンシネマのWebサイト内部で使用されている公式データAPIエンドポイントから最新のJSONデータを直接取得するため、**外部パッケージ（BeautifulSoup / Selenium / Playwright等）を一切使用せず、Python標準ライブラリのみで高速・軽量に動作**します。

---

## 特徴

- **標準ライブラリのみで動作**: `pip install` 不要（Python 3.9以上推奨）
- **URLから自動判定**: 劇場のWebページURLを渡すだけで、劇場IDや指定日（`?date=...`）を自動抽出
- **キャッシュバスター対応**: CloudFrontの古いキャッシュを回避し、常に最新のスケジュールを取得
- **JSTタイムゾーン自動変換**: UTC時刻を日本時間（JST）の「開始時刻〜終了時刻」に自動変換
- **多彩な出力形式**: 作品別テキスト表示、タイムテーブル順表示、JSON形式、CSV形式、ファイル保存に対応

---

## 使い方

### 1. 基本的な実行（デフォルトで指定の江別URLを処理）

```bash
python3 aeoncinema_scraper.py
```

### 2. URLを直接指定して実行

```bash
python3 aeoncinema_scraper.py "https://theater.aeoncinema.com/theaters/ebetsu/?date=20261012"
```

### 3. 日付を指定して実行（柔軟な指定が可能）

```bash
# 日付のみを直接指定
python3 aeoncinema_scraper.py 20261013

# -d / --date オプションで指定（ハイフン付きや「明日」も可）
python3 aeoncinema_scraper.py -d 2026-10-13
python3 aeoncinema_scraper.py -d 明日

# 劇場と日付を両方指定
python3 aeoncinema_scraper.py ebetsu 20261013
```

### 4. 指定日・指定時刻から3時間以内に開始する映画を抽出（--upcoming）

```bash
# 現在時刻から3時間以内に開始する作品を表示
python3 aeoncinema_scraper.py --upcoming

# 指定した日付（例: 明日）の現在時刻から3時間以内
python3 aeoncinema_scraper.py -d 明日 --upcoming

# 指定した日付・指定時刻（例: 明日の10:00）から3時間以内
python3 aeoncinema_scraper.py -d 20261013 --upcoming --time 10:00

# タイムテーブル順で表示
python3 aeoncinema_scraper.py -d 20261013 --upcoming --time 10:00 --format timetable

# 時間幅を変更（例: 2時間以内）
python3 aeoncinema_scraper.py --upcoming --within-hours 2
```

### 5. タイムテーブル順（上映開始時刻順）で全件表示

```bash
python3 aeoncinema_scraper.py ebetsu --format timetable
```

### 5. JSON形式で出力（他システムとの連携用）

```bash
python3 aeoncinema_scraper.py ebetsu --date 20261012 --format json
```

### 6. CSVファイルに保存

```bash
python3 aeoncinema_scraper.py ebetsu --date 20261012 --format csv -o schedule.csv
```

### 8. 許可されている劇場一覧の表示と更新

```bash
# theater.json に登録されている劇場一覧（全国99劇場）を表示
python3 aeoncinema_scraper.py --list-theaters

# 公式劇場ページ (https://www.aeoncinema.com/theater/) から theater.json を最新化
python3 update_theaters.py
# または
python3 aeoncinema_scraper.py --update-theaters
```

---

## 劇場制限（theater.json）について

本スクリプトは `https://www.aeoncinema.com/theater/` から取得した `theater.json` に含まれる公式劇場のみを検索対象として許可しています。

- **指定方法の柔軟性**:
  - 英字ID: `ebetsu`, `chofu`, `itabashi`
  - 日本語劇場名: `江別`, `シアタス調布`, `板橋`
  - 劇場コード: `81005`
  - 公式URL: `https://theater.aeoncinema.com/theaters/ebetsu/`
- **制限エラー**:
  登録外の劇場を指定した場合は即座にエラーメッセージが表示され、無効なリクエストが防止されます。

---

## コマンドライン引数一覧

| 引数 | 説明 | デフォルト |
| :--- | :--- | :--- |
| `target` | 劇場URL、劇場ID、または日付（例: `ebetsu`, `江別`, `20261013`） | 指定の江別URL |
| `date_arg` | 対象日付（第2引数として直接指定可能） | なし |
| `-d`, `--date` | 対象日付（YYYYMMDD形式、例: `20261012`, `2026-10-12`, `明日`） | URL内の日付 または 当日 |
| `-u`, `--upcoming` | 現在時刻以降、指定時間以内に開始する作品のみを抽出 | `False` |
| `--within-hours` | `--upcoming` 時の抽出対象とする時間幅（時間単位） | `3.0` |
| `-t`, `--time` | `--upcoming` 時の基準時刻（例: `"20:00"`, `"2026-10-12 20:00"`） | 現在時刻（JST） |
| `-f`, `--format` | 出力形式 (`text`, `timetable`, `json`, `csv`) | `text` |
| `-o`, `--output` | 結果の保存先ファイルパス | 標準出力 |
| `-l`, `--list-theaters` | 許可されている全劇場の一覧（都道府県別）を表示 | なし |
| `--list-dates` | 公開されている全日程一覧のみを表示 | なし |
| `--update-theaters` | 公式ページから `theater.json` を再取得・更新 | なし |
| `--theater-file` | 参照する `theater.json` のファイルパス | `theater.json` |

---

## ユニットテストの実行

外部通信を行わず、モックを活用した高速・安全なユニットテスト（全15テスト）を用意しています。

```bash
# 全テストを実行
python3 -m unittest discover tests

# 詳細表示で実行
python3 -m unittest -v tests/test_aeoncinema_scraper.py
python3 -m unittest -v tests/test_update_theaters.py
```

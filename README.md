# Aeon Cinema Schedule / Omarchy Plugin (イオンシネマ 上映スケジュールプラグイン)

An Omarchy bar widget and lightweight Python scraper for **Aeon Cinema** (イオンシネマ) schedules, screen facilities, and seat bookings across 99 theaters nationwide in Japan.

イオンシネマ（全国99劇場）の上映スケジュール、スクリーン設備情報（IMAX / 4DX 等）、座席予約購入リンクを表示する Omarchy デスクトップ向けバーウィジェットおよび Python スクリプトです。外部依存ライブラリなし（Python 標準ライブラリのみ）で高速・軽量に動作します。

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

### 7. 英語表記モード（--en / --lang en）

英語話者向けに、映画タイトル（英語タイトル・ローマ字表記）、スクリーン名（Screen 1 等）、座席情報、各種ヘッダーを英語で出力します。

```bash
# 英語表記でテキスト表示
python3 aeoncinema_scraper.py ebetsu --en

# 英語表記でタイムテーブル表示
python3 aeoncinema_scraper.py ebetsu --en --format timetable

# 英語表記でJSON出力
python3 aeoncinema_scraper.py ebetsu --en --format json
```

### 8. CSVファイルに保存

```bash
python3 aeoncinema_scraper.py ebetsu --date 20261012 --format csv -o schedule.csv
```

### 8. 設定の保存と表示（設定の永続化）

```bash
# デフォルト劇場、抽出時間、英語モードを設定ファイル (~/.config/aeoncinema-plugin/config.json) に保存
python3 aeoncinema_scraper.py 調布 --within-hours 2 --en --save-config

# 保存されている現在の設定を確認
python3 aeoncinema_scraper.py --show-config
```

### 9. 許可されている劇場一覧の表示と更新

```bash
# theater.json に登録されている劇場一覧（全国99劇場）を表示
python3 aeoncinema_scraper.py --list-theaters

# 公式劇場ページ (https://www.aeoncinema.com/theater/) から theater.json を最新化
python3 update_theaters.py
# または
python3 aeoncinema_scraper.py --update-theaters
```

---

## Omarchy プラグイン機能

本リポジトリは **Omarchy デスクトップ環境のバーウィジェット（`bar-widget`）** に完全対応しています。

### プラグインUIの機能
- **トップバー表示**: `🎬 3本`（直近数時間の上映作品数をリアルタイム表示）
- **劇場選択ダイアログ & 公式HPリンク**:
  - タイトル部「🎬 イオンシネマ [劇場名]」をクリックして劇場選択ダイアログを開き、全国99劇場から絞り込み検索・ワンクリック選択可能
  - 劇場名の右隣にある `[HP]` アイコンをクリックすると、該当劇場の公式ホームページをブラウザで即座に開きます
- **スクリーン設備・座席詳細ポップアップ**:
  - 各上映回のスクリーン名をクリックするとモーダルカードが開き、設備・音響（Features）、座席種類の内訳（通常座席、アップグレードシート、車椅子スペース等）と席数、総座席数を表示
  - 「🗺️ 公式座席図を開く」ボタンから、劇場の公式座席表（画像）をブラウザで開くことができます
- **特殊設備バッジ**:
  - IMAX、4DX、VIVE AUDIO、Dolby Atmos、THX などの特殊設備スクリーンで上映される回には、スクリーン名の右隣に `[IMAX]` や `[4DX]` 等の専用バッジを表示
- **上映作品のソートと日付切り替え**:
  - 各作品の中で最も早い上映開始時刻順に作品一覧を整列表示
  - `今日` / `明日` ボタンで当日の直近上映と翌日の上映スケジュールをワンクリック切り替え
- **直近作品抽出（Within Hours）**:
  - `1h` / `2h` / `3h` / `5h` のボタングループで抽出時間をワンタッチ切り替え
  - 映画タイトル、上映時刻、スクリーン名、残席状況（空席/残りわずか/満席）を表示
- **チケット予約購入ボタン**:
  - 作品名横の「🎟️ 予約購入」ボタンおよび各上映回横の「🎟️」ボタンから、公式ワタシアターのチケット購入画面を開くことができます
- **英語モード（English Mode）**:
  - `JA` / `EN` ボタンでタイトルやUI表示言語を日英切り替え可能
- **設定の永続化（Settings Persistence）**:
  - UI上で選択した「劇場」「抽出時間」「英語モード」は Omarchy のシェル設定に自動保持されます
  - 同時に `~/.config/aeoncinema-plugin/config.json` にも同期保存されるため、次回起動時やCLI実行時にも設定が引き継がれます

> [!NOTE]
> **チケット予約購入リンクの仕様**  
> 公式サイトと同じ正規の共通認証ゲートウェイ（`/auth?eventId=...`）を使用しているため、ブラウザ側ですでに「ワタシアター」にログイン中の方は既存セッションを引き継いで即座に該当上映回の座席選択画面へ進み、未ログインの方はログインまたは非会員購入の選択画面へスムーズに誘導されます。

### プラグインのインストール・配置方法

#### 方法 A: Omarchy コマンドによる追加（推奨）
```bash
# リポジトリから直接追加して有効化
omarchy plugin add https://github.com/yuskesuzki/aeoncinema-plugin.git --enable
```

#### 方法 B: ローカル開発ディレクトリからの手動配置
```bash
# プラグインディレクトリを Omarchy のユーザープラグインディレクトリにリンク
ln -s "$(pwd)" ~/.config/omarchy/plugins/com.yusuke.aeoncinema

# プラグインの有効化（トップバー右側に配置）
omarchy plugin enable com.yusuke.aeoncinema right
```

### プラグインのアンインストール・削除方法
```bash
# プラグインの削除
omarchy plugin remove com.yusuke.aeoncinema
```

### 依存関係 (Dependencies)
- **Python 3.9 以上**
- Python 標準ライブラリのみを使用（`urllib`, `json`, `datetime` 等）。追加の pip パッケージのインストールは不要です。
- **Quickshell** / **Omarchy** デスクトップ環境

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
| `target` | 劇場URL、劇場ID、または日付（例: `ebetsu`, `江別`, `20261013`） | 保存設定 または 江別URL |
| `date_arg` | 対象日付（第2引数として直接指定可能） | なし |
| `-d`, `--date` | 対象日付（YYYYMMDD形式、例: `20261012`, `2026-10-12`, `明日`） | URL内の日付 または 当日 |
| `-u`, `--upcoming` | 現在時刻以降、指定時間以内に開始する作品のみを抽出 | `False` |
| `--within-hours` | `--upcoming` 時の抽出対象とする時間幅（時間単位） | 保存設定 または `3.0` |
| `-t`, `--time` | `--upcoming` 時の基準時刻（例: `"20:00"`, `"2026-10-12 20:00"`） | 現在時刻（JST） |
| `--en`, `--english` | 英語表記モード（タイトルおよびUIを英語化） | 保存設定 または `False` |
| `--lang` | 表示言語の明示指定 (`ja` または `en`) | 保存設定 または `ja` |
| `-f`, `--format` | 出力形式 (`text`, `timetable`, `json`, `csv`) | `text` |
| `-o`, `--output` | 結果の保存先ファイルパス | 標準出力 |
| `--save-config` | 指定した引数の設定を保存ファイルに永続化 | なし |
| `--show-config` | 現在保存されている設定内容を表示 | なし |
| `--config-file` | 設定ファイルパスの指定 | `~/.config/aeoncinema-plugin/config.json` |
| `-l`, `--list-theaters` | 許可されている全劇場の一覧（都道府県別）を表示 | なし |
| `--list-dates` | 公開されている全日程一覧のみを表示 | なし |
| `--update-theaters` | 公式ページから `theater.json` を再取得・更新 | なし |
| `--theater-file` | 参照する `theater.json` のファイルパス | `theater.json` |

---

## ユニットテストの実行

外部通信を行わず、モックを活用した高速・安全なユニットテスト（全22テスト）を用意しています。

```bash
# 全テストを実行
python3 -m unittest discover tests

# 詳細表示で実行
python3 -m unittest -v tests/test_aeoncinema_scraper.py
python3 -m unittest -v tests/test_update_theaters.py
```

---

## ライセンス (License)

本ソフトウェアは [MIT License](LICENSE) の下で公開されています。詳細は [LICENSE](LICENSE) ファイルをご参照ください。


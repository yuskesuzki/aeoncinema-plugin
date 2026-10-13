import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "com.yusuke.aeoncinema"

  // 状態プロパティ (shell.json の entry から取得、フォールバック付き)
  property string selectedTheater: String(root.setting("theater", "ebetsu"))
  property real withinHours: Number(root.setting("withinHours", 3.0))
  property bool englishMode: Boolean(root.setting("englishMode", false))
  property string selectedDate: "today" // "yesterday", "today", "tomorrow"

  property string theaterDisplayName: "江別"
  property var moviesData: []
  property var allTheaters: []
  property bool loading: false
  property string errorMessage: ""
  property string payloadMessage: ""
  property bool popupOpen: false
  property bool showSettingsPanel: false
  property string theaterSearchText: ""

  readonly property string scriptPath: String(Qt.resolvedUrl("aeoncinema_scraper.py")).replace(/^file:\/\//, "")
  readonly property string theaterJsonPath: String(Qt.resolvedUrl("theater.json")).replace(/^file:\/\//, "")

  // バー上の表示テキスト
  readonly property string barSummaryText: {
    if (loading) return "..."
    if (moviesData.length > 0) {
      return englishMode ? (moviesData.length + " movies") : (moviesData.length + "本")
    }
    return englishMode ? "0 movies" : "0本"
  }

  readonly property string barTooltipText: {
    var title = englishMode ? "Aeon Cinema" : "イオンシネマ"
    var dateLabel = selectedDate === "yesterday" ? (englishMode ? "Yesterday" : "昨日") : (selectedDate === "tomorrow" ? (englishMode ? "Tomorrow" : "明日") : (englishMode ? (withinHours + "h window") : (withinHours + "時間以内")))
    return title + " - " + theaterDisplayName + " (" + dateLabel + ")"
  }

  function buildFetchCommand() {
    var cmd = [
      "python3",
      root.scriptPath,
      root.selectedTheater,
      "--format",
      "json",
      root.englishMode ? "--en" : "--lang=ja"
    ]
    if (root.selectedDate === "tomorrow") {
      cmd.push("-d", "明日")
    } else {
      cmd.push("--upcoming", "--within-hours", String(root.withinHours))
    }
    return cmd
  }

  // 劇場データの読み込み (Process)
  Process {
    id: fetchProcess
    running: false
    command: root.buildFetchCommand()

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        root.errorMessage = ""
        root.payloadMessage = ""
        try {
          var payload = JSON.parse(text)
          root.theaterDisplayName = payload.theater_name || payload.theater || root.selectedTheater
          var movies = payload.movies || []
          movies.sort(function(a, b) {
            var timeA = (a.showtimes && a.showtimes.length > 0) ? a.showtimes[0].start_time : "99:99"
            var timeB = (b.showtimes && b.showtimes.length > 0) ? b.showtimes[0].start_time : "99:99"
            if (timeA !== timeB) return timeA.localeCompare(timeB)
            return (a.title || "").localeCompare(b.title || "")
          })
          root.moviesData = movies
          root.payloadMessage = payload.message || ""
          console.log("[AeonCinema] Successfully fetched " + root.moviesData.length + " movies for " + root.theaterDisplayName + " (" + root.selectedDate + ")")
        } catch (e) {
          console.error("[AeonCinema] JSON parse error: " + e.message)
          root.errorMessage = root.englishMode ? "Failed to parse schedule" : "スケジュールの解析に失敗しました"
        }
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          console.warn("[AeonCinema] fetch stderr:", text.trim())
        }
      }
    }

    onExited: function(exitCode, exitStatus) {
      root.loading = false
      if (exitCode !== 0 && root.errorMessage === "") {
        root.errorMessage = root.englishMode ? "Failed to fetch schedule" : "スケジュール取得エラー"
      }
    }
  }

  // theater.json 読み込み用 Process
  Process {
    id: loadTheatersProcess
    running: false
    command: ["cat", root.theaterJsonPath]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.allTheaters = JSON.parse(text)
          for (var i = 0; i < root.allTheaters.length; i++) {
            if (root.allTheaters[i].id === root.selectedTheater) {
              root.theaterDisplayName = root.allTheaters[i].name
              break
            }
          }
        } catch (e) {}
      }
    }
  }

  // 設定を config.json に同期する Process
  Process {
    id: syncConfigProcess
    running: false
    command: [
      "python3",
      root.scriptPath,
      root.selectedTheater,
      "--within-hours",
      String(root.withinHours),
      root.englishMode ? "--en" : "--lang=ja",
      "--save-config"
    ]
  }

  function refresh() {
    if (!fetchProcess.running) {
      loading = true
      fetchProcess.command = root.buildFetchCommand()
      fetchProcess.running = true
    }
  }

  function syncConfig() {
    if (!syncConfigProcess.running) {
      syncConfigProcess.command = [
        "python3",
        root.scriptPath,
        root.selectedTheater,
        "--within-hours",
        String(root.withinHours),
        root.englishMode ? "--en" : "--lang=ja",
        "--save-config"
      ]
      syncConfigProcess.running = true
    }
  }

  // 設定の永続化 (Omarchy shell.json + Python config.json)
  function persistSettings(newTheater, newHours, newEn) {
    var entry = { id: root.moduleName || "com.yusuke.aeoncinema" }
    for (var k in root.settings) {
      if (k !== "id") entry[k] = root.settings[k]
    }
    if (newTheater !== undefined) entry.theater = newTheater
    if (newHours !== undefined) entry.withinHours = newHours
    if (newEn !== undefined) entry.englishMode = newEn
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName || "com.yusuke.aeoncinema", entry)
    }
    syncConfig()
  }

  function selectTheater(id, name) {
    selectedTheater = id
    theaterDisplayName = name
    showSettingsPanel = false
    persistSettings(id, undefined, undefined)
    refresh()
  }

  function setHours(h) {
    withinHours = h
    persistSettings(undefined, h, undefined)
    refresh()
  }

  function toggleLanguage() {
    englishMode = !englishMode
    persistSettings(undefined, undefined, englishMode)
    refresh()
  }

  function open() {
    popupOpen = true
  }

  function close() {
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) {
      close()
    } else {
      open()
    }
  }

  Component.onCompleted: {
    loadTheatersProcess.running = true
    refresh()
  }

  // 15分ごとに自動更新
  Timer {
    interval: 15 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // バー上のボタンスロット (テキストとアイコンを含むため WidgetButton を使用)
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "🎬 " + root.barSummaryText
    tooltipText: root.barTooltipText

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton || mouseButton === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.toggle()
      }
    }
  }

  // ポップアップ詳細パネル
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight, Style.space(580))

    onOpenChanged: {
      if (root.popupOpen !== open) {
        root.popupOpen = open
      }
    }

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(12)

      // 1. ヘッダーバー
      RowLayout {
        width: parent.width

        // タイトル & 劇場名 (クリックで劇場公式HPへ移動)
        Rectangle {
          radius: Style.space(6)
          color: titleHover.containsMouse ? Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.08) : "transparent"
          implicitWidth: titleRow.implicitWidth + Style.space(10)
          implicitHeight: titleRow.implicitHeight + Style.space(6)

          RowLayout {
            id: titleRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "🎬"
              font.pixelSize: Style.font ? Style.font.title : 16
            }
            Text {
              text: root.englishMode ? "AEON CINEMA" : "イオンシネマ"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font ? Style.font.title : 16
              font.bold: true
            }
            // 劇場名バッジ
            Rectangle {
              radius: Style.space(4)
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.15)
              implicitWidth: theaterLabel.implicitWidth + Style.space(10)
              implicitHeight: theaterLabel.implicitHeight + Style.space(4)

              Text {
                id: theaterLabel
                anchors.centerIn: parent
                text: root.theaterDisplayName
                color: root.bar ? root.bar.foreground : Color.foreground
                font.pixelSize: Style.font ? Style.font.caption : 11
                font.bold: true
              }
            }
            Text {
              text: "↗"
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.45)
              font.pixelSize: Style.font ? Style.font.caption : 10
            }
          }

          MouseArea {
            id: titleHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var url = "https://theater.aeoncinema.com/theaters/" + root.selectedTheater + "/"
              if (root.bar && typeof root.bar.run === "function") {
                root.bar.run("xdg-open '" + url + "'")
              }
            }
            onEntered: if (root.bar) root.bar.showTooltip(parent, root.englishMode ? "Open theater website" : (root.theaterDisplayName + " の公式ホームページを開く"))
            onExited: if (root.bar) root.bar.hideTooltip(parent)
          }
        }

        Item { Layout.fillWidth: true }

        // 言語切替ボタン (JA / EN)
        Rectangle {
          radius: Style.space(4)
          color: root.englishMode ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
          implicitWidth: langText.implicitWidth + Style.space(12)
          implicitHeight: Style.space(26)

          Text {
            id: langText
            anchors.centerIn: parent
            text: root.englishMode ? "EN" : "JA"
            color: root.englishMode ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
            font.pixelSize: Style.font ? Style.font.caption : 11
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleLanguage()
          }
        }

        // 設定トグルボタン
        Rectangle {
          radius: Style.space(4)
          color: root.showSettingsPanel ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
          implicitWidth: Style.space(26)
          implicitHeight: Style.space(26)

          Text {
            anchors.centerIn: parent
            text: "⚙"
            color: root.showSettingsPanel ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
            font.pixelSize: Style.font ? Style.font.caption : 12
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showSettingsPanel = !root.showSettingsPanel
          }
        }

        // 更新ボタン
        Rectangle {
          radius: Style.space(4)
          color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
          implicitWidth: Style.space(26)
          implicitHeight: Style.space(26)

          Text {
            anchors.centerIn: parent
            text: "🔄"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.pixelSize: Style.font ? Style.font.caption : 12
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refresh()
          }
        }
      }

      // 2. 日付切替セレクター (昨日 / 今日 / 明日)
      RowLayout {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: [
            { id: "today",     labelJa: "今日", labelEn: "Today" },
            { id: "tomorrow",  labelJa: "明日", labelEn: "Tomorrow" }
          ]

          delegate: Rectangle {
            Layout.fillWidth: true
            radius: Style.space(4)
            property bool isSelected: root.selectedDate === modelData.id
            color: isSelected ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.08)
            border.color: isSelected ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.15)
            border.width: 1
            implicitHeight: Style.space(26)

            Text {
              anchors.centerIn: parent
              text: root.englishMode ? modelData.labelEn : modelData.labelJa
              color: parent.isSelected ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
              font.pixelSize: Style.font ? Style.font.caption : 11
              font.bold: parent.isSelected
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.selectedDate !== modelData.id) {
                  root.selectedDate = modelData.id
                  root.refresh()
                }
              }
            }
          }
        }
      }

      // 3. 設定パネル (アコーディオン表示)
      Rectangle {
        width: parent.width
        visible: root.showSettingsPanel
        radius: Style.space(8)
        color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.06)
        border.color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.15)
        border.width: 1
        implicitHeight: settingsCol.implicitHeight + Style.space(16)

        Column {
          id: settingsCol
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          // 劇場選択
          Text {
            text: root.englishMode ? "Select Theater:" : "劇場を選択:"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.pixelSize: Style.font ? Style.font.body : 12
            font.bold: true
          }

          // 検索フィルター
          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(4)
            color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              verticalAlignment: TextInput.AlignVCenter
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font ? Style.font.caption : 12
              clip: true

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: searchInput.text === ""
                text: root.englishMode ? "Filter theaters..." : "劇場名・地域で絞り込み..."
                color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.4)
                font.pixelSize: Style.font ? Style.font.caption : 12
              }

              onTextChanged: root.theaterSearchText = text.trim().toLowerCase()
            }
          }

          // 劇場リスト (スクロール)
          Flickable {
            width: parent.width
            height: Style.space(110)
            contentHeight: theaterFlow.implicitHeight
            clip: true

            Flow {
              id: theaterFlow
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: {
                  var list = []
                  for (var i = 0; i < root.allTheaters.length; i++) {
                    var t = root.allTheaters[i]
                    if (root.theaterSearchText === "" ||
                        t.name.toLowerCase().indexOf(root.theaterSearchText) !== -1 ||
                        t.id.toLowerCase().indexOf(root.theaterSearchText) !== -1 ||
                        (t.area && t.area.toLowerCase().indexOf(root.theaterSearchText) !== -1)) {
                      list.push(t)
                    }
                  }
                  return list
                }

                delegate: Rectangle {
                  id: theaterChip
                  radius: Style.space(4)
                  property bool isSelected: modelData.id === root.selectedTheater
                  color: isSelected ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
                  implicitWidth: chipLabel.implicitWidth + Style.space(10)
                  implicitHeight: Style.space(22)

                  Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.name
                    color: theaterChip.isSelected ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
                    font.pixelSize: Style.font ? Style.font.caption : 11
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectTheater(modelData.id, modelData.name)
                  }
                }
              }
            }
          }

          // 時間範囲選択 (Within Hours - 今日選択時のみ有効)
          RowLayout {
            width: parent.width
            spacing: Style.space(8)
            visible: root.selectedDate === "today"

            Text {
              text: root.englishMode ? "Within:" : "抽出範囲:"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font ? Style.font.body : 12
              font.bold: true
            }

            Repeater {
              model: [1, 2, 3, 5]
              delegate: Rectangle {
                radius: Style.space(4)
                property bool isCurrent: Math.round(root.withinHours) === modelData
                color: isCurrent ? Color.accent : Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
                implicitWidth: hourLabel.implicitWidth + Style.space(10)
                implicitHeight: Style.space(24)

                Text {
                  id: hourLabel
                  anchors.centerIn: parent
                  text: root.englishMode ? (modelData + "h") : (modelData + "時間")
                  color: parent.isCurrent ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
                  font.pixelSize: Style.font ? Style.font.caption : 11
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setHours(modelData)
                }
              }
            }
          }

          Text {
            text: root.englishMode ? "✓ Settings are automatically saved" : "✓ 設定は自動的に保持・保存されます"
            color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.5)
            font.pixelSize: Style.font ? Style.font.caption : 10
          }
        }
      }

      // 4. 上映時間・作品一覧ヘッダー
      RowLayout {
        width: parent.width
        Text {
          text: {
            if (root.selectedDate === "tomorrow") {
              return root.englishMode ? "Tomorrow's Showtimes:" : "明日の上映作品一覧:"
            } else {
              return root.englishMode ? ("Upcoming in " + root.withinHours + " hours:") : ("直近 " + root.withinHours + " 時間の上映作品:")
            }
          }
          color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.7)
          font.pixelSize: Style.font ? Style.font.caption : 12
          font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
          visible: root.loading
          text: root.englishMode ? "Loading..." : "読み込み中..."
          color: Color.accent
          font.pixelSize: Style.font ? Style.font.caption : 11
        }
      }

      // エラーメッセージ
      Text {
        width: parent.width
        visible: root.errorMessage !== ""
        text: root.errorMessage
        color: Color.urgent || "#ff5555"
        wrapMode: Text.WordWrap
        font.pixelSize: Style.font ? Style.font.caption : 12
      }

      // 5. 上映作品リスト
      Flickable {
        width: parent.width
        height: Math.min(Style.space(360), movieColumn.implicitHeight)
        contentHeight: movieColumn.implicitHeight
        clip: true

        // 作品が0件の場合
        Item {
          width: parent.width
          height: Style.space(110)
          visible: !root.loading && root.moviesData.length === 0 && root.errorMessage === ""

          Column {
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "🎬"
              font.pixelSize: 24
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: {
                if (root.payloadMessage) return root.payloadMessage
                if (root.selectedDate === "tomorrow") {
                  return root.englishMode ? "No showtimes available for tomorrow" : "明日の上映作品はありません"
                } else {
                  return root.englishMode ? "No upcoming showtimes within window" : "直近の上映作品はありません"
                }
              }
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.6)
              font.pixelSize: Style.font ? Style.font.body : 12
            }
          }
        }

        Column {
          id: movieColumn
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.moviesData

            delegate: Rectangle {
              width: movieColumn.width
              radius: Style.space(6)
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.05)
              border.color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
              border.width: 1
              implicitHeight: cardInner.implicitHeight + Style.space(16)

              Column {
                id: cardInner
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(8)

                // 作品タイトル & 予約ボタン
                RowLayout {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.pixelSize: Style.font ? Style.font.body : 13
                    font.bold: true
                    wrapMode: Text.WordWrap
                  }

                  // 作品ごとのチケット予約ボタン (直近回へリンク)
                  Rectangle {
                    visible: Boolean(modelData.booking_url)
                    radius: Style.space(4)
                    color: bookBtnHover.containsMouse ? Color.accent : Util.alpha(Color.accent, 0.85)
                    implicitWidth: bookBtnTxt.implicitWidth + Style.space(10)
                    implicitHeight: Style.space(22)
                    z: 2

                    Text {
                      id: bookBtnTxt
                      anchors.centerIn: parent
                      text: root.englishMode ? "🎟️ Book" : "🎟️ 予約購入"
                      color: Color.background
                      font.pixelSize: Style.font ? Style.font.caption : 10
                      font.bold: true
                    }

                    MouseArea {
                      id: bookBtnHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: function(mouse) {
                        mouse.accepted = true
                        var url = modelData.booking_url
                        if (url && root.bar && typeof root.bar.run === "function") {
                          root.bar.run("xdg-open '" + url + "'")
                        }
                      }
                      onEntered: if (root.bar) root.bar.showTooltip(parent, root.englishMode ? "Book ticket on official Watatheatre site" : "ワタシアター予約購入ページを開く")
                      onExited: if (root.bar) root.bar.hideTooltip(parent)
                    }
                  }
                }

                // 上映回リスト
                Repeater {
                  model: modelData.showtimes

                  delegate: RowLayout {
                    width: parent.width
                    spacing: Style.space(6)

                    // 時間バッジ
                    Rectangle {
                      radius: Style.space(4)
                      color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.12)
                      implicitWidth: timeTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(20)

                      Text {
                        id: timeTxt
                        anchors.centerIn: parent
                        text: modelData.start_time + " 〜 " + modelData.end_time
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.pixelSize: Style.font ? Style.font.caption : 11
                        font.bold: true
                      }
                    }

                    // スクリーン名
                    Text {
                      text: modelData.screen
                      color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.7)
                      font.pixelSize: Style.font ? Style.font.caption : 11
                    }

                    Item { Layout.fillWidth: true }

                    // 残席情報
                    Rectangle {
                      visible: modelData.remaining_seats !== null && modelData.remaining_seats !== undefined
                      radius: Style.space(4)
                      color: {
                        if (modelData.remaining_seats === 0) return "#44ff4444"
                        if (modelData.remaining_seats <= 15) return "#44ffaa00"
                        return Util.alpha(Color.accent, 0.2)
                      }
                      implicitWidth: seatTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(20)

                      Text {
                        id: seatTxt
                        anchors.centerIn: parent
                        text: {
                          var seats = modelData.remaining_seats + "/" + modelData.total_seats
                          return root.englishMode ? ("Seats: " + seats) : ("残 " + seats)
                        }
                        color: root.bar ? root.bar.foreground : Color.foreground
                        font.pixelSize: Style.font ? Style.font.caption : 10
                      }
                    }

                    // 上映回ごとのチケット予約ボタン
                    Rectangle {
                      visible: Boolean(modelData.booking_url)
                      radius: Style.space(4)
                      color: stBookHover.containsMouse ? Util.alpha(Color.accent, 0.35) : Util.alpha(Color.accent, 0.15)
                      border.color: Util.alpha(Color.accent, 0.4)
                      border.width: 1
                      implicitWidth: stBookTxt.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(20)
                      z: 2

                      Text {
                        id: stBookTxt
                        anchors.centerIn: parent
                        text: "🎟️"
                        font.pixelSize: Style.font ? Style.font.caption : 10
                      }

                      MouseArea {
                        id: stBookHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                          mouse.accepted = true
                          var url = modelData.booking_url
                          if (url && root.bar && typeof root.bar.run === "function") {
                            root.bar.run("xdg-open '" + url + "'")
                          }
                        }
                        onEntered: if (root.bar) root.bar.showTooltip(parent, root.englishMode ? ("Book ticket for " + modelData.start_time) : (modelData.start_time + " のチケットを予約購入"))
                        onExited: if (root.bar) root.bar.hideTooltip(parent)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

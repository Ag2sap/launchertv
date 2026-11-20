import QtQuick

Item {
    id: hero

    property bool isActive: false
    property bool workspaceActive: false
    property int currentCardIndex: 0
    readonly property real s: Math.min(appConfig.scale, Math.max(0.65, height / 650))
    readonly property real clockScale: appConfig.scale
    property var forecastDays: []
    property alias workspaceRow: resumeRow

    function syncForecast() {
        try {
            forecastDays = JSON.parse(weather.forecastJson || "[]");
        } catch (e) {
            forecastDays = [];
        }
        forecastLine.requestPaint();
    }

    Connections {
        target: weather
        function onWeatherChanged() { hero.syncForecast(); }
    }

    Connections {
        target: appConfig
        function onConfigChanged() { forecastLine.requestPaint(); }
    }

    Component.onCompleted: hero.syncForecast()

    function moveLeft() {
        if (currentCardIndex > 0) {
            currentCardIndex--;
            recentList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function moveRight() {
        if (currentCardIndex < recentList.count - 1) {
            currentCardIndex++;
            recentList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function activate() {
        let cmd = mostUsedModel.execCmdAt(currentCardIndex);
        let did = mostUsedModel.desktopIdAt(currentCardIndex);
        let wmc = mostUsedModel.wmClassAt(currentCardIndex);
        let name = mostUsedModel.nameAt(currentCardIndex);
        let icon = mostUsedModel.iconSourceAt(currentCardIndex);
        if (cmd) appLauncher.launch(cmd, did, wmc, name, icon);
    }

    // ── Clock + current weather ─────────────────────────────────

    Item {
        id: topInfoArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10 * hero.s
        height: 230 * hero.clockScale

        Column {
            id: clockColumn
            anchors.left: parent.left
            anchors.leftMargin: 40 * hero.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: -14 * hero.clockScale

            Text {
                id: dateLine
                anchors.horizontalCenter: parent.horizontalCenter
                font { pixelSize: 19 * hero.clockScale; family: "Sans" }
                color: "#E8E4DC"
                bottomPadding: 12 * hero.clockScale

                Timer {
                    running: true
                    repeat: true
                    interval: 60000
                    triggeredOnStart: true
                    onTriggered: {
                        let d = new Date();
                        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                        dateLine.text = days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate();
                    }
                }
            }

            Text {
                id: hoursBlock
                anchors.horizontalCenter: parent.horizontalCenter
                font { pixelSize: 96 * hero.clockScale; bold: true; family: "Sans" }
                color: "#F5F0E6"
                Timer {
                    running: true
                    repeat: true
                    interval: 1000
                    triggeredOnStart: true
                    onTriggered: {
                        let d = new Date();
                        hoursBlock.text = String(d.getHours()).padStart(2, "0");
                    }
                }
            }

            Text {
                id: minsBlock
                anchors.horizontalCenter: parent.horizontalCenter
                font { pixelSize: 96 * hero.clockScale; bold: true; family: "Sans" }
                color: "#F5F0E6"
                Timer {
                    running: true
                    repeat: true
                    interval: 1000
                    triggeredOnStart: true
                    onTriggered: {
                        let d = new Date();
                        minsBlock.text = String(d.getMinutes()).padStart(2, "0");
                    }
                }
            }
        }

        Row {
            id: currentWeather
            anchors.left: clockColumn.right
            anchors.leftMargin: 22 * hero.s
            anchors.right: resumeDivider.visible ? resumeDivider.left : parent.right
            anchors.rightMargin: resumeDivider.visible ? 14 * hero.s : 24 * hero.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * hero.s

            Image {
                width: 72 * hero.s
                height: 72 * hero.s
                anchors.verticalCenter: parent.verticalCenter
                source: weather.icon
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * hero.s

                Text {
                    text: weather.temperature
                    font { pixelSize: 48 * hero.s; bold: true; family: "Sans" }
                    color: "#FFFFFF"
                }

                Text {
                    text: weather.condition
                    font { pixelSize: 17 * hero.s; family: "Sans" }
                    color: "#B0B8C1"
                    elide: Text.ElideRight
                    width: currentWeather.width - 84 * hero.s
                }

                Text {
                    text: weather.location || "—"
                    font { pixelSize: 33 * hero.s; bold: true; family: "Sans" }
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                    width: currentWeather.width - 84 * hero.s
                }
            }
        }

        Rectangle {
            id: resumeDivider
            visible: workspaceModel.count > 0
            anchors.right: resumeRow.left
            anchors.rightMargin: 8 * hero.s
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 116 * hero.s
            color: "#66717F"
            opacity: 0.55
        }

        WorkspaceRow {
            id: resumeRow
            visible: workspaceModel.count > 0
            anchors.right: parent.right
            anchors.rightMargin: 18 * hero.s
            anchors.verticalCenter: parent.verticalCenter
            width: 204 * hero.s
            height: 142 * hero.s
            modelObject: workspaceModel
            scaleFactor: hero.s
            isActiveRow: hero.workspaceActive
        }
    }

    // ── Three-day forecast, aligned with current weather ────────

    Item {
        id: forecastArea
        anchors.left: currentWeather.left
        anchors.right: parent.right
        anchors.rightMargin: 24 * hero.s
        height: 94 * hero.s
        anchors.top: topInfoArea.bottom
        anchors.topMargin: 3 * hero.s

        Canvas {
            id: forecastLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24 * hero.s

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                if (!ctx) return;
                ctx.clearRect(0, 0, width, height);
                var days = hero.forecastDays.slice(0, 3);
                if (!days || days.length < 2) return;

                var values = [];
                for (var i = 0; i < days.length; i++) values.push(days[i].max);
                var lo = Math.min.apply(null, values);
                var hi = Math.max.apply(null, values);
                if (hi - lo < 6) {
                    var mid = (hi + lo) / 2;
                    lo = mid - 3;
                    hi = mid + 3;
                }

                var xs = [], ys = [];
                for (var j = 0; j < days.length; j++) {
                    xs.push((j + 0.5) * width / days.length);
                    ys.push(5 + (1 - (days[j].max - lo) / (hi - lo)) * (height - 10));
                }

                ctx.strokeStyle = appConfig.highlightColor;
                ctx.lineWidth = Math.max(2, 2.5 * hero.s);
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.globalAlpha = 0.32;
                ctx.beginPath();
                ctx.moveTo(xs[0], ys[0]);
                for (var k = 1; k < xs.length; k++) {
                    var mx = (xs[k - 1] + xs[k]) / 2;
                    var my = (ys[k - 1] + ys[k]) / 2;
                    ctx.quadraticCurveTo(xs[k - 1], ys[k - 1], mx, my);
                }
                ctx.lineTo(xs[xs.length - 1], ys[ys.length - 1]);
                ctx.stroke();
                ctx.globalAlpha = 1;
            }
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: 3
                Item {
                    readonly property var dayData: index < hero.forecastDays.length ? hero.forecastDays[index] : null
                    width: forecastArea.width / 3
                    height: forecastArea.height

                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1 * hero.s

                        Image {
                            width: 38 * hero.s
                            height: 38 * hero.s
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: dayData ? dayData.icon : ""
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            width: parent.width
                            text: dayData ? (dayData.min + " / " + dayData.max + "°") : "—"
                            font { pixelSize: 16 * hero.s; bold: true; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#FFFFFF"
                        }

                        Text {
                            width: parent.width
                            text: dayData ? (dayData.rain + "%") : ""
                            font { pixelSize: 13 * hero.s; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#9AA0A6"
                        }

                        Text {
                            width: parent.width
                            text: dayData ? dayData.abbr : ""
                            font { pixelSize: 14 * hero.s; bold: true; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#D9DEE5"
                        }
                    }
                }
            }
        }
    }

    // ── Most used spans the full lower Home area ────────────────

    Item {
        id: bottomAppsArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 * hero.s
        height: 164 * hero.s

        Item {
            id: recentArea
            anchors.left: parent.left
            anchors.leftMargin: 24 * hero.s
            anchors.right: parent.right
            anchors.rightMargin: 18 * hero.s
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Text {
                id: recentTitle
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MOST USED"
                font { pixelSize: 13 * hero.s; bold: true; family: "Sans"; letterSpacing: 2.0 }
                color: hero.isActive ? "#DDE5EF" : "#8A95A3"
            }

            ListView {
                id: recentList
                anchors.top: recentTitle.bottom
                anchors.topMargin: 8 * hero.s
                anchors.left: parent.left
                anchors.right: parent.right
                height: 148 * hero.s
                orientation: ListView.Horizontal
                spacing: 12 * hero.s
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                clip: false
                cacheBuffer: 2000
                model: mostUsedModel

                delegate: AppCard {
                    width: 136 * hero.s
                    height: 150 * hero.s
                    appName: model.name
                    appIconSource: model.iconSource
                    isFocused: hero.isActive && (index === hero.currentCardIndex)
                    isLoading: model.desktopId === appLauncher.loadingId
                    onClicked: {
                        hero.currentCardIndex = index;
                        hero.activate();
                    }
                }

                Behavior on contentX {
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36 * hero.s
        anchors.rightMargin: 36 * hero.s
        height: 1
        color: "#66717F"
        opacity: 0.55
    }
}

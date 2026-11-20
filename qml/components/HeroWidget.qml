import QtQuick

Item {
    id: hero

    property bool isActive: false
    property int currentCardIndex: 0
    readonly property real s: appConfig.scale
    property var forecastDays: []

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
        if (cmd) appLauncher.launch(cmd, did, wmc);
    }

    // ── Clock ───────────────────────────────────────────────────

    Column {
        id: topStack
        anchors.top: parent.top
        anchors.topMargin: 20 * hero.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2 * hero.s

        Text {
            id: dateLine
            anchors.horizontalCenter: parent.horizontalCenter
            font { pixelSize: 17 * hero.s; family: "Sans"; letterSpacing: 0.8 }
            color: "#C7CDD5"

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

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * hero.s

            Text {
                id: hoursBlock
                font { pixelSize: 78 * hero.s; bold: true; family: "Sans" }
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
                text: ":"
                font { pixelSize: 72 * hero.s; bold: true; family: "Sans" }
                color: "#87909B"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: minsBlock
                font { pixelSize: 78 * hero.s; bold: true; family: "Sans" }
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

        // All current-weather details are grouped below the clock.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16 * hero.s

            Image {
                width: 66 * hero.s
                height: 66 * hero.s
                source: weather.icon
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * hero.s

                Text {
                    text: weather.temperature
                    font { pixelSize: 34 * hero.s; bold: true; family: "Sans" }
                    color: "#FFFFFF"
                }

                Text {
                    text: weather.condition
                    font { pixelSize: 16 * hero.s; family: "Sans" }
                    color: "#B0B8C1"
                }

                Text {
                    text: weather.location || "—"
                    font { pixelSize: 14 * hero.s; bold: true; family: "Sans" }
                    color: "#8794A4"
                    elide: Text.ElideRight
                    width: 230 * hero.s
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    // ── Five-day forecast ───────────────────────────────────────

    Item {
        id: forecastArea
        width: Math.min(parent.width - 120 * hero.s, 610 * hero.s)
        height: 104 * hero.s
        anchors.top: topStack.bottom
        anchors.topMargin: 5 * hero.s
        anchors.horizontalCenter: parent.horizontalCenter

        Canvas {
            id: forecastLine
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 42 * hero.s

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                if (!ctx) return;
                ctx.clearRect(0, 0, width, height);
                var days = hero.forecastDays;
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
            spacing: 0

            Repeater {
                model: 5

                Item {
                    readonly property var dayData: index < hero.forecastDays.length ? hero.forecastDays[index] : null
                    width: forecastArea.width / 5
                    height: forecastArea.height

                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1 * hero.s

                        Image {
                            width: 31 * hero.s
                            height: 31 * hero.s
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
                            font { pixelSize: 13 * hero.s; bold: true; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#FFFFFF"
                        }

                        Text {
                            width: parent.width
                            text: dayData ? (dayData.rain + "%") : ""
                            font { pixelSize: 11 * hero.s; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#9AA0A6"
                        }

                        Text {
                            width: parent.width
                            text: dayData ? dayData.abbr : ""
                            font { pixelSize: 12 * hero.s; bold: true; family: "Sans" }
                            horizontalAlignment: Text.AlignHCenter
                            color: "#D9DEE5"
                        }
                    }
                }
            }
        }
    }

    // ── Recent Apps ─────────────────────────────────────────────

    Item {
        id: recentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 * hero.s
        height: 164 * hero.s

        Text {
            id: recentTitle
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RECENT APPS"
            font { pixelSize: 13 * hero.s; bold: true; family: "Sans"; letterSpacing: 2.0 }
            color: hero.isActive ? "#DDE5EF" : "#8A95A3"
        }

        ListView {
            id: recentList
            anchors.top: recentTitle.bottom
            anchors.topMargin: 9 * hero.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 100 * hero.s,
                Math.max(120 * hero.s, count * 130 * hero.s))
            height: 136 * hero.s
            orientation: ListView.Horizontal
            spacing: 14 * hero.s
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            clip: false
            cacheBuffer: 2000
            model: mostUsedModel

            delegate: AppCard {
                width: 116 * hero.s
                height: 128 * hero.s
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

    // Home/App Drawer boundary.
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

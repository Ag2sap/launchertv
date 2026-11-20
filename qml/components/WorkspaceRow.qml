import QtQuick

Item {
    id: row

    property var modelObject: null
    property bool isActiveRow: false
    property int currentCardIndex: 0
    property real scaleFactor: 1.0
    readonly property real s: scaleFactor

    function moveUp() {
        if (currentCardIndex > 0) {
            currentCardIndex--;
            cardList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function moveDown() {
        if (modelObject && currentCardIndex < modelObject.count - 1) {
            currentCardIndex++;
            cardList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function moveLeft() {
        // Resume is the leftmost Home column.
    }

    function moveRight() {
        // The Home controller moves focus to Most used.
    }

    function activate() {
        if (modelObject && currentCardIndex >= 0)
            modelObject.restoreAt(currentCardIndex);
    }

    Connections {
        target: row.modelObject
        function onCountChanged() {
            if (!row.modelObject || row.modelObject.count === 0) {
                row.currentCardIndex = 0;
            } else {
                row.currentCardIndex = Math.min(
                    row.currentCardIndex, row.modelObject.count - 1
                );
                cardList.positionViewAtIndex(row.currentCardIndex, ListView.Contain);
            }
        }
    }

    Text {
        id: title
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: "RESUME"
        color: row.isActiveRow ? "#E8EAED" : "#8A95A3"
        font { pixelSize: 13 * row.s; bold: true; family: "Sans"; letterSpacing: 1.5 }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    ListView {
        id: cardList
        anchors.top: title.bottom
        anchors.topMargin: 7 * row.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3 * row.s
        orientation: ListView.Vertical
        spacing: 6 * row.s
        interactive: modelObject !== null && modelObject.count > 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        cacheBuffer: 600
        model: row.modelObject
        currentIndex: row.currentCardIndex

        delegate: Item {
            width: cardList.width
            height: 49 * row.s

            Rectangle {
                anchors.fill: parent
                radius: 8 * row.s
                color: row.isActiveRow && index === row.currentCardIndex
                    ? "#263447" : "#151A23"
                border.width: row.isActiveRow && index === row.currentCardIndex ? 1.5 : 0
                border.color: appConfig.highlightColor

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 7 * row.s
                    anchors.rightMargin: 5 * row.s
                    spacing: 7 * row.s

                    Image {
                        width: 30 * row.s
                        height: 30 * row.s
                        anchors.verticalCenter: parent.verticalCenter
                        source: model.iconSource
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    Text {
                        width: parent.width - 44 * row.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.name
                        color: row.isActiveRow && index === row.currentCardIndex
                            ? "#FFFFFF" : "#B0B8C1"
                        font { pixelSize: 12 * row.s; bold: row.isActiveRow && index === row.currentCardIndex; family: "Sans" }
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    row.currentCardIndex = index;
                    row.activate();
                }
            }
        }

        Behavior on contentY {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
    }
}

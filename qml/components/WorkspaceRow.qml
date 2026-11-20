import QtQuick

Item {
    id: row

    property var modelObject: null
    property bool isActiveRow: false
    property int currentCardIndex: 0
    property real scaleFactor: 1.0
    readonly property real s: scaleFactor

    function moveLeft() {
        if (currentCardIndex > 0) {
            currentCardIndex--;
            cardList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function moveRight() {
        if (modelObject && currentCardIndex < modelObject.count - 1) {
            currentCardIndex++;
            cardList.positionViewAtIndex(currentCardIndex, ListView.Contain);
        }
    }

    function activate() {
        if (modelObject && currentCardIndex >= 0
                && currentCardIndex < modelObject.count)
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
        height: 112 * row.s
        orientation: ListView.Horizontal
        spacing: 8 * row.s
        interactive: modelObject !== null && modelObject.count > 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        cacheBuffer: 600
        model: row.modelObject
        currentIndex: row.currentCardIndex

        delegate: AppCard {
            width: 94 * row.s
            height: 112 * row.s
            appName: model.name
            appIconSource: model.iconSource
            isFocused: row.isActiveRow && index === row.currentCardIndex
            isLoading: model.desktopId === appLauncher.loadingId
            onClicked: {
                row.currentCardIndex = index;
                row.activate();
            }
        }

        Behavior on contentX {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}

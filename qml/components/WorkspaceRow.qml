import QtQuick

Item {
    id: row

    property var modelObject: null
    property bool isActiveRow: false
    property int currentCardIndex: 0
    readonly property real s: appConfig.scale

    height: 150 * s
    visible: modelObject !== null && modelObject.count > 0

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
        if (modelObject && currentCardIndex >= 0)
            modelObject.restoreAt(currentCardIndex);
    }

    Text {
        id: title
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: "MINIMIZED WORKSPACE"
        color: row.isActiveRow ? "#E8EAED" : "#8A95A3"
        font { pixelSize: 13 * row.s; bold: true; family: "Sans"; letterSpacing: 2.0 }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    ListView {
        id: cardList
        anchors.top: title.bottom
        anchors.topMargin: 7 * row.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 100 * row.s,
            Math.max(120 * row.s, count * 130 * row.s))
        height: 128 * row.s
        orientation: ListView.Horizontal
        spacing: 14 * row.s
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        clip: false
        cacheBuffer: 2000
        model: row.modelObject

        delegate: AppCard {
            width: 116 * row.s
            height: 116 * row.s
            appName: model.name
            appIconSource: model.iconSource
            isFocused: row.isActiveRow && (index === row.currentCardIndex)
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

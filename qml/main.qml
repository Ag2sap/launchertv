import QtQuick
import QtQuick.Controls
import QtQuick.Window

import "components"

ApplicationWindow {
    id: root

    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    color: "#000000"
    title: "LauncherTV"

    property int currentRowIndex: 0
    property int homeFocusIndex: 1
    readonly property int totalRows: 1 + rowRepeater.count

    Timer {
        id: loadingTimeout
        interval: 8000
        onTriggered: appLauncher.loadingId = ""
    }

    Connections {
        target: appLauncher
        function onLoadingChanged() {
            if (appLauncher.loadingId !== "")
                loadingTimeout.restart();
            else
                loadingTimeout.stop();
        }
    }

    Connections {
        target: workspaceModel
        function onCountChanged() {
            if (workspaceModel.count === 0 && root.homeFocusIndex === 0)
                root.homeFocusIndex = 1;
        }
    }

    property bool bgShowA: true

    Image {
        id: bgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: root.bgShowA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1200 } }
    }
    Image {
        id: bgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: root.bgShowA ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 1200 } }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: appConfig.backgroundTint
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#400D1117" }
            GradientStop { position: 1.0; color: "#C0060911" }
        }
    }

    function setBackground(src) {
        if (bgShowA) bgB.source = src; else bgA.source = src;
        bgShowA = !bgShowA;
        if (appConfig.autoAccentColor)
            appConfig.highlightColor = appConfig.colorFromImage(src);
    }

    property var bgImages: []
    property int bgImageIdx: 0

    Timer {
        id: slideshowTimer
        running: root.bgImages.length > 1
        repeat: true
        interval: appConfig.slideshowInterval * 1000
        onTriggered: {
            root.bgImageIdx = (root.bgImageIdx + 1) % root.bgImages.length;
            root.setBackground(root.bgImages[root.bgImageIdx]);
        }
    }

    function reloadBackground() {
        if (appConfig.backgroundImage) {
            setBackground("file://" + appConfig.backgroundImage);
            slideshowTimer.stop();
        } else {
            bgImages = appConfig.backgroundImages();
            if (bgImages.length > 0) {
                bgImageIdx = 0;
                setBackground(bgImages[0]);
            }
        }
    }

    Connections {
        target: appConfig
        function onConfigChanged() { reloadBackground(); }
    }

    FocusScope {
        id: mainFocus
        anchors.fill: parent
        focus: true

        Flickable {
            id: mainFlickable
            anchors.fill: parent
            anchors.leftMargin: root.width * appConfig.safeAreaLeft / 100
            anchors.rightMargin: root.width * appConfig.safeAreaRight / 100
            anchors.topMargin: root.height * appConfig.safeAreaTop / 100
            anchors.bottomMargin: root.height * appConfig.safeAreaBottom / 100
            contentHeight: mainColumn.implicitHeight
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2500

            Column {
                id: mainColumn
                width: parent.width

                HeroWidget {
                    id: heroWidget
                    width: parent.width
                    height: mainFlickable.height
                    isActive: root.currentRowIndex === 0 && root.homeFocusIndex === 1 && !settingsPage.visible
                    workspaceActive: root.currentRowIndex === 0 && root.homeFocusIndex === 0 && !settingsPage.visible
                }

                Item {
                    id: drawerPage
                    width: parent.width
                    height: Math.max(mainFlickable.height, drawerColumn.implicitHeight)

                    Column {
                        id: drawerColumn
                        width: parent.width

                        Repeater {
                            id: rowRepeater
                            model: categoryModel

                            AppRow {
                                width: drawerColumn.width
                                rowCategoryName: model.categoryName
                                rowAppsModel: model.appsModel
                                rowAppCount: model.appCount
                                isActiveRow: (index + 1) === root.currentRowIndex && !settingsPage.visible
                            }
                        }
                    }
                }
            }
        }

        NumberAnimation {
            id: scrollAnim
            target: mainFlickable
            property: "contentY"
            duration: 420
            easing.type: Easing.OutCubic
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Up:
                if (root.currentRowIndex === 0 && root.homeFocusIndex === 0) {
                    heroWidget.workspaceRow.moveUp();
                } else if (root.currentRowIndex > 0) {
                    root.currentRowIndex--;
                    scrollToRow();
                }
                event.accepted = true;
                break;

            case Qt.Key_Down:
                if (root.currentRowIndex === 0) {
                    if (root.homeFocusIndex === 0 && workspaceModel.count > 0) {
                        heroWidget.workspaceRow.moveDown();
                    } else if (root.totalRows > 1) {
                        root.currentRowIndex = 1;
                        scrollToRow();
                    }
                } else if (root.currentRowIndex < root.totalRows - 1) {
                    root.currentRowIndex++;
                    scrollToRow();
                }
                event.accepted = true;
                break;

            case Qt.Key_Left: {
                if (root.currentRowIndex === 0 && root.homeFocusIndex === 1
                        && heroWidget.currentCardIndex === 0 && workspaceModel.count > 0) {
                    root.homeFocusIndex = 0;
                } else {
                    let r = getActiveRow();
                    if (r) r.moveLeft();
                }
                event.accepted = true;
                break;
            }
            case Qt.Key_Right: {
                if (root.currentRowIndex === 0 && root.homeFocusIndex === 0) {
                    root.homeFocusIndex = 1;
                } else {
                    let r = getActiveRow();
                    if (r) r.moveRight();
                }
                event.accepted = true;
                break;
            }
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space: {
                let r = getActiveRow();
                if (r) r.activate();
                event.accepted = true;
                break;
            }
            case Qt.Key_Escape:
                event.accepted = true;
                break;
            }
        }
    }

    function getActiveRow() {
        if (currentRowIndex === 0)
            return homeFocusIndex === 0 ? heroWidget.workspaceRow : heroWidget;
        return rowRepeater.itemAt(currentRowIndex - 1);
    }

    function scrollToRow() {
        let targetY = 0;
        if (currentRowIndex > 0) {
            let row = rowRepeater.itemAt(currentRowIndex - 1);
            if (!row) return;
            targetY = heroWidget.height + row.y;
        }
        targetY = Math.max(0, Math.min(targetY,
            mainFlickable.contentHeight - mainFlickable.height));
        scrollAnim.stop();
        scrollAnim.from = mainFlickable.contentY;
        scrollAnim.to = targetY;
        scrollAnim.start();
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: root.height * appConfig.safeAreaBottom / 100 + 18
        anchors.rightMargin: root.width * appConfig.safeAreaRight / 100 + 24
        width: 48
        height: 48
        radius: 24
        color: settingsBtn.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
        z: 50
        visible: !settingsPage.visible
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "⚙"
            font.pixelSize: 22
            color: "#CCCCCC"
        }

        MouseArea {
            id: settingsBtn
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: settingsPage.visible = true
        }
    }

    SettingsPage {
        id: settingsPage
        anchors.fill: parent
        visible: false
        z: 100
        onVisibleChanged: {
            if (visible) settingsPage.forceActiveFocus();
            else mainFocus.forceActiveFocus();
        }
    }

    Connections {
        target: appLauncher
        function onSettingsRequested() { settingsPage.visible = true; }
    }

    onActiveChanged: {
        if (!active)
            appLauncher.loadingId = "";
        if (active) {
            if (settingsPage.visible) settingsPage.forceActiveFocus();
            else mainFocus.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        mainFocus.forceActiveFocus();
        reloadBackground();
    }
}

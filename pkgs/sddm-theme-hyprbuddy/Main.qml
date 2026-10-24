// HyprBuddy SDDM 主题：深黑底 + 主视觉背景 + 霓虹青/品红渐变卡片。
// 配色与 docs/themes/HyprBuddy.md 一致，Plymouth 同源（pkgs/plymouth-theme-hyprbuddy）。
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0A0C0D"

    property string accent: "#02F0FA"        // 霓虹青（主强调）
    property string accent2: "#E926F5"       // 品红（次强调）
    property string fg: "#C6CDD0"            // 冷白正文
    property string fgDim: "#5A656A"         // 钢灰次要文字
    property string panel: "#DD0D0F10"       // 主面（半透明）
    property string danger: "#FF5C7A"        // 警示粉红

    // 背景：HyprBuddy 主视觉（构建期从 wallpapers/10-hyprbuddy.png 缩放）
    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    // 压暗背景，突出前景
    Rectangle { anchors.fill: parent; color: "#590A0C0D" }

    // 时钟（自绘，避免依赖 SddmComponents.Clock 的属性差异）
    Item {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.07
        property var now: new Date()
        width: childrenRect.width
        height: childrenRect.height
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: clock.now = new Date()
        }
        Column {
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.now, "HH:mm")
                font.pixelSize: 60
                font.weight: Font.Light
                color: root.fg
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.now, "dddd  MMMM d")
                font.pixelSize: 15
                color: root.accent
            }
        }
    }

    // 登录卡片：外层渐变矩形充当青→品红渐变描边（对应活动边框 45deg 渐变）
    Rectangle {
        id: cardBorder
        anchors.centerIn: parent
        width: 380
        height: cardColumn.implicitHeight + 56
        radius: 18
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.accent }
            GradientStop { position: 1.0; color: root.accent2 }
        }
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 1
            radius: 17
            color: root.panel
            Column {
                id: cardColumn
                anchors.centerIn: parent
                width: parent.width - 56
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "HyprBuddy"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: root.fg
                }

                Textbox {
                    id: user
                    width: parent.width
                    height: 34
                    font.pixelSize: 14
                    color: root.fg
                    text: userModel.lastUser
                    KeyNavigation.tab: password
                }
                Textbox {
                    id: password
                    width: parent.width
                    height: 34
                    font.pixelSize: 14
                    color: root.fg
                    echoMode: TextInput.Password
                    onAccepted: sddm.login(user.text, password.text, sessionButton.selectedIndex)
                    KeyNavigation.tab: loginButton
                }

                Text {
                    id: errorMsg
                    width: parent.width
                    text: textConstants.loginFailed
                    color: root.danger
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    visible: false
                }

                Button {
                    id: loginButton
                    width: parent.width
                    height: 36
                    text: textConstants.login
                    onClicked: sddm.login(user.text, password.text, sessionButton.selectedIndex)
                    KeyNavigation.tab: user
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { errorMsg.visible = true; password.text = ""; password.focus = true }
    }

    // 底部：会话选择（左） + 电源（右）
    SessionButton {
        id: sessionButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        font.pixelSize: 13
        color: root.fg
    }
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10
        Button {
            text: textConstants.reboot
            onClicked: sddm.reboot()
        }
        Button {
            text: textConstants.shutdown
            onClicked: sddm.powerOff()
        }
    }

    Component.onCompleted: {
        if (user.text === "") user.focus = true
        else password.focus = true
    }
}

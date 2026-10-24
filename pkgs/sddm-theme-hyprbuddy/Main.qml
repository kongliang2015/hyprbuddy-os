// HyprBuddy SDDM 主题：深黑底 + 主视觉背景 + 霓虹青/品红渐变卡片。
// 配色与 docs/themes/HyprBuddy.md 一致，Plymouth 同源（pkgs/plymouth-theme-hyprbuddy）。
// 布局：背景居左让出主视觉 logo，登录卡片靠右，两者互不遮挡。
// 注意：SDDM 0.21 (Qt6) 的 SddmComponents 已移除 SessionButton，TextBox/PasswordBox
// 不暴露 onAccepted（无法回车登录），且 textConstants 需自行实例化。
// 因此输入框用自定义 AuthField（TextInput），仅 Button/ComboBox/TextConstants 来自 SddmComponents。
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0A0C0D"

    // 布局参数
    property real bgZoom: 1.15    // 背景放大倍数：略大于 1 是为了保证左移后仍铺满右边缘
    property real bgShift: 0.15   // 背景左移量（占屏宽），logo 中心约在 35% 屏宽
    property real cardShift: 0.20 // 登录卡片中心右移，约在 70% 屏宽

    property string accent: "#02F0FA"        // 霓虹青（主强调）
    property string accent2: "#E926F5"       // 品红（次强调）
    property string fg: "#C6CDD0"            // 冷白正文
    property string fgDim: "#5A656A"         // 钢灰次要文字
    property string panel: "#DD0D0F10"       // 主面
    property string border: "#292C2E"        // 深钢灰描边
    property string danger: "#FF5C7A"        // 警示粉红

    TextConstants { id: textConstants }

    // 自定义输入框：支持回车（onAccepted），聚焦时青色描边
    component AuthField: Rectangle {
        id: field
        property alias text: input.text
        property bool isPassword: false
        signal accepted
        height: 34
        radius: 8
        color: "#440D0F10"
        border.color: input.activeFocus ? root.accent : root.border
        border.width: 1
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: 14
            color: root.fg
            selectionColor: root.accent
            selectedTextColor: "#0A0C0D"
            echoMode: field.isPassword ? TextInput.Password : TextInput.Normal
            onAccepted: field.accepted()
        }
    }

    // 背景：轻微放大并整体左移，logo 让到屏幕左侧
    Image {
        width: parent.width * root.bgZoom
        height: parent.height * root.bgZoom
        x: -parent.width * root.bgShift
        y: -(parent.height * root.bgZoom - parent.height) / 2
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    // 压暗背景，突出前景
    Rectangle { anchors.fill: parent; color: "#590A0C0D" }

    // 时钟（自绘），跟随 logo 居中在其上方
    Item {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -parent.width * root.bgShift
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

    // 登录卡片：外层渐变矩形充当青→品红渐变描边（对应活动边框 45deg 渐变），垂直居中、整体靠右
    Rectangle {
        id: cardBorder
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: parent.width * root.cardShift
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

                AuthField {
                    id: user
                    width: parent.width
                    text: userModel.lastUser
                    KeyNavigation.tab: password
                    onAccepted: password.forceActiveFocus()
                }
                AuthField {
                    id: password
                    width: parent.width
                    isPassword: true
                    KeyNavigation.tab: loginButton
                    onAccepted: sddm.login(user.text, password.text, sessionCombo.index)
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
                    textColor: root.fg
                    borderColor: root.accent
                    onClicked: sddm.login(user.text, password.text, sessionCombo.index)
                    KeyNavigation.tab: user
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { errorMsg.visible = true; password.text = ""; password.forceActiveFocus() }
    }

    // 底部：会话选择（左） + 电源（右）。SddmComponents 的 ComboBox 显示 sessionModel 的 name 角色
    ComboBox {
        id: sessionCombo
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        model: sessionModel
        index: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        font.pixelSize: 13
        textColor: root.fgDim
        color: "#440D0F10"
        borderColor: root.border
        focusColor: root.accent
        menuColor: "#EE0D0F10"
    }
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        spacing: 10
        Button {
            text: textConstants.reboot
            textColor: root.fgDim
            onClicked: sddm.reboot()
        }
        Button {
            text: textConstants.shutdown
            textColor: root.fgDim
            onClicked: sddm.powerOff()
        }
    }

    Component.onCompleted: {
        if (user.text === "") user.forceActiveFocus()
        else password.forceActiveFocus()
    }
}

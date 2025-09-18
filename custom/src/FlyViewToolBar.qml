/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls





Rectangle {
    id:     _root
    width:  parent.width
    height: ScreenTools.toolbarHeight
    color:  qgcPal.toolbarBackground

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple

    readonly property real _rightLogoMargin:  ScreenTools.defaultFontPixelHeight * 0.66
    readonly property real _rightLogoSpacing: ScreenTools.defaultFontPixelWidth

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          "black"
        visible:        qgcPal.globalTheme === QGCPalette.Light
    }

    Rectangle {
        anchors.fill: viewButtonRow
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;                                     color: _mainStatusBGColor }
            GradientStop { position: currentButton.x + currentButton.width; color: _mainStatusBGColor }
            GradientStop { position: 1;                                     color: _root.color }
        }
    }

    RowLayout {
        id:                     viewButtonRow
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCToolBarButton {
            id:                     currentButton
            Layout.preferredHeight: viewButtonRow.height
            icon.source:            "/res/QGCLogoFull.svg"
            logo:                   true
            onClicked:              mainWindow.showToolSelectDialog()
        }

        MainStatusIndicator {
            id: mainStatusIndicator
            Layout.preferredHeight: viewButtonRow.height
        }

        QGCButton {
            id:                 disconnectButton
            text:               qsTr("Disconnect")
            onClicked:          _activeVehicle.closeVehicle()
            visible:            _activeVehicle && _communicationLost
        }
    }

    QGCFlickable {
        id:                     toolsFlickable
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth / 2
        anchors.left:           viewButtonRow.right
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.right:          parent.right
        contentWidth:           toolIndicators.width
        flickableDirection:     Flickable.HorizontalFlick

        FlyViewToolBarIndicators { id: toolIndicators }
    }

    //-------------------------------------------------------------------------
    //-- Toolbar Logos
    Item {
        id:                     rightLogosRow
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.rightMargin:    _rightLogoMargin
        anchors.topMargin:      _rightLogoMargin
        anchors.bottomMargin:   _rightLogoMargin
        implicitWidth:          logosRow.implicitWidth + (brandImage.visible ? brandImage.width + _rightLogoSpacing : 0)
        width:                  implicitWidth
        visible:                x > (toolsFlickable.x + toolsFlickable.contentWidth + ScreenTools.defaultFontPixelWidth)

        Row {
            id:                     logosRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          brandImage.visible ? brandImage.left : parent.right
            anchors.rightMargin:    brandImage.visible ? _rightLogoSpacing : 0
            height:                 parent.height
            spacing:                _rightLogoSpacing

            Image {
                id:         spiderLogo
                width:      height
                height:     parent.height
                fillMode:   Image.PreserveAspectFit
                source:     "qrc:/Custom/res/SpiderLogo.svg"
                mipmap:     true
            }

            Image {
                id:         antLogo
                width:      height
                height:     parent.height
                fillMode:   Image.PreserveAspectFit
                source:     "qrc:/Custom/res/AntLogo.svg"
                mipmap:     true
            }
        }

        Image {
            id:                 brandImage
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            fillMode:           Image.PreserveAspectFit
            source:             _outdoorPalette ? _brandImageOutdoor : _brandImageIndoor
            mipmap:             true
            visible:            _activeVehicle && !_communicationLost && source.length !== 0

            property bool   _outdoorPalette:        qgcPal.globalTheme === QGCPalette.Light
            property bool   _corePluginBranding:    QGroundControl.corePlugin.brandImageIndoor.length != 0
            property string _userBrandImageIndoor:  QGroundControl.settingsManager.brandImageSettings.userBrandImageIndoor.value
            property string _userBrandImageOutdoor: QGroundControl.settingsManager.brandImageSettings.userBrandImageOutdoor.value
            property bool   _userBrandingIndoor:    QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageIndoor.length != 0
            property bool   _userBrandingOutdoor:   QGroundControl.settingsManager.brandImageSettings.visible && _userBrandImageOutdoor.length != 0
            property string _brandImageIndoor:      brandImageIndoor()
            property string _brandImageOutdoor:     brandImageOutdoor()

            function brandImageIndoor() {
                if (_userBrandingIndoor) {
                    return _userBrandImageIndoor
                } else {
                    if (_userBrandingOutdoor) {
                        return _userBrandImageOutdoor
                    } else {
                        if (_corePluginBranding) {
                            return QGroundControl.corePlugin.brandImageIndoor
                        } else {
                            return _activeVehicle ? _activeVehicle.brandImageIndoor : ""
                        }
                    }
                }
            }

            function brandImageOutdoor() {
                if (_userBrandingOutdoor) {
                    return _userBrandImageOutdoor
                } else {
                    if (_userBrandingIndoor) {
                        return _userBrandImageIndoor
                    } else {
                        if (_corePluginBranding) {
                            return QGroundControl.corePlugin.brandImageOutdoor
                        } else {
                            return _activeVehicle ? _activeVehicle.brandImageOutdoor : ""
                        }
                    }
                }
            }
        }
    }

    // Small parameter download progress bar
    Rectangle {
        anchors.bottom: parent.bottom
        height:         _root.height * 0.05
        width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
        color:          qgcPal.colorGreen
        visible:        !largeProgressBar.visible
    }

    // Large parameter download progress bar
    Rectangle {
        id:             largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         parent.height
        color:          qgcPal.window
        visible:        _showLargeProgress

        property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
        property bool _userHide:                false
        property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn:   parent
            text:               qsTr("Downloading")
            font.pointSize:     ScreenTools.largeFontPointSize
        }

        QGCLabel {
            anchors.margins:    _margin
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            text:               qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill:   parent
            onClicked:      largeProgressBar._userHide = true
        }
    }
}

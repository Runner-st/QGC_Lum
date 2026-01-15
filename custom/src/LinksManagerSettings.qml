/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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
import QGroundControl.AppSettings
import QGroundControl.Controls

SettingsPage {
    id: root

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    readonly property bool _pluginReady: QGroundControl.corePlugin !== null &&
                                          QGroundControl.corePlugin !== undefined &&
                                          QGroundControl.corePlugin.linksManager !== null
    readonly property var _linksManager: _pluginReady ? QGroundControl.corePlugin.linksManager : null

    function _openEditDialog(linkConfig, isNew) {
        if (!_pluginReady) return

        var dialog = editDialogComponent.createObject(root, {
            "editingConfig": isNew ? _linksManager.createConfiguration() : _linksManager.duplicateForEditing(linkConfig),
            "originalConfig": isNew ? null : linkConfig,
            "isNew": isNew
        })
        dialog.open()
    }

    function _deleteLink(linkConfig) {
        if (!_pluginReady || !linkConfig) return
        _linksManager.removeConfiguration(linkConfig)
    }

    function _activateLink(linkConfig) {
        if (!_pluginReady || !linkConfig) return
        _linksManager.activateLink(linkConfig)
    }

    function _testConnection(linkConfig) {
        if (!_pluginReady || !linkConfig) return
        _linksManager.testConnection(linkConfig)
    }

    // Edit Dialog Component
    Component {
        id: editDialogComponent
        LinksManagerEditDialog { }
    }

    // Import File Dialog (for single link)
    FileDialog {
        id: importDialog
        title: qsTr("Import Link from JSON")
        nameFilters: ["JSON files (*.json)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (_pluginReady) {
                _linksManager.importLinkFromJson(selectedFile.toString().replace("file:///", ""))
            }
        }
    }

    // Export File Dialog (for single link)
    FileDialog {
        id: exportDialog
        title: qsTr("Export Link to JSON")
        nameFilters: ["JSON files (*.json)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        property var linkToExport: null
        onAccepted: {
            if (_pluginReady && linkToExport) {
                _linksManager.exportLinkToJson(linkToExport, selectedFile.toString().replace("file:///", ""))
            }
        }
    }

    function _exportLink(linkConfig) {
        if (!_pluginReady || !linkConfig) return
        exportDialog.linkToExport = linkConfig
        exportDialog.open()
    }

    // Test Connection Results
    Connections {
        target: _linksManager
        function onTestConnectionResult(config, success, message) {
            testResultLabel.text = (success ? "✓ " : "✗ ") + message
            testResultLabel.color = success ? "green" : "red"
            testResultLabel.visible = true
            testResultTimer.restart()
        }
        function onImportExportResult(success, message) {
            testResultLabel.text = (success ? "✓ " : "✗ ") + message
            testResultLabel.color = success ? "green" : "red"
            testResultLabel.visible = true
            testResultTimer.restart()
        }
    }

    Timer {
        id: testResultTimer
        interval: 5000
        onTriggered: testResultLabel.visible = false
    }

    SettingsGroupLayout {
        Layout.minimumWidth: implicitWidth
        heading: qsTr("Managed Links")
        headingDescription: qsTr("Configure flight controller connections with associated camera streams.")
        contentSpacing: ScreenTools.defaultFontPixelHeight

        ColumnLayout {
            Layout.minimumWidth: implicitWidth
            spacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                visible: !_pluginReady
                text: qsTr("Links Manager is unavailable.")
            }

            // Status message
            QGCLabel {
                id: testResultLabel
                visible: false
            }

            // Links list
            QGCLabel {
                visible: _pluginReady && linkRepeater.count === 0
                text: qsTr("No managed links configured. Click 'Add New Link' to create one.")
            }

            Repeater {
                id: linkRepeater
                model: _pluginReady ? _linksManager.managedLinks : []

                Rectangle {
                    Layout.minimumWidth: linkColumn.implicitWidth + ScreenTools.defaultFontPixelHeight
                    height: linkColumn.height + ScreenTools.defaultFontPixelHeight
                    color: _linksManager && _linksManager.activeLink === object ?
                           Qt.rgba(0, 0.5, 0, 0.2) : "transparent"
                    border.color: qgcPal.groupBorder
                    border.width: 1
                    radius: 4

                    ColumnLayout {
                        id: linkColumn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: ScreenTools.defaultFontPixelHeight / 2
                        spacing: ScreenTools.defaultFontPixelHeight / 4

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                text: object.name
                                font.bold: true
                                font.pointSize: ScreenTools.mediumFontPointSize
                            }

                            QGCLabel {
                                visible: _linksManager && _linksManager.activeLink === object
                                text: qsTr("ACTIVE")
                                color: "green"
                                font.bold: true
                            }
                        }

                        QGCLabel {
                            text: object.serverAddress + ":" + object.serverPort +
                                  (object.autoConnect ? qsTr(" (Auto-connect)") : "")
                            color: qgcPal.textFieldText
                        }

                        // Camera info
                        QGCLabel {
                            visible: !object.camera1.isEmpty || !object.camera2.isEmpty
                            text: {
                                var cams = []
                                if (object.camera1 && !object.camera1.isEmpty) {
                                    cams.push(object.camera1.name || qsTr("Camera 1"))
                                }
                                if (object.camera2 && !object.camera2.isEmpty) {
                                    cams.push(object.camera2.name || qsTr("Camera 2"))
                                }
                                return qsTr("Cameras: ") + cams.join(", ")
                            }
                            color: qgcPal.textFieldText
                            font.pointSize: ScreenTools.smallFontPointSize
                        }

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCButton {
                                text: _linksManager && _linksManager.activeLink === object ?
                                      qsTr("Deactivate") : qsTr("Activate")
                                onClicked: {
                                    if (_linksManager.activeLink === object) {
                                        _linksManager.deactivateLink()
                                    } else {
                                        _activateLink(object)
                                    }
                                }
                                enabled: _pluginReady
                            }

                            QGCButton {
                                text: qsTr("Edit")
                                onClicked: _openEditDialog(object, false)
                                enabled: _pluginReady
                            }

                            QGCButton {
                                text: qsTr("Test")
                                onClicked: _testConnection(object)
                                enabled: _pluginReady
                            }

                            QGCButton {
                                text: qsTr("Export")
                                onClicked: _exportLink(object)
                                enabled: _pluginReady
                            }

                            QGCButton {
                                text: qsTr("Delete")
                                onClicked: _deleteLink(object)
                                enabled: _pluginReady
                            }
                        }
                    }
                }
            }

            // Add new link and import buttons
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: qsTr("Add New Link")
                    onClicked: _openEditDialog(null, true)
                    enabled: _pluginReady
                }

                QGCButton {
                    text: qsTr("Import Link")
                    onClicked: importDialog.open()
                    enabled: _pluginReady
                }
            }
        }
    }
}

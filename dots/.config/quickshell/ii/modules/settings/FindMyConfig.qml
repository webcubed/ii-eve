import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets


ContentPage {
    forceWidth: true

    ContentSection {
        icon: "location_on"
        title: Translation.tr("Find My People")

        ConfigSwitch {
            text: Translation.tr("Show the People widget in the left sidebar")
            checked: Config.options.sidebar.findMy.enable
            onCheckedChanged: Config.options.sidebar.findMy.enable = checked
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.sidebar.findMy.pollIntervalSeconds
            from: 10
            to: 600
            stepSize: 10
            onValueChanged: Config.options.sidebar.findMy.pollIntervalSeconds = value
        }
        ConfigSpinBox {
            icon: "timeline"
            text: Translation.tr("Trail history points per person")
            value: Config.options.sidebar.findMy.trailMaxPoints
            from: 50
            to: 2000
            stepSize: 50
            onValueChanged: Config.options.sidebar.findMy.trailMaxPoints = value
        }
        ConfigSwitch {
            text: Translation.tr("Draw movement trails")
            checked: Config.options.sidebar.findMy.showTrails
            onCheckedChanged: Config.options.sidebar.findMy.showTrails = checked
        }
        ConfigSwitch {
            text: Translation.tr("Notify when someone enters/leaves an area of interest")
            checked: Config.options.sidebar.findMy.aoiNotify
            onCheckedChanged: Config.options.sidebar.findMy.aoiNotify = checked
        }
        ConfigRow {
            StyledText {
                text: Translation.tr("Mapbox map style")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
            }
            MaterialTextField {
                Layout.preferredWidth: 200
                text: Config.options.sidebar.findMy.mapStyle
                placeholderText: "dark-v10"
                onTextEdited: Config.options.sidebar.findMy.mapStyle = text
            }
        }
    }

    ContentSection {
        icon: "key"
        title: Translation.tr("Mapbox access token")

        StyledText {
            text: Translation.tr("Get a free token at mapbox.com, then paste it below. It is stored in your keyring.")
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        ConfigRow {
            MaterialTextField {
                id: tokenField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Translation.tr("pk.eyJ1…")
                text: FindMy.mapboxTokenReady ? FindMy.mapboxToken : ""
            }
            RippleButtonWithIcon {
                materialIcon: "save"
                mainText: Translation.tr("Save")
                onClicked: {
                    const t = tokenField.text.trim();
                    if (t.length === 0) { FindMy.clearMapboxToken(); return; }
                    FindMy.setMapboxToken(t);
                }
            }
        }
        StyledText {
            visible: FindMy.mapboxTokenReady
            text: Translation.tr("Token saved ✓")
            color: Appearance.colors.colPrimary
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    ContentSection {
        icon: "account_circle"
        title: Translation.tr("Google account")

        ConfigRow {
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: FindMy.authenticated
                    ? Translation.tr("Signed in — monitoring %1 people shown in the widget").arg(FindMy.people.length)
                    : (FindMy.authenticating
                        ? Translation.tr("Waiting for sign-in… the browser should have opened. Grant access, then make sure people share their location with this account.")
                        : Translation.tr("Not signed in. Press Login, sign in with your browser, then share your own location too."))
                color: FindMy.authenticated ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
        ConfigRow {
            RippleButtonWithIcon {
                materialIcon: "login"
                mainText: Translation.tr("Login with Browser")
                onClicked: FindMy.login()
            }
            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: Translation.tr("Refresh now")
                onClicked: FindMy.refreshNow()
            }
            RippleButtonWithIcon {
                materialIcon: "logout"
                mainText: Translation.tr("Sign out")
                onClicked: FindMy.logout()
            }
            RippleButtonWithIcon {
                materialIcon: "cleaning_services"
                mainText: Translation.tr("Clear trails")
                onClicked: FindMy.clearTrails()
            }
        }
        StyledText {
            visible: FindMy.authError.length > 0
            text: Translation.tr("Last error: %1").arg(FindMy.authError)
            color: Appearance.colors.colErrorContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    ContentSection {
        icon: "add_location_alt"
        title: Translation.tr("Areas of interest")

        ConfigRow {
            MaterialTextField {
                id: aoiNameInput
                Layout.preferredWidth: 140
                placeholderText: Translation.tr("Name")
            }
            MaterialTextField {
                id: aoiLatInput
                Layout.preferredWidth: 90
                placeholderText: Translation.tr("Latitude")
            }
            MaterialTextField {
                id: aoiLngInput
                Layout.preferredWidth: 90
                placeholderText: Translation.tr("Longitude")
            }
            MaterialTextField {
                id: aoiRadiusInput
                Layout.preferredWidth: 70
                placeholderText: Translation.tr("km")
            }
            RippleButtonWithIcon {
                materialIcon: "add"
                mainText: Translation.tr("Add")
                onClicked: {
                    const name = aoiNameInput.text.trim();
                    const lat = parseFloat(aoiLatInput.text.replace(",", "."));
                    const lng = parseFloat(aoiLngInput.text.replace(",", "."));
                    const r = parseFloat(aoiRadiusInput.text.replace(",", ".")) || 1;
                    if (!name || isNaN(lat) || isNaN(lng)) return;
                    FindMy.addAoi(name, lat, lng, r);
                    aoiNameInput.text = ""; aoiLatInput.text = ""; aoiLngInput.text = ""; aoiRadiusInput.text = "";
                }
                StyledToolTip {
                    text: Translation.tr("Add an AOI by coordinates (you can also click the map in the sidebar widget while in AOI mode)")
                }
            }
        }
        Repeater {
            model: FindMy.aois
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    spacing: 8
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name + "  (" + modelData.lat + ", " + modelData.lng + ")  " + modelData.radius_km + " km"
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                    IconToolbarButton {
                        text: "close"
                        implicitHeight: 26
                        implicitWidth: 26
                        onClicked: FindMy.removeAoi(modelData.id)
                    }
                }
            }
        }
    }
}
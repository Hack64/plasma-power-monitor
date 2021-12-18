/*
 * Copyright 2021  Atul Gopinathan  <leoatul12@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */

import QtQuick 2.6
import QtQuick.Layouts 1.1
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0


Item {
    id: main
    anchors.fill: parent
    
    //height and width, when the widget is placed in desktop
    width: 80
    height: 20

    //height and width, when widget is placed in plasma panel
    Layout.preferredWidth: 80 * units.devicePixelRatio
    Layout.preferredHeight: 20 * units.devicePixelRatio

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    property variant paths: getBatPath()
    property bool powerNow: checkPowerNow(paths)
    property double power: getPower(paths)
    property bool inCharge: getChargingStatus()

    //this function checks whether the device is being charged or not
    function getChargingStatus(){
        var node = "/sys/class/power_supply/AC/online";
        var req = new XMLHttpRequest();
        req.open("GET", node, false);
        req.send(null);
        if(req.responseText == 1){
            return true;
        } else {
            return false;
        }
    }

    //this function tries to find the exact path to battery file
    function getBatPath() {
        var arr=[];
        for(var i=0; i<4; i++) {
            var path = "/sys/class/power_supply/BAT" + i + "/voltage_now";
            var req = new XMLHttpRequest();
            req.open("GET", path, false);
            req.send(null)
            if(req.responseText != "") {
                //console.log(path)
                arr.push("/sys/class/power_supply/BAT" + i);
            }
        }
        return arr
    }

    //this function checks if the "/sys/class/power_supply/BAT[i]/power_now" file exists
    function checkPowerNow(fileUrls) {
        if(fileUrls == "") {
            return false
        }
        var idx;
        for(idx in fileUrls){
            var path = fileUrls[idx] + "/power_now"
            var req = new XMLHttpRequest();

            req.open("GET", path, false);
            req.send(null);

            if(req.responseText == "") {
                return false
            }
            else {
                return true
            }
        }
    }

    //Returns power usage in Watts, rounded off to 1 decimal.
    function getPower(fileUrls) {
        //if there is no BAT[i] file at all
        if(fileUrls == "") {
            return "0.0"
        }

        //in case the "power_now" file exists:
        if( main.powerNow == true) {
            var idx;
            for(idx in fileUrls){
                var path = fileUrls[idx] + "/power_now"
                var req = new XMLHttpRequest();
                req.open("GET", path, false);
                req.send(null);

                var power = parseInt(req.responseText) / 1000000;
                if(power > 0){
                    return(Math.round(power*10)/10);
                }
            }

        }

        //if the power_now file doesn't exist, we collect voltage
        //and current and manually calculate power consumption
        for(var idx in fileUrls){
            var curUrl = fileUrls[idx] + "/current_now"
            var voltUrl = fileUrls[idx] + "/voltage_now"

            var curReq = new XMLHttpRequest();
            var voltReq = new XMLHttpRequest();

            curReq.open("GET", curUrl, false);
            voltReq.open("GET", voltUrl, false);

            curReq.send(null);
            voltReq.send(null);

            var power = (parseInt(curReq.responseText) * parseInt(voltReq.responseText))/1000000000000;
            //console.log(power.toFixed(1));
            if (power > 0){
                return Math.round(power*10)/10; //toFixed() is apparently slow, so we use this way
            }
        }

    }

    PlasmaComponents.Label {
        id: display

        anchors {
            fill: parent
            margins: Math.round(parent.width * 0.01)
        }

        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter

        text: {
            if(main.inCharge == false){
                if(Number.isInteger(main.power)) {
                    return(main.power + ".0 W");
                }
                else {
                    return(main.power + " W");
                }
            } else {
                return "⚡";
            }
        }

        font.pixelSize: 1000;
        minimumPointSize: theme.smallestFont.pointSize
        fontSizeMode: Text.Fit
        font.bold: plasmoid.configuration.makeFontBold
    }

    Timer {
        interval: plasmoid.configuration.updateInterval * 1000
        running: true
        repeat: true
        onTriggered: {
            main.inCharge = getChargingStatus();
            if (main.inCharge == false){
                main.power = getPower(main.paths)

                if(Number.isInteger(main.power)) {
                    //When power has 0 decimal places, it removes the decimal
                    //point inspite of power variable being double. This momentarily
                    //makes the font size bigger due to extra available space which
                    //does not look good. So we do this simple hack of manually adding
                    //a .0 to number
                    display.text = main.power + ".0 W";
                }
                else {
                    display.text = main.power + " W"
                }
            } else {
                display.text = "⚡";
            }
        }
    }
}

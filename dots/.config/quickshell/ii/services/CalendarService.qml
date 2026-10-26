import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import Qt.labs.platform
import qs.modules.common.functions
import qs.modules.common

Singleton {
    id: root

    readonly property string khalPath: "/home/webcubed/.local/bin/khal"
    property bool khalAvailable: false
    property var events: []
    property var weekdays: [
          Translation.tr("Sunday"),
          Translation.tr("Monday"),
          Translation.tr("Tuesday"),
          Translation.tr("Wednesday"),
          Translation.tr("Thursday"),
          Translation.tr("Friday"),
          Translation.tr("Saturday"),
        ];
    property var sortedWeekdays: root.weekdays.map((_, i) => weekdays[(i+Config.options.time.firstDayOfWeek+1)%7]);
    property var eventsInWeek: root.buildEventsInWeek()

    function buildEventsInWeek() {
        var result = [];
        var d = new Date();
        var currentDay = d.getDay();
        var mondayOffset = currentDay === 0 ? -6 : 1 - currentDay;
        d.setDate(d.getDate() + mondayOffset);
        d.setHours(0, 0, 0, 0);

        for (var i = 0; i < 7; i++) {
            var dayDate = new Date(d);
            dayDate.setDate(d.getDate() + i);
            var dayEvents = root.getTasksByDate(dayDate);
            var weekdayName = root.weekdays[dayDate.getDay()];
            var formattedEvents = [];
            for (var j = 0; j < dayEvents.length; j++) {
                var evt = dayEvents[j];
                var startTime = evt['startDate'] ? Qt.formatDateTime(evt['startDate'], "HH:mm") : "00:00";
                var endTime = evt['endDate'] ? Qt.formatDateTime(evt['endDate'], "HH:mm") : "23:59";
                formattedEvents.push({
                    "title": evt['content'],
                    "start": startTime,
                    "end": endTime,
                    "color": evt['color'],
                    "description": evt['description'] ?? ""
                });
            }
            result.push({
                "name": weekdayName,
                "events": formattedEvents
            });
        }
        return result;
    }

    // Process for checking khal configuration
    Process {
        id: khalCheckProcess
        command: [root.khalPath, "list", "today"]
        running: true
        onExited: (exitCode) => {
          root.khalAvailable = (exitCode === 0);
          console.log("[CalendarService] khal available:", root.khalAvailable)
          if(root.khalAvailable){
            getEventsProcess.running = true
          }
        }
      }

      function getTasksByDate(currentDate) {
        if(!khalAvailable){
          return []
        }
        const res = [];

        const currentDay = currentDate.getDate();
        const currentMonth = currentDate.getMonth();
        const currentYear = currentDate.getFullYear();

        for (let i = 0; i < root.events.length; i++) {
            const taskDate = new Date(root.events[i]['startDate']);
            if (
                taskDate.getDate() === currentDay &&
                taskDate.getMonth() === currentMonth &&
                taskDate.getFullYear() === currentYear
              ) {
                res.push(root.events[i]);
              }
        }

        return res;
      }

    // Process for loading events
    Process {
      id: getEventsProcess
      running: false
        command: [root.khalPath, "list", "--json", "title", "--json", "start-date", "--json" ,"start-time", "--json" ,"end-time", "--json", "description",    Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() - 3); return d; })(), "dd.MM.yyyy") ,Qt.formatDate((() => { let d = new Date(); d.setMonth(d.getMonth() + 3); return d; })(), "dd.MM.yyyy")]
        stdout: StdioCollector {

          onStreamFinished:{
            let events = []
            let lines = this.text.split('\n')
             for(let line of lines){
               line = line.trim()
               if (!line || line === "[]")
                    continue
               let dayEvents
               try {
                 dayEvents = JSON.parse(line)
               } catch(e) {
                 continue
               }
               for(let event of dayEvents){
                 let dateParts = event['start-date'].split('.')
                 let day = parseInt(dateParts[0])
                 let month = parseInt(dateParts[1]) - 1
                 let year = (dateParts.length > 2 && dateParts[2] !== "") ? parseInt(dateParts[2]) : new Date().getFullYear()

                 let startTimeParts = event['start-time']
                     ? event['start-time'].split(':').map(Number)
                     : [0, 0];

                 let endTimeParts = event['end-time']
                     ? event['end-time'].split(':').map(Number)
                     : [23, 59];


                 let startDate = new Date(year, month, day,
                                          parseInt(startTimeParts[0]),
                                          parseInt(startTimeParts[1]))

                 let endDate = new Date(year, month, day,
                                        parseInt(endTimeParts[0]),
                                        parseInt(endTimeParts[1]))

                 events.push({
                     "content": event['title'],
                     "startDate": startDate,
                     "endDate": endDate,
                     "color": ColorUtils.stringToColor(event['title']),
                     "description": event['description'] ?? ""
                 })
                 }
               }
               root.events = events
               console.log("[CalendarService] Loaded", events.length, "events")
               root.eventsInWeek = root.buildEventsInWeek()
          }

        }
      }

      Timer {
        id: refreshTimer
        running: root.khalAvailable
        interval: 30000
        repeat: true
        onTriggered: {
          getEventsProcess.running = true
        }
    }

      Process {
        id: khalAddTaskProcess
        running: false
      }

      function addItem(item){
        let title =  item['content']
        let formattedDate = Qt.formatDate(item['date'], "dd.MM.yyyy")
        khalAddTaskProcess.command = [root.khalPath, "new", formattedDate, title]
        khalAddTaskProcess.running = true
      }

    Process {
        id: khalRemoveProcess
        running: false
      }

      function removeItem(item){
        let taskToDelete =  item['content']

        khalRemoveProcess.command = [
          "sqlite3",
          String(StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]).replace("file://", "") + "/.local/share/khal/khal.db",
          "DELETE FROM events WHERE item LIKE '%SUMMARY:" + taskToDelete + "%';"
          ]

          khalRemoveProcess.running = true
          console.log(khalRemoveProcess.command)
    }
}

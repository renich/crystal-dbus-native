var data = {lines:[
{"lineNum":"    1","line":"require \"socket\""},
{"lineNum":"    2","line":""},
{"lineNum":"    3","line":"module Crystal::Dbus::Native"},
{"lineNum":"    4","line":"  class DBusConnection"},
{"lineNum":"    5","line":"    def initialize(@client : UNIXSocket)","class":"lineCov","hits":"3","order":"1","possible_hits":"3",},
{"lineNum":"    6","line":"    end","class":"lineCov","hits":"1","order":"2","possible_hits":"1",},
{"lineNum":"    7","line":""},
{"lineNum":"    8","line":"    def start"},
{"lineNum":"    9","line":"      # Start handling connection if necessary"},
{"lineNum":"   10","line":"    end"},
{"lineNum":"   11","line":""},
{"lineNum":"   12","line":"    def close(timeout : Time::Span? = nil)","class":"lineCov","hits":"2","order":"3","possible_hits":"2",},
{"lineNum":"   13","line":"      @client.close unless @client.closed?","class":"lineCov","hits":"1","order":"4","possible_hits":"1",},
{"lineNum":"   14","line":"    end"},
{"lineNum":"   15","line":"  end"},
{"lineNum":"   16","line":"end"},
]};
var percent_low = 25;var percent_high = 75;
var header = { "command" : "spec_runner", "date" : "2026-06-05 05:38:38", "instrumented" : 4, "covered" : 4,};
var merged_data = [];

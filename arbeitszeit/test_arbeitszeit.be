# Lokaler Test fuer arbeitszeit.ax: stubbt die AWTRIX-NG-Laufzeit und spielt Knopf, MQTT-Befehle,
# Pausenregeln und Mitternachts-Reset durch. Ausfuehren im Ordner arbeitszeit/ mit einem
# Standalone-Berry (https://github.com/berry-lang/berry, make): berry test_arbeitszeit.be
import string

# Standalone Berry has no re module; the app only uses "(\\d+):(\\d+)".
re = module("re")
re.search = def (pat, s)
  if s == nil || s == "" return nil end
  var i = string.find(s, ":")
  if i < 0 return nil end
  var h = s[0..i-1]
  var m = s[i+1..]
  if size(h) == 0 || size(m) == 0 return nil end
  return [s, h, m]
end

var clock = { "h": 9, "m": 0, "d": 1 }
var kv = {}
var published = []
var subs = {}

store = module("store")
store.get = def (k) return kv.find(k) end
store.set = def (k, v) kv[k] = v end

mqtt = module("mqtt")
mqtt.publish = def (t, p) published.push([t, p]) end
mqtt.subscribe = def (t, cb) subs[t] = cb end

hour = def () return clock["h"] end
minute = def () return clock["m"] end
day = def () return clock["d"] end
now_ms = def () return 0 end
width = def () return 32 end
text_ink_width = def (s) return size(s) * 4 end
text_width = def (s) return size(s) * 4 end
rgb = def (r, g, b) return (r << 16) | (g << 8) | b end
clamp = def (v, lo, hi) return v < lo ? lo : (v > hi ? hi : v) end
notify = def (m) print("notify: " + str(m)) end
clear = def () end
icon = def (i, x, y) return true end
rect_fill = def (x, y, w, h, c) end
text = def (x, y, s, c) end
log = def (v) print(v) end

var failures = 0
def check(name, cond)
  if cond
    print("ok   " + name)
  else
    failures += 1
    print("FAIL " + name)
  end
end

def defaults(with_mqtt)
  kv = {
    "start": "", "soll": 8, "farbe": 0x00CC44, "ueberzeit": 0xFF8800,
    "icon_unter": "5582", "icon_ueber": "24443", "ueber_max": 2, "max": 10,
    "mqtt": with_mqtt, "topic": "awtrix/arbeitszeit",
  }
  published = []
  subs = {}
end

def load_app()
  var f = open("arbeitszeit.ax", "r")
  var src = f.read()
  f.close()
  var app = compile(src)()
  app.setup()
  return app
end

def last_state()
  if size(published) == 0 return nil end
  return published[-1][1]
end

# --- 1. Not configured, MQTT on: subscribe happened, reminder publishes minutely
defaults(true)
var app = load_app()
check("subscribes to cmd topic", subs.contains("awtrix/arbeitszeit/cmd"))
app.loop()
check("reminder state published once", size(published) == 1 && last_state() == '{"start_min":null,"paused":false,"pause_min":0,"net_min":0}')
app.loop()
check("no second publish within the same minute", size(published) == 1)
clock["m"] = 1
app.loop()
check("publishes again in the next minute", size(published) == 2)

# --- 2. clock_in over MQTT at 09:01
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "clock_in")
check("clock_in sets start in store", kv["start"] == "09:01")
check("clock_in publishes start_min 541", last_state() == '{"start_min":541,"paused":false,"pause_min":0,"net_min":0}')
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "clock_in")
check("second clock_in is ignored", kv["start"] == "09:01")

# --- 3. net time with break rules at 15:01 (6h gross → 30 min break) and 17:01 (8h → 45)
clock["h"] = 15
app.loop()
check("6h gross gives 330 net", app.netto == 330)
clock["h"] = 17
app.loop()
check("8h gross gives 435 net", app.netto == 435)
check("minutely publish carries net_min", last_state() == '{"start_min":541,"paused":false,"pause_min":0,"net_min":435}')

# --- 4. pause / resume via the select button (same code path as MQTT)
clock["h"] = 17; clock["m"] = 10
app.loop()
app.on_button("select")
check("select pauses", app.stopped && app.paused_at == 17 * 60 + 10)
check("pause publishes paused=true and pause_min", last_state() == '{"start_min":541,"paused":true,"pause_min":1030,"net_min":444}')
clock["m"] = 25
app.loop()
check("time frozen while paused", app.netto == 444)
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "resume")
check("resume shifts start by 15 min", kv["start"] == "09:16" && !app.stopped && app.paused_at == nil)
check("resume publishes new start_min", last_state() == '{"start_min":556,"paused":false,"pause_min":0,"net_min":444}')
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "resume")
check("resume while running is ignored", kv["start"] == "09:16")

# --- 5. state query and unknown command
var before = size(published)
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "state")
check("state command answers", size(published) == before + 1)
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "bogus")
check("unknown command ignored", size(published) == before + 1 && kv["start"] == "09:16")

# --- 6. reset over MQTT
subs["awtrix/arbeitszeit/cmd"]("awtrix/arbeitszeit/cmd", "reset")
check("reset clears start", kv["start"] == "" && !app.configured && app.netto == nil)
check("reset publishes null", last_state() == '{"start_min":null,"paused":false,"pause_min":0,"net_min":0}')

# --- 7. midnight reset goes through reset() and publishes
defaults(true)
kv["start"] = "08:00"
clock["h"] = 23; clock["m"] = 59; clock["d"] = 1
app = load_app()
check("restored start from store", app.configured && app.start_min == 480)
clock["h"] = 0; clock["m"] = 0; clock["d"] = 2
app.loop()
check("midnight reset clears start", kv["start"] == "" && !app.configured)
check("midnight reset publishes null", last_state() == '{"start_min":null,"paused":false,"pause_min":0,"net_min":0}')

# --- 8. MQTT switched off: no subscribe, no publish, button still works
defaults(false)
clock["h"] = 9; clock["m"] = 0
app = load_app()
check("no subscription when mqtt is off", size(subs) == 0)
app.loop()
app.on_button("select")
check("button clocks in without mqtt", kv["start"] == "09:00" && app.configured)
app.on_button("select")
app.on_button("select")
check("button pause/resume without mqtt", !app.stopped && kv["start"] == "09:00")
clock["h"] = 12
app.loop()
check("net time without mqtt", app.netto == 180)
check("nothing published when mqtt is off", size(published) == 0)

# --- 9. fanfare at max
defaults(true)
kv["start"] = "07:00"
clock["h"] = 17; clock["m"] = 46
app = load_app()
app.loop()
check("net at max triggers once", app.netto >= 600 && app.fanfare_done)

print("")
print(failures == 0 ? "ALL PASSED" : str(failures) + " FAILED")

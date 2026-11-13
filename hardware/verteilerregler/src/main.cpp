// Duck Curve Verteilerregler - Prototyp fuer 10 Motorventile.
//
// Was die Firmware tut: Sie faehrt Stellungen an, misst dabei den Motorstrom, liest die
// Ruecklauffuehler und meldet alles ueber MQTT. Mehr nicht. Abgleich, Einlernen des Hauses und
// jede Entscheidung, welches Ventil wie weit offen sein soll, gehoeren in den Kern von
// Duck Curve Home - so bleibt die Hardware austauschbar.
//
// Aufbau: ESP32-S3, zwei Portexpander MCP23017 (0x20, 0x21), fuenf Doppel-H-Bruecken DRV8833,
// ein Strommesser INA219 (0x40) in der gemeinsamen Motorversorgung, DS18B20 an einem 1-Wire-Bus.
// Es faehrt immer nur EIN Ventil. Deshalb reicht ein Strommesser fuer alle.
// Der Testaufbau mit zwei Ventilen braucht nur den Expander 0x20 und einen DRV8833; Ventile, deren
// Expander fehlt, melden die Stoerung "I2C" und bleiben stehen.
//
// Stand: uebersetzt, nie an Hardware gelaufen. Alle Stromschwellen sind Startwerte und am ersten
// Antrieb einzustellen.

#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <Adafruit_MCP23X17.h>
#include <Adafruit_INA219.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <esp_task_wdt.h>

// ---------------------------------------------------------------- Zugang (vor dem Flashen eintragen)
static const char* WLAN_SSID = "WLAN-NAME";
static const char* WLAN_PASS = "WLAN-PASSWORT";
static const char* MQTT_HOST = "192.168.1.10";
static const uint16_t MQTT_PORT = 1883;
static const char* BASIS = "duckcurve/verteiler1";

// ---------------------------------------------------------------- Verdrahtung
static const uint8_t N = 10;              // Ventile
static const int PIN_SDA = 8;             // I2C: beide MCP23017 und der INA219
static const int PIN_SCL = 9;
static const int PIN_ONEWIRE = 4;         // DS18B20, 3,3 kOhm nach 3V3
static const int PIN_TREIBER_EIN = 5;     // nSLEEP aller DRV8833, 10 kOhm nach GND
// Ventil k (0..9) haengt an Expander k/8, Pins 2*(k%8) (IN1) und 2*(k%8)+1 (IN2).
static const bool OEFFNEN_IST_IN1 = true; // faehrt "auf" in die falsche Richtung: auf false stellen

// ---------------------------------------------------------------- Schwellen (Startwerte)
static const uint32_t TAKT_MS = 5;             // Abtastung des Motorstroms
static const uint32_t KURVE_DT_MS = 20;        // Raster der aufgezeichneten Stromkurve
static const uint32_t ANLAUF_MS = 150;         // Anlaufstrom ueberspringen
static const uint32_t RUHE_VON_MS = 200;       // Fenster fuer den Freilaufstrom
static const uint32_t RUHE_BIS_MS = 500;
static const uint32_t ANSCHLAG_HALTEN_MS = 40; // so lange muss der Strom ueber der Schwelle liegen
static const uint32_t LAUF_MAX_MS = 90000;     // laenger faehrt kein Antrieb
static const float I_MIN_MA = 2.0f;            // darunter: Antrieb nicht angeschlossen
static const float I_ANSCHLAG_ABS_MA = 80.0f;  // Anschlag, unabhaengig vom Freilaufstrom
static const float I_SOFORT_AUS_MA = 110.0f;   // der VDMOT nennt 120 mA als Hoechstwert
static const float ANSCHLAG_FAKTOR = 2.5f;     // Anschlag = Freilaufstrom mal Faktor ...
static const float ANSCHLAG_PLUS_MA = 30.0f;   // ... oder Freilaufstrom plus Zuschlag, das Groessere
static const float TOTBAND = 2.0f;             // kleinere Aenderungen werden nicht gefahren
// Mindestdurchfluss: Summe aller Sollstellungen in Prozentpunkten. 0 = aus (Werkbank).
// Vor dem Betrieb an einer Waermepumpe setzen, z. B. 100 = ein Kreis ganz offen.
static const float MIN_SUMME_OFFEN = 0.0f;
static const float RUECKFALL_POS = 50.0f;      // Stellung, wenn der Kern lange schweigt
static const uint32_t RUECKFALL_NACH_MS = 30UL * 60UL * 1000UL;

// ---------------------------------------------------------------- Zustand
enum Zustand : uint8_t { UNGELERNT, BEREIT, FAEHRT, LERNT, STOERUNG };
enum Richtung : uint8_t { HALT, AUF, ZU };
enum Phase : uint8_t { P_KEINE, P_FAHRT, P_LERN_AUF1, P_LERN_ZU, P_LERN_AUF2 };
static const char* ZUSTAND_NAME[] = {"ungelernt", "bereit", "faehrt", "lernt", "stoerung"};

struct Ventil {
  float pos = NAN;           // 0 = zu, 100 = offen
  float soll = NAN;
  uint32_t tAuf = 0;         // gelernte Laufzeit zu -> auf in ms
  uint32_t tZu = 0;          // gelernte Laufzeit auf -> zu in ms
  float stromRuhe = 0;       // Freilaufstrom der letzten Fahrt in mA
  Zustand z = UNGELERNT;
  bool lernen = false;       // Lernfahrt angefordert
  bool da = true;            // Expander und Strommesser fuer dieses Ventil antworten
  const char* stoerung = "";
};

struct Lauf {
  int8_t k = -1;             // -1: kein Motor laeuft
  Phase ph = P_KEINE;
  Richtung r = HALT;
  uint32_t start = 0;
  uint32_t dauer = 0;        // 0 = bis zum Anschlag
  float posStart = 0, posZiel = 0;
  uint32_t ueberSeit = 0;    // seit wann der Strom ueber der Schwelle liegt (0 = nicht)
  float ruheSumme = 0;
  uint16_t ruheN = 0;
  uint32_t letzteKurve = 0;
  uint32_t letzterTakt = 0;
};

static const uint16_t KURVE_MAX = 3500;   // 70 s im 20-ms-Raster
static uint16_t kurve[KURVE_MAX];         // Zehntel-Milliampere
static uint16_t kurveN = 0;

static Ventil ventil[N];
static Lauf lauf;
static int8_t zuletztBedient = -1;
static uint32_t letzterBefehl = 0;
static bool rueckfallAktiv = false;

static Adafruit_MCP23X17 mcp[2];
static Adafruit_INA219 ina(0x40);
static OneWire oneWire(PIN_ONEWIRE);
static DallasTemperature fuehler(&oneWire);
static WiFiClient netz;
static PubSubClient mqtt(netz);
static Preferences speicher;
static char puffer[1400];

// ---------------------------------------------------------------- Melden
static void melde(const char* unterthema, const char* text, bool behalten = false) {
  char thema[96];
  snprintf(thema, sizeof(thema), "%s/%s", BASIS, unterthema);
  if (mqtt.connected()) mqtt.publish(thema, text, behalten);
  Serial.printf("%s %s\n", thema, text);
}

static void meldeVentil(uint8_t k) {
  const Ventil& v = ventil[k];
  char thema[40];
  snprintf(thema, sizeof(thema), "ventil/%u/zustand", k + 1);
  snprintf(puffer, sizeof(puffer),
           "{\"pos\":%.1f,\"soll\":%.1f,\"zustand\":\"%s\",\"t_auf_ms\":%lu,\"t_zu_ms\":%lu,"
           "\"strom_ruhe_ma\":%.1f,\"stoerung\":\"%s\"}",
           isnan(v.pos) ? -1.0f : v.pos, isnan(v.soll) ? -1.0f : v.soll, ZUSTAND_NAME[v.z],
           (unsigned long)v.tAuf, (unsigned long)v.tZu, v.stromRuhe, v.stoerung);
  melde(thema, puffer, true);
}

// Die Stromkurve der Schliessfahrt, in Teilen zu 100 Werten. Aus ihr liest der Kern, wo der
// Antrieb den Ventilstift beruehrt und wo die Dichtung schliesst.
static void meldeKurve(uint8_t k) {
  char thema[40];
  snprintf(thema, sizeof(thema), "ventil/%u/kurve", k + 1);
  for (uint16_t von = 0; von < kurveN; von += 100) {
    int n = snprintf(puffer, sizeof(puffer), "{\"von\":%u,\"gesamt\":%u,\"dt_ms\":%lu,\"ma\":[",
                     von, kurveN, (unsigned long)KURVE_DT_MS);
    for (uint16_t i = von; i < kurveN && i < von + 100; i++) {
      n += snprintf(puffer + n, sizeof(puffer) - n, "%s%.1f", i > von ? "," : "", kurve[i] / 10.0f);
    }
    snprintf(puffer + n, sizeof(puffer) - n, "]}");
    melde(thema, puffer);
    esp_task_wdt_reset();
  }
}

// ---------------------------------------------------------------- Dauerhaft merken
static void merke(uint8_t k) {
  char name[8];
  snprintf(name, sizeof(name), "p%u", k);
  speicher.putFloat(name, ventil[k].pos);
  snprintf(name, sizeof(name), "a%u", k);
  speicher.putUInt(name, ventil[k].tAuf);
  snprintf(name, sizeof(name), "z%u", k);
  speicher.putUInt(name, ventil[k].tZu);
}

static void erinnere() {
  char name[8];
  for (uint8_t k = 0; k < N; k++) {
    snprintf(name, sizeof(name), "a%u", k);
    ventil[k].tAuf = speicher.getUInt(name, 0);
    snprintf(name, sizeof(name), "z%u", k);
    ventil[k].tZu = speicher.getUInt(name, 0);
    snprintf(name, sizeof(name), "p%u", k);
    ventil[k].pos = speicher.getFloat(name, NAN);
    if (ventil[k].tAuf > 0 && ventil[k].tZu > 0 && !isnan(ventil[k].pos)) {
      ventil[k].z = BEREIT;
      ventil[k].soll = ventil[k].pos;   // nach dem Start nichts bewegen, bis ein Befehl kommt
    }
  }
}

// ---------------------------------------------------------------- Motor
static void treiber(uint8_t k, Richtung r) {
  Adafruit_MCP23X17& e = mcp[k / 8];
  const uint8_t in1 = 2 * (k % 8), in2 = in1 + 1;
  const bool auf = (r == AUF), zu = (r == ZU);
  e.digitalWrite(in1, (OEFFNEN_IST_IN1 ? auf : zu) ? HIGH : LOW);
  e.digitalWrite(in2, (OEFFNEN_IST_IN1 ? zu : auf) ? HIGH : LOW);
}

static void starte(uint8_t k, Phase ph, Richtung r, uint32_t dauer, float posZiel) {
  digitalWrite(PIN_TREIBER_EIN, HIGH);
  delay(2);                                   // die Treiber brauchen rund 1 ms zum Aufwachen
  lauf = Lauf();
  lauf.k = k;
  lauf.ph = ph;
  lauf.r = r;
  lauf.dauer = dauer;
  lauf.posStart = isnan(ventil[k].pos) ? 0 : ventil[k].pos;
  lauf.posZiel = posZiel;
  lauf.start = millis();
  ventil[k].z = (ph == P_FAHRT) ? FAEHRT : LERNT;
  if (ph == P_LERN_ZU) kurveN = 0;
  treiber(k, r);
}

static void stoppe() {
  if (lauf.k >= 0) treiber(lauf.k, HALT);
  digitalWrite(PIN_TREIBER_EIN, LOW);
}

static void beende(Zustand z, const char* stoerung = "") {
  const uint8_t k = lauf.k;
  stoppe();
  ventil[k].z = z;
  ventil[k].stoerung = stoerung;
  if (lauf.ruheN > 0) ventil[k].stromRuhe = lauf.ruheSumme / lauf.ruheN;
  lauf.k = -1;
  zuletztBedient = k;
  if (z == BEREIT) merke(k);
  meldeVentil(k);
}

static void anschlagErreicht(uint32_t t) {
  const uint8_t k = lauf.k;
  Ventil& v = ventil[k];
  switch (lauf.ph) {
    case P_FAHRT:
      v.pos = (lauf.r == ZU) ? 0.0f : 100.0f;    // der Anschlag ist zugleich die neue Referenz
      beende(BEREIT);
      break;
    case P_LERN_AUF1:
      stoppe();
      starte(k, P_LERN_ZU, ZU, 0, 0);
      break;
    case P_LERN_ZU:
      v.tZu = t;
      stoppe();
      starte(k, P_LERN_AUF2, AUF, 0, 100);
      break;
    case P_LERN_AUF2:
      v.tAuf = t;
      v.pos = 100.0f;
      if (isnan(v.soll)) v.soll = 100.0f;
      if (v.tAuf < 2000 || v.tZu < 2000) {
        beende(STOERUNG, "Hub zu kurz");         // sitzt nicht auf einem Ventil, oder die Schwelle ist zu tief
      } else {
        beende(BEREIT);
        meldeKurve(k);
      }
      break;
    default:
      beende(STOERUNG, "Phase");
  }
}

static void motorTakt() {
  if (lauf.k < 0) return;
  const uint32_t jetzt = millis();
  if (jetzt - lauf.letzterTakt < TAKT_MS) return;
  lauf.letzterTakt = jetzt;
  const uint32_t t = jetzt - lauf.start;
  const float i = fabsf(ina.getCurrent_mA());
  Ventil& v = ventil[lauf.k];

  if (lauf.ph == P_LERN_ZU && jetzt - lauf.letzteKurve >= KURVE_DT_MS && kurveN < KURVE_MAX) {
    lauf.letzteKurve = jetzt;
    kurve[kurveN++] = (uint16_t)constrain(i * 10.0f, 0.0f, 65535.0f);
  }
  if (i >= I_SOFORT_AUS_MA && t > ANLAUF_MS) { anschlagErreicht(t); return; }
  if (t > 300 && i < I_MIN_MA) { beende(STOERUNG, "kein Strom"); return; }
  if (t > LAUF_MAX_MS) { beende(STOERUNG, "Zeit"); return; }

  if (t >= RUHE_VON_MS && t < RUHE_BIS_MS) {
    lauf.ruheSumme += i;
    lauf.ruheN++;
  }
  if (t > ANLAUF_MS) {
    float schwelle = I_ANSCHLAG_ABS_MA;
    if (lauf.ruheN > 0 && t >= RUHE_BIS_MS) {
      const float ruhe = lauf.ruheSumme / lauf.ruheN;
      schwelle = min(schwelle, max(ruhe * ANSCHLAG_FAKTOR, ruhe + ANSCHLAG_PLUS_MA));
    }
    if (i > schwelle) {
      if (lauf.ueberSeit == 0) lauf.ueberSeit = jetzt;
      if (jetzt - lauf.ueberSeit >= ANSCHLAG_HALTEN_MS) { anschlagErreicht(t); return; }
    } else {
      lauf.ueberSeit = 0;
    }
  }
  if (lauf.ph == P_FAHRT && lauf.dauer > 0) {
    const float anteil = min(1.0f, (float)t / (float)lauf.dauer);
    v.pos = lauf.posStart + (lauf.posZiel - lauf.posStart) * anteil;
    if (t >= lauf.dauer) {
      v.pos = lauf.posZiel;
      beende(BEREIT);
    }
  }
}

// Sucht reihum das naechste Ventil, das etwas zu tun hat. Es faehrt immer nur eines.
static void planer() {
  if (lauf.k >= 0) return;
  for (uint8_t n = 1; n <= N; n++) {
    const uint8_t k = (zuletztBedient + n + N) % N;
    Ventil& v = ventil[k];
    if (!v.da) { v.lernen = false; continue; }
    if (v.lernen) {
      v.lernen = false;
      v.stoerung = "";
      starte(k, P_LERN_AUF1, AUF, 0, 100);
      return;
    }
    if (v.z != BEREIT || isnan(v.soll) || isnan(v.pos)) continue;
    const float weg = v.soll - v.pos;
    if (fabsf(weg) < TOTBAND) continue;
    if (v.soll <= 0.5f) { starte(k, P_FAHRT, ZU, 0, 0); return; }       // bis zum Anschlag
    if (v.soll >= 99.5f) { starte(k, P_FAHRT, AUF, 0, 100); return; }
    const uint32_t voll = (weg > 0) ? v.tAuf : v.tZu;
    starte(k, P_FAHRT, weg > 0 ? AUF : ZU, (uint32_t)(fabsf(weg) / 100.0f * voll), v.soll);
    return;
  }
}

// ---------------------------------------------------------------- Befehle
static void setzeSoll(uint8_t k, float wert) {
  wert = constrain(wert, 0.0f, 100.0f);
  if (MIN_SUMME_OFFEN > 0) {
    float andere = 0;
    for (uint8_t j = 0; j < N; j++) {
      if (j != k && !isnan(ventil[j].soll)) andere += ventil[j].soll;
    }
    if (wert + andere < MIN_SUMME_OFFEN) {
      wert = min(100.0f, MIN_SUMME_OFFEN - andere);
      melde("meldung", "Mindestdurchfluss: Sollwert angehoben");
    }
  }
  ventil[k].soll = wert;
  if (ventil[k].z == UNGELERNT) melde("meldung", "Ventil ist ungelernt, erst lernen");
}

static void befehl(const char* was, int nr, float wert) {
  letzterBefehl = millis();
  rueckfallAktiv = false;
  const bool alle = (nr == 0);
  for (uint8_t k = 0; k < N; k++) {
    if (!alle && k != nr - 1) continue;
    if (strcmp(was, "soll") == 0) setzeSoll(k, wert);
    else if (strcmp(was, "lernen") == 0) ventil[k].lernen = true;
  }
}

// Themen: <BASIS>/ventil/<1..10>/soll (0..100), <BASIS>/ventil/<n>/lernen,
//         <BASIS>/alle/soll, <BASIS>/alle/lernen
static void mqttEmpfang(char* thema, byte* daten, unsigned int laenge) {
  char text[24];
  const unsigned int n = min(laenge, (unsigned int)sizeof(text) - 1);
  memcpy(text, daten, n);
  text[n] = 0;
  const char* rest = thema + strlen(BASIS) + 1;
  int nr = 0;
  char was[12] = "";
  if (sscanf(rest, "ventil/%d/%11s", &nr, was) == 2 && nr >= 1 && nr <= N) {
    befehl(was, nr, atof(text));
  } else if (sscanf(rest, "alle/%11s", was) == 1) {
    befehl(was, 0, atof(text));
  }
}

// Werkbank ohne MQTT, ueber die serielle Schnittstelle:
//   ?          Zustand aller Ventile       l 3     Ventil 3 lernen      l 0   alle lernen
//   s 3 40     Ventil 3 auf 40 %           s 0 50  alle auf 50 %        x     alles anhalten
static void seriellEmpfang() {
  static char zeile[32];
  static uint8_t n = 0;
  while (Serial.available()) {
    const char c = Serial.read();
    if (c != '\n' && c != '\r') {
      if (n < sizeof(zeile) - 1) zeile[n++] = c;
      continue;
    }
    zeile[n] = 0;
    n = 0;
    int nr = 0;
    float wert = 0;
    if (zeile[0] == '?') {
      for (uint8_t k = 0; k < N; k++) meldeVentil(k);
    } else if (zeile[0] == 'x') {
      if (lauf.k >= 0) {
        // Eine Zeitfahrt kennt ihre Stellung auch mittendrin; eine Anschlag- oder Lernfahrt nicht.
        if (lauf.ph == P_FAHRT && lauf.dauer > 0) beende(BEREIT);
        else beende(STOERUNG, "angehalten");
      }
      for (uint8_t k = 0; k < N; k++) { ventil[k].lernen = false; ventil[k].soll = ventil[k].pos; }
    } else if (sscanf(zeile, "l %d", &nr) == 1 && nr >= 0 && nr <= N) {
      befehl("lernen", nr, 0);
    } else if (sscanf(zeile, "s %d %f", &nr, &wert) == 2 && nr >= 0 && nr <= N) {
      befehl("soll", nr, wert);
    }
  }
}

// ---------------------------------------------------------------- Fuehler
// Gemeldet wird je Fuehler unter seiner Adresse. Welcher Fuehler an welchem Kreis sitzt, weiss
// der Kern, nicht die Firmware.
static void fuehlerTakt() {
  static uint32_t angefragt = 0, letzte = 0;
  const uint32_t jetzt = millis();
  if (angefragt == 0 && jetzt - letzte >= 30000) {
    fuehler.requestTemperatures();
    angefragt = jetzt;
  }
  if (angefragt != 0 && jetzt - angefragt >= 800) {     // 12 Bit brauchen 750 ms
    const uint8_t anzahl = fuehler.getDeviceCount();
    for (uint8_t i = 0; i < anzahl; i++) {
      DeviceAddress a;
      if (!fuehler.getAddress(a, i)) continue;
      const float c = fuehler.getTempC(a);
      if (c == DEVICE_DISCONNECTED_C) continue;
      char thema[40], wert[12];
      snprintf(thema, sizeof(thema), "fuehler/%02x%02x%02x%02x%02x%02x%02x%02x",
               a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
      snprintf(wert, sizeof(wert), "%.2f", c);
      melde(thema, wert);
    }
    angefragt = 0;
    letzte = jetzt;
  }
}

// ---------------------------------------------------------------- Netz
static void netzTakt() {
  static uint32_t letzterVersuch = 0;
  if (WiFi.status() != WL_CONNECTED || mqtt.connected()) return;
  if (millis() - letzterVersuch < 5000) return;
  letzterVersuch = millis();
  char status[96], thema[96];
  snprintf(status, sizeof(status), "%s/status", BASIS);
  if (mqtt.connect("dc-verteiler1", status, 1, true, "offline")) {
    mqtt.publish(status, "online", true);
    snprintf(thema, sizeof(thema), "%s/ventil/+/soll", BASIS);
    mqtt.subscribe(thema);
    snprintf(thema, sizeof(thema), "%s/ventil/+/lernen", BASIS);
    mqtt.subscribe(thema);
    snprintf(thema, sizeof(thema), "%s/alle/+", BASIS);
    mqtt.subscribe(thema);
    for (uint8_t k = 0; k < N; k++) meldeVentil(k);
  }
}

// Schweigt der Kern lange, gehen alle gelernten Ventile auf eine mittlere Stellung: Das Haus
// bleibt warm, auch wenn Server oder WLAN ausfallen.
static void rueckfallTakt() {
  if (rueckfallAktiv || millis() - letzterBefehl < RUECKFALL_NACH_MS) return;
  rueckfallAktiv = true;
  for (uint8_t k = 0; k < N; k++) {
    if (ventil[k].z == BEREIT) ventil[k].soll = RUECKFALL_POS;
  }
  melde("meldung", "Rueckfall: kein Befehl seit 30 min, alle Ventile auf Mittelstellung");
}

// ---------------------------------------------------------------- Start
void setup() {
  pinMode(PIN_TREIBER_EIN, OUTPUT);
  digitalWrite(PIN_TREIBER_EIN, LOW);          // zuerst: alle Treiber schlafen
  Serial.begin(115200);
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(400000);

  // Jeder Expander fuer sich: Der Testaufbau mit zwei Ventilen hat nur den ersten.
  bool expander[2];
  expander[0] = mcp[0].begin_I2C(0x20, &Wire);
  expander[1] = mcp[1].begin_I2C(0x21, &Wire);
  for (uint8_t e = 0; e < 2; e++) {
    for (uint8_t p = 0; expander[e] && p < 16; p++) {
      mcp[e].pinMode(p, OUTPUT);
      mcp[e].digitalWrite(p, LOW);
    }
  }
  const bool strommesser = ina.begin(&Wire);
  if (strommesser) ina.setCalibration_16V_400mA();
  Serial.printf("I2C: Expander A %s, Expander B %s, Strommesser %s\n", expander[0] ? "da" : "fehlt",
                expander[1] ? "da" : "fehlt", strommesser ? "da" : "fehlt");

  speicher.begin("verteiler", false);
  erinnere();
  fuehler.begin();
  fuehler.setResolution(12);
  fuehler.setWaitForConversion(false);

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WLAN_SSID, WLAN_PASS);
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setBufferSize(1536);
  mqtt.setSocketTimeout(4);                    // kuerzer als der Wachhund (8 s)
  mqtt.setCallback(mqttEmpfang);

  // Haengt die Schleife, startet der Chip neu. Die Treiber-Freigabe faellt dabei auf LOW.
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_task_wdt_config_t wdt = {.timeout_ms = 8000, .idle_core_mask = 0, .trigger_panic = true};
  esp_task_wdt_reconfigure(&wdt);
#else
  esp_task_wdt_init(8, true);
#endif
  esp_task_wdt_add(NULL);
  letzterBefehl = millis();
  for (uint8_t k = 0; k < N; k++) {
    if (strommesser && expander[k / 8]) continue;
    ventil[k].da = false;                      // ohne Strommesser faehrt kein Motor
    ventil[k].z = STOERUNG;
    ventil[k].stoerung = "I2C";
  }
}

void loop() {
  esp_task_wdt_reset();
  motorTakt();
  planer();
  seriellEmpfang();
  mqtt.loop();
  if (lauf.k < 0) {
    // Nur ohne laufenden Motor: Der Verbindungsaufbau kann Sekunden blockieren, und in dieser
    // Zeit saehe niemand den Anschlag. 1-Wire sperrt ausserdem kurz die Interrupts.
    netzTakt();
    fuehlerTakt();
  }
  rueckfallTakt();
}

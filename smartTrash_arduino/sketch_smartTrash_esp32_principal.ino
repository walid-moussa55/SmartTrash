#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include "HX711.h"
#include <esp_now.h>

// ── WiFi ─────────────────────────────────────────────
#define WIFI_SSID     "[SSID]"
#define WIFI_PASSWORD "[PASSWORD]"

// ── API ──────────────────────────────────────────────
const char* serverName      = "http:/[API_IP_ADDRESS]:8000/update/trash_1";
const char* depositCloseUrl = "http://[API_IP_ADDRESS]:8000/deposit/close";

// ── MAC ESP32-CAM ────────────────────────────────────
// !! Remplacer par le vrai MAC de votre ESP32-CAM !!
// Lisible dans le Serial Monitor de la CAM au demarrage
uint8_t camMAC[] = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // A remplacer par le MAC de l'esp32 CAM

// ── PINS ─────────────────────────────────────────────
#define TRIG_OBJ         4
#define ECHO_OBJ         5
#define TRIG_TRASH      19
#define ECHO_TRASH      18
#define DHTPIN          23
#define DHTTYPE         DHT11
#define WATER_SENSOR_PIN 32
#define GAS_SENSOR_A0   34
#define HX711_DT        26
#define HX711_SCK       27
#define SERVO_PIN       25
#define BUZZER_PIN      33

// ── CONSTANTES ───────────────────────────────────────
const float hauteurPoubelle = 12.00;
const float distanceMin     = 2.0;
const int   dryValue        = 200;
const int   wetValue        = 2400;
const unsigned long CAM_TIMEOUT_MS = 8000; // attente max reponse CAM

// ── OBJETS ───────────────────────────────────────────
DHT               dht(DHTPIN, DHTTYPE);
HX711             scale;
Servo             servo;
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ── ICONES LCD ───────────────────────────────────────
byte wifiIcon[8]   = {B00000,B00100,B01010,B10001,B00000,B00100,B00000,B00100};
byte serverIcon[8] = {B11111,B10101,B11111,B10101,B11111,B00100,B01010,B10001};

// ── VARIABLES ────────────────────────────────────────
unsigned long lastSend       = 0;
const unsigned long sendInterval = 10000;
bool isConnectToServer       = false;
float facteur_etalon         = 450000.0;

// ── POUBELLE SPECIALISEE ─────────────────────────────
const String BIN_TYPE = "paper"; // changer selon votre poubelle
const String BIN_ID   = "trash_1"; // doit correspondre a Firebase

// ── ESP-NOW : STRUCTURES ──────────────────────────────
// Message envoye a la CAM (trigger)
typedef struct {
  char command[10]; // "SCAN"
} TriggerMessage;

// Message recu de la CAM (resultat)
typedef struct {
  char trash_type[20];
} TrashMessage;

// ── LECTURE CAPTEURS (non-bloquante) ─────────────────
struct SensorData {
  int   gasLevel;
  float humidity;
  float temperature;
  float trashLevelPercent;
  int   waterLevelPercent;
  float weight;
};

TriggerMessage trigMsg;
TrashMessage   receivedMsg;

// ── ETAT SCAN ────────────────────────────────────────
volatile bool camResultReceived = false;
String detectedType = "";

// ── CALLBACKS ESP-NOW ─────────────────────────────────
void onSent(const wifi_tx_info_t* info, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS
    ? "ESP-NOW → CAM : trigger envoye OK"
    : "ESP-NOW → CAM : echec envoi trigger");
}

void onReceive(const esp_now_recv_info* info, const uint8_t* data, int len) {
  memcpy(&receivedMsg, data, sizeof(receivedMsg));
  detectedType      = String(receivedMsg.trash_type);
  camResultReceived = true;
  Serial.println("ESP-NOW recu depuis CAM: " + detectedType);
}

// ── FONCTIONS CAPTEURS ───────────────────────────────
float readUltrasonicCM(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  float duration = pulseIn(echoPin, HIGH, 30000);
  return duration * 0.034 / 2;
}

float lireDistance() {
  digitalWrite(TRIG_TRASH, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_TRASH, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_TRASH, LOW);
  long  duration = pulseIn(ECHO_TRASH, HIGH);
  float distance = duration * 0.034 / 2.0;
  return (distance < distanceMin) ? 0 : distance;
}

float calculerNiveau(float distance) {
  if (distance <= 0) return 100.0;
  float hauteurLue = constrain(distance, 0, hauteurPoubelle);
  float niveau     = 100.0 * (1.0 - (hauteurLue / hauteurPoubelle));
  return constrain(niveau, 0, 100);
}

void lcdMessage(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1.substring(0, 16));
  lcd.setCursor(0, 1);
  lcd.print(line2.substring(0, 16));
}



SensorData readAllSensors() {
  SensorData d;
  d.gasLevel          = map(analogRead(GAS_SENSOR_A0), 0, 1200, 0, 20);
  d.humidity          = dht.readHumidity();
  d.temperature       = dht.readTemperature();
  float trashDistance = lireDistance();
  d.trashLevelPercent = calculerNiveau(trashDistance);
  int rawWater        = analogRead(WATER_SENSOR_PIN);
  d.waterLevelPercent = constrain(map(rawWater, dryValue, wetValue, 0, 100), 0, 100);
  d.weight            = 0;
  if (scale.is_ready()) {
    float p = scale.get_units(3); // 3 lectures pour etre plus rapide
    d.weight = (p < 0) ? 0 : p;
  }
  return d;
}

// ── AFFICHAGE LCD NORMAL ──────────────────────────────
void updateLCDNormal(float trashLevel) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Trash:");
  lcd.print((int)trashLevel);
  lcd.print("% ");
  lcd.setCursor(15, 0);
  if (WiFi.status() == WL_CONNECTED) lcd.write(byte(0));
  lcd.setCursor(0, 1);
  if      (trashLevel < 20) lcd.print("LOW   ");
  else if (trashLevel < 80) lcd.print("MEDIUM");
  else                      lcd.print("FULL  ");
  lcd.setCursor(15, 1);
  if (isConnectToServer) lcd.write(byte(1));
}

// ── ENVOI API ─────────────────────────────────────────
void sendToAPI(const SensorData& d) {
  if (isnan(d.humidity) || isnan(d.temperature)) return;

  String jsonData = "{";
  jsonData += "\"bin_id\":\"trash_1\",";
  jsonData += "\"gaz_level\":"    + String(d.gasLevel)          + ",";
  jsonData += "\"humidity\":"     + String(d.humidity)          + ",";
  jsonData += "\"temperature\":"  + String(d.temperature)       + ",";
  jsonData += "\"location\":{\"latitude\":33.996649,\"longitude\":-6.847036},";
  jsonData += "\"name\":\"Poubelle 1 - Hôtel Atlantic Agdal\",";
  jsonData += "\"trash_level\":"  + String(d.trashLevelPercent) + ",";
  jsonData += "\"trash_type\":\""  + BIN_TYPE           + "\",";
  jsonData += "\"weight\":"       + String(d.weight)            + ",";
  jsonData += "\"volume\":100,";
  jsonData += "\"water_level\":"  + String(d.waterLevelPercent);
  jsonData += "}";

  Serial.println("Sending to API: " + jsonData);

  HTTPClient http;
  http.begin(serverName);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(jsonData);
  isConnectToServer = (code > 0);
  if (code > 0) Serial.println("API OK: " + http.getString());
  else          Serial.println("API Error: " + String(code));
  http.end();
}

void sendDepositCloseEvent(float weightAfter, const String& arduinoType) {
  if (WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  http.begin(depositCloseUrl);
  http.addHeader("Content-Type", "application/json");
  String body = "{";
  body += "\"bin_id\": \"" + BIN_ID + "\",";
  body += "\"weight_after\": " + String(weightAfter, 3) + ",";
  body += "\"arduino_detected_type\": \"" + arduinoType + "\",";
  body += "\"deposit_event\": true";
  body += "}";
  int code = http.POST(body);
  Serial.println("Deposit close event sent, HTTP: " + String(code));
  if (code > 0) Serial.println("Response: " + http.getString());
  http.end();
}

// ── LOGIQUE SERVO ─────────────────────────────────────
void handleServoDecision(const String& detType, float weightBefore) {
  Serial.printf("Decision: detecte=%s | bin=%s\n",
    detType.c_str(), BIN_TYPE.c_str());

  if (detType == BIN_TYPE) {
    Serial.println("BON TYPE — ouverture");
    lcdMessage("Merci !", BIN_TYPE + " accepte!");
    
    servo.write(140);
    delay(4000); // lid stays open
    servo.write(0); // lid closes

    // Snapshot de poids APRES le depot
    float weightAfter = weightBefore;
    if (scale.is_ready()) {
      float w = scale.get_units(5); // Plus de lectures post-depot pour etre sur
      if (w < 0) w = 0;
      weightAfter = w;
    }
    Serial.printf("Weight before: %.3f kg | after: %.3f kg\n", weightBefore, weightAfter);

    // Declencher l'API pour les points
    sendDepositCloseEvent(weightAfter, detType);

    // Bip succes
    for (int i = 0; i < 2; i++) {
      digitalWrite(BUZZER_PIN, HIGH); delay(100);
      digitalWrite(BUZZER_PIN, LOW);  delay(100);
    }
  } else {
    Serial.println("MAUVAIS TYPE — refuse");
    lcdMessage("Bin: " + BIN_TYPE, "Seulement!");
    servo.write(0);
    
    // Declencher l'API pour enregistrer le depot invalide (points negatifs)
    sendDepositCloseEvent(weightBefore, detType);
    
    // Bip alerte
    digitalWrite(BUZZER_PIN, HIGH); delay(800);
    digitalWrite(BUZZER_PIN, LOW);
  }
  delay(2000);
  lcd.clear();
}

// ── SCAN AVEC ATTENTE NON-BLOQUANTE ──────────────────
// Envoie SCAN a la CAM, attend jusqu'a CAM_TIMEOUT_MS
// Pendant l'attente: lit les capteurs et met a jour LCD
void triggerCamAndWait() {
  Serial.println("Envoi SCAN a la CAM...");
  lcdMessage("Analyse...", "Patientez");

  camResultReceived = false;

  // Envoyer trigger SCAN
  strcpy(trigMsg.command, "SCAN");
  esp_now_send(camMAC, (uint8_t*)&trigMsg, sizeof(trigMsg));

  unsigned long startTime = millis();

  // Attente non-bloquante avec lecture capteurs
  while (!camResultReceived && (millis() - startTime < CAM_TIMEOUT_MS)) {
    // Pendant l'attente: continuer a servir les capteurs
    // (pas d'API call ici pour ne pas bloquer)
    delay(50);
  }

  if (camResultReceived) {
    Serial.printf("Reponse CAM: %s (en %lums)\n",
      detectedType.c_str(), millis() - startTime);

    // Snapshot poids juste AVANT ouverture
    float weightBeforeDeposit = 0;
    if (scale.is_ready()) {
      float p = scale.get_units(3);
      weightBeforeDeposit = (p < 0) ? 0 : p;
    }

    handleServoDecision(detectedType, weightBeforeDeposit);
  } else {
    Serial.println("TIMEOUT: pas de reponse de la CAM en 8s");
    lcdMessage("CAM timeout", "Reessayez");
    delay(2000);
    lcd.clear();
  }
}

// ── SETUP ────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // LCD
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.createChar(0, wifiIcon);
  lcd.createChar(1, serverIcon);
  lcdMessage("NaqiAI", "Demarrage...");

  // WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi OK — IP: " + WiFi.localIP().toString());
  Serial.println("MAC: " + WiFi.macAddress());

  // ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED");
    lcdMessage("ESP-NOW", "ERREUR!");
  } else {
    esp_now_register_send_cb(onSent);
    esp_now_register_recv_cb(onReceive);

    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, camMAC, 6);
    peer.channel = 0;
    peer.encrypt = false;
    esp_now_add_peer(&peer);
    Serial.println("ESP-NOW OK");
  }

  // Capteurs
  servo.attach(SERVO_PIN);
  servo.write(0);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(WATER_SENSOR_PIN, INPUT);
  pinMode(TRIG_OBJ, OUTPUT);
  pinMode(ECHO_OBJ, INPUT);
  pinMode(TRIG_TRASH, OUTPUT);
  pinMode(ECHO_TRASH, INPUT);
  dht.begin();
  scale.begin(HX711_DT, HX711_SCK);
  scale.set_scale(facteur_etalon);
  scale.tare();

  lcdMessage("NaqiAI Pret!", "Bin: " + BIN_TYPE);
  delay(2000);
  lcd.clear();
}

// ── LOOP ─────────────────────────────────────────────
void loop() {
  SensorData sensors = readAllSensors();

  // ── Affichage LCD normal ─────────────────────────
  updateLCDNormal(sensors.trashLevelPercent);

  // ── Detection objet → trigger CAM + attente ──────
  float objDistance = readUltrasonicCM(TRIG_OBJ, ECHO_OBJ);
  if (objDistance > 0 && objDistance < 15) {
    Serial.printf("Objet detecte a %.1f cm\n", objDistance);

    // Anti-rebond: attendre confirmation pendant 500ms
    delay(500);
    objDistance = readUltrasonicCM(TRIG_OBJ, ECHO_OBJ);
    if (objDistance > 0 && objDistance < 15) {
      triggerCamAndWait(); // envoie SCAN, attend resultat, actionne servo
    }
  }

  // ── Buzzer eau ───────────────────────────────────
  if (sensors.waterLevelPercent > 50) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(1000);
    digitalWrite(BUZZER_PIN, LOW);
  }

  // ── Envoi API toutes les 10 secondes ─────────────
  if (millis() - lastSend > sendInterval) {
    lastSend = millis();
    sendToAPI(sensors);
  }

  delay(100);
}

#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include "HX711.h"
#include <esp_now.h>

// ── WiFi ─────────────────────────────────────────────
#define WIFI_SSID     "Bouchra✨"
#define WIFI_PASSWORD "BOCHRA2026"

// ── API ──────────────────────────────────────────────
const char* serverName = "http://192.168.43.184:8000/update/trash_1";

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
const float hauteurPoubelle = 15.00;
const float distanceMin     = 2.0;
const int   dryValue        = 200;
const int   wetValue        = 2400;

// ── OBJETS ───────────────────────────────────────────
DHT               dht(DHTPIN, DHTTYPE);
HX711             scale;
Servo             servo;
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ── ICONES LCD ───────────────────────────────────────
byte wifiIcon[8]   = {B00000,B00100,B01010,B10001,B00000,B00100,B00000,B00100};
byte serverIcon[8] = {B11111,B10101,B11111,B10101,B11111,B00100,B01010,B10001};

// ── VARIABLES ────────────────────────────────────────
unsigned long lastSend      = 0;
const unsigned long sendInterval = 10000;
bool isConnectToServer      = false;
float facteur_etalon        = 100000.0;

// ── ESP-NOW : TYPE RECU DE LA CAM ────────────────────
typedef struct {
  char trash_type[20];
} TrashMessage;

TrashMessage receivedMsg;
String detectedType  = "";
bool   newDetection  = false;

// ── POUBELLE SPÉCIALISÉE ─────────────────────────────
// Changez cette valeur selon le type de votre poubelle
// "paper", "plastic", "metal", "glass", "organic", "cardboard"
const String BIN_TYPE = "paper";

// ── CALLBACK ESP-NOW RÉCEPTION (compatible SDK 3.x) ──
void onReceive(const esp_now_recv_info* info, const uint8_t* data, int len) {
  memcpy(&receivedMsg, data, sizeof(receivedMsg));
  detectedType = String(receivedMsg.trash_type);
  newDetection = true;
  Serial.println("ESP-NOW recu: " + detectedType);
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

// ── AFFICHER MESSAGE LCD 2 LIGNES ────────────────────
void lcdMessage(String line1, String line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1.substring(0, 16));
  lcd.setCursor(0, 1);
  lcd.print(line2.substring(0, 16));
}

// ── LOGIQUE SERVO INTELLIGENTE ───────────────────────
void handleServoDecision() {

  if (!newDetection) {
    // Pas encore de réponse de la CAM — afficher attente
    lcdMessage("Analyse image", "Patientez...");
    Serial.println("En attente detection CAM...");
    return;
  }

  newDetection = false;
  Serial.println("Decision pour type: " + detectedType + " | Bin accepte: " + BIN_TYPE);

  if (detectedType == BIN_TYPE) {
    // ✅ BON TYPE — ouvrir la poubelle
    Serial.println("BON TYPE — Ouverture servo");

    lcdMessage("Merci !", BIN_TYPE + " accepte !");
    servo.write(140);
    delay(4000);
    servo.write(0);

    // Bip de succès court
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);

    delay(1000);
    lcd.clear();

  } else {
    // ❌ MAUVAIS TYPE — rester fermé + alerter
    Serial.println("MAUVAIS TYPE — Servo reste ferme");

    servo.write(0); // s'assurer que c'est bien fermé

    lcdMessage("Poubelle " + BIN_TYPE, "Seulement !");

    // Bip d'alerte long
    digitalWrite(BUZZER_PIN, HIGH);
    delay(800);
    digitalWrite(BUZZER_PIN, LOW);

    delay(3000);
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

  // WiFi — WIFI_STA obligatoire pour ESP-NOW
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi OK — IP: " + WiFi.localIP().toString());

  // ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED");
    lcdMessage("ESP-NOW", "ERREUR !");
  } else {
    esp_now_register_recv_cb(onReceive);
    Serial.println("ESP-NOW OK — en attente messages CAM");
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

  lcdMessage("NaqiAI Pret !", "Bin: " + BIN_TYPE);
  delay(2000);
  lcd.clear();
}

// ── LOOP ─────────────────────────────────────────────
void loop() {

  // ── LECTURE CAPTEURS ─────────────────────────────
  int   gasLevel          = map(analogRead(GAS_SENSOR_A0), 0, 1200, 0, 20);
  float humidity          = dht.readHumidity();
  float temperature       = dht.readTemperature();
  float objDistance       = readUltrasonicCM(TRIG_OBJ, ECHO_OBJ);
  int   rawValue          = analogRead(WATER_SENSOR_PIN);
  float trashDistance     = lireDistance();
  float trashLevelPercent = calculerNiveau(trashDistance);
  float weight            = 0;

  if (scale.is_ready()) {
    float poids = scale.get_units(5);
    if (poids < 0) poids = 0;
    weight = poids;
    Serial.printf("Poids: %.2f kg\n", weight);
  }

  // ── AFFICHAGE LCD NORMAL ──────────────────────────
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Trash:");
  lcd.print((int)trashLevelPercent);
  lcd.print("% ");

  // Icone WiFi en haut droite
  lcd.setCursor(15, 0);
  if (WiFi.status() == WL_CONNECTED) lcd.write(byte(0));

  lcd.setCursor(0, 1);
  if      (trashLevelPercent < 20) lcd.print("LOW   ");
  else if (trashLevelPercent < 80) lcd.print("MEDIUM");
  else                             lcd.print("FULL  ");

  // Icone serveur en bas droite
  lcd.setCursor(15, 1);
  if (isConnectToServer) lcd.write(byte(1));

  // ── DÉTECTION OBJET → LOGIQUE SERVO ──────────────
  if (objDistance > 0 && objDistance < 15) {
    Serial.printf("Objet detecte a %.1f cm\n", objDistance);
    handleServoDecision();
  }

  // ── BUZZER EAU ───────────────────────────────────
  int waterLevelPercent = map(rawValue, dryValue, wetValue, 0, 100);
  waterLevelPercent = constrain(waterLevelPercent, 0, 100);
  Serial.printf("Water: %d%%\n", waterLevelPercent);

  if (waterLevelPercent > 50) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(1000);
    digitalWrite(BUZZER_PIN, LOW);
  }

  // ── ENVOI API TOUTES LES 10 SECONDES ─────────────
  if (millis() - lastSend > sendInterval) {
    lastSend = millis();

    if (isnan(humidity))          humidity          = 0;
    if (isnan(temperature))       temperature       = 0;
    if (isnan(weight))            weight            = 0;
    if (isnan(trashLevelPercent)) trashLevelPercent = 0;

    // Utiliser le type détecté par la CAM si disponible
    String trashTypeToSend = (detectedType != "") ? detectedType : "unknown";

    String jsonData = "{";
    jsonData += "\"bin_id\": \"trash_1\",";
    jsonData += "\"gaz_level\": "    + String(gasLevel)          + ",";
    jsonData += "\"humidity\": "     + String(humidity)          + ",";
    jsonData += "\"temperature\": "  + String(temperature)       + ",";
    jsonData += "\"location\": {\"latitude\": 32.376553, \"longitude\": -6.320284},";
    jsonData += "\"name\": \"Bin 1 - Lobby\",";
    jsonData += "\"trash_level\": "  + String(trashLevelPercent) + ",";
    jsonData += "\"trash_type\": \""  + trashTypeToSend           + "\",";
    jsonData += "\"weight\": "       + String(weight)            + ",";
    jsonData += "\"volume\": 100,";
    jsonData += "\"water_level\": "  + String(waterLevelPercent);
    jsonData += "}";

    Serial.println("==================================================");
    Serial.println("Sending: " + jsonData);
    Serial.println("==================================================");

    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");

    int httpResponseCode = http.POST(jsonData);
    if (httpResponseCode > 0) {
      Serial.println("Server: " + http.getString());
      isConnectToServer = true;
    } else {
      Serial.println("HTTP Error: " + String(httpResponseCode));
      isConnectToServer = false;
    }
    http.end();
  }

  delay(100);
}
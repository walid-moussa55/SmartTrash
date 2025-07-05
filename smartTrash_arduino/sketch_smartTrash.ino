#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include "HX711.h"

// WiFi Credentials
#define WIFI_SSID "wam"
#define WIFI_PASSWORD "123456789"

// API Endpoint
const char* serverName = "http://192.168.141.2:8000/update/trash_1";  // Replace with your actual PC IP

// Ultrasonic Object Detection
#define TRIG_OBJ 4
#define ECHO_OBJ 5

// Ultrasonic Trash Capacity
#define TRIG_TRASH 19
#define ECHO_TRASH 18
const float MIN_DISTANCE = 2.0; // cm
const float hauteurPoubelle = 15.00;  // Hauteur en cm
const float distanceMin = 2.0;        // Distance minimale = 2cm (objet collé)


// DHT11
#define DHTPIN 23
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// Water Sensor
#define WATER_SENSOR_PIN 32
const int dryValue = 200;    // Value when sensor is dry (adjust based on test)
const int wetValue = 2400;   // Value when fully submerged

// Gas Sensor
#define GAS_SENSOR_A0 34

// HX711 Weight Sensor
#define HX711_DT 26
#define HX711_SCK 27
HX711 scale;
float facteur_etalon = 100000.0; 

// Servo
#define SERVO_PIN 25
Servo servo;

// Buzzer
#define BUZZER_PIN 33

// LCD I2C
LiquidCrystal_I2C lcd(0x27, 16, 2); // Adresse 0x27, 16 colonnes, 2 lignes
const int lcdBrightness = 150;  // Luminosité moyenne (ajustable)
// WiFi icon (simple version)
byte wifiIcon[8] = {
  B00000,
  B00100,
  B01010,
  B10001,
  B00000,
  B00100,
  B00000,
  B00100
};

// Server icon (simple version)
byte serverIcon[8] = {
  B11111,
  B10101,
  B11111,
  B10101,
  B11111,
  B00100,
  B01010,
  B10001
};

unsigned long lastSend = 0;
const unsigned long sendInterval = 10000; // Send every 10 seconds
bool isConnectToServer = 0;

void setup() {
  Serial.begin(115200);
  // Initialisation LCD
  Wire.begin(21, 22); 
  lcd.init();
  lcd.backlight();
  lcd.setBacklight(lcdBrightness);
  lcd.createChar(0, wifiIcon);   // Save WiFi icon to location 0
  lcd.createChar(1, serverIcon); // Save Server icon to location 1

  // Affichage démarrage
  lcd.setCursor(0, 0);
  lcd.print("Systeme Initialisation...");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected!");

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
  scale.set_scale(facteur_etalon);  // Applique le facteur d'étalonnage
  scale.tare();                     // Met la balance à zéro

  lcd.clear();
}

float readUltrasonicCM(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  float duration = pulseIn(echoPin, HIGH, 30000);
  return duration * 0.034 / 2;
}

// Lecture distance HC-SR04 (en cm)
float lireDistance() {
  digitalWrite(TRIG_TRASH, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_TRASH, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_TRASH, LOW);
  
  long duration = pulseIn(ECHO_TRASH, HIGH);
  float distance = duration * 0.034 / 2.0;  // Conversion en cm

  // Si objet trop proche (<2cm), on considère distance=0
  return (distance < distanceMin) ? 0 : distance;
}

// Calcul du niveau de remplissage (0-100%)
float calculerNiveau(float distance) {
  if (distance <= 0) return 100.0;  // Objet collé = 100%
  
  float hauteurLue = constrain(distance, 0, hauteurPoubelle);
  float niveau = 100.0 * (1.0 - (hauteurLue / hauteurPoubelle));
  return constrain(niveau, 0, 100);
}


void loop() {
  int gasLevel = map(analogRead(GAS_SENSOR_A0), 0, 1200, 0, 20);
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  float objDistance = readUltrasonicCM(TRIG_OBJ, ECHO_OBJ);
  int rawValue = analogRead(WATER_SENSOR_PIN);

  float trashDistance = lireDistance();
  float trashLevelPercent = calculerNiveau(trashDistance);

  float weight = 0; // Adjust calibration as needed
  if (scale.is_ready()) {
    float poids = scale.get_units(5);  // Moyenne sur 5 lectures
    if (poids < 0) poids = 0;
    Serial.print("⚖ Poids mesuré : ");
    Serial.print(poids, 2);  // 2 chiffres après la virgule
    Serial.println(" kg");
    weight = poids;
  } else {
    Serial.println("❌ HX711 non prêt. Vérifie les connexions.");
  }
  
  // Show trash level on LCD
  lcd.clear();
  lcd.setCursor(15, 0); // Top right corner (column 15, row 0)
  if (WiFi.status() == WL_CONNECTED) {
    lcd.write(byte(0)); // Show WiFi icon
  } else {
    lcd.print(" "); // Clear if not connected
  }
  lcd.setCursor(0, 0);
  lcd.print("Trash: ");
  lcd.print(trashLevelPercent);
  lcd.print("%");
  lcd.setCursor(0, 1);
  lcd.print("Status: ");

  if (trashLevelPercent < 20) {
    lcd.print("LOW");
  } else if (trashLevelPercent < 80) {
    lcd.print("MEDIUM");
  } else {
    lcd.print("FULL");
  }

  // After int httpResponseCode = http.POST(jsonData);
  lcd.setCursor(15, 1); // Bottom right corner (column 15, row 1)
  if (isConnectToServer) {
    lcd.write(byte(1));  // Server icon
  } else {
    lcd.print(" ");      // Clear if failed
  }

  // If object detected within 20 cm, open servo
  if (objDistance > 0 && objDistance < 15) {
    servo.write(140);
    delay(4000);
    servo.write(0);
  }

  // Trigger buzzer if water is detected
  int waterLevelPercent = map(rawValue, dryValue, wetValue, 0, 100);
  waterLevelPercent = constrain(waterLevelPercent, 0, 100);

  Serial.print("Water level: ");
  Serial.print(waterLevelPercent);
  Serial.println("%");
  if (waterLevelPercent > 50) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(1000);
    digitalWrite(BUZZER_PIN, LOW);
  }

  // Send data periodically
  if (millis() - lastSend > sendInterval) {
    lastSend = millis();

    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");

    if (isnan(humidity)) humidity = 0;
    if (isnan(temperature)) temperature = 0;
    if (isnan(weight)) weight = 0;
    if (isnan(trashLevelPercent)) trashLevelPercent = 0;

    String jsonData = "{";
    jsonData += "\"bin_id\": \"trash_1\",";
    jsonData += "\"gaz_level\": " + String(gasLevel) + ",";
    jsonData += "\"humidity\": " + String(humidity) + ",";
    jsonData += "\"temperature\": " + String(temperature) + ",";
    jsonData += "\"location\": {\"latitude\": 32.376553, \"longitude\": -6.320284},";
    jsonData += "\"name\": \"Bin 1 - Lobby\",";
    jsonData += "\"trash_level\": " + String(trashLevelPercent) + ",";
    jsonData += "\"trash_type\": \"plastic\",";
    jsonData += "\"weight\": " + String(weight) + ",";
    jsonData += "\"volume\": 100,";
    jsonData += "\"water_level\": " + String(waterLevelPercent);
    jsonData += "}";
    
    Serial.println("==================================================");
    Serial.println("Sending JSON:");
    String SensorData = "{\n";
    SensorData += "\"gaz_level\": " + String(gasLevel) + ",\n";
    SensorData += "\"humidity\": " + String(humidity) + ",\n";
    SensorData += "\"temperature\": " + String(temperature) + ",\n";
    SensorData += "\"location\": {\"latitude\": 32.376553, \"longitude\": -6.320284},\n";
    SensorData += "\"name\": \"Bin 1 - Lobby\",\n";
    SensorData += "\"trash_level\": " + String(trashLevelPercent) + ",\n";
    SensorData += "\"trash_type\": \"plastic\",\n";
    SensorData += "\"weight\": " + String(weight) + ",\n";
    SensorData += "\"volume\": 100,\n";
    SensorData += "\"water_level\": " + String(waterLevelPercent)+"\n";
    SensorData += "}\n";
    Serial.println(SensorData);
    Serial.println("==================================================");

    int httpResponseCode = http.POST(jsonData);
    if (httpResponseCode > 0) {
      Serial.println("Server response: " + http.getString());
      isConnectToServer = true;
    } else {
      Serial.println("Error code: " + String(httpResponseCode));
      isConnectToServer = false;
    }
    http.end();
  }

  delay(100);
}

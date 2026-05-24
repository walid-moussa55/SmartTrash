#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <esp_now.h>
#include <Arduino.h>

// ── WiFi ────────────────────────────────────────────
const char* ssid     = "[SSID]";
const char* password = "[PASSWORD]";

// ── API ─────────────────────────────────────────────
const char* apiUrl = "http://[API_IP_ADDRESS]:8090/predict/trash_type";

// ── MAC ESP32 PRINCIPAL ──────────────────────────────
uint8_t receiverMAC[] = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // A remplacer par le MAC de l'esp32 principal (celui qui envoie le trigger)

// ── FLASH LED ───────────────────────────────────────
#define FLASH_LED_PIN 4

// ── PINS AI THINKER ─────────────────────────────────
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ── STRUCTURES ESP-NOW ───────────────────────────────
// Message recu du principal (trigger)
typedef struct {
  char command[10]; // "SCAN"
} TriggerMessage;

// Message envoye au principal (resultat)
typedef struct {
  char trash_type[20];
} TrashMessage;

TrashMessage msgToSend;

// ── ETAT GLOBAL ──────────────────────────────────────
#define NUM_CAPTURES 5
volatile bool triggerReceived = false;

WebServer server(80);

String   lastClass    = "En attente...";
uint8_t* lastImage    = nullptr;
size_t   lastImageLen = 0;
size_t   lastSize     = 0;
int      captureCount = 0; // nombre de cycles complets effectues

// ── CLASSES CONNUES ──────────────────────────────────
const char* KNOWN_CLASSES[] = {"plastic","metal","paper","organic","glass","cardboard","unknown"};
const int   NUM_CLASSES = 7;

// ── CALLBACK ESP-NOW RECEPTION ───────────────────────
void onReceive(const esp_now_recv_info* info, const uint8_t* data, int len) {
  TriggerMessage msg;
  memcpy(&msg, data, sizeof(msg));
  if (strcmp(msg.command, "SCAN") == 0) {
    triggerReceived = true;
    Serial.println("ESP-NOW: SCAN recu — demarrage capture");
  }
}

// ── CALLBACK ESP-NOW ENVOI ───────────────────────────
void onSent(const wifi_tx_info_t* info, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS
    ? "ESP-NOW → Principal : OK"
    : "ESP-NOW → Principal : ERREUR");
}

// ── INIT CAMERA ──────────────────────────────────────
bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound()) {
    config.frame_size   = FRAMESIZE_QVGA;  // 320x240 — fast upload
    config.jpeg_quality = 15;
    config.fb_count     = 2;
    config.fb_location  = CAMERA_FB_IN_PSRAM;
  } else {
    config.frame_size   = FRAMESIZE_QQVGA;
    config.jpeg_quality = 18;
    config.fb_count     = 1;
    config.fb_location  = CAMERA_FB_IN_DRAM;
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Camera init FAILED");
    return false;
  }

  // Discard warm-up frames
  for (int i = 0; i < 3; i++) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (fb) esp_camera_fb_return(fb);
    delay(80);
  }

  Serial.println("Camera init OK");
  return true;
}

// ── EXTRAIRE CLASSE DU JSON ──────────────────────────
String extractClass(const String& json) {
  int idx = json.indexOf("predicted_class");
  if (idx == -1) return "unknown";
  int start = json.indexOf("\"", idx + 17) + 1;
  int end   = json.indexOf("\"", start);
  if (start <= 0 || end <= start) return "unknown";
  return json.substring(start, end);
}

// ── COULEUR PAR TYPE ─────────────────────────────────
String colorForClass(const String& cls) {
  if (cls == "plastic")   return "#3498db";
  if (cls == "metal")     return "#95a5a6";
  if (cls == "paper")     return "#f39c12";
  if (cls == "organic")   return "#27ae60";
  if (cls == "glass")     return "#1abc9c";
  if (cls == "cardboard") return "#e67e22";
  return "#8e44ad";
}

// ── ENVOI UNE IMAGE VERS API ─────────────────────────
String sendImageToAPI(camera_fb_t* fb) {
  if (WiFi.status() != WL_CONNECTED) return "no_wifi";

  HTTPClient http;
  http.begin(apiUrl);
  http.setTimeout(8000);

  const char* boundary  = "B0undary";
  const char* bodyStart =
    "--B0undary\r\n"
    "Content-Disposition: form-data; name=\"file\"; filename=\"p.jpg\"\r\n"
    "Content-Type: image/jpeg\r\n\r\n";
  const char* bodyEnd = "\r\n--B0undary--\r\n";

  size_t startLen = strlen(bodyStart);
  size_t endLen   = strlen(bodyEnd);
  size_t totalLen = startLen + fb->len + endLen;

  uint8_t* buffer = (uint8_t*)malloc(totalLen);
  if (!buffer) { http.end(); return "mem_err"; }

  memcpy(buffer,                    bodyStart, startLen);
  memcpy(buffer + startLen,         fb->buf,   fb->len);
  memcpy(buffer + startLen + fb->len, bodyEnd, endLen);

  http.addHeader("Content-Type", "multipart/form-data; boundary=B0undary");
  http.addHeader("Content-Length", String(totalLen));

  int code = http.POST(buffer, totalLen);
  free(buffer);

  String result = "unknown";
  if (code > 0) {
    String resp = http.getString();
    Serial.printf("  HTTP %d — %s\n", code, resp.c_str());
    result = extractClass(resp);
  } else {
    Serial.printf("  HTTP Error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return result;
}

// ── VOTE MAJORITAIRE ─────────────────────────────────
String majorityVote(String results[], int count) {
  int votes[NUM_CLASSES] = {0};

  for (int i = 0; i < count; i++) {
    for (int j = 0; j < NUM_CLASSES; j++) {
      if (results[i] == String(KNOWN_CLASSES[j])) {
        votes[j]++;
        break;
      }
    }
  }

  int   maxVotes = 0;
  int   winner   = NUM_CLASSES - 1; // default: "unknown"
  for (int j = 0; j < NUM_CLASSES; j++) {
    if (votes[j] > maxVotes) {
      maxVotes = votes[j];
      winner   = j;
    }
  }

  Serial.print("Votes: ");
  for (int j = 0; j < NUM_CLASSES; j++) {
    if (votes[j] > 0)
      Serial.printf("%s=%d ", KNOWN_CLASSES[j], votes[j]);
  }
  Serial.printf("→ WINNER: %s (%d/5)\n", KNOWN_CLASSES[winner], maxVotes);

  return String(KNOWN_CLASSES[winner]);
}

// ── CYCLE COMPLET: 5 CAPTURES + VOTE ────────────────
void runScanCycle() {
  Serial.println("=== DEBUT CYCLE SCAN ===");
  String results[NUM_CAPTURES];
  camera_fb_t* lastGoodFrame = nullptr;

  for (int i = 0; i < NUM_CAPTURES; i++) {
    Serial.printf("Capture %d/%d...\n", i + 1, NUM_CAPTURES);

    // Flash ON
    digitalWrite(FLASH_LED_PIN, HIGH);
    delay(100);

    camera_fb_t* fb = esp_camera_fb_get();
    digitalWrite(FLASH_LED_PIN, LOW);

    if (!fb) {
      Serial.println("  Capture echouee — skip");
      results[i] = "unknown";
      continue;
    }

    // Sauvegarder la derniere bonne image pour le web
    if (lastGoodFrame) esp_camera_fb_return(lastGoodFrame);
    lastGoodFrame = fb;

    // Copier pour /live.jpg avant d'envoyer a l'API
    if (lastImage) { free(lastImage); lastImage = nullptr; }
    lastImage = (uint8_t*)malloc(fb->len);
    if (lastImage) {
      memcpy(lastImage, fb->buf, fb->len);
      lastImageLen = fb->len;
      lastSize     = fb->len;
    }

    // Envoyer a l'API
    results[i] = sendImageToAPI(fb);
    Serial.printf("  Resultat %d: %s\n", i + 1, results[i].c_str());

    // Rendre le buffer (on a deja copie l'image)
    esp_camera_fb_return(fb);
    lastGoodFrame = nullptr;

    // Petite pause entre captures pour eviter surcharge
    if (i < NUM_CAPTURES - 1) delay(200);
  }

  // Vote majoritaire
  String winner = majorityVote(results, NUM_CAPTURES);
  lastClass = winner;
  captureCount++;

  // Envoyer resultat au principal via ESP-NOW
  winner.toCharArray(msgToSend.trash_type, 20);
  esp_now_send(receiverMAC, (uint8_t*)&msgToSend, sizeof(msgToSend));

  Serial.printf("=== FIN CYCLE — Resultat envoye: %s ===\n", winner.c_str());
}

// ── PAGE WEB ─────────────────────────────────────────
void handleRoot() {
  String col = colorForClass(lastClass);

  String html = "<!DOCTYPE html><html lang='fr'><head>";
  html += "<meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta http-equiv='refresh' content='3'>";
  html += "<title>NaqiAI CAM</title>";
  html += "<link href='https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap' rel='stylesheet'>";
  html += "<style>";
  html += ":root{--bg:#0a0a0a;--surface:#111;--border:#1e1e1e;--text:#f0f0f0;--muted:#444;--accent:" + col + ";}";
  html += "*{margin:0;padding:0;box-sizing:border-box;}";
  html += "body{background:var(--bg);color:var(--text);font-family:'Space Mono',monospace;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:28px 16px;}";
  html += "header{width:100%;max-width:580px;display:flex;justify-content:space-between;align-items:baseline;margin-bottom:28px;}";
  html += "header h1{font-family:'Syne',sans-serif;font-size:26px;font-weight:800;letter-spacing:-1px;}";
  html += "header h1 span{color:var(--accent);}";
  html += ".live-dot{width:7px;height:7px;background:#27ae60;border-radius:50%;display:inline-block;margin-right:8px;animation:blink 1.4s ease-in-out infinite;}";
  html += "@keyframes blink{0%,100%{opacity:1}50%{opacity:0.1}}";
  html += ".status{font-size:10px;color:var(--muted);letter-spacing:2px;text-transform:uppercase;}";
  html += ".card{width:100%;max-width:580px;background:var(--surface);border:1px solid var(--border);border-radius:12px;overflow:hidden;}";
  html += ".cam-view{width:100%;aspect-ratio:4/3;background:#050505;display:flex;align-items:center;justify-content:center;position:relative;}";
  html += ".cam-view img{width:100%;height:100%;object-fit:cover;display:block;}";
  html += ".cam-view .no-img{color:var(--muted);font-size:11px;letter-spacing:3px;text-align:center;line-height:2;}";
  html += ".corner{position:absolute;width:20px;height:20px;border-color:var(--accent);border-style:solid;opacity:0.8;}";
  html += ".corner.tl{top:12px;left:12px;border-width:2px 0 0 2px;}";
  html += ".corner.tr{top:12px;right:12px;border-width:2px 2px 0 0;}";
  html += ".corner.bl{bottom:12px;left:12px;border-width:0 0 2px 2px;}";
  html += ".corner.br{bottom:12px;right:12px;border-width:0 2px 2px 0;}";
  html += ".result{padding:18px 22px;border-top:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;gap:12px;}";
  html += ".badge{font-family:'Syne',sans-serif;font-size:20px;font-weight:800;text-transform:uppercase;letter-spacing:3px;color:var(--accent);}";
  html += ".meta{text-align:right;font-size:10px;color:var(--muted);line-height:2.2;letter-spacing:1px;}";
  html += ".meta strong{color:#777;}";
  html += ".state-banner{margin-top:14px;width:100%;max-width:580px;padding:10px 18px;border-radius:8px;font-size:10px;letter-spacing:2px;text-transform:uppercase;border:1px solid var(--border);color:var(--muted);text-align:center;}";
  html += ".refresh-bar{width:100%;max-width:580px;margin-top:14px;height:2px;background:var(--border);border-radius:2px;overflow:hidden;}";
  html += ".refresh-bar-inner{height:100%;background:var(--accent);width:0%;animation:fillBar 3s linear infinite;opacity:0.5;}";
  html += "@keyframes fillBar{from{width:0%}to{width:100%}}";
  html += "</style></head><body>";

  html += "<header><h1>Naqi<span>AI</span> CAM</h1>";
  html += "<span class='status'><span class='live-dot'></span>STANDBY</span></header>";

  html += "<div class='card'><div class='cam-view'>";
  html += "<div class='corner tl'></div><div class='corner tr'></div>";
  html += "<div class='corner bl'></div><div class='corner br'></div>";

  if (lastImageLen > 0)
    html += "<img src='/live.jpg' alt='derniere capture'>";
  else
    html += "<div class='no-img'>EN ATTENTE<br>DU TRIGGER</div>";

  html += "</div><div class='result'>";
  html += "<div class='badge'>" + lastClass + "</div>";
  html += "<div class='meta'>";
  html += "<div><strong>CYCLES</strong> &nbsp;" + String(captureCount) + "</div>";
  html += "<div><strong>TAILLE</strong> &nbsp;" + String(lastSize / 1024.0, 1) + " KB</div>";
  html += "<div><strong>5 CAPTURES / CYCLE</strong></div>";
  html += "</div></div></div>";

  html += "<div class='state-banner'>Attend trigger ESP-NOW du principal</div>";
  html += "<div class='refresh-bar'><div class='refresh-bar-inner'></div></div>";
  html += "</body></html>";

  server.send(200, "text/html", html);
}

void handleLiveJpeg() {
  if (lastImage && lastImageLen > 0) {
    server.sendHeader("Cache-Control", "no-cache, no-store");
    server.send_P(200, "image/jpeg", (const char*)lastImage, lastImageLen);
  } else {
    server.send(404, "text/plain", "No image yet");
  }
}

// ── SETUP ────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);

  // WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi OK — IP: " + WiFi.localIP().toString());
  Serial.println("MAC: " + WiFi.macAddress());

  // ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED");
    return;
  }
  esp_now_register_recv_cb(onReceive);
  esp_now_register_send_cb(onSent);

  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, receiverMAC, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
  Serial.println("ESP-NOW OK — en attente SCAN du principal");

  // Camera
  if (!initCamera()) {
    Serial.println("Camera FAILED — halting");
    while (true) delay(1000);
  }

  // Web server
  server.on("/",         handleRoot);
  server.on("/live.jpg", handleLiveJpeg);
  server.begin();
  Serial.println("Web server OK — pret");
}

// ── LOOP ─────────────────────────────────────────────
void loop() {
  server.handleClient();

  if (triggerReceived) {
    triggerReceived = false;
    runScanCycle(); // bloquant ~8s max, puis retour au standby
  }
}

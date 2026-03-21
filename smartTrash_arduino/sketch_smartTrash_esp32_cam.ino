#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <esp_now.h>
#include <Arduino.h>

// ── WiFi ────────────────────────────────────────────
const char* ssid     = "Bouchra✨";
const char* password = "BOCHRA2026";

// ── API ─────────────────────────────────────────────
const char* apiUrl = "http://192.168.43.184:8000/predict/trash_type";

// ── MAC ESP32 PRINCIPAL ──────────────────────────────
uint8_t receiverMAC[] = {0xBC, 0xDD, 0xC2, 0xCE, 0x09, 0x18};

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

// ── STRUCTURE MESSAGE ESP-NOW ────────────────────────
typedef struct {
  char trash_type[20]; // "paper", "plastic", "metal"...
} TrashMessage;

TrashMessage msgToSend;

// ── VARIABLES GLOBALES ───────────────────────────────
WebServer server(80);

#define MAX_HISTORY 5
struct Capture {
  uint8_t* data;
  size_t   len;
  String   predicted_class;
  bool     used;
};

Capture history[MAX_HISTORY];
int      historyIndex = 0;
int      captureCount = 0;
String   lastClass    = "En attente...";
size_t   lastSize     = 0;
uint8_t* lastImage    = nullptr;
size_t   lastImageLen = 0;

// ── CALLBACK ESP-NOW ENVOI (compatible SDK 3.x) ──────
void onSent(const wifi_tx_info_t* info, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS
    ? "ESP-NOW → ESP32 Principal : OK"
    : "ESP-NOW → ESP32 Principal : ERREUR");
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

  // Utiliser PSRAM si disponible sinon reduire la resolution
  if (psramFound()) {
    Serial.println("PSRAM trouve - VGA active");
    config.frame_size  = FRAMESIZE_VGA;
    config.jpeg_quality = 12;
    config.fb_count    = 2;
    config.fb_location = CAMERA_FB_IN_PSRAM;
  } else {
    Serial.println("Pas de PSRAM - resolution CIF");
    config.frame_size  = FRAMESIZE_CIF;
    config.jpeg_quality = 15;
    config.fb_count    = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }
  Serial.println("Camera init OK");
  return true;
}

// ── EXTRAIRE CLASSE DU JSON ──────────────────────────
String extractClass(String json) {
  int idx = json.indexOf("predicted_class");
  if (idx == -1) return "unknown";
  int start = json.indexOf("\"", idx + 17) + 1;
  int end   = json.indexOf("\"", start);
  return json.substring(start, end);
}

// ── COULEUR PAR TYPE ─────────────────────────────────
String colorForClass(String cls) {
  if (cls == "plastic")   return "#3498db";
  if (cls == "metal")     return "#95a5a6";
  if (cls == "paper")     return "#f39c12";
  if (cls == "organic")   return "#27ae60";
  if (cls == "glass")     return "#1abc9c";
  if (cls == "cardboard") return "#e67e22";
  return "#8e44ad";
}

// ── PAGE WEB ─────────────────────────────────────────
void handleRoot() {
  String html = R"rawhtml(
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="5">
<title>NaqiAI — Vision</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: Arial, sans-serif; background:#0f0f0f; color:#fff; }
  header { background:#111; border-bottom:1px solid #222; padding:16px 24px; display:flex; align-items:center; justify-content:space-between; }
  header h1 { font-size:22px; }
  header span { font-size:12px; color:#666; }
  .dot { width:8px; height:8px; background:#27ae60; border-radius:50%; display:inline-block; margin-right:6px; animation:pulse 1.5s infinite; }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }
  .stats { display:flex; gap:16px; padding:20px 24px; }
  .stat { background:#1a1a1a; border:1px solid #222; border-radius:8px; padding:16px 24px; flex:1; text-align:center; }
  .stat .val { font-size:32px; font-weight:bold; }
  .stat .lbl { font-size:11px; color:#666; margin-top:4px; text-transform:uppercase; letter-spacing:1px; }
  .live { margin:0 24px 24px; background:#1a1a1a; border:1px solid #222; border-radius:8px; overflow:hidden; }
  .live-header { padding:12px 20px; border-bottom:1px solid #222; font-size:13px; font-weight:bold; }
  .live-body { display:flex; align-items:center; gap:24px; padding:20px; }
  .live-body img { width:320px; height:240px; object-fit:cover; border-radius:6px; border:1px solid #333; }
  .live-info { flex:1; }
  .class-badge { display:inline-block; padding:8px 20px; border-radius:20px; font-size:18px; font-weight:bold; text-transform:uppercase; letter-spacing:2px; margin-bottom:16px; }
  .info-row { display:flex; justify-content:space-between; padding:8px 0; border-bottom:1px solid #222; font-size:13px; }
  .info-row span:last-child { color:#aaa; }
  .history { margin:0 24px 24px; }
  .history h2 { font-size:14px; color:#666; text-transform:uppercase; letter-spacing:1px; margin-bottom:12px; }
  .history-grid { display:grid; grid-template-columns:repeat(5, 1fr); gap:12px; }
  .history-card { background:#1a1a1a; border:1px solid #222; border-radius:8px; overflow:hidden; }
  .history-card img { width:100%; height:120px; object-fit:cover; }
  .history-card .card-info { padding:8px; }
  .history-card .card-class { font-size:11px; font-weight:bold; text-transform:uppercase; letter-spacing:1px; }
  .history-card .card-size { font-size:10px; color:#555; margin-top:2px; }
  .no-image { width:320px; height:240px; background:#111; border-radius:6px; display:flex; align-items:center; justify-content:center; color:#333; font-size:13px; }
</style>
</head>
<body>
<header>
  <h1><span class="dot"></span>NaqiAI — Waste Vision</h1>
  <span>Rafraichissement automatique toutes les 5s</span>
</header>
)rawhtml";

  html += "<div class='stats'>";
  html += "<div class='stat'><div class='val'>" + String(captureCount) + "</div><div class='lbl'>Captures totales</div></div>";
  html += "<div class='stat'><div class='val' style='color:" + colorForClass(lastClass) + "'>" + lastClass + "</div><div class='lbl'>Derniere classification</div></div>";
  html += "<div class='stat'><div class='val'>" + String(lastSize / 1024.0, 1) + " KB</div><div class='lbl'>Taille derniere image</div></div>";
  html += "</div>";

  html += "<div class='live'><div class='live-header'>Derniere capture</div><div class='live-body'>";
  if (lastImageLen > 0) html += "<img src='/live.jpg'>";
  else html += "<div class='no-image'>Aucune image capturee</div>";
  html += "<div class='live-info'>";
  html += "<div class='class-badge' style='background:" + colorForClass(lastClass) + "20;color:" + colorForClass(lastClass) + ";border:1px solid " + colorForClass(lastClass) + "'>" + lastClass + "</div>";
  html += "<div class='info-row'><span>Taille image</span><span>" + String(lastSize) + " bytes</span></div>";
  html += "<div class='info-row'><span>Resolution</span><span>VGA 640x480</span></div>";
  html += "<div class='info-row'><span>Format</span><span>JPEG</span></div>";
  html += "<div class='info-row'><span>Captures totales</span><span>" + String(captureCount) + "</span></div>";
  html += "</div></div></div>";

  html += "<div class='history'><h2>Historique des 5 dernieres captures</h2><div class='history-grid'>";
  for (int i = 0; i < MAX_HISTORY; i++) {
    int idx = (historyIndex - 1 - i + MAX_HISTORY) % MAX_HISTORY;
    if (history[idx].used) {
      html += "<div class='history-card'><img src='/img/" + String(idx) + ".jpg'><div class='card-info'>";
      html += "<div class='card-class' style='color:" + colorForClass(history[idx].predicted_class) + "'>" + history[idx].predicted_class + "</div>";
      html += "<div class='card-size'>" + String(history[idx].len / 1024.0, 1) + " KB</div></div></div>";
    } else {
      html += "<div class='history-card' style='opacity:0.2'><div style='width:100%;height:120px;background:#111;display:flex;align-items:center;justify-content:center;font-size:11px;color:#333'>Vide</div>";
      html += "<div class='card-info'><div class='card-class' style='color:#333'>---</div></div></div>";
    }
  }
  html += "</div></div></body></html>";
  server.send(200, "text/html", html);
}

void handleLiveJpeg() {
  if (lastImage && lastImageLen > 0) {
    server.sendHeader("Cache-Control", "no-cache");
    server.send_P(200, "image/jpeg", (const char*)lastImage, lastImageLen);
  } else {
    server.send(404, "text/plain", "No image");
  }
}

void handleHistoryJpeg() {
  String uri = server.uri();
  int idx = uri.substring(5, uri.indexOf(".jpg")).toInt();
  if (idx >= 0 && idx < MAX_HISTORY && history[idx].used) {
    server.sendHeader("Cache-Control", "no-cache");
    server.send_P(200, "image/jpeg", (const char*)history[idx].data, history[idx].len);
  } else {
    server.send(404, "text/plain", "Not found");
  }
}

void saveToHistory(uint8_t* buf, size_t len, String cls) {
  int idx = historyIndex % MAX_HISTORY;
  if (history[idx].used && history[idx].data) {
    free(history[idx].data);
    history[idx].data = nullptr;
  }
  history[idx].data = (uint8_t*)malloc(len);
  if (history[idx].data) {
    memcpy(history[idx].data, buf, len);
    history[idx].len             = len;
    history[idx].predicted_class = cls;
    history[idx].used            = true;
  }
  historyIndex = (historyIndex + 1) % MAX_HISTORY;
}

// ── ENVOI IMAGE VERS API ─────────────────────────────
String sendImageToAPI(camera_fb_t* fb) {
  if (WiFi.status() != WL_CONNECTED) return "no_wifi";

  HTTPClient http;
  http.begin(apiUrl);
  http.setTimeout(10000);

  String boundary  = "----ESP32Boundary7MA4YWxkTrZu0gW";
  String bodyStart = "--" + boundary + "\r\n";
  bodyStart += "Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n";
  bodyStart += "Content-Type: image/jpeg\r\n\r\n";
  String bodyEnd   = "\r\n--" + boundary + "--\r\n";
  int totalLen     = bodyStart.length() + fb->len + bodyEnd.length();

  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
  http.addHeader("Content-Length", String(totalLen));

  uint8_t* buffer = (uint8_t*)malloc(totalLen);
  if (!buffer) { http.end(); return "memory_error"; }

  memcpy(buffer,                                  bodyStart.c_str(), bodyStart.length());
  memcpy(buffer + bodyStart.length(),             fb->buf,           fb->len);
  memcpy(buffer + bodyStart.length() + fb->len,  bodyEnd.c_str(),   bodyEnd.length());

  int code = http.POST(buffer, totalLen);
  free(buffer);

  String result = "unknown";
  if (code > 0) {
    String response = http.getString();
    Serial.printf("HTTP %d — %s\n", code, response.c_str());
    result = extractClass(response);
  } else {
    Serial.printf("HTTP Error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return result;
}

// ── SETUP ────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);

  for (int i = 0; i < MAX_HISTORY; i++) {
    history[i].data = nullptr;
    history[i].used = false;
  }

  // WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi OK — IP: " + WiFi.localIP().toString());
  Serial.println("Dashboard: http://" + WiFi.localIP().toString());

  // ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init FAILED");
    return;
  }
  esp_now_register_send_cb(onSent);

  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, receiverMAC, 6);
  peer.channel = 0;
  peer.encrypt = false;
  esp_now_add_peer(&peer);
  Serial.println("ESP-NOW OK — peer ajouté");

  // Camera
  if (!initCamera()) {
    Serial.println("Camera FAILED — halting");
    while (true) delay(1000);
  }

  // Web server
  server.on("/",         handleRoot);
  server.on("/live.jpg", handleLiveJpeg);
  server.onNotFound([](){ 
    if (server.uri().startsWith("/img/")) handleHistoryJpeg();
    else server.send(404, "text/plain", "Not found");
  });
  server.begin();
  Serial.println("Web server started");
  Serial.println("Pret — capture toutes les 5 secondes");
}

// ── LOOP ─────────────────────────────────────────────
void loop() {
  server.handleClient();

  static unsigned long lastCapture = 0;
  if (millis() - lastCapture >= 5000) {
    lastCapture = millis();

    // Capture image
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Capture failed");
      return;
    }

    Serial.printf("Captured: %d bytes — ", fb->len);

    // Sauvegarder pour /live.jpg
    if (lastImage) free(lastImage);
    lastImage    = (uint8_t*)malloc(fb->len);
    lastImageLen = 0;
    if (lastImage) {
      memcpy(lastImage, fb->buf, fb->len);
      lastImageLen = fb->len;
    }
    lastSize = fb->len;

    // Envoyer vers API
    String cls = sendImageToAPI(fb);
    lastClass  = cls;
    captureCount++;

    Serial.println("Type detecte: " + cls);

    // ── ENVOYER RÉSULTAT VIA ESP-NOW ─────────────────
    cls.toCharArray(msgToSend.trash_type, 20);
    esp_now_send(receiverMAC, (uint8_t*)&msgToSend, sizeof(msgToSend));

    // Sauvegarder dans historique
    if (lastImage) saveToHistory(lastImage, lastImageLen, cls);

    esp_camera_fb_return(fb);
  }
}
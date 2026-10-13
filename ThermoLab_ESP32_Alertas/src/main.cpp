#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <DHT.h>
#include <Adafruit_AMG88xx.h>
#include <LittleFS.h>
#include <esp_timer.h>
#include <math.h>
#include <time.h>
#include <Preferences.h>
#include "dashboard.h"

// ESP32 DevKit: DHT11 no GPIO27; AMG8833 SDA=21, SCL=22.
#define PINO_DHT 27
#define PINO_SDA 21
#define PINO_SCL 22
#define TOTAL_PIXELS 64
#define MEDIANA_N 5

// AMG8833 aceita ate 10 quadros/s (no modo adequado). 200 ms = 5 leituras/s.
// O DHT11 tem intervalo MINIMO de 2 s; nao adianta consulta-lo mais depressa.
constexpr uint32_t INTERVALO_AMG_MS  = 200;
constexpr uint32_t INTERVALO_DHT_MS  = 2100;
constexpr uint32_t INTERVALO_LOG_MS  = 1000;
constexpr uint32_t FLUSH_LOG_MS      = 10000;
constexpr uint32_t TENTATIVA_AMG_MS  = 15000;
constexpr size_t   LIMITE_CSV_BYTES  = 1700000;
constexpr uint16_t HIST_RAM_N        = 900;   // 15 min de amostras de 1 s
constexpr size_t   HIST_GRAFICO_MAX  = 1000;  // amostragem para consulta da sessao

constexpr float ALFA_AMG_SUAVE = 0.33f;
constexpr float ALFA_AMG_RAPIDO = 0.68f;
constexpr float DIFERENCA_RAPIDA = 2.2f;
constexpr float ZONA_AMG = 0.05f;
// Alertas para pesquisa termica de vegetacao. Margem reduz falsos positivos:
// o DHT11 pode ter erro de +/-2 C e o sensor termico enxerga superficies.
constexpr float ALERTA_DELTA_MIN_C = 1.5f;  // minimo acima da temperatura ambiente
constexpr float ALERTA_HISTERESE_C = 0.6f;
constexpr uint8_t ALERTA_PIXELS_MIN = 1;      // drone: aceitar 1 pixel aquecido confirmado
constexpr uint8_t ALERTA_FRAMES_MIN = 3;      // 3 quadros consecutivos (600 ms)
constexpr uint32_t ALERTA_COOLDOWN_MS = 5000;
constexpr uint32_t ALERTA_REARM_MS = 1500;   // precisa esfriar para rearmar
constexpr size_t ALERTAS_LIMITE_BYTES = 150000; // reserva flash para historico

constexpr float ALFA_DHT_TEMP = 0.34f;
constexpr float ALFA_DHT_UMID = 0.30f;

const char* WIFI_NOME = "ESP32-Termico";
const char* WIFI_SENHA = "12345678";
const char* CAMINHO_CSV = "/leituras.csv";
const char* CAMINHO_ALERTAS = "/alertas.csv";


DHT dht(PINO_DHT, DHT11);
Adafruit_AMG88xx amg;
WebServer servidor(80);
File arquivoLog;
Preferences preferencias;

bool amgOK = false;
bool dhtOK = false;
bool leituraAMGOK = false;
bool pixelsIniciados = false;
bool flashOK = false;
bool logCheio = false;
bool relogioSincronizado = false;
bool alertasCheios = false;
bool alertasDisponiveis = false;
bool alertaArmado = true;
bool temUltimoAlerta = false;
uint8_t framesQuentes = 0;
uint32_t inicioResfriamento = 0;
uint32_t ultimoAlertaMs = 0;
uint32_t proximoAlertaId = 0;
uint32_t sessaoBoot = 0;
uint32_t totalAlertas = 0;
int alertaPixelsAcima = 0;
float alertaDeltaAtual = NAN;
const char* alertaEstado = "AGUARDANDO_SENSORES";


int64_t offsetUnixMs = 0;  // unix_ms = uptime_ms + offsetUnixMs

uint32_t ultimoAMG = 0, ultimoDHT = 0, ultimoLog = 0;
uint32_t ultimoFlush = 0, ultimaTentativa = 0;
uint64_t instanteDHT = 0, instanteAMG = 0;
uint32_t sequencia = 0;

float tempDHT = NAN, umidDHT = NAN;
float tempDHTBruta = NAN, umidDHTBruta = NAN;
float amgMedia = NAN, amgMin = NAN, amgMax = NAN, amgMaxBruta = NAN;
int pixelQuente = -1;
float pixelsBrutos[TOTAL_PIXELS] = {};
float pixelsFiltrados[TOTAL_PIXELS] = {};
float janela[TOTAL_PIXELS][MEDIANA_N] = {};
int posJanela = 0, qtdJanela = 0;

// Campos do CSV, menos a data UTC opcional calculada na exportacao.
struct Registro {
  uint32_t id;
  uint64_t tempoMs;
  float temp, umidade, media, minima, maxima;
  float tempBruta, umidBruta, maxBruta;
};
Registro historico[HIST_RAM_N];
uint16_t histInicio = 0, histQuantidade = 0;

uint64_t tempoMs() { return (uint64_t)(esp_timer_get_time() / 1000LL); }
String inteiro64(uint64_t n) {
  char buffer[24];
  snprintf(buffer, sizeof(buffer), "%llu", (unsigned long long)n);
  return String(buffer);
}
String jsonNumero(float n) { return isfinite(n) ? String(n, 2) : "null"; }
String csvNumero(float n) { return isfinite(n) ? String(n, 2) : ""; }

uint64_t dataEventoMs(uint32_t sessao, uint64_t ms, uint64_t epochRegistrado) {
  // Ajusta eventos anteriores a sincronizacao, mas somente no boot atual.
  if (epochRegistrado > 1577836800000ULL) return epochRegistrado;
  if (relogioSincronizado && sessao == sessaoBoot) {
    int64_t t = (int64_t)ms + offsetUnixMs;
    return t > 1577836800000LL ? (uint64_t)t : 0;
  }
  return 0;
}

String jsonEvento(int id, uint32_t sessao, uint64_t ms, uint64_t epoch,
    float ambiente, float pico, float delta, int x, int y, int pixels) {
  String j;
  j.reserve(205);
  j += "{\"id\":" + String(id);
  j += ",\"sessao\":" + String(sessao);
  j += ",\"tempo_ms\":" + inteiro64(ms);
  j += ",\"epoch_ms\":" + inteiro64(dataEventoMs(sessao, ms, epoch));
  j += ",\"ambiente_c\":" + jsonNumero(ambiente);
  j += ",\"pico_c\":" + jsonNumero(pico);
  j += ",\"delta_c\":" + jsonNumero(delta);
  j += ",\"pixel_x\":" + String(x);
  j += ",\"pixel_y\":" + String(y);
  j += ",\"pixels_quentes\":" + String(pixels) + "}";
  return j;
}


float suavizar(float anterior, float atual, float alfa, float zona) {
  if (!isfinite(atual)) return anterior;
  if (!isfinite(anterior)) return atual;
  float novo = anterior + alfa * (atual - anterior);
  return fabsf(novo - anterior) < zona ? anterior : novo;
}
float mediana(int pixel, int n) {
  float valores[MEDIANA_N];
  for (int i = 0; i < n; i++) valores[i] = janela[pixel][i];
  for (int i = 1; i < n; i++) {
    float chave = valores[i];
    int j = i - 1;
    while (j >= 0 && valores[j] > chave) { valores[j+1] = valores[j]; j--; }
    valores[j+1] = chave;
  }
  return valores[n/2];
}
void lerDHT() {
  float t = dht.readTemperature();
  float u = dht.readHumidity();
  dhtOK = isfinite(t) && isfinite(u) && t > -10 && t < 60 && u >= 0 && u <= 100;
  if (!dhtOK) return;
  tempDHTBruta = t;
  umidDHTBruta = u;
  tempDHT = suavizar(tempDHT, t, ALFA_DHT_TEMP, 0.05f);
  umidDHT = suavizar(umidDHT, u, ALFA_DHT_UMID, 0.10f);
  instanteDHT = tempoMs();
}
void iniciarAMG() {
  ultimaTentativa = millis();
  amgOK = amg.begin(0x69, &Wire) || amg.begin(0x68, &Wire);
  if (amgOK) {
    posJanela = qtdJanela = 0;
    pixelsIniciados = false;
    for (float &v : pixelsFiltrados) v = NAN;
  }
  Serial.println(amgOK ? "AMG8833 conectado" : "AMG8833 nao encontrado");
}
void lerAMG() {
  if (!amgOK) { leituraAMGOK = false; return; }
  amg.readPixels(pixelsBrutos);
  for (float v : pixelsBrutos) {
    if (!isfinite(v) || v < -20 || v > 120) { leituraAMGOK = false; return; }
  }
  leituraAMGOK = true;
  float soma = 0, minimo = INFINITY, maximo = -INFINITY, maxBruto = -INFINITY;
  int pico = -1;
  for (int i = 0; i < TOTAL_PIXELS; i++) {
    janela[i][posJanela] = pixelsBrutos[i];
    if (pixelsBrutos[i] > maxBruto) maxBruto = pixelsBrutos[i];
  }
  if (qtdJanela < MEDIANA_N) qtdJanela++;
  posJanela = (posJanela+1) % MEDIANA_N;
  for (int i = 0; i < TOTAL_PIXELS; i++) {
    float m = mediana(i, qtdJanela);
    float alfa = (!pixelsIniciados || fabsf(m - pixelsFiltrados[i]) > DIFERENCA_RAPIDA) ? ALFA_AMG_RAPIDO : ALFA_AMG_SUAVE;
    pixelsFiltrados[i] = suavizar(pixelsFiltrados[i], m, alfa, ZONA_AMG);
    const float v = pixelsFiltrados[i];
    soma += v;
    if (v < minimo) minimo = v;
    if (v > maximo) { maximo = v; pico = i; }
  }
  pixelsIniciados = true;
  amgMin = minimo; amgMax = maximo; amgMedia = soma / TOTAL_PIXELS;
  amgMaxBruta = maxBruto;
  pixelQuente = pico;
  instanteAMG = tempoMs();
}

String linhaCSV(const Registro& r) {
  String linha;
  linha.reserve(110);
  linha += String(r.id); linha += ',';
  linha += inteiro64(r.tempoMs); linha += ',';
  linha += csvNumero(r.temp); linha += ',';
  linha += csvNumero(r.umidade); linha += ',';
  linha += csvNumero(r.media); linha += ',';
  linha += csvNumero(r.minima); linha += ',';
  linha += csvNumero(r.maxima); linha += ',';
  linha += csvNumero(r.tempBruta); linha += ',';
  linha += csvNumero(r.umidBruta); linha += ',';
  linha += csvNumero(r.maxBruta);
  linha += '\n';
  return linha;
}
void salvarNaRAM(const Registro& r) {
  uint16_t pos = (histInicio + histQuantidade) % HIST_RAM_N;
  if (histQuantidade == HIST_RAM_N) {
    pos = histInicio;
    histInicio = (histInicio+1) % HIST_RAM_N;
  } else histQuantidade++;
  historico[pos] = r;
}
void registrar() {
  uint64_t agora = tempoMs();
  bool dhtValido = instanteDHT && agora - instanteDHT < 5000 && isfinite(tempDHT);
  bool amgValido = instanteAMG && agora - instanteAMG < 2000 && isfinite(amgMedia);
  if (!dhtValido && !amgValido) return;
  Registro r{};
  r.id = ++sequencia;
  r.tempoMs = agora;
  r.temp = dhtValido ? tempDHT : NAN;
  r.umidade = dhtValido ? umidDHT : NAN;
  r.tempBruta = dhtValido ? tempDHTBruta : NAN;
  r.umidBruta = dhtValido ? umidDHTBruta : NAN;
  r.media = amgValido ? amgMedia : NAN;
  r.minima = amgValido ? amgMin : NAN;
  r.maxima = amgValido ? amgMax : NAN;
  r.maxBruta = amgValido ? amgMaxBruta : NAN;
  salvarNaRAM(r);
  if (flashOK && !logCheio && arquivoLog) {
    String linha = linhaCSV(r);
    if (arquivoLog.size() + linha.length() > LIMITE_CSV_BYTES) {
      logCheio = true;
      arquivoLog.flush();
      Serial.println("CSV atingiu limite: dados anteriores preservados; exporte o arquivo.");
    } else if (arquivoLog.print(linha) != linha.length()) {
      logCheio = true;
      Serial.println("Falha de gravacao: verifique espaco livre do LittleFS.");
    }
  }
}

// O arquivo de alertas nao e apagado a cada reinicializacao.
void iniciarAlertas() {
  preferencias.begin("infrared", false);
  sessaoBoot = preferencias.getUInt("sessao", 0) + 1;
  preferencias.putUInt("sessao", sessaoBoot);
  preferencias.end();
  if (!flashOK) {
    Serial.println("ALERTAS: LittleFS indisponivel; persistencia desativada.");
    return;
  }
  if (!LittleFS.exists(CAMINHO_ALERTAS)) {
    File novo = LittleFS.open(CAMINHO_ALERTAS, "w");
    if (!novo) return;
    novo.println("id,sessao,tempo_ms,epoch_ms,ambiente_c,pico_c,delta_c,pixel_x,pixel_y,pixels_quentes");
    novo.close();
  }
  File f = LittleFS.open(CAMINHO_ALERTAS, "r");
  if (!f) return;
  f.readStringUntil('\n');
  while (f.available()) {
    String linha = f.readStringUntil('\n');
    if (!linha.length()) continue;
    uint32_t id = (uint32_t)strtoul(linha.c_str(), nullptr, 10);
    if (id > proximoAlertaId) proximoAlertaId = id;
    totalAlertas++;
    if ((totalAlertas & 255) == 0) yield();
  }
  alertasCheios = f.size() >= ALERTAS_LIMITE_BYTES;
  f.close();
  alertasDisponiveis = true;
  Serial.printf("ALERTAS: %u eventos preservados, sessao %u\n", totalAlertas, sessaoBoot);
}

bool registrarAlerta(uint64_t ms, float ambiente, float pico, int pixels) {
  if (!alertasDisponiveis || alertasCheios) {
    Serial.println("ALERTA: armazenamento indisponivel ou cheio.");
    return false;
  }
  uint64_t epoch = relogioSincronizado ? dataEventoMs(sessaoBoot, ms, 0) : 0;
  String linha;
  linha.reserve(135);
  linha += String(proximoAlertaId + 1) + ',' + String(sessaoBoot) + ',';
  linha += inteiro64(ms) + ',' + inteiro64(epoch) + ',';
  linha += csvNumero(ambiente) + ',' + csvNumero(pico) + ',';
  linha += csvNumero(pico - ambiente) + ',';
  linha += String(pixelQuente % 8) + ',' + String(pixelQuente / 8) + ',';
  linha += String(pixels) + '\n';
  File f = LittleFS.open(CAMINHO_ALERTAS, "a");
  if (!f) { alertasDisponiveis = false; return false; }
  bool salvo = false;
  if (f.size() + linha.length() > ALERTAS_LIMITE_BYTES) {
    alertasCheios = true;
    Serial.println("ALERTAS: armazenamento cheio; exporte eventos.");
  } else if (f.print(linha) == linha.length()) {
    f.flush();
    proximoAlertaId++;
    totalAlertas++;
    salvo = true;
    Serial.printf("ALERTA #%u: ambiente %.2f C, pico %.2f C (delta %.2f), %d pixels\n",
                  proximoAlertaId, ambiente, pico, pico-ambiente, pixels);
  } else {
    alertasDisponiveis = false;
  }
  f.close();
  return salvo;
}

void avaliarAlertaTermico() {
  const uint64_t ms = tempoMs();
  const uint32_t agora = millis();
  alertaPixelsAcima = 0;
  alertaDeltaAtual = NAN;
  if (!dhtOK || !leituraAMGOK || !pixelsIniciados ||
      !instanteDHT || ms - instanteDHT > 5000 || !isfinite(tempDHT) ||
      !instanteAMG || ms - instanteAMG > 1000) {
    framesQuentes = 0;
    alertaEstado = "AGUARDANDO_SENSORES";
    return;
  }

  // Compara o ponto mais quente do mapa com a temperatura ambiente.
  // Um pico isolado também é válido, mas só depois de três quadros.
  alertaDeltaAtual = amgMax - tempDHT;
  for (int i = 0; i < TOTAL_PIXELS; i++) {
    if (pixelsFiltrados[i] >= tempDHT + ALERTA_DELTA_MIN_C) alertaPixelsAcima++;
  }
  bool quente = alertaDeltaAtual >= ALERTA_DELTA_MIN_C &&
                alertaPixelsAcima >= ALERTA_PIXELS_MIN;

  if (quente) {
    inicioResfriamento = 0;
    if (framesQuentes < 255) framesQuentes++;

    if (!alertaArmado) {
      alertaEstado = "AGUARDANDO_RESFRIAMENTO";
      return;
    }
    if (temUltimoAlerta && (uint32_t)(agora-ultimoAlertaMs) < ALERTA_COOLDOWN_MS) {
      alertaEstado = "TRAVA_5_SEGUNDOS";
      return;
    }
    if (framesQuentes < ALERTA_FRAMES_MIN) {
      alertaEstado = "CONFIRMANDO";
      return;
    }
    if (registrarAlerta(ms, tempDHT, amgMax, alertaPixelsAcima)) {
      ultimoAlertaMs = agora;
      temUltimoAlerta = true;
      alertaArmado = false;
      framesQuentes = 0;
      alertaEstado = "ALERTA_REGISTRADO";
    } else {
      alertaEstado = "FALHA_ARMAZENAMENTO";
    }
  } else {
    framesQuentes = 0;
    alertaEstado = alertaDeltaAtual < 0 ? "AMG_ABAIXO_AMBIENTE" : "ABAIXO_LIMIAR";
    // Um novo evento apenas depois de esfriar por 1,5 s: evita spam.
    if (amgMax <= tempDHT + ALERTA_DELTA_MIN_C - ALERTA_HISTERESE_C) {
      if (!inicioResfriamento) inicioResfriamento = agora;
      if ((uint32_t)(agora - inicioResfriamento) >= ALERTA_REARM_MS) {
        alertaArmado = true;
      }
    } else {
      inicioResfriamento = 0;
    }
    if (!alertaArmado) alertaEstado = "AGUARDANDO_RESFRIAMENTO";
  }
}

void iniciarCSV() {
  flashOK = LittleFS.begin(true);
  if (!flashOK) { Serial.println("LittleFS indisponivel: CSV desativado."); return; }
  // Cada boot inicia uma nova sessao. Exporte antes de reiniciar.
  arquivoLog = LittleFS.open(CAMINHO_CSV, "w");
  if (!arquivoLog) { flashOK = false; Serial.println("Falha ao abrir CSV"); return; }
  arquivoLog.print("id,tempo_ms,temperatura_dht_c,umidade_pct,amg_media_c,amg_min_c,amg_max_c,temperatura_dht_bruta_c,umidade_bruta_pct,amg_max_bruta_c\n");
  arquivoLog.flush();
  ultimoFlush = millis();
}
void jsonRegistro(String& json, const Registro& r) {
  json += '['; json += String(r.id); json += ',';
  json += inteiro64(r.tempoMs); json += ',';
  json += jsonNumero(r.temp); json += ',';
  json += jsonNumero(r.umidade); json += ',';
  json += jsonNumero(r.media); json += ',';
  json += jsonNumero(r.minima); json += ',';
  json += jsonNumero(r.maxima); json += ',';
  json += jsonNumero(r.tempBruta); json += ',';
  json += jsonNumero(r.maxBruta); json += ',';
  json += jsonNumero(r.umidBruta); json += ']';
}
void enviarAPI() {
  String j; j.reserve(1200);
  const uint64_t agora = tempoMs();
  j += "{\"id\":" + String(sequencia);
  j += ",\"ms\":" + inteiro64(agora);
  j += ",\"temperatura\":" + jsonNumero(tempDHT);
  j += ",\"umidade\":" + jsonNumero(umidDHT);
  j += ",\"temp_bruta\":" + jsonNumero(tempDHTBruta);
  j += ",\"umid_bruta\":" + jsonNumero(umidDHTBruta);
  j += ",\"minima\":" + jsonNumero(amgMin);
  j += ",\"maxima\":" + jsonNumero(amgMax);
  j += ",\"media\":" + jsonNumero(amgMedia);
  j += ",\"max_bruta\":" + jsonNumero(amgMaxBruta);
  j += ",\"pico_x\":" + String(pixelQuente < 0 ? -1 : pixelQuente%8);
  j += ",\"pico_y\":" + String(pixelQuente < 0 ? -1 : pixelQuente/8);
  j += ",\"amg_ok\":"; j += amgOK ? "true" : "false";
  j += ",\"amg_leitura_ok\":"; j += (leituraAMGOK && agora-instanteAMG<2000) ? "true" : "false";
  j += ",\"dht_leitura_ok\":"; j += (dhtOK && agora-instanteDHT<5000) ? "true" : "false";
  j += ",\"alertas_total\":" + String(totalAlertas);
  j += ",\"alerta_versao\":2";
  j += ",\"alerta_estado\":\"" + String(alertaEstado) + "\"";
  j += ",\"alerta_delta_atual_c\":" + jsonNumero(alertaDeltaAtual);
  j += ",\"alerta_pixels_quentes\":" + String(alertaPixelsAcima);
  j += ",\"alerta_frames_confirmados\":" + String(framesQuentes);
  j += ",\"alerta_armado\":"; j += alertaArmado ? "true" : "false";
  j += ",\"alerta_cooldown_restante_ms\":" +
      String(temUltimoAlerta && (uint32_t)(millis()-ultimoAlertaMs) < ALERTA_COOLDOWN_MS ?
             ALERTA_COOLDOWN_MS - (uint32_t)(millis()-ultimoAlertaMs) : 0);

  j += ",\"alertas_ultimo_id\":" + String(proximoAlertaId);
  j += ",\"alertas_cheios\":"; j += alertasCheios ? "true" : "false";
  j += ",\"alertas_ok\":"; j += alertasDisponiveis ? "true" : "false";
  j += ",\"sessao\":" + String(sessaoBoot);
  j += ",\"alerta_delta_min_c\":" + String(ALERTA_DELTA_MIN_C, 2);
  j += ",\"clientes\":" + String(WiFi.softAPgetStationNum());
  j += ",\"total\":" + String(sequencia);
  j += ",\"flash_ok\":"; j += flashOK ? "true" : "false";
  j += ",\"log_cheio\":"; j += logCheio ? "true" : "false";
  j += ",\"csv_bytes\":" + String(arquivoLog ? arquivoLog.size() : 0);
  j += ",\"csv_limite\":" + String(LIMITE_CSV_BYTES);
  j += ",\"relogio_sincronizado\":"; j += relogioSincronizado ? "true" : "false";
  j += ",\"pixels\":[";
  if (pixelsIniciados) for (int i = 0; i < TOTAL_PIXELS; i++) {
    if (i) j += ',';
    j += jsonNumero(pixelsFiltrados[i]);
  }
  j += "]}";
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.send(200, "application/json; charset=utf-8", j);
}

void enviarHistorico() {
  // Historico inteiro: leitura CSV com subamostragem espacial no tempo.
  // Mantem os pontos de inicio e fim. CSV original nunca e reduzido.
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.setContentLength(CONTENT_LENGTH_UNKNOWN);
  servidor.send(200, "application/json; charset=utf-8", "");
  servidor.sendContent("{\"registros\":[");
  String bloco; bloco.reserve(1600);
  bool primeiro = true;
  if (flashOK) {
    arquivoLog.flush();
    File file = LittleFS.open(CAMINHO_CSV, "r");
    if (file) {
      file.readStringUntil('\n'); // cabecalho
      size_t stride = max((size_t)1, ((size_t)sequencia + HIST_GRAFICO_MAX - 1) / HIST_GRAFICO_MAX);
      while (file.available()) {
        String s = file.readStringUntil('\n');
        if (!s.length()) continue;
        // Evita usar ArduinoJson: CSV padronizado, todos os campos sem aspas.
        int virgulas[9], encontrados = 0;
        for (int i = 0; i < s.length() && encontrados < 9; i++) if (s[i] == ',') virgulas[encontrados++] = i;
        if (encontrados != 9) continue;
        uint32_t id = (uint32_t)strtoul(s.c_str(), nullptr, 10);
        if (id != 1 && id != sequencia && (id % stride) != 0) continue;
        Registro r{};
        r.id = id;
        r.tempoMs = strtoull(s.c_str()+virgulas[0]+1, nullptr, 10);
        float* campos[] = {&r.temp,&r.umidade,&r.media,&r.minima,&r.maxima,&r.tempBruta,&r.umidBruta,&r.maxBruta};
        for (int n = 0; n < 8; n++) {
          int inicio = virgulas[n+1]+1;
          int fim = n+2 < 9 ? virgulas[n+2] : (int)s.length();
          *campos[n] = inicio == fim ? NAN : atof(s.substring(inicio, fim).c_str());
        }
        if (!primeiro) bloco += ',';
        primeiro = false;
        jsonRegistro(bloco, r);
        if (bloco.length() > 1200) { servidor.sendContent(bloco); bloco = ""; }
        yield();
      }
      file.close();
    }
  }
  // Se a flash falhou, pelo menos os ultimos 15 minutos ficam disponiveis.
  if (!flashOK) for (int i = 0; i < histQuantidade; i++) {
    if (!primeiro) bloco += ',';
    primeiro = false;
    jsonRegistro(bloco, historico[(histInicio+i) % HIST_RAM_N]);
    if (bloco.length() > 1200) { servidor.sendContent(bloco); bloco = ""; }
  }
  if (bloco.length()) servidor.sendContent(bloco);
  servidor.sendContent("]}");
  servidor.sendContent("");
}

void enviarRecentes() {
  uint32_t depois = servidor.hasArg("depois") ? (uint32_t)servidor.arg("depois").toInt() : 0;
  const uint32_t primeiroDisponivel = histQuantidade ? historico[histInicio].id : 0;
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.setContentLength(CONTENT_LENGTH_UNKNOWN);
  servidor.send(200, "application/json; charset=utf-8", "");
  String cabecalho = "{\"recarregar\":";
  cabecalho += (primeiroDisponivel && depois+1 < primeiroDisponivel) ? "true" : "false";
  cabecalho += ",\"registros\":[";
  servidor.sendContent(cabecalho);
  String bloco; bloco.reserve(1400);
  bool primeiro = true;
  for (int i = 0; i < histQuantidade; i++) {
    const Registro& r = historico[(histInicio+i) % HIST_RAM_N];
    if (r.id <= depois) continue;
    if (!primeiro) bloco += ',';
    primeiro = false;
    jsonRegistro(bloco, r);
    if (bloco.length() > 1200) { servidor.sendContent(bloco); bloco = ""; }
  }
  if (bloco.length()) servidor.sendContent(bloco);
  servidor.sendContent("]}");
  servidor.sendContent("");
}

void sincronizarHora() {
  // O celular/PC envia horario UTC em epoch_ms. Sem internet/RTC, a hora depende dele.
  if (!servidor.hasArg("epoch")) { servidor.send(400, "text/plain", "epoch ausente"); return; }
  int64_t epoch = atoll(servidor.arg("epoch").c_str());
  if (epoch < 1577836800000LL || epoch > 4102444800000LL) {
    servidor.send(400, "text/plain", "Horario invalido"); return;
  }
  offsetUnixMs = epoch - (int64_t)tempoMs();
  relogioSincronizado = true;
  servidor.send(200, "text/plain", "OK");
}
String dataHoraUTC(uint64_t ms) {
  if (!relogioSincronizado) return "";
  int64_t unixMs = (int64_t)ms + offsetUnixMs;
  time_t segundos = (time_t)(unixMs / 1000LL);
  struct tm utc;
  gmtime_r(&segundos, &utc);
  char buffer[36];
  snprintf(buffer, sizeof(buffer), "%04d-%02d-%02dT%02d:%02d:%02d.%03lldZ",
    utc.tm_year+1900, utc.tm_mon+1, utc.tm_mday, utc.tm_hour, utc.tm_min, utc.tm_sec,
    (long long)(unixMs % 1000));
  return String(buffer);
}
// Formata instante absoluto em UTC, se houver sincronizacao de horario.
String formatarEpochUTC(uint64_t epochMs) {
  if (epochMs < 1577836800000ULL) return "";
  time_t segundos = (time_t)(epochMs / 1000ULL);
  struct tm utc;
  gmtime_r(&segundos, &utc);
  char buffer[34];
  snprintf(buffer, sizeof(buffer), "%04d-%02d-%02dT%02d:%02d:%02dZ",
    utc.tm_year + 1900, utc.tm_mon + 1, utc.tm_mday,
    utc.tm_hour, utc.tm_min, utc.tm_sec);
  return String(buffer);
}
// Lista permanente de eventos; API incremental via ?depois=123.
void enviarAlertas() {
  if (!alertasDisponiveis) {
    servidor.send(503, "application/json", "{\"erro\":\"alertas indisponiveis\"}");
    return;
  }
  uint32_t depois = servidor.hasArg("depois") ?
      (uint32_t)strtoul(servidor.arg("depois").c_str(), nullptr, 10) : 0;
  File f = LittleFS.open(CAMINHO_ALERTAS, "r");
  if (!f) { servidor.send(500, "text/plain", "Falha em alertas.csv"); return; }
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.setContentLength(CONTENT_LENGTH_UNKNOWN);
  servidor.send(200, "application/json; charset=utf-8", "");
  String cabecalho = "{\"total\":" + String(totalAlertas) + ",\"cheio\":";
  cabecalho += alertasCheios ? "true" : "false";
  cabecalho += ",\"eventos\":[";
  servidor.sendContent(cabecalho);
  f.readStringUntil('\n');
  String bloco; bloco.reserve(1650);
  bool primeiro = true;
  while (f.available()) {
    String linha = f.readStringUntil('\n');
    if (!linha.length()) continue;
    int pos[9], n = 0;
    for (int i = 0; i < linha.length() && n < 9; i++) {
      if (linha[i] == ',') pos[n++] = i;
    }
    if (n != 9) continue;
    uint32_t id = (uint32_t)strtoul(linha.c_str(), nullptr, 10);
    if (id <= depois) continue;
    String campo[10];
    int inicio = 0;
    for (int k = 0; k < 9; k++) {
      campo[k] = linha.substring(inicio, pos[k]);
      inicio = pos[k] + 1;
    }
    campo[9] = linha.substring(inicio);
    if (!primeiro) bloco += ',';
    primeiro = false;
    bloco += jsonEvento(id, campo[1].toInt(), strtoull(campo[2].c_str(), nullptr, 10),
         strtoull(campo[3].c_str(), nullptr, 10), campo[4].toFloat(), campo[5].toFloat(),
         campo[6].toFloat(), campo[7].toInt(), campo[8].toInt(), campo[9].toInt());
    if (bloco.length() > 1200) { servidor.sendContent(bloco); bloco = ""; yield(); }
  }
  if (bloco.length()) servidor.sendContent(bloco);
  servidor.sendContent("]}");
  servidor.sendContent("");
  f.close();
}

void exportarAlertasCSV() {
  if (!alertasDisponiveis) {
    servidor.send(503, "text/plain", "Alertas indisponiveis"); return;
  }
  File f = LittleFS.open(CAMINHO_ALERTAS, "r");
  if (!f) { servidor.send(500, "text/plain", "Falha em alertas.csv"); return; }
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.sendHeader("Content-Disposition", "attachment; filename=infrared_alertas.csv");
  servidor.setContentLength(CONTENT_LENGTH_UNKNOWN);
  servidor.send(200, "text/csv; charset=utf-8", "");
  servidor.sendContent("data_hora_utc,id,sessao,tempo_ms,epoch_ms,temperatura_ambiente_c,pico_termico_c,diferenca_c,pixel_x,pixel_y,pixels_quentes\r\n");
  f.readStringUntil('\n');
  String bloco; bloco.reserve(1450);
  while (f.available()) {
    String l = f.readStringUntil('\n');
    if (!l.length()) continue;
    // Se o horario foi sincronizado depois do evento, reconstitui-o somente
    // para a sessao atual (sem inventar horario para boots anteriores).
    int a = l.indexOf(',');
    int b = l.indexOf(',', a+1);
    int c = l.indexOf(',', b+1);
    int d = l.indexOf(',', c+1);
    if (a<0 || b<0 || c<0 || d<0) continue;
    uint32_t sessao = (uint32_t)strtoul(l.c_str()+a+1, nullptr, 10);
    uint64_t uptime = strtoull(l.c_str()+b+1, nullptr, 10);
    uint64_t epoch = strtoull(l.c_str()+c+1, nullptr, 10);
    String ajustada = l.substring(0, c+1) +
        inteiro64(dataEventoMs(sessao, uptime, epoch)) + l.substring(d);
    bloco += formatarEpochUTC(dataEventoMs(sessao, uptime, epoch)) + "," + ajustada + "\r\n";
    if (bloco.length() > 1200) { servidor.sendContent(bloco); bloco = ""; yield(); }
  }
  if (bloco.length()) servidor.sendContent(bloco);
  servidor.sendContent("");
  f.close();
}

void enviarCSV() {
  if (!flashOK) { servidor.send(503, "text/plain", "Armazenamento LittleFS indisponivel"); return; }
  arquivoLog.flush();
  File file = LittleFS.open(CAMINHO_CSV, "r");
  if (!file) { servidor.send(500, "text/plain", "Nao foi possivel ler CSV"); return; }
  servidor.sendHeader("Content-Disposition", "attachment; filename=thermolab_leituras.csv");
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.setContentLength(CONTENT_LENGTH_UNKNOWN);
  servidor.send(200, "text/csv; charset=utf-8", "");
  servidor.sendContent("data_hora_utc,id,tempo_ms,temperatura_dht_c,umidade_pct,amg_media_c,amg_min_c,amg_max_c,temperatura_dht_bruta_c,umidade_bruta_pct,amg_max_bruta_c\r\n");
  file.readStringUntil('\n');
  String bloco;
  bloco.reserve(1800);
  while (file.available()) {
    String linha = file.readStringUntil('\n');
    if (!linha.length()) continue;
    int a = linha.indexOf(',');
    int b = linha.indexOf(',', a+1);
    if (a < 0 || b < 0) continue;
    uint64_t ms = strtoull(linha.c_str()+a+1, nullptr, 10);
    bloco += dataHoraUTC(ms);
    bloco += ',';
    bloco += linha;
    bloco += "\r\n";
    if (bloco.length() > 1400) {
      servidor.sendContent(bloco);
      bloco = "";
      yield();
    }
  }
  if (bloco.length()) servidor.sendContent(bloco);
  file.close();
  servidor.sendContent("");
}

void setup() {
  Serial.begin(115200);
  delay(500);
  dht.begin();
  Wire.begin(PINO_SDA, PINO_SCL);
  Wire.setClock(100000);
  iniciarAMG();
  iniciarCSV();
  iniciarAlertas();
  WiFi.mode(WIFI_AP);
  bool enderecoOK = WiFi.softAPConfig(IPAddress(192,168,4,1), IPAddress(192,168,4,1), IPAddress(255,255,255,0));
  bool wifiOK = WiFi.softAP(WIFI_NOME, WIFI_SENHA);
  Serial.printf("Wi-Fi AP: %s | IP configurado: %s\n",
                wifiOK ? "INICIADO" : "FALHOU",
                enderecoOK ? "SIM" : "NAO");
  if (wifiOK) {
    Serial.print("IP do ESP32: ");
    Serial.println(WiFi.softAPIP());
  } else {
    Serial.println("ERRO: falha ao iniciar Wi-Fi. Verifique tensao de alimentacao (VIN 5V / 3V3).");
  }
  servidor.on("/", HTTP_GET, [](){ servidor.send_P(200, "text/html; charset=utf-8", PAGINA_HTML); });
  servidor.on("/api", HTTP_GET, enviarAPI);
  servidor.on("/historico", HTTP_GET, enviarHistorico);
  servidor.on("/recentes", HTTP_GET, enviarRecentes);
  servidor.on("/csv", HTTP_GET, enviarCSV);
  servidor.on("/alertas", HTTP_GET, enviarAlertas);
  servidor.on("/alertas.csv", HTTP_GET, exportarAlertasCSV);
  servidor.on("/sincronizar", HTTP_GET, sincronizarHora);
  servidor.on("/favicon.ico", HTTP_GET, [](){servidor.send(204);});
  servidor.onNotFound([](){ servidor.send(404, "text/plain", "Nao encontrado"); });
  servidor.begin();
  uint32_t agora = millis();
  ultimoAMG = agora - INTERVALO_AMG_MS;
  ultimoDHT = agora - INTERVALO_DHT_MS;
  ultimoLog = agora - INTERVALO_LOG_MS;
  Serial.println("ThermoLab ALERTAS V1.4 GPIO27 | http://192.168.4.1 | Wi-Fi ESP32-Termico / 12345678");
}
void loop() {
  servidor.handleClient();
  uint32_t agora = millis();
  if ((uint32_t)(agora - ultimoAMG) >= INTERVALO_AMG_MS) {
    ultimoAMG = agora;
    lerAMG();
    avaliarAlertaTermico();
  }
  if ((uint32_t)(agora - ultimoDHT) >= INTERVALO_DHT_MS) {
    ultimoDHT = agora;
    lerDHT();
  }
  if (!amgOK && (uint32_t)(agora - ultimaTentativa) >= TENTATIVA_AMG_MS) iniciarAMG();
  if ((uint32_t)(agora - ultimoLog) >= INTERVALO_LOG_MS) {
    ultimoLog = agora;
    registrar();
  }
  if (flashOK && arquivoLog && (uint32_t)(agora - ultimoFlush) >= FLUSH_LOG_MS) {
    ultimoFlush = agora;
    arquivoLog.flush();
  }
}

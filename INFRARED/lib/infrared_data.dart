import 'dart:convert';
import 'package:http/http.dart' as http;

const String espAddress = 'http://192.168.4.1';
const String espSsid = 'ESP32-Termico';
const String espPassword = '12345678';

/// Estrutura EXATA retornada pela rota /api do firmware ThermoLab V2.1.
class ThermalFrame {
  const ThermalFrame({
    required this.id, required this.ms, required this.session, required this.temperature,
    required this.humidity, required this.avg, required this.min,
    required this.max, required this.hotX, required this.hotY,
    required this.pixels, required this.dhtOk, required this.amgOk,
    required this.csvFull, required this.flashOk, required this.csvBytes,
    required this.csvLimit, required this.clients,
    this.alertSupported=false, this.alertStorageOk=false, this.alertFull=false,
    this.alertArmed=false, this.alertTotal=0, this.alertPixels=0,
    this.alertFrames=0, this.alertCooldownMs=0, this.alertDelta=null,
    this.alertThreshold=1.5, this.alertState='DESCONHECIDO',
  });

  final int id, ms, session, hotX, hotY, clients, csvBytes, csvLimit;
  final double? temperature, humidity, avg, min, max;
  final List<double?> pixels;
  final bool dhtOk, amgOk, csvFull, flashOk;
  final bool alertSupported, alertStorageOk, alertFull, alertArmed;
  final int alertTotal, alertPixels, alertFrames, alertCooldownMs;
  final double? alertDelta;
  final double alertThreshold;
  final String alertState;


  factory ThermalFrame.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is num ? v.toInt() : 0;
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    return ThermalFrame(
      id: toInt(j['id']), ms: toInt(j['ms']), session: toInt(j['sessao']),
      temperature: n(j['temperatura']), humidity: n(j['umidade']),
      avg: n(j['media']), min: n(j['minima']), max: n(j['maxima']),
      hotX: j['pico_x'] is num ? (j['pico_x'] as num).toInt() : -1,
      hotY: j['pico_y'] is num ? (j['pico_y'] as num).toInt() : -1,
      pixels: (j['pixels'] is List)
          ? (j['pixels'] as List).map(n).toList(growable: false)
          : const <double?>[],
      dhtOk: j['dht_leitura_ok'] == true,
      amgOk: j['amg_leitura_ok'] == true,
      csvFull: j['log_cheio'] == true, flashOk: j['flash_ok'] == true,
      csvBytes: toInt(j['csv_bytes']), csvLimit: toInt(j['csv_limite']),
      clients: toInt(j['clientes']),
      alertSupported: j.containsKey('alertas_total'),
      alertStorageOk: j['alertas_ok'] == true,
      alertFull: j['alertas_cheios'] == true,
      alertArmed: j['alerta_armado'] == true,
      alertTotal: toInt(j['alertas_total']),
      alertPixels: toInt(j['alerta_pixels_quentes']),
      alertFrames: toInt(j['alerta_frames_confirmados']),
      alertCooldownMs: toInt(j['alerta_cooldown_restante_ms']),
      alertDelta: n(j['alerta_delta_atual_c']) ?? (
        n(j['maxima']) != null && n(j['temperatura']) != null
          ? n(j['maxima'])! - n(j['temperatura'])! : null),
      alertThreshold: n(j['alerta_delta_min_c']) ?? 1.5,
      alertState: j['alerta_estado'] is String
        ? j['alerta_estado'] as String : 'FIRMWARE_ANTIGO',

    );
  }
}

/// Cada linha do /historico vem como vetor numérico:
/// [id, ms, tempDHT, umidDHT, amgMedia, amgMin, amgMax, tempBruta, maxBruta, umidBruta]
class ThermalSample {
  const ThermalSample({required this.id, required this.ms,
    required this.temp, required this.humidity,
    required this.mean, required this.min, required this.max});
  final int id, ms;
  final double? temp, humidity, mean, min, max;
  static ThermalSample? fromList(dynamic raw) {
    if (raw is! List || raw.length < 7 || raw[0] is! num || raw[1] is! num) return null;
    double? n(int i) => raw[i] is num ? (raw[i] as num).toDouble() : null;
    return ThermalSample(id: (raw[0] as num).toInt(),
      ms: (raw[1] as num).toInt(), temp: n(2), humidity: n(3),
      mean: n(4), min: n(5), max: n(6));
  }
}

class InfraredApi {
  InfraredApi() : _client = http.Client();
  final http.Client _client;
  void close() => _client.close();

  Future<ThermalFrame> read() async {
    final response = await _client.get(Uri.parse('$espAddress/api'),
      headers: {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('pixels')) {
      throw const FormatException('Resposta inválida do ESP32');
    }
    return ThermalFrame.fromJson(decoded);
  }

  Future<List<ThermalSample>> readHistory() async {
    final response = await _client.get(Uri.parse('$espAddress/historico'),
      headers: {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return _parseSamples(response.body);
  }

  Future<List<ThermalSample>> readRecent(int lastId) async {
    final response = await _client.get(Uri.parse('$espAddress/recentes?depois=$lastId'),
      headers: {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return _parseSamples(response.body);
  }

  List<ThermalSample> _parseSamples(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic> || decoded['registros'] is! List) return [];
    return (decoded['registros'] as List)
      .map(ThermalSample.fromList).whereType<ThermalSample>().toList();
  }

  Future<void> setClock() async {
    try {
      await _client.get(Uri.parse('$espAddress/sincronizar?epoch=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 3));
    } catch (_) { /* Nao impede as leituras. */ }
  }

  Future<List<ThermalAlert>> readAlerts({int afterId = 0}) async {
    final res=await _client.get(Uri.parse('$espAddress/alertas?depois=$afterId'),
      headers:{'Cache-Control':'no-cache'}).timeout(const Duration(seconds:12));
    if(res.statusCode != 200) throw Exception('Alertas indisponiveis: HTTP ${res.statusCode}');
    final decoded=jsonDecode(res.body);
    if(decoded is! Map || decoded['eventos'] is! List) return [];
    return (decoded['eventos'] as List)
      .whereType<Map<String,dynamic>>()
      .map(ThermalAlert.fromJson).toList(growable:false);
  }

  Future<List<int>> getAlertsCsv() async {
    final response=await _client.get(Uri.parse('$espAddress/alertas.csv'))
      .timeout(const Duration(seconds:40));
    if(response.statusCode!=200) throw Exception('CSV de alertas indisponivel');
    return response.bodyBytes;
  }

  Future<List<int>> getCsv() async {
    final response = await _client.get(Uri.parse('$espAddress/csv'))
      .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) throw Exception('CSV indisponível (HTTP ${response.statusCode})');
    return response.bodyBytes;
  }
}


/// Alerta persistido no ESP32. A data pode estar ausente se o horario nao
/// tinha sido sincronizado; o tempo de boot sempre existe.
class ThermalAlert {
  const ThermalAlert({required this.id, required this.session, required this.ms,
    required this.epochMs, required this.ambient, required this.peak,
    required this.delta, required this.x, required this.y, required this.hotPixels});
  final int id, session, ms, epochMs, x, y, hotPixels;
  final double ambient, peak, delta;

  factory ThermalAlert.fromJson(Map<String, dynamic> j) {
    int i(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    double d(String k) => j[k] is num ? (j[k] as num).toDouble() : 0;
    return ThermalAlert(id:i('id'),session:i('sessao'),ms:i('tempo_ms'),
      epochMs:i('epoch_ms'),ambient:d('ambiente_c'),peak:d('pico_c'),
      delta:d('delta_c'),x:i('pixel_x'),y:i('pixel_y'),hotPixels:i('pixels_quentes'));
  }
  DateTime? get localTime => epochMs > 1577836800000
      ? DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal() : null;
}

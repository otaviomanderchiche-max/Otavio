import 'dart:convert';
import 'package:http/http.dart' as http;

const String espAddress = 'http://192.168.4.1';
const String espSsid = 'ESP32-Termico';
const String espPassword = '12345678';

/// Estrutura EXATA retornada pela rota /api do firmware ThermoLab V2.1.
class ThermalFrame {
  const ThermalFrame({
    required this.id, required this.ms, required this.temperature,
    required this.humidity, required this.avg, required this.min,
    required this.max, required this.hotX, required this.hotY,
    required this.pixels, required this.dhtOk, required this.amgOk,
    required this.csvFull, required this.flashOk, required this.csvBytes,
    required this.csvLimit, required this.clients,
  });

  final int id, ms, hotX, hotY, clients, csvBytes, csvLimit;
  final double? temperature, humidity, avg, min, max;
  final List<double?> pixels;
  final bool dhtOk, amgOk, csvFull, flashOk;

  factory ThermalFrame.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is num ? v.toInt() : 0;
    double? n(dynamic v) => v is num ? v.toDouble() : null;
    return ThermalFrame(
      id: toInt(j['id']), ms: toInt(j['ms']),
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

  Future<List<int>> getCsv() async {
    final response = await _client.get(Uri.parse('$espAddress/csv'))
      .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) throw Exception('CSV indisponível (HTTP ${response.statusCode})');
    return response.bodyBytes;
  }
}

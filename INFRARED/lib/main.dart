import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'infrared_data.dart';
import 'esp_wifi_connector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InfraredApp());
}

class C {
  static const bg = Color(0xFF070C14);
  static const surface = Color(0xFF111A27);
  static const surface2 = Color(0xFF162335);
  static const border = Color(0xFF253348);
  static const text = Color(0xFFF1F6FF);
  static const muted = Color(0xFF90A2B8);
  static const cyan = Color(0xFF48E0DC);
  static const blue = Color(0xFF5E94F5);
  static const purple = Color(0xFFA895F9);
  static const orange = Color(0xFFFFAD68);
  static const red = Color(0xFFFC6D68);
  static const green = Color(0xFF63DFA5);
}

class InfraredApp extends StatelessWidget {
  const InfraredApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INFRARED', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg, colorSchemeSeed: C.cyan,
        fontFamily: 'Roboto',
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const InfraredHome()));
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: RadialGradient(
        center: Alignment(0, -0.15), radius: 1.15,
        colors: [Color(0xFF173044), C.bg],
      )),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BrandMark(size: 92), const SizedBox(height: 26),
        const Text('INFRARED', style: TextStyle(fontSize: 35,
          fontWeight: FontWeight.w900, letterSpacing: 6, color: C.text)),
        const SizedBox(height: 8),
        const Text('INTELLIGENT THERMAL MONITOR', style: TextStyle(
          color: C.muted, letterSpacing: 2.3, fontSize: 10)),
        const SizedBox(height: 42),
        SizedBox(width: 74, child: LinearProgressIndicator(
          minHeight: 2, backgroundColor: C.border,
          color: C.cyan, borderRadius: BorderRadius.circular(3))),
      ])),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .29),
      gradient: const LinearGradient(begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF255C6D), Color(0xFF1C283D)]),
      border: Border.all(color: C.cyan.withValues(alpha: .5)),
      boxShadow: [BoxShadow(color: C.cyan.withValues(alpha: .12), blurRadius: 32)],
    ),
    child: Icon(Icons.sensors_rounded, size: size * .52, color: C.cyan),
  );
}

class InfraredHome extends StatefulWidget {
  const InfraredHome({super.key});
  @override
  State<InfraredHome> createState() => _InfraredHomeState();
}

class _InfraredHomeState extends State<InfraredHome> with WidgetsBindingObserver {
  final InfraredApi _api = InfraredApi();
  Timer? _refreshTimer;
  Timer? _historyTimer;
  ThermalFrame? _frame;
  List<ThermalSample> _history = [];
  bool _connected = false;
  bool _connecting = false;
  bool _polling = false;
  bool _historyLoading = false;
  bool _exporting = false;
  int _failures = 0;
  int _tab = 0;
  int _rangeMin = 0;
  int _pixel = -1;
  String _status = 'Toque em Conectar para iniciar';
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Se o aparelho ja esta na rede do ESP32, abre o painel sozinho.
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeExisting());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_connected) { _poll(); _syncRecent(); }
      else if (!_connecting) { _probeExisting(); }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel(); _historyTimer?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _probeExisting() async {
    if (_connecting || _connected) return;
    try {
      final frame = await _api.read();
      if (mounted) await _onConnected(frame);
    } catch (_) { /* Sem ESP na rede: exibir Conectar. */ }
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() { _connecting = true; _status = 'Procurando ESP32...'; });
    try {
      // Primeiro tenta a API, inclusive quando a rede ja foi selecionada manualmente.
      try {
        final existing = await _api.read();
        if (mounted) await _onConnected(existing);
        return;
      } catch (_) {}
      setState(() => _status = 'Solicitando conexão ao Wi-Fi $espSsid...');
      await EspWifiConnector.connect();
      setState(() => _status = 'Rede solicitada. Verificando comunicação com o ESP32...');
      for (var retry = 0; retry < 20; retry++) {
        if (!mounted) return;
        try {
          final frame = await _api.read();
          await _onConnected(frame);
          return;
        } catch (_) { await Future<void>.delayed(const Duration(seconds: 1)); }
      }
      throw Exception('Wi-Fi conectado, mas o ESP32 não respondeu em 192.168.4.1.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '${_message(e)}\nSe precisar, conecte manualmente em $espSsid e toque novamente.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _onConnected(ThermalFrame frame) async {
    if (!mounted) return;
    _refreshTimer?.cancel(); _historyTimer?.cancel();
    setState(() {
      _connected = true; _connecting = false; _frame = frame;
      _status = 'Conectado ao ESP32'; _failures = 0;
      _lastUpdate = DateTime.now();
    });
    _api.setClock(); // Sincroniza a hora do computador/celular, sem bloquear o painel.
    _loadHistory();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => _poll());
    _historyTimer = Timer.periodic(const Duration(seconds: 3), (_) => _syncRecent());
  }

  Future<void> _poll() async {
    if (!_connected || _polling) return;
    _polling = true;
    try {
      final next = await _api.read();
      if (!mounted) return;
      // Reinicializacao do ESP32: os ids e o historico voltam ao inicio.
      if (_frame != null && next.ms < _frame!.ms) _loadHistory();
      setState(() {
        _frame = next;
        _lastUpdate = DateTime.now();
        _failures = 0;
        _status = 'Conectado ao ESP32';
      });
    } catch (_) {
      _failures++;
      if (!mounted) return;
      if (_failures >= 5) {
        setState(() => _status = 'Sinal perdido. Tentando reconectar automaticamente...');
      }
    } finally { _polling = false; }
  }

  Future<void> _loadHistory() async {
    if (_historyLoading || !_connected) return;
    _historyLoading = true;
    try {
      final result = await _api.readHistory();
      if (mounted) setState(() => _history = result);
    } catch (_) { /* API de tempo real continua funcionando. */ }
    finally { _historyLoading = false; }
  }

  Future<void> _syncRecent() async {
    if (!_connected || _historyLoading) return;
    try {
      final next = await _api.readRecent(_history.isEmpty ? 0 : _history.last.id);
      if (!mounted || next.isEmpty) return;
      if (_history.isNotEmpty && next.first.id < _history.last.id) {
        await _loadHistory(); return;
      }
      setState(() {
        final known = _history.isEmpty ? 0 : _history.last.id;
        _history.addAll(next.where((s) => s.id > known));
        // Diminui a densidade, mas preserva sempre o comeco e o fim
        // da sessao, permitindo visualizar "Desde o inicio" por horas.
        if (_history.length > 4500) {
          final reduced = <ThermalSample>[];
          for (var i = 0; i < _history.length; i += 2) {
            reduced.add(_history[i]);
          }
          if (reduced.last.id != _history.last.id) reduced.add(_history.last);
          _history = reduced;
        }
      });
    } catch (_) { /* Pode estar indisponivel durante reinicializacao. */ }
  }

  Future<void> _exportCsv() async {
    if (!_connected || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _api.getCsv();
      final filename = 'INFRARED_${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv';
      if (Platform.isWindows) {
        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) _toast('CSV salvo em: ${file.path}');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Leituras do INFRARED',
          text: 'Histórico de medições do ESP32',
        ));
      }
    } catch (e) {
      if (mounted) _toast('Não foi possível exportar: ${_message(e)}');
    } finally { if (mounted) setState(() => _exporting = false); }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text), backgroundColor: C.surface2));
  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final desktop = _connected && Platform.isWindows && box.maxWidth >= 950;
      return Scaffold(
        body: SafeArea(child: desktop
          ? Row(children: [
              _desktopNavigation(),
              Expanded(child: _dashboard()),
            ])
          : (_connected ? _dashboard() : _connectionPage())),
        bottomNavigationBar: _connected && !desktop ? _bottomNav() : null,
      );
    });
  }

  Widget _connectionPage() => Container(
    decoration: const BoxDecoration(gradient: RadialGradient(
      center: Alignment(.8, -.4), radius: 1.5,
      colors: [Color(0xFF142D42), C.bg])),
    child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(26),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 30),
          const BrandMark(size: 80), const SizedBox(height: 24),
          const Text('INFRARED', style: TextStyle(fontSize: 37,
            letterSpacing: 5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text('CONTROLE E MONITORAMENTO TÉRMICO',
            textAlign: TextAlign.center, style: TextStyle(
            color: C.muted, fontSize: 10, letterSpacing: 1.6)),
          const SizedBox(height: 54),
          Panel(child: Column(children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: C.cyan.withValues(alpha: .1)),
              child: const Icon(Icons.wifi_tethering, color: C.cyan, size: 27)),
            const SizedBox(height: 15),
            const Text('Conecte seu ESP32', style: TextStyle(fontSize: 21,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Entre na rede do dispositivo e visualize os sensores em tempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.muted, height: 1.45, fontSize: 13)),
            const SizedBox(height: 18),
            Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(color: C.bg,
                border: Border.all(color: C.border), borderRadius: BorderRadius.circular(13)),
              child: const Row(children: [
                Icon(Icons.wifi, color: C.cyan, size: 20), SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(espSsid, style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('ESP32 · 192.168.4.1', style: TextStyle(color: C.muted, fontSize: 11)),
                ])),
                Icon(Icons.lock_outline, size: 16, color: C.muted),
              ])),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 54,
              child: FilledButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: _connecting ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.power_settings_new),
                label: Text(_connecting ? 'CONECTANDO...' : 'CONECTAR',
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                style: FilledButton.styleFrom(
                  backgroundColor: C.cyan, foregroundColor: C.bg,
                  disabledBackgroundColor: C.cyan.withValues(alpha: .55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              )),
            const SizedBox(height: 13),
            Text(_status, textAlign: TextAlign.center,
              style: const TextStyle(color: C.muted, fontSize: 12, height: 1.5)),
          ])),
          const SizedBox(height: 22),
          Text(Platform.isWindows
              ? 'Mantenha o Wi-Fi do computador ativado. O aplicativo pode solicitar acesso à rede do ESP32.'
              : 'Se o Android pedir autorização para conectar ao Wi-Fi, confirme.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 34),
          Text('INFRARED  /  V1.1  ·  ${Platform.isWindows ? 'WINDOWS' : 'ANDROID'}', style: TextStyle(color: C.muted,
            fontSize: 10, letterSpacing: 2)),
        ])),
    )),
  );

  Widget _dashboard() => LayoutBuilder(builder: (context, constraints) =>
    RefreshIndicator(color: C.cyan, onRefresh: () async {
      await _poll(); await _loadHistory();
    }, child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _topBar(), const SizedBox(height: 28),
            if (_tab == 0) _overview(),
            if (_tab == 1) _chartsPage(),
            if (_tab == 2) _systemPage(),
          ])),
      ))),
    ])),
  );

  Widget _topBar() => Row(children: [
    const BrandMark(size: 43), const SizedBox(width: 12),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INFRARED', style: TextStyle(fontSize: 20, letterSpacing: 2.5,
        fontWeight: FontWeight.w900)),
      SizedBox(height: 2),
      Text('LIVE MONITOR', style: TextStyle(
        color: C.muted, letterSpacing: 2, fontSize: 9)),
    ])),
    Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99),
        color: (_failures < 5 ? C.green : C.orange).withValues(alpha: .1),
        border: Border.all(color: (_failures < 5 ? C.green : C.orange).withValues(alpha: .35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 4, backgroundColor: _failures < 5 ? C.green : C.orange),
        const SizedBox(width: 8),
        Text(_failures < 5 ? 'AO VIVO' : 'SEM SINAL',
          style: TextStyle(color: _failures < 5 ? C.green : C.orange,
            fontSize: 10, fontWeight: FontWeight.w900)),
      ])),
  ]);

  Widget _overview() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Painel térmico', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 5),
    Text('Dados do ESP32 em tempo real · ${_status}',
      style: const TextStyle(color: C.muted, fontSize: 12)),
    const SizedBox(height: 20),
    LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 610;
      return GridView.count(
        crossAxisCount: wide ? 4 : 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        childAspectRatio: wide ? 1.50 : 1.38,
        children: [
          MetricCard('TEMPERATURA', fmt(_frame?.temperature, '°C'),
            'DHT11 · ambiente', Icons.thermostat, C.cyan),
          MetricCard('UMIDADE', fmt(_frame?.humidity, '%'),
            'DHT11 · relativa', Icons.water_drop_outlined, C.blue),
          MetricCard('TÉRMICA MÁX.', fmt(_frame?.max, '°C'),
            'AMG8833 · pico', Icons.local_fire_department_outlined, C.orange),
          MetricCard('TÉRMICA MÉDIA', fmt(_frame?.avg, '°C'),
            'AMG8833 · 64 pixels', Icons.grid_view_rounded, C.purple),
        ],
      );
    }),
    const SizedBox(height: 18),
    ThermalMap(frame: _frame, pixel: _pixel,
      onTap: (p) => setState(() => _pixel = p)),
    const SizedBox(height: 18),
    _graphPanel(mini: true),
    const SizedBox(height: 12),
    _footerInfo(),
  ]);

  Widget _chartsPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Histórico', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Dados recuperados do início da sessão no ESP32.',
      style: TextStyle(color: C.muted, fontSize: 12)),
    const SizedBox(height: 20),
    _rangePicker(),
    const SizedBox(height: 14),
    _graphPanel(),
    const SizedBox(height: 14),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Umidade relativa', Icons.water_drop_outlined, C.blue),
      const SizedBox(height: 12),
      SizedBox(height: 190, child: HistoryChart(
        samples: _filteredSamples(), series: const [ChartLine('Umidade', C.blue, ChartField.humidity)],
        unit: '%')),
    ])),
    const SizedBox(height: 18),
    _downloadButton(),
  ]);

  Widget _systemPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Dispositivo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 18),
    Panel(child: Column(children: [
      _systemRow('Rede Wi-Fi', espSsid, Icons.wifi),
      _systemRow('Endereço do ESP32', '192.168.4.1', Icons.router_outlined),
      _systemRow('DHT11', _frame?.dhtOk == true ? 'Operando' : 'Sem leitura', Icons.thermostat),
      _systemRow('AMG8833', _frame?.amgOk == true ? 'Operando' : 'Sem leitura', Icons.grid_view_outlined),
      _systemRow('Tempo desde o boot', clock(_frame?.ms ?? 0), Icons.timer_outlined),
      _systemRow('Registros (ESP32)', '${_frame?.id ?? 0}', Icons.storage),
      _systemRow('Dispositivos no AP', '${_frame?.clients ?? 0}', Icons.devices),
      _systemRow('CSV', _frame?.flashOk == true
        ? (_frame?.csvFull == true ? 'Cheio — exporte agora' : 'Ativo')
        : 'LittleFS indisponível', Icons.save_alt),
    ])),
    const SizedBox(height: 12),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ARMAZENAMENTO', style: TextStyle(color: C.muted, fontSize: 10,
        letterSpacing: 1.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      LinearProgressIndicator(minHeight: 9, borderRadius: BorderRadius.circular(10),
        value: (_frame?.csvLimit ?? 0) > 0
          ? (_frame!.csvBytes / _frame!.csvLimit).clamp(0, 1).toDouble() : 0,
        backgroundColor: C.border, valueColor: const AlwaysStoppedAnimation(C.cyan)),
      const SizedBox(height: 9),
      Text('${((_frame?.csvBytes ?? 0)/1024).toStringAsFixed(0)} KB usados de '
        '${((_frame?.csvLimit ?? 0)/1024).toStringAsFixed(0)} KB',
        style: const TextStyle(color: C.muted, fontSize: 12)),
    ])),
    const SizedBox(height: 14),
    _downloadButton(),
    const SizedBox(height: 24),
    Center(child: OutlinedButton.icon(onPressed: () {
      _refreshTimer?.cancel(); _historyTimer?.cancel();
      setState(() { _connected = false; _frame = null; _history = []; _status = 'Pronto para conectar'; });
    }, icon: const Icon(Icons.link_off), label: const Text('Voltar à conexão'))),
  ]);

  Widget _systemRow(String title, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: C.muted, size: 17), const SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(color: C.muted, fontSize: 12))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _downloadButton() => SizedBox(width: double.infinity, height: 53,
    child: OutlinedButton.icon(
      onPressed: _exporting ? null : _exportCsv,
      icon: _exporting ? const SizedBox(width: 17, height: 17,
        child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download_rounded),
      label: Text(_exporting ? 'PREPARANDO CSV...' : 'EXPORTAR LEITURAS CSV',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .9)),
      style: OutlinedButton.styleFrom(foregroundColor: C.cyan,
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
    ));

  Widget _rangePicker() => Wrap(spacing: 7, runSpacing: 8,
    children: [
      for (final r in const [(1, '1 min'), (5, '5 min'), (15, '15 min'), (0, 'Desde o início')])
        InkWell(borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _rangeMin = r.$1),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              color: _rangeMin == r.$1 ? C.cyan.withValues(alpha: .13) : C.surface,
              border: Border.all(color: _rangeMin == r.$1 ? C.cyan : C.border)),
            child: Text(r.$2, style: TextStyle(fontSize: 11,
              color: _rangeMin == r.$1 ? C.cyan : C.muted,
              fontWeight: FontWeight.w700)))),
    ]);

  List<ThermalSample> _filteredSamples() {
    if (_rangeMin == 0 || _history.isEmpty) return _history;
    final last = _frame?.ms ?? _history.last.ms;
    final cutoff = last - _rangeMin * 60000;
    return _history.where((s) => s.ms >= cutoff).toList();
  }

  Widget _graphPanel({bool mini = false}) => Panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: SectionTitle('Evolução térmica', Icons.show_chart, C.cyan)),
        if (mini) InkWell(onTap: () => setState(() => _tab = 1),
          child: const Text('VER TUDO →', style: TextStyle(
            color: C.cyan, fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 16),
      SizedBox(height: mini ? 176 : 246, child: HistoryChart(
        samples: _filteredSamples(), unit: '°C',
        series: const [
          ChartLine('DHT11', C.cyan, ChartField.temp),
          ChartLine('AMG média', C.purple, ChartField.mean),
          ChartLine('AMG máxima', C.orange, ChartField.max),
        ])),
      const SizedBox(height: 10),
      const Wrap(spacing: 15, runSpacing: 8, children: [
        LegendDot('Ambiente', C.cyan), LegendDot('Térmica média', C.purple),
        LegendDot('Térmica máxima', C.orange),
      ]),
      if (!mini) ...[
        const SizedBox(height: 10),
        Text('${_filteredSamples().length} pontos exibidos · tempo desde que o ESP32 ligou',
          style: const TextStyle(color: C.muted, fontSize: 11)),
      ],
    ]));

  Widget _footerInfo() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text('Atualizado: ${_lastUpdate == null ? '--' : TimeOfDay.fromDateTime(_lastUpdate!).format(context)}',
      style: const TextStyle(color: C.muted, fontSize: 10)),
    Text('ESP32 · ${clock(_frame?.ms ?? 0)}',
      style: const TextStyle(color: C.muted, fontSize: 10)),
  ]);

  Widget _desktopNavigation() => Container(
    width: 225,
    decoration: const BoxDecoration(color: C.surface,
      border: Border(right: BorderSide(color: C.border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.fromLTRB(22, 28, 14, 30), child: Row(children: [
        BrandMark(size: 42), SizedBox(width: 12),
        Text('INFRARED', style: TextStyle(fontWeight: FontWeight.w900,
          letterSpacing: 1.7, fontSize: 17)),
      ])),
      _desktopNavItem(0, 'Painel', Icons.dashboard_outlined),
      _desktopNavItem(1, 'Gráficos', Icons.query_stats_outlined),
      _desktopNavItem(2, 'Dispositivo', Icons.settings_input_antenna_outlined),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(19), child: Text(
        'ESP32-Termico\n192.168.4.1',
        style: TextStyle(fontSize: 11, color: C.muted, height: 1.7))),
    ]),
  );

  Widget _desktopNavItem(int index, String label, IconData icon) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        selected: _tab == index,
        selectedTileColor: C.cyan.withValues(alpha: .11),
        selectedColor: C.cyan,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon), title: Text(label),
        onTap: () => setState(() => _tab = index),
      ));

  Widget _bottomNav() => Container(
    decoration: const BoxDecoration(color: C.surface,
      border: Border(top: BorderSide(color: C.border))),
    child: NavigationBar(height: 67, backgroundColor: C.surface,
      indicatorColor: C.cyan.withValues(alpha: .12),
      selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded, color: C.cyan), label: 'Painel'),
        NavigationDestination(icon: Icon(Icons.query_stats_outlined),
          selectedIcon: Icon(Icons.query_stats, color: C.cyan), label: 'Gráficos'),
        NavigationDestination(icon: Icon(Icons.settings_input_antenna_outlined),
          selectedIcon: Icon(Icons.settings_input_antenna, color: C.cyan), label: 'Dispositivo'),
      ]),
  );
}

String fmt(double? value, String unit) => value == null || !value.isFinite
  ? '-- $unit' : '${value.toStringAsFixed(1).replaceAll('.', ',')} $unit';
String clock(int ms) {
  final s = (ms / 1000).floor();
  return '${(s ~/ 3600).toString().padLeft(2, '0')}:${((s ~/ 60) % 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: C.surface,
      borderRadius: BorderRadius.circular(19), border: Border.all(color: C.border)),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.icon, this.color, {super.key});
  final String title; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 18), const SizedBox(width: 9),
    Flexible(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
  ]);
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.subtitle, this.icon, this.color, {super.key});
  final String label, value, subtitle;
  final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: C.surface,
      borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: C.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .65))),
        Icon(icon, color: color, size: 18),
      ]),
      const Spacer(),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(value, style: TextStyle(color: color,
          fontSize: 24, fontWeight: FontWeight.w900))),
      const SizedBox(height: 3),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: C.muted, fontSize: 10)),
    ]),
  );
}

Color thermalColor(double? temp) {
  if (temp == null || !temp.isFinite) return const Color(0xFF283342);
  final t = ((temp - 18) / 27).clamp(0.0, 1.0);
  const stops = <Color>[
    Color(0xFF2F5A9D), Color(0xFF5AA9C2), Color(0xFFB6CE8C),
    Color(0xFFF3C05C), Color(0xFFEB7437), Color(0xFFE93B35),
  ];
  final n = t * (stops.length - 1);
  final i = n.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], n - i)!;
}

class ThermalMap extends StatelessWidget {
  const ThermalMap({super.key, required this.frame, required this.pixel, required this.onTap});
  final ThermalFrame? frame;
  final int pixel;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final px = frame?.pixels ?? [];
    final index = pixel >= 0 ? pixel : ((frame?.hotY ?? -1) * 8 + (frame?.hotX ?? -1));
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Câmera infravermelha', Icons.grid_on, C.orange),
      const SizedBox(height: 4),
      const Text('AMG8833 · mapa térmico 8 × 8',
        style: TextStyle(fontSize: 11, color: C.muted)),
      const SizedBox(height: 17),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390),
        child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8, mainAxisSpacing: 3, crossAxisSpacing: 3),
          itemCount: 64, itemBuilder: (context, i) {
            final t = i < px.length ? px[i] : null;
            return GestureDetector(onTap: () => onTap(i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: thermalColor(t),
                  borderRadius: BorderRadius.circular(5),
                  border: i == index ? Border.all(color: Colors.white, width: 2.5) : null),
                child: Text(t == null ? '–' : t.toStringAsFixed(0),
                  style: const TextStyle(color: Color(0xFF101B2A),
                    fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            );
          }),
        ))),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('18 °C', style: TextStyle(fontSize: 11, color: C.muted)),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(height: 8, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(colors: [
              Color(0xFF2F5A9D), Color(0xFF5AA9C2), Color(0xFFB6CE8C),
              Color(0xFFF3C05C), Color(0xFFEB7437), Color(0xFFE93B35),
            ]))))),
        const Text('45 °C', style: TextStyle(fontSize: 11, color: C.muted)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _smallStatistic('MÍNIMA', fmt(frame?.min, '°C'), C.blue)),
        Expanded(child: _smallStatistic('MÁXIMA', fmt(frame?.max, '°C'), C.orange)),
        Expanded(child: _smallStatistic('PIXEL', index >= 0 && index < 64
          ? 'X${index % 8} / Y${index ~/ 8}' : '--', C.cyan)),
      ]),
      if (index >= 0 && index < px.length) ...[
        const SizedBox(height: 11),
        Text('Ponto selecionado: ${fmt(px[index], '°C')}',
          style: const TextStyle(color: C.muted, fontSize: 11)),
      ],
    ]));
  }
  Widget _smallStatistic(String label, String value, Color color) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: C.muted,
        letterSpacing: .7, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      FittedBox(child: Text(value, style: TextStyle(color: color,
        fontSize: 17, fontWeight: FontWeight.w800))),
    ]);
}

enum ChartField { temp, humidity, mean, min, max }
class ChartLine {
  const ChartLine(this.name, this.color, this.field);
  final String name; final Color color; final ChartField field;
  double? value(ThermalSample s) => switch (field) {
    ChartField.temp => s.temp,
    ChartField.humidity => s.humidity,
    ChartField.mean => s.mean,
    ChartField.min => s.min,
    ChartField.max => s.max,
  };
}
class LegendDot extends StatelessWidget {
  const LegendDot(this.title, this.color, {super.key});
  final String title; final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [CircleAvatar(radius: 3, backgroundColor: color),
      const SizedBox(width: 5),
      Text(title, style: const TextStyle(fontSize: 10, color: C.muted))]);
}

class HistoryChart extends StatefulWidget {
  const HistoryChart({super.key, required this.samples, required this.series, required this.unit});
  final List<ThermalSample> samples;
  final List<ChartLine> series;
  final String unit;
  @override
  State<HistoryChart> createState() => _HistoryChartState();
}
class _HistoryChartState extends State<HistoryChart> {
  int? _selectedMs;
  @override
  Widget build(BuildContext context) {
    if (widget.samples.length < 2) return const Center(child: Text(
      'Aguardando histórico de medições...',
      style: TextStyle(color: C.muted, fontSize: 12)));
    final samples = widget.samples;
    ThermalSample? picked;
    if (_selectedMs != null) {
      var diff = 1 << 62;
      for (final s in samples) {
        final delta = (s.ms - _selectedMs!).abs();
        if (delta < diff) { diff = delta; picked = s; }
      }
    }
    return Column(children: [
      if (picked != null) Padding(padding: const EdgeInsets.only(bottom: 6),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            Text(clock(picked.ms), style: const TextStyle(color: C.muted, fontSize: 10)),
            for (final line in widget.series)
              Padding(padding: const EdgeInsets.only(left: 10),
                child: Text('${line.name}: ${fmt(line.value(picked!), widget.unit)}',
                  style: TextStyle(color: line.color, fontSize: 10))),
          ]))),
      Expanded(child: LayoutBuilder(builder: (context, constraints) =>
        GestureDetector(behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _select(d.localPosition.dx, constraints.maxWidth, samples),
          onPanUpdate: (d) => _select(d.localPosition.dx, constraints.maxWidth, samples),
          child: CustomPaint(size: Size.infinite,
            painter: PlotPainter(samples: samples, series: widget.series,
              unit: widget.unit, pickedMs: picked?.ms)),
        ))),
    ]);
  }
  void _select(double dx, double width, List<ThermalSample> ss) {
    const left = 43.0, right = 7.0;
    final factor = ((dx - left) / math.max(1, width - left - right)).clamp(0.0, 1.0);
    final wanted = ss.first.ms + ((ss.last.ms - ss.first.ms) * factor).round();
    setState(() => _selectedMs = wanted);
  }
}

class PlotPainter extends CustomPainter {
  PlotPainter({required this.samples, required this.series,
    required this.unit, required this.pickedMs});
  final List<ThermalSample> samples;
  final List<ChartLine> series;
  final String unit;
  final int? pickedMs;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 43.0, r = 7.0, t = 9.0, b = 25.0;
    if (size.width <= l + r || size.height <= t + b || samples.length < 2) return;
    final w = size.width - l - r, h = size.height - t - b;
    final values = <double>[];
    for (final s in samples) {
      for (final line in series) {
        final v = line.value(s);
        if (v != null && v.isFinite) values.add(v);
      }
    }
    if (values.isEmpty) return;
    var minV = values.reduce(math.min), maxV = values.reduce(math.max);
    final pad = math.max(1.2, (maxV - minV) * .16);
    minV -= pad; maxV += pad;
    final first = samples.first.ms;
    final duration = math.max(1, samples.last.ms - first);
    double x(ThermalSample s) => l + (s.ms - first) / duration * w;
    double y(double v) => t + (maxV - v) / (maxV - minV) * h;
    final grid = Paint()..color = C.border..strokeWidth = .7;
    for (var k = 0; k <= 4; k++) {
      final gy = t + h * k / 4;
      canvas.drawLine(Offset(l, gy), Offset(l + w, gy), grid);
      _label(canvas, (maxV - (maxV - minV) * k / 4).toStringAsFixed(0),
        Offset(1, gy - 7), C.muted);
    }
    for (var k = 0; k <= 3; k++) {
      final gx = l + w * k / 3;
      if (k > 0 && k < 3) canvas.drawLine(Offset(gx, t), Offset(gx, t + h), grid);
      final ms = first + duration * k ~/ 3;
      _label(canvas, '${(ms / 60000).toStringAsFixed(1)}m',
        Offset(gx - 11, t + h + 7), C.muted);
    }
    for (final line in series) {
      final paint = Paint()..color = line.color..strokeWidth = 2.2
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round..isAntiAlias = true;
      final path = Path();
      var started = false;
      for (final sample in samples) {
        final v = line.value(sample);
        if (v == null || !v.isFinite) { started = false; continue; }
        if (!started) { path.moveTo(x(sample), y(v)); started = true; }
        else { path.lineTo(x(sample), y(v)); }
      }
      canvas.drawPath(path, paint);
    }
    if (pickedMs != null) {
      final gx = l + ((pickedMs! - first) / duration).clamp(0.0, 1.0) * w;
      canvas.drawLine(Offset(gx, t), Offset(gx, t + h),
        Paint()..color = C.text.withValues(alpha: .5)..strokeWidth = 1);
    }
  }
  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text,
        style: TextStyle(fontSize: 10, color: color)),
      textDirection: TextDirection.ltr);
    painter.layout(); painter.paint(canvas, at);
  }
  @override
  bool shouldRepaint(covariant PlotPainter old) => true;
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

const espSsid = 'EcoMonitor-ESP32';
const espAddress = 'http://192.168.4.1';
const ecoGreen = Color(0xFF087D40);
const ecoDark = Color(0xFF0A2C1C);
const canvasColor = Color(0xFFF4F7F5);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EcoMonitorApp());
}

class EcoMonitorApp extends StatelessWidget {
  const EcoMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoMonitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: ecoGreen),
        scaffoldBackgroundColor: canvasColor,
        fontFamily: 'Roboto',
      ),
      home: const EcoHome(),
    );
  }
}

class EcoWifiNetwork {
  final String ssid;
  final int rssi;
  final bool isEco;
  final bool secured;

  EcoWifiNetwork.fromMap(Map<dynamic, dynamic> map)
      : ssid = (map['ssid'] ?? '').toString(),
        rssi = (map['rssi'] as num?)?.toInt() ?? -100,
        isEco = map['isEcoMonitor'] == true,
        secured = map['secured'] == true;
}

class EcoHome extends StatefulWidget {
  const EcoHome({super.key});

  @override
  State<EcoHome> createState() => _EcoHomeState();
}

class _EcoHomeState extends State<EcoHome> {
  static const _wifi = MethodChannel('ecomonitor/wifi');
  final List<EcoWifiNetwork> _networks = [];
  WebViewController? _webController;
  bool _scanning = false;
  bool _connecting = false;
  bool _showPanel = false;
  bool _loadingPage = false;
  bool _wifiEnabled = true;
  bool _locationEnabled = true;
  String _currentSsid = '';
  String? _error;
  String _message = 'Procurando o seu EcoMonitor…';

  @override
  void initState() {
    super.initState();
    _wifi.setMethodCallHandler((call) async {
      if (call.method == 'wifiLost' && mounted) {
        setState(() {
          _showPanel = false;
          _webController = null;
          _error = 'A conexão com o ESP32 foi interrompida.';
        });
        await _scanNetworks();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await _status();
    if (!mounted) return;
    try {
      // Se o telefone já estiver no Wi-Fi do ESP32, entra direto no painel.
      final bound = await _wifi.invokeMethod<bool>('bindExisting') ?? false;
      if (bound) {
        await _launchWebPanel();
        return;
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
    await _scanNetworks();
  }

  Future<void> _status() async {
    try {
      final result = await _wifi.invokeMapMethod<String, dynamic>('getStatus');
      if (!mounted || result == null) return;
      setState(() {
        _wifiEnabled = result['wifiEnabled'] == true;
        _locationEnabled = result['locationEnabled'] == true;
        _currentSsid = (result['ssid'] ?? '').toString();
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  Future<void> _scanNetworks() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
      _message = 'Pesquisando redes Wi-Fi próximas…';
    });
    await _status();
    try {
      final found = await _wifi.invokeListMethod<dynamic>('scanNetworks') ?? [];
      final networks = found
          .whereType<Map>()
          .map((entry) => EcoWifiNetwork.fromMap(entry))
          .toList();
      if (!mounted) return;
      setState(() {
        _networks
          ..clear()
          ..addAll(networks);
        _message = networks.any((n) => n.isEco)
            ? 'Seu ESP32 está ao alcance.'
            : 'Não encontramos o ESP32. Verifique se ele está ligado.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Erro ao pesquisar Wi-Fi.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível pesquisar redes: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
      _message = 'Confirme a conexão na janela do Android…';
    });
    try {
      // No Android 10+, o sistema mostra uma autorização oficial do Wi-Fi.
      final ok = await _wifi.invokeMethod<bool>('connect') ?? false;
      if (!ok) throw StateError('O Android não autorizou a conexão.');
      if (!mounted) return;
      setState(() => _message = 'ESP32 conectado. Abrindo painel…');
      await _launchWebPanel();
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Falha na conexão: ${e.code}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Falha na conexão: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _launchWebPanel() async {
    // Primeiro testa o servidor real; evita mostrar tela branca/Chrome externo.
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
    try {
      final request = await client.getUrl(Uri.parse('$espAddress/api/status'))
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw const HttpException('O ESP32 não respondeu corretamente.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'O Wi-Fi foi conectado, mas o servidor do ESP32 não respondeu em '
            '$espAddress. Aguarde alguns segundos e toque em Abrir painel.';
      });
      return;
    } finally {
      client.close(force: true);
    }
    if (!mounted) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loadingPage = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loadingPage = false);
        },
        onWebResourceError: (error) {
          if ((error.isForMainFrame ?? true) && mounted) {
            setState(() {
              _loadingPage = false;
              _error = 'Não foi possível abrir o painel: ${error.description}';
            });
          }
        },
        onNavigationRequest: (request) {
          final url = Uri.tryParse(request.url);
          // O WebView carrega somente páginas do servidor local do ESP32.
          if (url?.host == '192.168.4.1' && url?.scheme == 'http') {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));
    setState(() {
      _webController = controller;
      _showPanel = true;
      _loadingPage = true;
      _currentSsid = espSsid;
      _error = null;
    });
    await controller.loadRequest(Uri.parse(espAddress));
  }

  Future<void> _openExistingConnection() async {
    try {
      final isConnected = await _wifi.invokeMethod<bool>('bindExisting') ?? false;
      if (!isConnected) {
        if (mounted) setState(() => _error =
            'Conecte primeiro o celular ao Wi-Fi EcoMonitor-ESP32 ou toque em Conectar e abrir painel.');
        return;
      }
      await _launchWebPanel();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _wifi.invokeMethod<bool>('disconnect');
    } catch (_) { /* Conexão já encerrada: volta à descoberta de todo modo. */ }
    if (!mounted) return;
    setState(() {
      _showPanel = false;
      _webController = null;
      _currentSsid = '';
      _error = null;
    });
    await _scanNetworks();
  }

  Future<void> _openWifiSettings() async {
    try { await _wifi.invokeMethod<bool>('openWifiSettings'); }
    on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  Widget _pill(IconData icon, String label, {Color color = ecoGreen}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _showPanel ? _panelView() : _networkView(),
      ),
    );
  }

  Widget _panelView() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: Colors.white,
        child: Row(children: [
          Container(
            decoration: BoxDecoration(color: const Color(0xFFE1F7E9), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.eco_rounded, color: ecoGreen),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EcoMonitor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ecoDark)),
            Text('Conectado ao ESP32 · Sem internet', style: TextStyle(fontSize: 11, color: ecoGreen)),
          ])),
          IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _webController?.reload()),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Opções',
            onSelected: (value) {
              if (value == 'disconnect') _disconnect();
              if (value == 'reload') _webController?.reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reload', child: Text('Recarregar painel')),
              PopupMenuItem(value: 'disconnect', child: Text('Desconectar ESP32')),
            ],
          ),
        ]),
      ),
      if (_loadingPage) const LinearProgressIndicator(minHeight: 3, color: ecoGreen),
      Expanded(child: _webController == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _webController!)),
    ]);
  }

  Widget _networkView() {
    final espVisible = _networks.any((network) => network.isEco);
    return RefreshIndicator(
      color: ecoGreen,
      onRefresh: _scanNetworks,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 278,
            child: Stack(fit: StackFit.expand, children: [
              Container(color: const Color(0xFF12663E)),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xB9002815), Color(0x4A02210F), Color(0xED062B17)],
              ))),
              Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 26), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pill(Icons.eco, 'BLUE BIRDS  ·  MONITORAMENTO', color: const Color(0xFFA8F6BC)),
                  const Spacer(),
                  const Text('EcoMonitor', style: TextStyle(color: Colors.white, fontSize: 34,
                      fontWeight: FontWeight.w900, letterSpacing: -1.1)),
                  const SizedBox(height: 6),
                  const Text('Sua natureza, em tempo real.',
                    style: TextStyle(color: Color(0xFFE5FFEA), fontSize: 15)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFB8F9CB), size: 18),
                    const SizedBox(width: 7),
                    Expanded(child: Text(_currentSsid.isEmpty ? 'Aguardando conexão Wi-Fi' :
                        'Wi-Fi atual: $_currentSsid', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                ],
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Conectar ao ESP32', style: TextStyle(fontSize: 23,
                    letterSpacing: -0.5, color: ecoDark, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text('Selecione sua estação ambiental', style: TextStyle(color: Color(0xFF71877A), fontSize: 13)),
                ])),
                IconButton.filledTonal(
                  tooltip: 'Pesquisar novamente',
                  onPressed: _scanning || _connecting ? null : _scanNetworks,
                  icon: _scanning
                      ? const SizedBox(height: 19, width: 19,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ecoGreen))
                      : const Icon(Icons.refresh_rounded),
                ),
              ]),
              const SizedBox(height: 19),
              if (_error != null) _feedbackBox(Icons.info_outline_rounded, _error!,
                  const Color(0xFF9D5317), const Color(0xFFFFF2DF)),
              if (!_wifiEnabled) ...[
                _feedbackBox(Icons.wifi_off_rounded, 'O Wi-Fi está desligado.',
                    const Color(0xFF925A16), const Color(0xFFFFF1D9)),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _openWifiSettings,
                    icon: const Icon(Icons.settings), label: const Text('Ativar Wi-Fi')),
              ],
              if (!_locationEnabled) ...[
                const SizedBox(height: 10),
                _feedbackBox(Icons.location_off_outlined,
                  'Ative a Localização do Android para procurar redes próximas.',
                  const Color(0xFF925A16), const Color(0xFFFFF1D9)),
              ],
              const SizedBox(height: 6),
              _deviceCard(espVisible),
              const SizedBox(height: 18),
              Text(_scanning ? 'Procurando redes…' : 'Redes detectadas',
                  style: const TextStyle(color: ecoDark, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 7),
              Text(_message, style: const TextStyle(fontSize: 12, color: Color(0xFF6E8175))),
              const SizedBox(height: 11),
              if (_networks.isEmpty && !_scanning)
                _feedbackBox(Icons.radar, 'Nenhuma rede exibida. Ligue o ESP32 e toque em Atualizar.',
                    const Color(0xFF35694C), const Color(0xFFE5F3E9)),
              ..._networks.map((network) => _networkTile(network)),
              const SizedBox(height: 20),
              const Center(child: Text('Conexão local · Sem Chrome · Sem internet',
                  style: TextStyle(fontSize: 11, color: Color(0xFF839388)))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(bool isVisible) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFDDE8E0)),
        boxShadow: const [BoxShadow(color: Color(0x0E1C5033), blurRadius: 15, offset: Offset(0, 6))]),
      child: Column(children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFFE1F9E8), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.sensors_rounded, size: 28, color: ecoGreen)),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(espSsid, style: TextStyle(color: ecoDark, fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('ESP32 Dev Module · 192.168.4.1',
                style: TextStyle(fontSize: 11, color: Color(0xFF708174))),
          ])),
          _pill(isVisible ? Icons.circle : Icons.wifi_find,
              isVisible ? 'Encontrado' : 'Procurar',
              color: isVisible ? ecoGreen : const Color(0xFF9B7A25)),
        ]),
        const SizedBox(height: 17),
        SizedBox(width: double.infinity, height: 49, child: FilledButton.icon(
          onPressed: _connecting || !_wifiEnabled ? null : _connect,
          icon: _connecting ? const SizedBox(width: 19, height: 19,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.wifi_rounded),
          label: Text(_connecting ? 'Aguardando Android…' : 'Conectar e abrir painel',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(backgroundColor: ecoGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )),
        const SizedBox(height: 10),
        TextButton.icon(onPressed: _connecting ? null : _openExistingConnection,
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Já estou conectado · Abrir painel')),
      ]),
    );
  }

  Widget _networkTile(EcoWifiNetwork network) {
    final strength = network.rssi > -55 ? Icons.wifi_rounded
        : network.rssi > -72 ? Icons.wifi_2_bar_rounded : Icons.wifi_1_bar_rounded;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: Color(0xFFE2EAE5))),
      child: ListTile(
        onTap: network.isEco && !_connecting ? _connect : null,
        leading: Icon(strength, color: network.isEco ? ecoGreen : const Color(0xFF899D91)),
        title: Text(network.ssid, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: network.isEco ? FontWeight.w800 : FontWeight.w500,
                color: ecoDark, fontSize: 14)),
        subtitle: Text(network.isEco ? 'Seu EcoMonitor · Toque para conectar'
            : 'Outra rede${network.secured ? ' · Protegida' : ''}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF799085))),
        trailing: network.isEco ? const Icon(Icons.chevron_right_rounded, color: ecoGreen) : null,
      ),
    );
  }

  Widget _feedbackBox(IconData icon, String message, Color fg, Color bg) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      padding: const EdgeInsets.all(13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: 9),
        Expanded(child: Text(message, style: TextStyle(color: fg, fontSize: 12, height: 1.4))),
      ]),
    );
  }
}
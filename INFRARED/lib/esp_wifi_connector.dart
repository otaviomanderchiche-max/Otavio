import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'infrared_data.dart';

/// Pede a conexao ao SO, sem fingir que conectou antes da API responder.
class EspWifiConnector {
  static Future<void> connect() async {
    if (Platform.isAndroid) {
      await Permission.locationWhenInUse.request();
      await Permission.nearbyWifiDevices.request();
      final joined = await WiFiForIoTPlugin.connect(
        espSsid, password: espPassword, security: NetworkSecurity.WPA,
        joinOnce: true, withInternet: false, timeoutInSeconds: 25,
      );
      if (!joined) {
        throw Exception('O Android nao autorizou a rede $espSsid. '
            'Confirme a janela do sistema ou conecte manualmente ao Wi-Fi.');
      }
      await WiFiForIoTPlugin.forceWifiUsage(true);
      return;
    }
    if (Platform.isWindows) {
      await _connectWindows();
      return;
    }
    throw UnsupportedError('Conexao automatica disponivel apenas no Android e Windows.');
  }

  /// netsh usa o adaptador Wi-Fi ja existente no Windows; nao exige internet.
  /// Cria um perfil WPA2 apenas quando necessario, e apaga o XML temporario.
  static Future<void> _connectWindows() async {
    Future<ProcessResult> run(List<String> args) => Process.run(
      'netsh', args, runInShell: false,
    ).timeout(const Duration(seconds: 15));

    ProcessResult existing;
    try {
      existing = await run(['wlan', 'show', 'profiles', 'name=$espSsid']);
    } on ProcessException {
      throw Exception('O comando netsh nao esta disponivel. Verifique o Wi-Fi do Windows.');
    }
    if (existing.exitCode != 0) {
      final file = File('${Directory.systemTemp.path}/infrared_wifi_${pid}.xml');
      const profile = r'''<?xml version="1.0" encoding="UTF-8"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>ESP32-Termico</name>
  <SSIDConfig><SSID><name>ESP32-Termico</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM><security>
    <authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>12345678</keyMaterial></sharedKey>
  </security></MSM>
</WLANProfile>''';
      try {
        await file.writeAsString(profile, flush: true);
        final add = await run(['wlan', 'add', 'profile', 'filename=${file.path}', 'user=current']);
        if (add.exitCode != 0) {
          throw Exception('Nao foi possivel criar o perfil Wi-Fi. Ative o adaptador Wi-Fi no Windows.');
        }
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
    final result = await run(['wlan', 'connect', 'name=$espSsid', 'ssid=$espSsid']);
    if (result.exitCode != 0) {
      throw Exception('Nao foi possivel conectar a $espSsid. '
          'Confira se o ESP32 esta ligado e se o Wi-Fi do computador esta ativado.');
    }
    // A conexao efetiva e verificada pelo GET /api no aplicativo.
  }
}

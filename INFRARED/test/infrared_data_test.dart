import 'package:flutter_test/flutter_test.dart';
import 'package:infrared/infrared_data.dart';

void main() {
  test('API ThermoLab V2.1 - lê sensores e matriz térmica', () {
    final frame = ThermalFrame.fromJson({
      'id': 120, 'ms': 120842, 'temperatura': 31.3, 'umidade': 27.0,
      'media': 25.45, 'minima': 23.5, 'maxima': 29.5,
      'pico_x': 4, 'pico_y': 3, 'pixels': List.filled(64, 25.1),
      'dht_leitura_ok': true, 'amg_leitura_ok': true,
      'flash_ok': true, 'log_cheio': false, 'csv_bytes': 20202,
      'csv_limite': 1700000, 'clientes': 1,
    });
    expect(frame.temperature, 31.3);
    expect(frame.humidity, 27);
    expect(frame.pixels.length, 64);
    expect(frame.hotX, 4);
    expect(frame.hotY, 3);
    expect(frame.amgOk, true);
  });

  test('histórico por tempo com dados nulos', () {
    final sample = ThermalSample.fromList([
      17, 18000, 31.4, 27.0, 25.8, 24.2, 31.0, null, 31.0, null,
    ]);
    expect(sample?.id, 17);
    expect(sample?.ms, 18000);
    expect(sample?.max, 31.0);
    expect(sample?.temp, 31.4);
    expect(ThermalSample.fromList([1]), null);
  });


  test('alertas: recupera diferenca, pixels, horario e sessao', () {
    final alert=ThermalAlert.fromJson({
      'id': 12, 'sessao': 3, 'tempo_ms': 222000,
      'epoch_ms': 1791891200000, 'ambiente_c': 28.0,
      'pico_c': 32.4, 'delta_c': 4.4,
      'pixel_x':4,'pixel_y':3,'pixels_quentes':6,
    });
    expect(alert.id,12);
    expect(alert.session,3);
    expect(alert.ms,222000);
    expect(alert.delta,4.4);
    expect(alert.localTime,isNotNull);
    expect(alert.x,4);
    expect(alert.y,3);
  });

  test('sem sincronizacao: uptime persiste, data fica ausente', () {
    final alert=ThermalAlert.fromJson({
      'id':1,'sessao':1,'tempo_ms':4300,'epoch_ms':0,
      'ambiente_c':28,'pico_c':32,'delta_c':4,
      'pixel_x':0,'pixel_y':0,'pixels_quentes':3
    });
    expect(alert.localTime,isNull);
    expect(alert.ms,4300);
  });
}

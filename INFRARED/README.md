# INFRARED — aplicativo Android e Windows

Aplicativo Flutter para ESP32 DevKit, DHT11 e AMG8833.
Rede Wi-Fi `ESP32-Termico` (senha `12345678`), endpoint `192.168.4.1`.
Ao abrir, use CONECTAR. O programa inclui dashboard, mapa térmico 8×8,
gráficos históricos e download CSV.

O workflow do repositório gera um APK Android e um instalador EXE Windows
que inclui as dependências nativas (DLLs, pasta data). Ambos são publicados
na Release `infrared-v1.2.0`.

Hardware e firmware físico precisam de validação em dispositivo real.

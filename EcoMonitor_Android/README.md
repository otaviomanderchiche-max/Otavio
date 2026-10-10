# EcoMonitor Android

App Flutter Android com acesso ao painel local do ESP32 Dev Module.

- Encontra a rede **EcoMonitor-ESP32**, e pede autorizacao de conexao ao Android.
- Abre o painel **http://192.168.4.1** no proprio aplicativo (WebView).
- Exibe os dados recebidos pelo firmware do ESP32, sem usar o Chrome.
- Requer Android 10 ou superior e permissoes de Wi-Fi e localizacao.

## Gerar e baixar o instalador direto no Samsung

1. Abra a aba **Actions** deste repositorio no navegador do celular.
2. Abra **Gerar APK EcoMonitor** e a execucao mais recente.
3. Quando terminar em verde, abra **Artifacts**.
4. Baixe **EcoMonitor-APK-Android**, extraia o ZIP e instale EcoMonitor.apk.
5. Autorize instalacao de apps desconhecidos para o gerenciador de arquivos se necessario.

O APK e de testes (assinatura de depuracao). O primeiro uso pede as
permissoes e a confirmacao nativa da conexao Wi-Fi ao ESP32.

O ESP32 deve estar ligado, com o firmware que serve /api/status,
a pagina / e o endpoint /api/readings na rede EcoMonitor-ESP32.

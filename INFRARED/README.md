# INFRARED V1.3 — Alertas térmicos para drone e plantas

## O que foi implementado

- ESP32 analisa os 64 pixels filtrados do AMG8833, comparando o pico com a temperatura ambiente DHT11.
- Alerta somente se ao menos **3 pixels** estiverem **1,5 °C acima** da temperatura ambiente por **3 leituras** consecutivas (200 ms cada). Evita disparos por um único pixel instável.
- Trava de **5 segundos** entre alertas; o alvo deve esfriar abaixo do limiar por 1,5 s para rearme (histerese de 0,6 °C), evitando repetição enquanto a planta permanece quente.
- ESP32 salva eventos no LittleFS (`/alertas.csv`) **entre reinicializações** (até ~150 KB). Não mistura alertas com o CSV normal de leituras.
- App INFRARED Android/Windows consulta `/alertas` a cada 2 s, exibe um aviso temporário por 5 s e mostra um sino com **ponto vermelho persistente** até visualizar os eventos.
- Cada evento registra: número do evento, sessão/boot, tempo desde inicialização, data/hora quando disponíveis, temperatura ambiente, pico térmico, diferença, pixel X/Y, número de pixels aquecidos.
- Exportação independente de histórico de alertas como CSV via `/alertas.csv`, disponível pelo app.
- A marcação de lido é salva no dispositivo em que o app roda; os registros em si permanecem no ESP32.

## Instalação

1. O firmware atualizado está em `ESP32/` (PlatformIO). Mantenha DHT11 DATA no **GPIO27**, AMG8833 SDA 21 e SCL 22.
2. Atualize o ESP32 via **Upload** com o projeto da pasta `ESP32/`.
3. O app Flutter está em `Aplicativo/`, com o workflow de GitHub Actions em `.github/workflows` para gerar APK Android e um instalador EXE Windows.
4. No celular ou PC, conecte à rede `ESP32-Termico` e abra o app, pressione **CONECTAR**.
5. Ao conectar, o app envia a hora atual ao ESP32. **Se nenhum dispositivo sincronizar a hora**, eventos guardam o tempo desde o boot mas não possuem uma data absoluta confiável. Eventos anteriores à sincronização podem receber data retroativa somente na sessão atual; eventos de sessões passadas sem relógio ficam sem data.
6. Toque no **sino vermelho** para ver todos os alertas, com horário, tempo desde a inicialização e temperaturas. Na tela de alertas, toque em **BAIXAR HISTÓRICO DE ALERTAS CSV**.

## Limites e cautelas

- **Não é diagnóstico de doença da planta**. Sol, vento, fundo, reflexos, distância do drone, emissividade das folhas e precisão limitada do DHT11 e AMG8833 podem gerar diferenças. Não garante que o ponto quente pertence à planta.
- **O AMG8833 é apenas 8x8**. Aponte o sensor para que a planta ocupe vários pixels, sem céu/chão quente no campo de visão.
- O sensor não fornece coordenadas geográficas; os pixels X/Y são locais da imagem.
- Os eventos persistem em memória flash até atingir o limite reservado de 150 KB. Nesse caso, exporte os CSVs e faça manutenção; esta versão não apaga automaticamente o histórico.
- **ALERTA DE HARDWARE:** antes de operar o drone, confirme a medição anterior de 5,19 V no pino 3V3. Se estiver correta, NÃO energize a placa por essa fonte, pois 3V3 deve ser aproximadamente 3,3 V. Uma troca de pino ou atualização de software não conserta sobretensão.

## Rotas novas do firmware

- `GET http://192.168.4.1/alertas` — lista eventos persistentes.
- `GET http://192.168.4.1/alertas?depois=ID` — busca apenas registros novos.
- `GET http://192.168.4.1/alertas.csv` — exporta alertas completos.
- `GET http://192.168.4.1/api` — agora também informa `alertas_total`, `sessao`, `alertas_ok`, `alertas_cheios`.

## Ajustar sensibilidade

No firmware `ESP32/src/main.cpp`:

- `ALERTA_DELTA_MIN_C = 1.5f`: diferença mínima de temperatura
- `ALERTA_PIXELS_MIN = 3`: quantidade mínima de pixels quentes
- `ALERTA_FRAMES_MIN = 3`: quantidade de quadros consecutivos
- `ALERTA_COOLDOWN_MS = 5000`: tempo de bloqueio entre eventos
- `ALERTA_REARM_MS = 1500`: tempo de esfriamento necessário para detectar uma nova ocorrência

**Compilação:** o projeto está preparado para PlatformIO + Flutter. Os binários APK/EXE e funcionamento em hardware ainda precisam ser compilados/validados. Não anuncie como executáveis testados sem resultado positivo do workflow.

## V1.4 — Diagnóstico de alertas

A tela Monitor agora informa a diferença entre AMG máximo e DHT11 e explica o motivo de não gerar alertas. Mostra erro quando o firmware é antigo ou LittleFS não salva eventos. O sino no canto direito fica vermelho quando há alertas não lidos.
A atualização do app requer **também** a programação V1.4 no ESP32.

Observação: app V1.4 requer firmware V1.4 do ESP32 para alertas.

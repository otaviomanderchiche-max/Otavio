# ThermoLab V2.1 GPIO27 — ESP32 DevKit + DHT11 + AMG8833

Dashboard HTML 100% offline na rede Wi-Fi do ESP32. A interface exibe leituras, três gráficos, mapa térmico 8×8 e permite exportar o CSV desde o início da **sessão atual de inicialização**.

## Ligações

| Sensor | Sensor | ESP32 |
|---|---|---|
| DHT11 | DATA / OUT | **GPIO 27** |
| DHT11 | VCC / GND | 3V3 / GND |
| AMG8833 | SDA | GPIO 21 |
| AMG8833 | SCL | GPIO 22 |
| AMG8833 | VCC / GND | 3V3 / GND, se o módulo aceitar 3,3 V |

- Se o DHT11 for avulso, instale resistor pull-up de 10 kΩ entre DATA e 3V3.
- **Alteração principal:** mova o fio DATA do DHT11 que estava no GPIO 2 para o **GPIO 27**.
- O GPIO 2 participa do processo de boot em placas ESP32 clássicas. Usar o GPIO 27 evita essa possível interferência.
- Se a rede funcionar no USB, mas não com baterias, verifique estabilidade do regulador de 5 V e dos 3,3 V nos picos do Wi-Fi.

## Instruções

1. Abra esta pasta inteira no VS Code com a extensão PlatformIO.
2. Faça **Build** e depois **Upload** (pode ser necessário indicar a porta USB).
3. Abra o Monitor Serial em 115200 baud.
4. Conecte o dispositivo à rede `ESP32-Termico`, senha `12345678`.
5. Abra **http://192.168.4.1** no navegador, conectado ao Wi-Fi do ESP32.
6. Clique no botão **⬇ Baixar CSV** no topo do site. Alternativamente, abra diretamente **http://192.168.4.1/csv** no navegador.

**Atenção à tabela de partições:** esta versão usa `partitions.csv` personalizado, com 2 MB para app e ~1,94 MB para o filesystem. Foi pensado para placas com **4 MB de flash**. Não é apropriado para ESP32 com flash menor sem modificar partições. A mudança de partições pode invalidar dados existentes no flash. Não é necessário fazer Upload Filesystem: LittleFS cria o arquivo automaticamente.

## Taxas e filtros

- AMG8833: 5 Hz (uma amostra a cada 200 ms); média da mediana de 5 quadros por pixel com EMA adaptativo para reduzir ruído.
- Dashboard: consulta ao vivo a cada 400 ms (2,5 atualizações/s).
- DHT11: leitura a cada 2100 ms (aproximadamente 0,48 Hz). O DHT11 não fornece novas medições de forma confiável mais rapidamente do que ~2 s.
- CSV: uma linha por segundo, usando última leitura válida de cada sensor. A temperatura/umidade do DHT11 pode permanecer igual em duas ou três linhas consecutivas.
- RAM: janela das últimas 900 linhas para atualizar gráficos sem reconsultar todo o arquivo.
- Flash: CSV com todas as linhas, até o limite definido de 1.700.000 bytes, e amostragem de ~1.000 pontos para desenhar a visão completa da sessão.
- Cada 10 segundos o CSV é descarregado do buffer para flash. Em queda súbita de energia podem faltar os últimos segundos.

## Dados do CSV

`data_hora_utc,id,tempo_ms,temperatura_dht_c,umidade_pct,amg_media_c,amg_min_c,amg_max_c,temperatura_dht_bruta_c,umidade_bruta_pct,amg_max_bruta_c`

- `tempo_ms`: milissegundos desde a inicialização do ESP32. Este campo existe sem internet e sem GPS.
- `data_hora_utc`: horário aproximado em ISO 8601 UTC, calculado a partir do relógio do celular/computador. O browser sincroniza o ESP32 ao abrir a página. Se isso não ocorrer, o campo permanece vazio e `tempo_ms` continua válido.
- Os campos numéricos usam ponto decimal e vírgula como separador CSV. No Excel configurado para português brasileiro, importe como arquivo delimitado por vírgulas com ponto decimal (Dados > De Texto/CSV) caso não separe automaticamente as colunas.
- Leituras inválidas ficam com campo vazio no CSV; não são substituídas por zero.

## Limite do histórico — leia antes de usar

**Não existe armazenamento infinito na flash interna**. O firmware reserva **até 1,7 MB de CSV** por sessão; dependendo dos valores de cada linha, isso equivale aproximadamente a algumas horas a 1 linha por segundo. Ao alcançar o limite, o painel exibe um aviso e **novas linhas deixam de ser gravadas**; os dados existentes são preservados até a exportação. Para coleta por dias ou semanas, use microSD ou envie dados a um servidor.

O arquivo CSV da **sessão atual** é reiniciado em cada boot; portanto **faça o download antes de desligar/reiniciar**. A página do navegador pode ser fechada sem perder dados, enquanto o ESP32 permanecer ligado e com espaço disponível. O gráfico da sessão é reconstruído lendo o CSV e agregando pontos; **o CSV baixado não é agregado**.

O sensor mede a temperatura aparente das superfícies em sua matriz infravermelha; não obtém imagens RGB, distância nem localização geográfica.

## Rotas da API

- `/` dashboard HTML
- `/api` estado atual + 64 pixels
- `/historico` histórico do CSV amostrado para visualização
- `/recentes?depois=ID` registros RAM posteriores a um ID
- `/csv` exportação CSV completa
- `/sincronizar?epoch=MILISSEGUNDOS_UNIX` sincronização do relógio com o navegador

## Compilação / limitações de verificação

A sintaxe JavaScript do dashboard foi verificada e sua inicialização executada com um mock local, mas não foi possível executar o Build real via PlatformIO ou testar os sensores físicos neste ambiente. Recomenda-se validar a gravação CSV, reboot e Wi-Fi na sua placa antes de coletar dados importantes.

## Se o botão CSV não aparecer

Verifique que o firmware **V2.1** foi enviado à placa via **PlatformIO > Upload**, e não apenas o projeto foi aberto no computador. Recarregue o endereço `http://192.168.4.1/` forçando atualização (Ctrl+F5 no Windows). Em celular, feche a aba e abra novamente. Acesse `http://192.168.4.1/csv` diretamente como teste. Se a rota retornar **404**, o ESP32 continua com firmware antigo; se retornar **503**, houve problema com LittleFS.

## Diagnóstico de Wi-Fi

Abra o Monitor Serial em **115200 baud** e reinicie a placa. Procure por `Wi-Fi AP: INICIADO` e `IP do ESP32: 192.168.4.1`.
Se aparecer `Wi-Fi AP: FALHOU`, teste com alimentação USB e depois com a bateria regulada em 5 V. Esta atualização altera a pinagem e acrescenta mensagens de diagnóstico; **não corrige quedas de tensão**.

**Compatibilidade:** rotas `/`, `/api`, `/historico`, `/recentes`, `/csv` e `/sincronizar` preservadas, portanto o aplicativo INFRARED continua compatível.

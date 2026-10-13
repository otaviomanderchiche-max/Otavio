#pragma once
const char PAGINA_HTML[] PROGMEM = R"HTML(
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#0B1020">
<title>ThermoLab V2 | Dashboard de sensores</title>
<style>
:root{color-scheme:dark;--bg:#090f1d;--panel:#131d2e;--edge:#2a3950;--muted:#96a7bf;--text:#edf4ff;--cyan:#46d2f0;--violet:#a593ff;--orange:#ffb069;--green:#5fe6aa;--red:#ff6b76}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse 800px 420px at 85% -100px,#1e3153 0%,transparent 75%),var(--bg);color:var(--text);font-family:Inter,system-ui,-apple-system,Segoe UI,Arial,sans-serif;font-size:14px}button,input{font:inherit}button{cursor:pointer}
.wrapper{max-width:1390px;padding:24px 22px 60px;margin:auto}.top{display:flex;justify-content:space-between;gap:16px;align-items:center;flex-wrap:wrap;margin-bottom:28px}.brand{display:flex;align-items:center;gap:13px}.logo{display:grid;place-items:center;width:42px;height:42px;border-radius:14px;background:linear-gradient(140deg,#1a81ba,#7253d5);font-size:23px;box-shadow:0 9px 30px #3589ff25}h1{font-size:24px;letter-spacing:-.8px;margin:0}.sub{color:var(--muted);margin:3px 0 0;font-size:12px}.topRight{display:flex;align-items:center;gap:12px;flex-wrap:wrap}.dot{width:8px;height:8px;background:var(--green);border-radius:50%;box-shadow:0 0 12px #5fe6aa80}.dot.off{background:var(--red);box-shadow:0 0 12px #ff6b7655}.connected{display:flex;align-items:center;gap:9px;color:var(--muted);background:#192538;border:1px solid var(--edge);padding:10px 13px;border-radius:12px}.pill{border:1px solid var(--edge);color:#d3e1f5;background:#162236;padding:9px 12px;border-radius:12px;font-size:12px}.heading{display:flex;justify-content:space-between;gap:14px;align-items:end;margin:28px 0 12px}h2{font-size:17px;margin:0;font-weight:650;letter-spacing:-.3px}.heading p{color:var(--muted);font-size:12px;margin:4px 0 0}.updated{color:var(--muted);font-size:12px;white-space:nowrap}.cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:13px}.card,.panel{border:1px solid var(--edge);border-radius:18px;background:linear-gradient(160deg,#18253a,#111a2a);box-shadow:0 8px 28px #03061222}.card{padding:19px 19px 17px;min-height:134px;position:relative;overflow:hidden}.card:before{content:'';position:absolute;left:0;top:19px;bottom:19px;width:3px;border-radius:5px;background:var(--accent)}.cardIcon{font-size:18px;float:right;opacity:.8}.cardLabel{font-size:12px;color:#adbcd2}.cardValue{font-size:clamp(25px,2.8vw,35px);line-height:1.2;font-weight:720;letter-spacing:-1px;margin-top:13px;font-variant-numeric:tabular-nums}.unit{font-size:.56em;color:#b0bfd1;font-weight:500;letter-spacing:0}.cardFoot{font-size:11px;color:var(--muted);margin-top:9px}.panel{padding:20px}.panelTitle{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:15px}.legend{display:flex;align-items:center;flex-wrap:wrap;gap:14px;color:#a8bad0;font-size:11px}.legend span{display:flex;align-items:center;gap:6px}.line{display:inline-block;width:19px;height:3px;background:var(--lc);border-radius:3px}.line.dashed{background:none;border-top:2px dashed var(--lc);height:0}.filters{display:flex;flex-wrap:wrap;align-items:center;gap:10px}.seg{display:flex;background:#0b1424;border:1px solid #2e4059;padding:4px;gap:4px;border-radius:12px}.seg button{border:0;background:transparent;color:var(--muted);border-radius:8px;padding:7px 12px;font-size:12px}.seg button.active{background:#2b405e;color:white}.toggle{display:flex;align-items:center;gap:7px;color:#b0c0d5;font-size:12px;cursor:pointer}.toggle input{accent-color:#4dc7e9}.charts{display:grid;grid-template-columns:1fr 1fr;gap:14px}.chartBox{height:266px;position:relative}.chartBox canvas{width:100%;height:100%;display:block;touch-action:pan-y}.hoverTip{position:absolute;display:none;pointer-events:none;padding:8px 10px;border-radius:8px;background:#07101deb;border:1px solid #32445c;color:#edf5ff;white-space:pre-line;font-size:11px;line-height:1.6;z-index:2}.bottom{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,.9fr);gap:14px}.heatRow{display:grid;grid-template-columns:minmax(0,1fr) 150px;gap:18px}.matrix{display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:5px;max-width:560px}.pixel{aspect-ratio:1;border-radius:6px;display:grid;place-items:center;color:white;font-size:clamp(9px,1.1vw,14px);font-weight:700;text-shadow:0 1px 3px #0008;font-variant-numeric:tabular-nums;position:relative;transition:background .25s}.pixel.hot{outline:2px solid #f7f7ff;outline-offset:-2px}.heatLegend{max-width:560px;margin-top:13px;display:flex;justify-content:space-between;gap:7px;align-items:center;color:var(--muted);font-size:11px}.scale{height:7px;flex:1;max-width:245px;border-radius:20px;background:linear-gradient(to right,#2449ab,#35afdf,#6ce2b6,#f9d167,#fb842f,#d22d43)}.readouts{display:flex;flex-direction:column;gap:12px}.readout{background:#0e1828;border:1px solid #25364e;padding:13px;border-radius:12px}.readout .t{color:#98adc7;font-size:11px}.readout .v{font-size:22px;font-weight:720;margin-top:7px;font-variant-numeric:tabular-nums}.readout .note{font-size:10px;color:#8298b0;margin-top:3px}.details{display:grid;grid-template-columns:1fr 1fr;gap:11px}.detail{background:#0e1828;padding:14px;border-radius:12px;border:1px solid #263750}.detail b{font-size:14px;display:block;margin-top:6px}.detail small{color:var(--muted);font-size:11px}.notice{margin-top:16px;padding:12px 14px;background:#0b1525;border:1px solid #25364c;border-radius:11px;color:#afc1d5;font-size:12px;line-height:1.6}.foot{font-size:11px;color:#7488a4;margin-top:20px;text-align:center}#error{color:#ffadb2}.empty{color:#899bb3;font-size:12px;min-height:40px}#tooltipPixel{font-size:11px;color:#aebdd1;margin-top:13px;min-height:17px}
@media(max-width:1000px){.cards{grid-template-columns:repeat(2,minmax(0,1fr))}.charts{grid-template-columns:1fr}.bottom{grid-template-columns:1fr}.pixel{font-size:12px}}
@media(max-width:600px){.wrapper{padding:19px 12px 42px}.top{margin-bottom:20px}.brand h1{font-size:21px}.cards{gap:9px}.card{padding:14px;min-height:126px}.cardValue{font-size:27px}.heading{align-items:start;flex-direction:column}.panel{padding:13px}.chartBox{height:230px}.panelTitle{flex-wrap:wrap}.heatRow{grid-template-columns:1fr}.readouts{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.readout{padding:10px}.readout .v{font-size:16px}.matrix{gap:3px}.pixel{font-size:clamp(9px,2.3vw,12px)}.details{gap:7px}.detail{padding:10px}.connected{padding:8px 10px}.topRight{gap:7px}}

/* Atualização V2: gráficos e módulo de exportação */
.topCsv{display:inline-flex;align-items:center;justify-content:center;background:linear-gradient(110deg,#247fa9,#6256bf);border:1px solid #6991dc;border-radius:11px;padding:11px 15px;text-decoration:none;color:#fff;font-weight:700;font-size:13px;white-space:nowrap}.topCsv:hover{filter:brightness(1.12)}
.charts{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}
.charts>.panel:first-child{grid-column:1/-1}
.chartBox{height:286px}
.charts>.panel:first-child .chartBox{height:318px}
.exportPanel{margin-bottom:8px;background:linear-gradient(110deg,#15263d,#121b2d)}
.exportInfo{display:flex;justify-content:space-between;align-items:center;gap:28px;flex-wrap:wrap}
.exportInfo h2{font-size:17px}.exportInfo p{color:var(--muted);font-size:12px;margin:6px 0 10px}
.exportInfo small{font-size:11px;color:#9ab4cd}.exportInfo>div:first-child{flex:1;min-width:230px}
.csvStatus{font-size:12px;color:#62ddbc;margin-top:12px}.csvStatus.attention{color:#ffb069}
.progress{height:5px;background:#0b1422;border-radius:4px;overflow:hidden;margin:9px 0;max-width:470px}
.progress>div{height:100%;width:0%;background:linear-gradient(90deg,#56c4e7,#9d89fb);border-radius:4px;transition:width .4s}
.csvHint{font-size:11px;color:#819ab6;margin-top:9px}
.exportButtons{display:flex;flex-wrap:wrap;gap:10px}
.primaryButton,.secondaryButton{border-radius:11px;padding:12px 15px;display:inline-block;text-decoration:none;font-size:12px;font-weight:650;text-align:center}
.primaryButton{background:linear-gradient(110deg,#299bcc,#645bca);color:white;border:1px solid #5b9fd6}
.secondaryButton{background:#15253b;color:#cadcf0;border:1px solid #33465e}
.hoverTip{min-width:155px;box-shadow:0 9px 26px #0008}
@media(max-width:800px){.charts{grid-template-columns:1fr}.charts>.panel:first-child{grid-column:auto}.chartBox,.charts>.panel:first-child .chartBox{height:252px}.exportButtons{width:100%}.exportButtons a,.exportButtons button{flex:1}}
</style>
</head>
<body>
<div class="wrapper">
<header class="top">
  <div class="brand"><div class="logo">◈</div><div><h1>ThermoLab <span style="color:#61c6ee">/ ESP32</span></h1><p class="sub">Dashboard térmico · DHT11 + AMG8833 · Wi-Fi local</p></div></div>
  <div class="topRight"><a class="topCsv" href="/csv" download="thermolab_leituras.csv" title="Baixar todas as leituras em CSV">⬇ Baixar CSV</a><div class="pill">192.168.4.1</div><div class="connected"><i id="dot" class="dot off"></i><span id="status">Conectando...</span></div></div>
</header>
<section class="heading"><div><h2>Visão geral</h2><p>Medições filtradas em tempo real</p></div><span class="updated" id="atualizacao">Aguardando sensores...</span></section>
<div class="cards">
  <article class="card" style="--accent:var(--cyan)"><span class="cardIcon">◉</span><div class="cardLabel">Temperatura ambiente · DHT11</div><div class="cardValue"><span id="temp">--</span> <span class="unit">°C</span></div><div class="cardFoot" id="footTemp">Filtro exponencial ativo</div></article>
  <article class="card" style="--accent:var(--green)"><span class="cardIcon">◌</span><div class="cardLabel">Umidade relativa · DHT11</div><div class="cardValue"><span id="umid">--</span> <span class="unit">%</span></div><div class="cardFoot">Média suavizada</div></article>
  <article class="card" style="--accent:var(--orange)"><span class="cardIcon">▲</span><div class="cardLabel">Temperatura máxima · AMG</div><div class="cardValue"><span id="max">--</span> <span class="unit">°C</span></div><div class="cardFoot" id="pico">Ponto mais quente: --</div></article>
  <article class="card" style="--accent:var(--violet)"><span class="cardIcon">▦</span><div class="cardLabel">Temperatura média · AMG</div><div class="cardValue"><span id="media">--</span> <span class="unit">°C</span></div><div class="cardFoot">Média de 64 pixels filtrados</div></article>
</div>
<section class="heading"><div><h2>Histórico das medições</h2><p>Gráficos com histórico completo desde a inicialização do ESP32</p></div><div class="filters"><label class="toggle"><input type="checkbox" id="bruto">Comparar com leitura bruta</label><div class="seg" id="faixa"><button data-sec="30">30 s</button><button data-sec="120">2 min</button><button data-sec="600">10 min</button><button class="active" data-sec="all">Desde o início</button></div></div></section>
<div class="charts">
  <section class="panel"><div class="panelTitle"><h2>Temperaturas ao longo do tempo</h2></div><div class="legend"><span><i class="line" style="--lc:#46d2f0"></i>Ambiente</span><span><i class="line" style="--lc:#a593ff"></i>AMG média</span><span><i class="line" style="--lc:#ffb069"></i>AMG máxima</span><span id="rawLegend" style="display:none"><i class="line dashed" style="--lc:#8fa0b9"></i>Brutas</span></div><div class="chartBox"><canvas id="grafTemp"></canvas><div class="hoverTip" id="tipTemp"></div></div></section>
  <section class="panel"><div class="panelTitle"><h2>Temperaturas da matriz térmica</h2></div><div class="legend"><span><i class="line" style="--lc:#64dcce"></i>Mínima</span><span><i class="line" style="--lc:#a593ff"></i>Média</span><span><i class="line" style="--lc:#ffb069"></i>Máxima</span></div><div class="chartBox"><canvas id="grafAMG"></canvas><div class="hoverTip" id="tipAMG"></div></div></section>
  <section class="panel"><div class="panelTitle"><h2>Umidade relativa</h2><span style="font-size:11px;color:var(--muted)">DHT11 · % UR</span></div><div class="legend"><span><i class="line" style="--lc:#5fe6aa"></i>Umidade filtrada</span><span id="rawHumLegend" style="display:none"><i class="line dashed" style="--lc:#8fa0b9"></i>Bruta</span></div><div class="chartBox"><canvas id="grafUmid"></canvas><div class="hoverTip" id="tipUmid"></div></div></section>
</div>
<section class="heading"><div><h2>Registro e exportação</h2><p>Armazenamento local no ESP32 · um registro por segundo</p></div></section>
<div class="panel exportPanel"><div class="exportInfo"><div><h2>Histórico CSV completo</h2><p>Dados brutos e filtrados, tempo decorrido e data/hora UTC quando sincronizada</p><div id="csvStatus" class="csvStatus">Inicializando armazenamento...</div><div class="progress"><div id="csvProgress"></div></div><small id="relogioStatus">Sincronizando relógio com o navegador...</small><div id="csvMsg" class="csvHint">A exportação preserva todos os registros gravados; o gráfico usa amostragem para manter a fluidez.</div></div><div class="exportButtons"><a id="csvDownload" class="primaryButton" href="/csv" download="thermolab_leituras.csv">↓ Baixar CSV completo</a><button id="recarregarTudo" class="secondaryButton">↻ Atualizar histórico</button></div></div></div>
<section class="heading"><div><h2>Câmera térmica</h2><p>64 pixels infravermelhos · cores estáveis na escala de 18 a 45 °C</p></div><span class="updated">Mediana 5 amostras + EMA</span></section>
<div class="bottom">
  <section class="panel"><div class="panelTitle"><h2>Matriz 8 × 8</h2><span id="sensorAMG" class="pill">AGUARDANDO</span></div><div class="heatRow"><div><div class="matrix" id="matriz"></div><div class="heatLegend"><span>18 °C</span><div class="scale"></div><span>45 °C</span></div><div id="tooltipPixel">Selecione um pixel para ver suas coordenadas.</div></div><div class="readouts"><div class="readout"><div class="t">Mínima</div><div class="v"><span id="min">--</span>°</div></div><div class="readout"><div class="t">Média</div><div class="v"><span id="media2">--</span>°</div></div><div class="readout"><div class="t">Máxima</div><div class="v"><span id="max2">--</span>°</div><div class="note" id="pico2">X -- · Y --</div></div></div></div></section>
  <section class="panel"><div class="panelTitle"><h2>Informações do sistema</h2></div><div class="details"><div class="detail"><small>Modo de conexão</small><b>Access Point · Offline</b></div><div class="detail"><small>Dispositivos conectados</small><b id="clientes">--</b></div><div class="detail"><small>Sensor de umidade</small><b id="dhtStatus">Aguardando</b></div><div class="detail"><small>Sensor infravermelho</small><b id="amgStatus">Aguardando</b></div><div class="detail"><small>Tempo em operação</small><b id="uptime">--</b></div><div class="detail"><small>Amostras no histórico</small><b id="nRegistros">--</b></div></div><div class="notice"><b>Filtros em operação</b><div>AMG8833: mediana temporal de 5 quadros + EMA adaptativo por pixel, com rejeição de valores inválidos. DHT11: EMA + zona morta, respeitando o intervalo mínimo de leitura.</div><div style="margin-top:8px;color:#849cb5">Os registros são gravados em CSV no LittleFS a cada 1 s, até atingir o limite de espaço. Faça o download antes de reiniciar, pois cada inicialização inicia um arquivo novo. A medição térmica representa a superfície observada, não o ar.</div><div id="error"></div></div></section>
</div>
<div class="foot">ThermoLab V2 · ESP32 DevKit · Offline · Gravação CSV na memória flash</div>
</div>
<script>
'use strict';
const $=id=>document.getElementById(id);
const cores=[[36,73,171],[53,175,223],[108,226,182],[249,209,103],[251,132,47],[210,45,67]];
const numero=(n,d=1)=>Number.isFinite(n)?n.toFixed(d):'--';
const visuais=[];
const paleta={ambiente:'#46d2f0',amgMedia:'#a593ff',amgMax:'#ffb069',amgMin:'#64dcce',umidade:'#5fe6aa',bruta:'#849fbe'};
let registros=[], ids=new Set(), ultimoId=0, msAtual=0, tempoVisivel='all';
let conectado=false, atualizando=false, atualizandoRegistros=false, selecionado=-1;
let pixelsAtuais=[], mostrarBruto=false, relogioOK=false;
let ultimaAtualizacao=0, relogioUltimoSync=0, csvCheio=false, recarregando=false;
const charts=[
  {el:$('grafTemp'),tip:$('tipTemp'),area:true,series:[{i:2,n:'Ambiente',cor:paleta.ambiente},{i:4,n:'AMG média',cor:paleta.amgMedia},{i:6,n:'AMG máxima',cor:paleta.amgMax}]},
  {el:$('grafAMG'),tip:$('tipAMG'),area:false,series:[{i:5,n:'AMG mínima',cor:paleta.amgMin},{i:4,n:'AMG média',cor:paleta.amgMedia},{i:6,n:'AMG máxima',cor:paleta.amgMax}]},
  {el:$('grafUmid'),tip:$('tipUmid'),area:true,percent:true,series:[{i:3,n:'Umidade',cor:paleta.umidade}]}
];
function corTermica(temp){
  if(!Number.isFinite(temp))return '#35445b';
  let p=Math.min(1,Math.max(0,(temp-18)/27))*(cores.length-1),i=Math.min(cores.length-2,Math.floor(p)),f=p-i;
  return 'rgb('+cores[i].map((v,k)=>Math.round(v+(cores[i+1][k]-v)*f)).join(',')+')';
}
function iniciarPixels(){
  const grade=$('matriz');
  for(let i=0;i<64;i++){
    let el=document.createElement('div');el.className='pixel';el.textContent='--';
    el.title='X='+(i%8)+' Y='+Math.floor(i/8);
    el.addEventListener('click',()=>{selecionado=i;atualizarSelecao();});
    grade.appendChild(el);visuais.push(el);
  }
}
function atualizarSelecao(){
  visuais.forEach((el,i)=>el.classList.toggle('hot',i===selecionado));
  if(selecionado>=0)$('tooltipPixel').textContent='Pixel X='+selecionado%8+' · Y='+Math.floor(selecionado/8)+' · '+numero(pixelsAtuais[selecionado])+' °C';
}
function desenharMapa(p){
  pixelsAtuais=Array.isArray(p)?p:[];
  visuais.forEach((el,i)=>{
    const n=pixelsAtuais[i];el.textContent=numero(n,0);el.style.background=corTermica(n);
  });
  atualizarSelecao();
}
function formatarDuracao(s){
  s=Math.max(0,Math.floor(s));
  let d=Math.floor(s/86400),h=Math.floor(s%86400/3600),m=Math.floor(s%3600/60),seg=s%60;
  return d?d+'d '+h+'h':h?h+'h '+m+'min':m?m+'min '+seg+'s':seg+'s';
}
function horaUptime(ms){
  const s=Math.floor(ms/1000),h=Math.floor(s/3600),m=Math.floor(s%3600/60),x=s%60;
  return [h,m,x].map(x=>String(x).padStart(2,'0')).join(':');
}
function incluir(regs){
  if(!Array.isArray(regs))return;
  for(const p of regs){
    if(!Array.isArray(p)||p.length<10||!Number.isFinite(p[0])||ids.has(p[0]))continue;
    ids.add(p[0]);registros.push(p);
    ultimoId=Math.max(ultimoId,p[0]);
  }
  registros.sort((a,b)=>a[0]-b[0]);
  if(registros.length>2400){
    // Diminui pontos antigos; conserva detalhes dos ultimos 1200 segundos.
    const antigos=registros.slice(0,-1200).filter((_,i)=>i%2===0);
    registros=antigos.concat(registros.slice(-1200));
    ids=new Set(registros.map(x=>x[0]));
  }
  $('nRegistros').textContent=ultimoId+' amostras';
  desenharGraficos();
}
async function carregarHistorico(){
  if(recarregando)return;
  recarregando=true;
  try{
    const r=await fetch('/historico',{cache:'no-store'});
    if(!r.ok)throw Error('HTTP '+r.status);
    const j=await r.json();
    // Uma nova consulta recompõe a amostragem de toda a sessao.
    registros=[];ids.clear();ultimoId=0;
    incluir(j.registros);
    await carregarRecentes();
  }catch(e){console.warn('Não foi possível carregar o histórico:',e);}
  finally{recarregando=false;}
}
async function carregarRecentes(){
  if(atualizandoRegistros)return;
  atualizandoRegistros=true;
  let precisaRecarregar=false;
  try{
    const r=await fetch('/recentes?depois='+ultimoId,{cache:'no-store'});
    if(!r.ok)throw Error('HTTP '+r.status);
    const j=await r.json();
    precisaRecarregar=!!j.recarregar;
    incluir(j.registros);
  }catch(e){console.warn('Falha ao atualizar série:',e);}
  finally{atualizandoRegistros=false;}
  if(precisaRecarregar&&!csvCheio&&!recarregando)carregarHistorico();
}
function atualizarStatus(){
  $('dot').className='dot'+(conectado?'':' off');
  $('status').textContent=conectado?'Conectado · ao vivo':'Sem comunicação';
  $('atualizacao').textContent=ultimaAtualizacao?'Atualizado há '+Math.floor((Date.now()-ultimaAtualizacao)/1000)+'s':'Aguardando';
}
function aplicarDados(d){
  msAtual=d.ms;
  $('temp').textContent=numero(d.temperatura);$('umid').textContent=numero(d.umidade);
  $('max').textContent=numero(d.maxima);$('max2').textContent=numero(d.maxima);
  $('min').textContent=numero(d.minima);$('media').textContent=numero(d.media);$('media2').textContent=numero(d.media);
  $('pico').textContent=d.pico_x<0?'Ponto mais quente: --':'Ponto mais quente: X '+d.pico_x+' · Y '+d.pico_y;
  $('pico2').textContent=d.pico_x<0?'X -- · Y --':'X '+d.pico_x+' · Y '+d.pico_y;
  $('clientes').textContent=d.clientes;
  $('uptime').textContent=formatarDuracao(d.ms/1000);
  $('nRegistros').textContent=d.total+' amostras';
  $('dhtStatus').textContent=d.dht_leitura_ok?'Ativo':'Aguardando / falha';
  $('amgStatus').textContent=d.amg_leitura_ok?'Ativo':(d.amg_ok?'Falha na leitura':'Não encontrado');
  $('sensorAMG').textContent=d.amg_leitura_ok?'CONECTADO':'VERIFICAR SENSOR';
  $('footTemp').textContent=Number.isFinite(d.temp_bruta)?'Leitura bruta: '+numero(d.temp_bruta)+' °C':'Aguardando DHT11';
  csvCheio=!!d.log_cheio;
  $('csvStatus').textContent=!d.flash_ok?'Falha no LittleFS':d.log_cheio?'Armazenamento cheio · exporte o CSV':'Gravando · '+Math.round(d.csv_bytes/1024)+' KB de '+Math.round(d.csv_limite/1024)+' KB';
  $('csvStatus').classList.toggle('attention',!d.flash_ok||d.log_cheio);
  $('csvProgress').style.width=Math.min(100,100*d.csv_bytes/d.csv_limite)+'%';
  $('relogioStatus').textContent=d.relogio_sincronizado?'Data/hora UTC habilitada':'Data/hora será sincronizada ao abrir';
  $('error').textContent=!d.dht_leitura_ok&&!d.amg_leitura_ok?'Confira conexões dos sensores.':!d.amg_leitura_ok?'AMG8833 sem leitura válida.':!d.dht_leitura_ok?'DHT11 sem leitura válida.':'';
  desenharMapa(d.pixels);
  ultimaAtualizacao=Date.now();conectado=true;atualizarStatus();
}
async function atualizar(){
  if(atualizando)return;
  atualizando=true;
  try{
    const r=await fetch('/api',{cache:'no-store'});
    if(!r.ok)throw Error('HTTP '+r.status);
    aplicarDados(await r.json());
  }catch(e){conectado=false;atualizarStatus();$('error').textContent='ESP32 inacessível: '+e.message;}
  finally{atualizando=false;}
}
async function sincronizarRelogio(){
  try{
    const r=await fetch('/sincronizar?epoch='+Date.now(),{cache:'no-store'});
    relogioOK=r.ok;
    if(r.ok)relogioUltimoSync=Date.now();
  }catch(e){relogioOK=false;}
}
function prepararCanvas(c){
  const rect=c.getBoundingClientRect(),dpr=Math.min(2,devicePixelRatio||1);
  const w=Math.max(250,rect.width),h=Math.max(190,rect.height);
  if(c.width!==Math.round(w*dpr)||c.height!==Math.round(h*dpr)){
    c.width=Math.round(w*dpr);c.height=Math.round(h*dpr);
  }
  const ctx=c.getContext('2d');ctx.setTransform(dpr,0,0,dpr,0,0);
  ctx.clearRect(0,0,w,h);return {ctx,w,h};
}
function dadosVisiveis(){
  if(!registros.length)return [];
  if(tempoVisivel==='all')return registros;
  const de=Math.max(0,msAtual-Number(tempoVisivel)*1000);
  return registros.filter(p=>p[1]>=de);
}
function arredondar(t){return t<1?t.toFixed(1):t.toFixed(0);}
function rotuloTempo(ms){return horaUptime(ms);}
function desenharCaminho(ctx,points,index,x,y,suave){
  let inicio=false,prev=null;
  ctx.beginPath();
  for(const p of points){
    if(!Number.isFinite(p[index])){inicio=false;prev=null;continue;}
    const xx=x(p[1]),yy=y(p[index]);
    if(!inicio){ctx.moveTo(xx,yy);inicio=true;}
    else if(suave && prev){
      const mid=(prev[0]+xx)/2;
      ctx.bezierCurveTo(mid,prev[1],mid,yy,xx,yy);
    }else ctx.lineTo(xx,yy);
    prev=[xx,yy];
  }
}
function plotar(ch){
  const {ctx,w,h}=prepararCanvas(ch.el);
  const p=dadosVisiveis();
  const pad={l:47,r:14,t:24,b:36},pw=w-pad.l-pad.r,ph=h-pad.t-pad.b;
  let series=[...ch.series];
  if(mostrarBruto){
    if(ch===charts[0])series.push({i:7,n:'DHT bruto',cor:paleta.bruta,raw:true});
    if(ch===charts[1])series.push({i:8,n:'AMG máx. bruto',cor:paleta.bruta,raw:true});
    if(ch===charts[2])series.push({i:9,n:'Umidade bruta',cor:paleta.bruta,raw:true});
  }
  const valores=[];
  for(const q of p)for(const s of series)if(Number.isFinite(q[s.i]))valores.push(q[s.i]);
  let min=valores.length?Math.min(...valores):(ch.percent?40:20);
  let max=valores.length?Math.max(...valores):(ch.percent?80:40);
  const extra=Math.max(ch.percent?1.5:0.6,(max-min)*0.15);
  min-=extra;max+=extra;
  if(ch.percent){min=Math.max(0,min);max=Math.min(100,max);}
  if(max-min<1.5){const c=(max+min)/2;min=c-0.75;max=c+0.75;}
  const inicio=tempoVisivel==='all'?0:Math.max(0,msAtual-Number(tempoVisivel)*1000);
  const fim=Math.max(msAtual,inicio+1000);
  const eixoX=ms=>pad.l+pw*Math.max(0,Math.min(1,(ms-inicio)/(fim-inicio)));
  const eixoY=v=>pad.t+ph*(1-(v-min)/(max-min));
  ctx.font='11px system-ui, sans-serif';
  for(let i=0;i<=4;i++){
    const yy=pad.t+ph*i/4,v=max-(max-min)*i/4;
    ctx.strokeStyle='#2a3950';ctx.lineWidth=1;
    ctx.beginPath();ctx.moveTo(pad.l,yy);ctx.lineTo(w-pad.r,yy);ctx.stroke();
    ctx.fillStyle='#91a4bc';ctx.textAlign='right';ctx.fillText(v.toFixed(1),pad.l-8,yy+4);
  }
  for(let i=0;i<=4;i++){
    const x=pad.l+pw*i/4;
    const ms=inicio+(fim-inicio)*i/4;
    ctx.strokeStyle='#223148';ctx.beginPath();ctx.moveTo(x,pad.t);ctx.lineTo(x,h-pad.b);ctx.stroke();
    ctx.fillStyle='#91a4bc';ctx.textAlign='center';ctx.fillText(rotuloTempo(ms),x,h-10);
  }
  if(!p.length){ctx.fillStyle='#8297b1';ctx.textAlign='center';ctx.font='13px system-ui';ctx.fillText('Aguardando medições...',w/2,h/2);ch.meta=null;return;}
  for(const s of [...series].reverse()){
    desenharCaminho(ctx,p,s.i,eixoX,eixoY,true);
    ctx.setLineDash(s.raw?[4,5]:[]);
    ctx.lineWidth=s.raw?1.3:2.4;
    ctx.strokeStyle=s.cor;ctx.globalAlpha=s.raw?0.55:1;
    ctx.lineJoin='round';ctx.lineCap='round';ctx.stroke();
    ctx.setLineDash([]);ctx.globalAlpha=1;
  }
  // Marcador no ultimo valor de cada curva.
  for(const s of ch.series){
    const fimSerie=[...p].reverse().find(x=>Number.isFinite(x[s.i]));
    if(!fimSerie)continue;
    const x=eixoX(fimSerie[1]),y=eixoY(fimSerie[s.i]);
    ctx.beginPath();ctx.arc(x,y,3.8,0,Math.PI*2);
    ctx.fillStyle=s.cor;ctx.fill();ctx.strokeStyle='#0b1423';ctx.lineWidth=1.5;ctx.stroke();
  }
  ch.meta={p,pad,w,h,eixoX,eixoY,series};
}
function desenharGraficos(){charts.forEach(plotar);}
function configurarTooltip(ch){
  const mostrar=e=>{
    const m=ch.meta;if(!m||!m.p.length)return;
    const rect=ch.el.getBoundingClientRect(),x=e.clientX-rect.left;
    let escolhido=m.p[0],menor=Infinity;
    for(const r of m.p){const dist=Math.abs(m.eixoX(r[1])-x);if(dist<menor){escolhido=r;menor=dist;}}
    const px=m.eixoX(escolhido[1]);
    ch.tip.textContent='Desde o início: '+horaUptime(escolhido[1])+'\n'+m.series.map(s=>s.n+': '+numero(escolhido[s.i])+(ch.percent?' %':' °C')).join('\n');
    ch.tip.style.display='block';
    ch.tip.style.left=Math.min(rect.width-182,Math.max(5,px+10))+'px';
    ch.tip.style.top='15px';
    ch.el._cursor=px;
  };
  ch.el.addEventListener('pointermove',mostrar);
  ch.el.addEventListener('pointerdown',mostrar);
  ch.el.addEventListener('pointerleave',()=>ch.tip.style.display='none');
}
$('faixa').addEventListener('click',e=>{
  const b=e.target.closest('button');if(!b)return;
  tempoVisivel=b.dataset.sec;
  $('faixa').querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));
  desenharGraficos();
});
$('bruto').addEventListener('change',e=>{mostrarBruto=e.target.checked;desenharGraficos();});
$('csvDownload').addEventListener('click',()=>{$('csvMsg').textContent='Download solicitado. As amostras serão exportadas desde a inicialização.';});
$('recarregarTudo').addEventListener('click',carregarHistorico);
window.addEventListener('resize',desenharGraficos);
iniciarPixels();charts.forEach(configurarTooltip);
(async()=>{
  await sincronizarRelogio();
  await carregarHistorico();
  await atualizar();
  setInterval(atualizar,400);
  setInterval(carregarRecentes,1000);
  setInterval(atualizarStatus,1000);
  setInterval(desenharGraficos,1000);
  setInterval(()=>{if(Date.now()-relogioUltimoSync>300000)sincronizarRelogio();},60000);
})();
</script>
</body>
</html>
)HTML";

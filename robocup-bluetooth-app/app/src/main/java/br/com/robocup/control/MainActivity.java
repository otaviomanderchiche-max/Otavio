package br.com.robocup.control;

import android.Manifest;
import android.app.*;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class MainActivity extends Activity {
  static final UUID SERVICE=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442001");
  static final UUID CMD=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442002");
  static final UUID STATE=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442003");
  static final UUID MAC_CHAR=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442004");
  static final UUID CCCD=UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
  static final int BG=0xff0B1019, PANEL=0xff161F2E, PANEL2=0xff1B2638, LINE=0xff2E3B4F;
  static final int WHITE=0xffF6F9FC, GRAY=0xff97A8BF, CYAN=0xff53C6FF;
  static final int GREEN=0xff58DEA4, RED=0xffFF657A, GOLD=0xffF8C86D, BLUE=0xff5BA7FA;
  final Handler h=new Handler(Looper.getMainLooper());
  final LinkedHashMap<String,Robot> robots=new LinkedHashMap<>();
  final LinkedHashMap<String,Sighting> devices=new LinkedHashMap<>();
  final ArrayList<Phase> phases=new ArrayList<>();
  BluetoothAdapter adapter;BluetoothLeScanner scanner; boolean scanning=false,foreground=true;
  SharedPreferences preferences;int tab=0, blue=0, red=0, phaseIndex=0, remaining=600;
  boolean clockRunning=false, clockPaused=false;long deadline=0;
  LinearLayout root, pageMatch, pageRobots, pageBluetooth, robotsList, results, diagPanel;
  TextView timer, phaseName, phaseDetail, scoreBlue, scoreRed, statusTop, scanStatus, foundCount;
  TextView fleetText, diagBt, diagPerm, diagLocation; EditText inputMac;
  long lastRedraw=0;
  static class Robot {
    String mac, name, team="Azul", firmwareMac="", state="0", problem="";
    boolean connected=false, ready=false, connecting=false, wanted=false, writing=false;
    int outs=0;long lastTap=0, lastWrite=0, penalizedUntil=0, lastTry=0;
    BluetoothGatt gatt;BluetoothGattCharacteristic cmd;
    TextView title,sub,indicator,count;LinearLayout card;
    Robot(String m,String n){mac=m;name=n;}
  }
  static class Sighting{
    BluetoothDevice device;String name="";int rssi;long seen;
    Sighting(BluetoothDevice d,String n,int power){device=d;name=n;rssi=power;seen=SystemClock.elapsedRealtime();}
  }
  static class Phase {String name;int min;Phase(String n,int m){name=n;min=m;}}
  @Override public void onCreate(Bundle s){
    super.onCreate(s);
    getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);
    BluetoothManager m=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);adapter=m==null?null:m.getAdapter();
    preferences=getSharedPreferences("robocup_control_v2",MODE_PRIVATE);
    phases.add(new Phase("Calibração",5));phases.add(new Phase("1º tempo",10));
    phases.add(new Phase("Intervalo",5));phases.add(new Phase("2º tempo",10));
    restore();build();checkAccess(false);h.postDelayed(this::tick,250);
  }
  @Override protected void onResume(){super.onResume();foreground=true;}
  @Override protected void onPause(){
    // Perdeu a tela: trava todos. O ESP32 também tem watchdog próprio.
    for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
    foreground=false;save();super.onPause();
  }
  @Override protected void onDestroy(){
    stopSearch();for(Robot r:robots.values())if(r.gatt!=null)
      try{r.gatt.disconnect();r.gatt.close();}catch(Exception ignored){}
    h.removeCallbacksAndMessages(null);super.onDestroy();
  }
  int dp(float v){return(int)(v*getResources().getDisplayMetrics().density+.5f);}
  LinearLayout col(){LinearLayout l=new LinearLayout(this);l.setOrientation(1);return l;}
  LinearLayout row(){LinearLayout l=new LinearLayout(this);l.setOrientation(0);l.setGravity(Gravity.CENTER_VERTICAL);return l;}
  GradientDrawable shape(int fill,int stroke,int radius){
    GradientDrawable d=new GradientDrawable();d.setColor(fill);d.setCornerRadius(dp(radius));
    if(stroke!=0)d.setStroke(dp(1),stroke);return d;
  }
  TextView t(String value,int size,int color,boolean bold){
    TextView x=new TextView(this);x.setText(value);x.setTextColor(color);x.setTextSize(size);
    x.setIncludeFontPadding(false);if(bold)x.setTypeface(Typeface.DEFAULT,Typeface.BOLD);return x;
  }
  void p(View v,int a){v.setPadding(dp(a),dp(a),dp(a),dp(a));}
  void space(LinearLayout v,int height){View g=new View(this);v.addView(g,new LinearLayout.LayoutParams(1,dp(height)));}
  Button b(String label,int color,Runnable action){
    Button v=new Button(this);v.setText(label);v.setAllCaps(false);v.setTextSize(13);
    v.setTypeface(Typeface.DEFAULT,Typeface.BOLD);v.setTextColor(color==CYAN?BG:WHITE);
    v.setBackground(shape(color,0,12));v.setMinHeight(0);v.setMinimumHeight(0);
    v.setPadding(dp(12),dp(11),dp(12),dp(11));v.setOnClickListener(view->action.run());return v;
  }
  void pair(LinearLayout parent,Button one,Button two){
    LinearLayout r=row();LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(48),1);lp.rightMargin=dp(8);
    r.addView(one,lp);r.addView(two,new LinearLayout.LayoutParams(0,dp(48),1));parent.addView(r);
  }
  LinearLayout panel(LinearLayout into,int fill){
    LinearLayout v=col();p(v,15);v.setBackground(shape(fill,LINE,18));into.addView(v);return v;
  }
  void section(LinearLayout in,String name,String sub){
    space(in,19);in.addView(t(name,17,WHITE,true));
    if(!sub.isEmpty()){space(in,5);in.addView(t(sub,12,GRAY,false));}
    space(in,11);
  }
  void build(){
    ScrollView sv=new ScrollView(this);sv.setFillViewport(true);sv.setBackgroundColor(BG);
    root=col();p(root,16);sv.addView(root);setContentView(sv);
    LinearLayout top=row();root.addView(top);
    LinearLayout branding=col();branding.addView(t("ROBOCUP",12,CYAN,true));space(branding,3);
    branding.addView(t("MATCH CONTROL",23,WHITE,true));
    top.addView(branding,new LinearLayout.LayoutParams(0,-2,1));
    TextView v=t("BLE  •  V2",11,GREEN,true);p(v,10);v.setBackground(shape(PANEL2,LINE,20));top.addView(v);
    space(root,9);
    statusTop=t("Bluetooth • verificando...",12,GRAY,false);root.addView(statusTop);
    space(root,17);
    LinearLayout tabs=row();root.addView(tabs);
    String[] labels={"PARTIDA","ROBÔS","BLUETOOTH"};
    for(int i=0;i<3;i++){final int n=i;Button tabBtn=b(labels[i],PANEL2,()->setTab(n));
      LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(47),1);lp.rightMargin=i<2?dp(5):0;tabs.addView(tabBtn,lp);
      tabBtn.setTag(i);
    }
    space(root,16);
    pageMatch=col();root.addView(pageMatch);
    pageRobots=col();root.addView(pageRobots);
    pageBluetooth=col();root.addView(pageBluetooth);
    makeMatch();makeRobots();makeBluetooth();setTab(0);refresh();
  }
  void setTab(int i){
    tab=i;pageMatch.setVisibility(i==0?View.VISIBLE:View.GONE);
    pageRobots.setVisibility(i==1?View.VISIBLE:View.GONE);
    pageBluetooth.setVisibility(i==2?View.VISIBLE:View.GONE);
    LinearLayout r=(LinearLayout)root.getChildAt(4);
    if(r!=null){for(int j=0;j<r.getChildCount();j++){
      View child=r.getChildAt(j);if(child instanceof Button){
        child.setBackground(shape(j==i?CYAN:PANEL2,j==i?0:LINE,12));
        ((Button)child).setTextColor(j==i?BG:WHITE);
      }
    }}
  }
  void makeMatch(){
    LinearLayout board=panel(pageMatch,PANEL);
    board.addView(t("PLACAR AO VIVO",11,GRAY,true));space(board,13);
    LinearLayout scores=row();board.addView(scores);
    LinearLayout left=teamScore(true),right=teamScore(false);
    scores.addView(left,new LinearLayout.LayoutParams(0,-2,1));
    TextView sep=t("×",24,GRAY,true);p(sep,8);scores.addView(sep);
    scores.addView(right,new LinearLayout.LayoutParams(0,-2,1));
    space(board,15);
    LinearLayout clock=row();p(clock,14);clock.setBackground(shape(PANEL2,0,14));board.addView(clock);
    LinearLayout clockLabels=col();phaseName=t("1º tempo",13,CYAN,true);
    phaseDetail=t("Etapa 1 / 4",12,GRAY,false);clockLabels.addView(phaseName);space(clockLabels,5);clockLabels.addView(phaseDetail);
    clock.addView(clockLabels,new LinearLayout.LayoutParams(0,-2,1));
    timer=t("10:00",31,WHITE,true);timer.setTypeface(Typeface.MONOSPACE,Typeface.BOLD);clock.addView(timer);
    section(pageMatch,"Tempo da partida","Calibração, tempos e intervalos personalizados.");
    pair(pageMatch,b("INICIAR / PAUSAR",CYAN,this::toggleClock),b("PULAR ETAPA",PANEL2,this::skip));
    space(pageMatch,8);pageMatch.addView(b("CONFIGURAR PARTIDA",PANEL2,this::configureTime));
    section(pageMatch,"Controle geral","Cada robô obedece aos comandos individualmente.");
    pair(pageMatch,b("ATIVAR TODOS",0xff28594C,()->{for(Robot x:robots.values())if(x.penalizedUntil<SystemClock.elapsedRealtime())x.wanted=true;refresh();}),
      b("PARADA GERAL",0xff71313B,()->{for(Robot x:robots.values()){x.wanted=false;send(x,"0");}refresh();}));
    space(pageMatch,17);LinearLayout summary=panel(pageMatch,PANEL);
    summary.addView(t("RESUMO DE CONEXÕES",11,GRAY,true));space(summary,9);
    fleetText=t("0 robôs cadastrados",15,WHITE,true);summary.addView(fleetText);
    space(summary,9);summary.addView(b("ABRIR MEUS ROBÔS  →",PANEL2,()->setTab(1)));
  }
  LinearLayout teamScore(boolean azul){
    LinearLayout c=col();c.setGravity(Gravity.CENTER);
    c.addView(t(azul?"TIME AZUL":"TIME VERMELHO",12,azul?BLUE:RED,true));space(c,7);
    TextView score=t("00",39,WHITE,true);score.setTypeface(Typeface.MONOSPACE,Typeface.BOLD);
    if(azul)scoreBlue=score;else scoreRed=score;
    c.addView(score);space(c,8);
    LinearLayout buttons=row();buttons.setGravity(Gravity.CENTER);
    Button minus=b("−",PANEL2,()->{if(azul)blue=Math.max(0,blue-1);else red=Math.max(0,red-1);refresh();save();});
    Button plus=b("+",PANEL2,()->{if(azul)blue++;else red++;refresh();save();});
    LinearLayout.LayoutParams a=new LinearLayout.LayoutParams(dp(56),dp(40));a.rightMargin=dp(4);
    buttons.addView(minus,a);buttons.addView(plus,new LinearLayout.LayoutParams(dp(56),dp(40)));
    c.addView(buttons);return c;
  }
  void makeRobots(){
    LinearLayout header=panel(pageRobots,PANEL);
    header.addView(t("CONTROLE INDIVIDUAL",11,CYAN,true));space(header,7);
    header.addView(t("Dois toques no cartão: alterna 0 / 1.",15,WHITE,true));
    space(header,7);header.addView(t("VERMELHO = ativo   •   VERDE = parado   •   ÂMBAR = penalidade",11,GRAY,false));
    space(pageRobots,12);
    pair(pageRobots,b("NOVO ROBÔ",PANEL2,()->setTab(2)),
      b("PARAR TODOS",0xff71313B,()->{for(Robot x:robots.values()){x.wanted=false;send(x,"0");}refresh();}));
    space(pageRobots,12);robotsList=col();pageRobots.addView(robotsList);showRobots();
  }
  void showRobots(){
    if(robotsList==null)return;robotsList.removeAllViews();
    if(robots.isEmpty()){
      LinearLayout empty=panel(robotsList,PANEL);
      empty.addView(t("Nenhum robô cadastrado",16,WHITE,true));space(empty,8);
      empty.addView(t("Abra a aba Bluetooth, faça a busca e toque em ADICIONAR.",13,GRAY,false));
      return;
    }
    for(Robot x:robots.values()){
      LinearLayout card=col();p(card,15);card.setBackground(shape(PANEL,LINE,16));x.card=card;
      LinearLayout head=row();card.addView(head);
      LinearLayout names=col();x.title=t(x.name,17,WHITE,true);names.addView(x.title);space(names,6);
      x.sub=t("Time "+x.team+"  •  "+x.mac,11,GRAY,false);names.addView(x.sub);
      head.addView(names,new LinearLayout.LayoutParams(0,-2,1));
      x.indicator=t("PARADO",11,GREEN,true);p(x.indicator,9);x.indicator.setBackground(shape(0xff1E493D,0,10));head.addView(x.indicator);
      space(card,9);x.count=t("0 saídas • desconectado",12,GRAY,false);card.addView(x.count);
      space(card,11);pair(card,b("OUT OF BOUNDS",0xff584524,()->penalty(x)),
        b("EDITAR",PANEL2,()->edit(x)));
      card.setOnClickListener(view->{long now=SystemClock.elapsedRealtime();
        if(now-x.lastTap<=650){
          x.lastTap=0;
          if(x.penalizedUntil>now){toast("Robô penalizado. Aguarde.");return;}
          x.wanted=!x.wanted;
          if(!x.wanted)send(x,"0");else send(x,"1");
          refresh();save();
        }else{x.lastTap=now;toast("Toque de novo para alternar 0 / 1");}
      });
      robotsList.addView(card);space(robotsList,10);
    }
  }
  void makeBluetooth(){
    LinearLayout diag=panel(pageBluetooth,PANEL);
    diag.addView(t("DIAGNÓSTICO BLUETOOTH",11,CYAN,true));space(diag,12);
    diagBt=t("Bluetooth: verificando",13,WHITE,false);diag.addView(diagBt);space(diag,6);
    diagPerm=t("Permissão: verificando",13,WHITE,false);diag.addView(diagPerm);space(diag,6);
    diagLocation=t("Localização: verificando",13,WHITE,false);diag.addView(diagLocation);
    space(pageBluetooth,13);
    pair(pageBluetooth,b("BUSCAR TODOS",CYAN,this::startSearch),b("PARAR BUSCA",PANEL2,this::stopSearch));
    space(pageBluetooth,9);
    scanStatus=t("A busca mostra qualquer dispositivo BLE, inclusive sem nome.",12,GRAY,false);
    pageBluetooth.addView(scanStatus);space(pageBluetooth,11);
    LinearLayout manual=panel(pageBluetooth,PANEL);
    manual.addView(t("ADICIONAR POR MAC",11,GRAY,true));space(manual,8);
    inputMac=new EditText(this);inputMac.setSingleLine(true);inputMac.setHint("AA:BB:CC:DD:EE:FF");
    inputMac.setTextColor(WHITE);inputMac.setHintTextColor(GRAY);
    inputMac.setBackground(shape(PANEL2,LINE,12));p(inputMac,12);manual.addView(inputMac);
    space(manual,9);manual.addView(b("SALVAR MAC E CONECTAR",PANEL2,()->addMac(inputMac.getText().toString())));
    section(pageBluetooth,"Dispositivos encontrados","Os RC- aparecem primeiro. Outros BLE ajudam a diagnosticar a busca.");
    foundCount=t("Nenhum dispositivo ainda",12,GRAY,true);pageBluetooth.addView(foundCount);
    space(pageBluetooth,9);results=col();pageBluetooth.addView(results);
    space(pageBluetooth,14);pageBluetooth.addView(t(
      "Se nenhum dispositivo aparece, verifique o Monitor Serial do ESP32 a 115200 baud. A placa deve exibir [BLE] ANUNCIANDO e um MAC BLE.",12,GRAY,false));
    showDevices();
  }
  void addMac(String raw){
    String mac=raw.trim().toUpperCase(Locale.ROOT);
    if(!BluetoothAdapter.checkBluetoothAddress(mac)){toast("MAC inválido. Use AA:BB:CC:DD:EE:FF");return;}
    Robot x=robots.get(mac);if(x==null){x=new Robot(mac,"Robô "+(robots.size()+1));robots.put(mac,x);}
    inputMac.setText("");showRobots();refresh();save();
    Sighting found=devices.get(mac);if(found!=null)connect(x,found.device);
    else{toast("MAC salvo. Faça BUSCAR TODOS e confira se aparece.");startSearch();}
  }
  void showDevices(){
    if(results==null)return;
    results.removeAllViews();
    int rc=0;for(Sighting s:devices.values())if(s.name.startsWith("RC-"))rc++;
    foundCount.setText(devices.size()+" dispositivos BLE vistos • "+rc+" identificados como RC-");
    ArrayList<Map.Entry<String,Sighting>> items=new ArrayList<>(devices.entrySet());
    Collections.sort(items,(a,b)->{
      int ai=a.getValue().name.startsWith("RC-")?0:1;
      int bi=b.getValue().name.startsWith("RC-")?0:1;
      if(ai!=bi)return ai-bi;return b.getValue().rssi-a.getValue().rssi;
    });
    int max=0;for(Map.Entry<String,Sighting> e:items){
      if(max++>=60)break;
      String mac=e.getKey();Sighting s=e.getValue();
      LinearLayout block=col();p(block,12);block.setBackground(shape(PANEL,s.name.startsWith("RC-")?CYAN:LINE,14));
      LinearLayout line=row();block.addView(line);
      LinearLayout title=col();title.addView(t(s.name.isEmpty()?"BLE sem nome":s.name,14,WHITE,true));space(title,6);
      title.addView(t(mac+"   •   "+s.rssi+" dBm",11,GRAY,false));
      line.addView(title,new LinearLayout.LayoutParams(0,-2,1));
      line.addView(b(robots.containsKey(mac)?"CONECTAR":"ADICIONAR",s.name.startsWith("RC-")?CYAN:PANEL2,()->{
        Robot x=robots.get(mac);if(x==null){x=new Robot(mac,s.name.startsWith("RC-")?s.name:"Robô "+(robots.size()+1));robots.put(mac,x);showRobots();save();}
        connect(x,s.device);refresh();
      }));
      results.addView(block);space(results,7);
    }
  }
  boolean hasAccess(){
    if(Build.VERSION.SDK_INT>=31)return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED
      &&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;
    return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;
  }
  void checkAccess(boolean ask){
    if(!hasAccess()&&ask){
      if(Build.VERSION.SDK_INT>=31)
        requestPermissions(new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT},22);
      else requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION},22);
    }
    if(diagBt!=null)diagnostics();
  }
  @Override public void onRequestPermissionsResult(int r,String[] names,int[] outcomes){
    super.onRequestPermissionsResult(r,names,outcomes);diagnostics();
    if(r==22&&hasAccess())startSearch();
  }
  void diagnostics(){
    if(diagBt==null)return;
    boolean on=false;try{on=adapter!=null&&adapter.isEnabled();}catch(SecurityException ignored){on=false;}
    diagBt.setText("Bluetooth: "+(adapter==null?"não disponível":on?"LIGADO":"DESLIGADO"));
    diagPerm.setText("Permissão BLE: "+(hasAccess()?"CONCEDIDA":"NÃO CONCEDIDA"));
    android.location.LocationManager lm=(android.location.LocationManager)getSystemService(LOCATION_SERVICE);
    boolean loc=false;try{loc=lm!=null&&(Build.VERSION.SDK_INT>=28?lm.isLocationEnabled():lm.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER));}catch(Exception ignored){}
    diagLocation.setText("Localização do Android: "+(loc?"ligada":"desligada")+" (em alguns aparelhos afeta o scan)");
    statusTop.setText("BLE "+(on?"ativado":"desligado")+"   •   "+online()+" / "+robots.size()+" conectados");
  }
  void startSearch(){
    if(!hasAccess()){checkAccess(true);return;}
    if(adapter==null){toast("Bluetooth indisponível");return;}
    if(!adapter.isEnabled()){
      startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE));
      scanStatus.setText("Ative o Bluetooth, retorne e toque novamente em BUSCAR TODOS.");
      return;
    }
    if(scanning)return;
    try{
      scanner=adapter.getBluetoothLeScanner();
      if(scanner==null){scanStatus.setText("Scanner BLE indisponível. Reinicie o Bluetooth.");return;}
      devices.clear();showDevices();
      scanner.startScan(null,new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
        .setReportDelay(0).build(),callback);
      scanning=true;scanStatus.setText("Buscando todos os BLE nas proximidades...");
      h.postDelayed(()->{if(scanning&&devices.isEmpty())scanStatus.setText(
        "Nenhum BLE detectado: aproxime a placa, verifique permissões e [BLE] ANUNCIANDO.");},9000);
    }catch(Exception e){scanning=false;scanStatus.setText("Erro de busca: "+e.getMessage());}
  }
  void stopSearch(){
    try{if(scanning&&scanner!=null&&hasAccess())scanner.stopScan(callback);}catch(Exception ignored){}
    scanning=false;if(scanStatus!=null)scanStatus.setText("Busca encerrada • "+devices.size()+" dispositivos encontrados.");
  }
  final ScanCallback callback=new ScanCallback(){
    @Override public void onScanResult(int type,ScanResult r){
      if(!hasAccess())return;
      BluetoothDevice device=r.getDevice();if(device==null)return;
      String mac=device.getAddress().toUpperCase(Locale.ROOT);
      String name=r.getScanRecord()==null?null:r.getScanRecord().getDeviceName();
      if(name==null)try{name=device.getName();}catch(Exception ignored){}
      if(name==null)name="";
      final String foundName=name;final int dbm=r.getRssi();
      h.post(()->{
        Sighting existing=devices.get(mac);
        boolean update=existing==null||(!foundName.isEmpty()&&existing.name.isEmpty())||existing.rssi!=dbm;
        if(existing==null)devices.put(mac,new Sighting(device,foundName,dbm));
        else{existing.device=device;existing.rssi=dbm;if(!foundName.isEmpty())existing.name=foundName;}
        Robot known=robots.get(mac);
        if(known!=null&&!known.connected&&!known.connecting&&known.gatt==null
          &&SystemClock.elapsedRealtime()-known.lastTry>5000)connect(known,device);
        if(update&&SystemClock.elapsedRealtime()-lastRedraw>350){lastRedraw=SystemClock.elapsedRealtime();showDevices();}
        else if(update)h.removeCallbacks(pendingDraw);
        if(update)h.postDelayed(pendingDraw,500);
      });
    }
    @Override public void onScanFailed(int code){
      h.post(()->{scanning=false;scanStatus.setText("FALHA DO SCAN BLE: código "+code+
        " • tente reiniciar Bluetooth e conceder permissões.");});
    }
  };
  final Runnable pendingDraw=()->{lastRedraw=SystemClock.elapsedRealtime();showDevices();};
  void connect(Robot x,BluetoothDevice device){
    if(!hasAccess()){checkAccess(true);return;}
    if(x.gatt!=null||x.connecting)return;
    x.lastTry=SystemClock.elapsedRealtime();x.connecting=true;x.problem="Conectando...";
    try{
      x.gatt=device.connectGatt(this,false,new Gatt(x),BluetoothDevice.TRANSPORT_LE);
      if(x.gatt==null){x.connecting=false;x.problem="Não foi possível abrir GATT";}
    }catch(Exception e){x.connecting=false;x.problem=e.getMessage();}
    showRobots();refresh();
  }
  class Gatt extends BluetoothGattCallback{
    final Robot x;Gatt(Robot robot){x=robot;}
    @Override public void onConnectionStateChange(BluetoothGatt g,int status,int state){
      if(status==BluetoothGatt.GATT_SUCCESS&&state==BluetoothProfile.STATE_CONNECTED){
        h.post(()->{x.connected=true;x.connecting=false;x.problem="Descobrindo serviço RoboCup...";refresh();});
        try{g.discoverServices();}catch(Exception e){fail(g,"Falhou discoverServices");}
      }else if(state==BluetoothProfile.STATE_DISCONNECTED||status!=BluetoothGatt.GATT_SUCCESS){
        fail(g,"Desconectado (GATT "+status+")");
      }
    }
    void fail(BluetoothGatt g,String msg){
      h.post(()->{
        x.connected=false;x.connecting=false;x.ready=false;x.wanted=false;x.writing=false;x.cmd=null;x.problem=msg;
        if(x.gatt==g)x.gatt=null;
        try{g.close();}catch(Exception ignored){}
        refresh();
      });
    }
    @Override public void onServicesDiscovered(BluetoothGatt g,int status){
      BluetoothGattService service=status==BluetoothGatt.GATT_SUCCESS?g.getService(SERVICE):null;
      if(service==null){fail(g,"ESP sem UUID de serviço RoboCup");try{g.disconnect();}catch(Exception ignored){}return;}
      BluetoothGattCharacteristic command=service.getCharacteristic(CMD);
      if(command==null){fail(g,"Característica de comando ausente");return;}
      x.cmd=command;
      BluetoothGattCharacteristic state=service.getCharacteristic(STATE);
      boolean requested=false;
      if(state!=null){
        try{
          g.setCharacteristicNotification(state,true);
          BluetoothGattDescriptor descriptor=state.getDescriptor(CCCD);
          if(descriptor!=null){
            if(Build.VERSION.SDK_INT>=33)
              requested=g.writeDescriptor(descriptor,BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)==BluetoothStatusCodes.SUCCESS;
            else {descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);requested=g.writeDescriptor(descriptor);}
          }
        }catch(Exception ignored){}
      }
      if(!requested)afterSubscribe(g);
      h.post(()->{x.problem="UUID confirmado • configurando notificações";refresh();});
    }
    @Override public void onDescriptorWrite(BluetoothGatt g,BluetoothGattDescriptor d,int status){
      afterSubscribe(g);
    }
    void afterSubscribe(BluetoothGatt g){
      BluetoothGattService s=g.getService(SERVICE);
      BluetoothGattCharacteristic mac=s==null?null:s.getCharacteristic(MAC_CHAR);
      boolean started=false;
      if(mac!=null)try{started=g.readCharacteristic(mac);}catch(Exception ignored){}
      if(!started)ready();
    }
    @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,int status){
      if(status==BluetoothGatt.GATT_SUCCESS&&MAC_CHAR.equals(c.getUuid()))readMac(c.getValue());
      ready();
    }
    @Override public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value,int status){
      if(status==BluetoothGatt.GATT_SUCCESS&&MAC_CHAR.equals(c.getUuid()))readMac(value);
      ready();
    }
    void readMac(byte[] bytes){
      if(bytes!=null){String str=new String(bytes,StandardCharsets.UTF_8).trim().toUpperCase(Locale.ROOT);
        if(BluetoothAdapter.checkBluetoothAddress(str))x.firmwareMac=str;}
    }
    void ready(){h.post(()->{
      x.ready=true;x.connected=true;x.problem="Serviço validado";x.wanted=false;refresh();send(x,"0");
    });}
    @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c){
      received(c.getValue());
    }
    @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value){received(value);}
    void received(byte[] bytes){if(bytes==null)return;
      String val=new String(bytes,StandardCharsets.UTF_8).trim();
      if(val.equals("0")||val.equals("1"))h.post(()->{x.state=val;refresh();});}
    @Override public void onCharacteristicWrite(BluetoothGatt g,BluetoothGattCharacteristic c,int status){
      h.post(()->{x.writing=false;if(status!=BluetoothGatt.GATT_SUCCESS)x.problem="Falha envio GATT "+status;refresh();});
    }
  }
  void send(Robot x,String value){
    if(!hasAccess()||!x.ready||x.gatt==null||x.cmd==null||x.writing)return;
    try{
      x.writing=true;x.lastWrite=SystemClock.elapsedRealtime();
      byte[] packet=value.getBytes(StandardCharsets.UTF_8);
      boolean ok;
      if(Build.VERSION.SDK_INT>=33)
        ok=x.gatt.writeCharacteristic(x.cmd,packet,BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)==BluetoothStatusCodes.SUCCESS;
      else{x.cmd.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);x.cmd.setValue(packet);ok=x.gatt.writeCharacteristic(x.cmd);}
      if(!ok){x.writing=false;x.problem="Falha ao enviar "+value;}
    }catch(Exception e){x.writing=false;x.problem="Exceção BLE "+e.getClass().getSimpleName();}
  }
  void penalty(Robot x){
    x.outs++;x.penalizedUntil=SystemClock.elapsedRealtime()+60000;
    send(x,"0");refresh();save();
  }
  void edit(Robot x){
    LinearLayout container=col();p(container,14);
    EditText name=new EditText(this);name.setText(x.name);container.addView(name);
    Spinner team=new Spinner(this);String[] options={"Azul","Vermelho"};
    team.setAdapter(new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,options));
    team.setSelection(x.team.equals("Azul")?0:1);container.addView(team);
    new AlertDialog.Builder(this).setTitle("Editar robô").setView(container)
      .setPositiveButton("Salvar",(d,w)->{x.name=name.getText().toString().trim();
        if(x.name.isEmpty())x.name="Robô";x.team=team.getSelectedItem().toString();refresh();save();})
      .setNegativeButton("Cancelar",null).show();
  }
  void toggleClock(){
    if(clockRunning){remaining=(int)Math.max(0,(deadline-SystemClock.elapsedRealtime()+999)/1000);
      clockRunning=false;clockPaused=true;for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
    }else{
      if(remaining<1)remaining=phases.get(phaseIndex).min*60;
      deadline=SystemClock.elapsedRealtime()+remaining*1000L;clockRunning=true;clockPaused=false;
    }
    refresh();
  }
  void skip(){
    for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
    boolean previously=clockRunning;
    phaseIndex=(phaseIndex+1)%phases.size();remaining=phases.get(phaseIndex).min*60;
    clockRunning=previously;
    if(previously)deadline=SystemClock.elapsedRealtime()+remaining*1000L;
    refresh();
  }
  void configureTime(){
    final String[] options={"5 min calibração + 10 + 5 + 10","10 + 5 intervalo + 10","Somente 10 minutos","Personalizar duração"};
    new AlertDialog.Builder(this).setTitle("Formato da partida").setItems(options,(d,which)->{
      if(which==0)preset(new int[]{5,10,5,10});
      if(which==1)preset(new int[]{0,10,5,10});
      if(which==2)preset(new int[]{0,10,0,0});
      if(which==3)customTime();
    }).show();
  }
  void preset(int[] ms){
    phases.clear();if(ms[0]>0)phases.add(new Phase("Calibração",ms[0]));
    if(ms[1]>0)phases.add(new Phase("1º tempo",ms[1]));
    if(ms[2]>0)phases.add(new Phase("Intervalo",ms[2]));
    if(ms[3]>0)phases.add(new Phase("2º tempo",ms[3]));
    phaseIndex=0;remaining=phases.get(0).min*60;clockRunning=false;
    for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
    refresh();save();
  }
  void customTime(){
    LinearLayout inputs=col();p(inputs,16);
    String[] names={"Calibração (min)","1º tempo (min)","Intervalo (min)","2º tempo (min)"};
    int[] defaults={5,10,5,10};EditText[] fields=new EditText[4];
    for(int i=0;i<4;i++){inputs.addView(t(names[i],14,Color.DKGRAY,true));
      EditText e=new EditText(this);e.setInputType(2);e.setText(""+defaults[i]);inputs.addView(e);fields[i]=e;}
    new AlertDialog.Builder(this).setTitle("Minutos de cada etapa").setView(inputs)
      .setPositiveButton("Aplicar",(d,w)->{
        int[] values=new int[4];try{
          for(int i=0;i<4;i++){values[i]=Integer.parseInt(fields[i].getText().toString());
            if(values[i]<0||values[i]>120)throw new Exception();}
          if(values[1]<=0)throw new Exception();preset(values);
        }catch(Exception e){toast("Informe 1º tempo maior que 0; os demais de 0 a 120.");}
      }).setNegativeButton("Cancelar",null).show();
  }
  void tick(){
    long now=SystemClock.elapsedRealtime();
    if(clockRunning){
      remaining=(int)Math.max(0,(deadline-now+999)/1000);
      if(remaining==0){
        if(phaseIndex<phases.size()-1){
          phaseIndex++;remaining=phases.get(phaseIndex).min*60;deadline=now+remaining*1000L;
          for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
        }else{
          clockRunning=false;for(Robot r:robots.values()){r.wanted=false;send(r,"0");}
        }
      }
    }
    for(Robot r:robots.values()){
      if(r.penalizedUntil>0&&now>=r.penalizedUntil)r.penalizedUntil=0;
      if(r.writing&&now-r.lastWrite>3000){r.writing=false;r.problem="Escrita BLE sem resposta";}
      boolean interval=clockRunning&&phases.get(phaseIndex).name.equals("Intervalo");
      boolean want=foreground&&r.wanted&&r.penalizedUntil==0&&!interval;
      if(r.ready&&!r.writing&&now-r.lastWrite> (want?950:1300) &&(want||r.state.equals("1")))
        send(r,want?"1":"0");
    }
    refresh();h.postDelayed(this::tick,250);
  }
  int online(){int n=0;for(Robot x:robots.values())if(x.ready&&x.connected)n++;return n;}
  void refresh(){
    if(timer!=null){
      timer.setText(String.format(Locale.ROOT,"%02d:%02d",remaining/60,remaining%60));
      phaseName.setText(phases.get(phaseIndex).name+(clockRunning?"   •   EM ANDAMENTO":"   •   PAUSADO"));
      phaseDetail.setText("Etapa "+(phaseIndex+1)+" de "+phases.size());
      scoreBlue.setText(String.format(Locale.ROOT,"%02d",blue));
      scoreRed.setText(String.format(Locale.ROOT,"%02d",red));
      fleetText.setText(online()+" conectados  /  "+robots.size()+" cadastrados");
    }
    for(Robot x:robots.values()){
      if(x.card==null)continue;
      long now=SystemClock.elapsedRealtime();
      boolean penalized=x.penalizedUntil>now;
      boolean active=x.connected&&x.ready&&x.state.equals("1")&&!penalized;
      int color=penalized?GOLD:active?RED:x.ready?GREEN:GRAY;
      int fill=penalized?0xff443820:active?0xff49242E:x.ready?0xff1F4136:PANEL;
      x.card.setBackground(shape(fill,LINE,16));
      x.title.setText(x.name);x.sub.setText("TIME "+x.team.toUpperCase(Locale.ROOT)+"   •   "+x.mac);
      x.indicator.setText(penalized?"PENA "+((x.penalizedUntil-now+999)/1000)+"s":active?"ATIVO 1":x.ready?"PARADO 0":x.connecting?"CONECTANDO":"OFFLINE");
      x.indicator.setTextColor(color);x.indicator.setBackground(shape(PANEL2,0,10));
      x.count.setText(x.outs+" saída(s)  •  "+(x.problem.isEmpty()?"BLE aguardando":x.problem)
        +(x.firmwareMac.isEmpty()?"":" • MAC firmware "+x.firmwareMac));
    }
    if(diagBt!=null)diagnostics();
  }
  void toast(String msg){Toast.makeText(this,msg,Toast.LENGTH_SHORT).show();}
  void save(){
    try{
      JSONArray a=new JSONArray();for(Robot r:robots.values()){
        JSONObject o=new JSONObject();o.put("mac",r.mac);o.put("name",r.name);o.put("team",r.team);o.put("outs",r.outs);a.put(o);}
      JSONArray f=new JSONArray();for(Phase phase:phases){
        JSONObject o=new JSONObject();o.put("name",phase.name);o.put("min",phase.min);f.put(o);}
      preferences.edit().putString("robots",a.toString()).putString("phases",f.toString())
        .putInt("blue",blue).putInt("red",red).apply();
    }catch(Exception ignored){}
  }
  void restore(){
    blue=preferences.getInt("blue",0);red=preferences.getInt("red",0);
    try{
      JSONArray a=new JSONArray(preferences.getString("robots","[]"));
      for(int i=0;i<a.length();i++){JSONObject o=a.getJSONObject(i);String mac=o.optString("mac","");
        if(!BluetoothAdapter.checkBluetoothAddress(mac))continue;
        Robot x=new Robot(mac,o.optString("name","Robô"));x.team=o.optString("team","Azul");
        x.outs=o.optInt("outs",0);robots.put(mac,x);}
      JSONArray list=new JSONArray(preferences.getString("phases","[]"));
      if(list.length()>0){phases.clear();for(int i=0;i<list.length();i++){
        JSONObject item=list.getJSONObject(i);phases.add(new Phase(item.optString("name","Tempo"),Math.max(1,item.optInt("min",10))));}}
    }catch(Exception ignored){}
    if(phases.isEmpty())phases.add(new Phase("1º tempo",10));remaining=phases.get(0).min*60;
  }
}
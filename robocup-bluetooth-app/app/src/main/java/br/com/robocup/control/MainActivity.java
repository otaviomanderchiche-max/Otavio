package br.com.robocup.control;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.*;
import android.bluetooth.le.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.*;
import android.view.*;
import android.widget.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class MainActivity extends Activity {
 static final UUID SERVICE=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442001");
 static final UUID COMMAND=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442002");
 static final UUID STATE=UUID.fromString("b8b7d610-4304-4ac1-9c68-0b3d87442003");
 static final UUID CCCD=UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
 final Handler h=new Handler(Looper.getMainLooper());
 final LinkedHashMap<String,Peer> peers=new LinkedHashMap<>();
 final LinkedHashMap<String,BluetoothDevice> discovered=new LinkedHashMap<>();
 BluetoothAdapter bt; BluetoothLeScanner scanner; boolean scanning=false, appVisible=false;
 LinearLayout list, found, base; EditText macInput; TextView info, clock, scoreA, scoreB;
 int blue=0,red=0; long clockEnds=0; int seconds=600; boolean match=false;
 static class Peer {
   String mac, label, team="Azul", effective="0";
   BluetoothDevice device; BluetoothGatt gatt; BluetoothGattCharacteristic command;
   boolean connecting=false, connected=false, ready=false, wanted=false, busy=false;
   long lastWrite=0, penaltyUntil=0, lastTap=0; int outs=0;
   LinearLayout card; TextView name, state, details;
   Peer(String m,String n){mac=m;label=n;}
 }
 int dp(int x){return (int)(x*getResources().getDisplayMetrics().density+.5);}
 LinearLayout col(){LinearLayout l=new LinearLayout(this);l.setOrientation(1);return l;}
 LinearLayout row(){LinearLayout l=new LinearLayout(this);l.setOrientation(0);l.setGravity(Gravity.CENTER_VERTICAL);return l;}
 TextView text(String s,int sz,int color,boolean bold){TextView t=new TextView(this);t.setText(s);t.setTextSize(sz);t.setTextColor(color);if(bold)t.setTypeface(null,Typeface.BOLD);return t;}
 void pad(View v,int n){v.setPadding(dp(n),dp(n),dp(n),dp(n));}
 void gap(LinearLayout l){View v=new View(this);l.addView(v,new LinearLayout.LayoutParams(1,dp(9)));}
 Button btn(String s,Runnable a){Button b=new Button(this);b.setText(s);b.setAllCaps(false);b.setOnClickListener(v->a.run());return b;}
 void toast(String s){Toast.makeText(this,s,Toast.LENGTH_SHORT).show();}
 @Override public void onCreate(Bundle b){
  super.onCreate(b);getWindow().setStatusBarColor(0xff101722);getWindow().setNavigationBarColor(0xff101722);
  BluetoothManager manager=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);bt=manager==null?null:manager.getAdapter();
  ScrollView sv=new ScrollView(this);sv.setBackgroundColor(0xff101722);base=col();pad(base,14);sv.addView(base);setContentView(sv);
  base.addView(text("ROBOCUP CONTROL BLE",23,Color.WHITE,true));
  base.addView(text("Detecta ESP32 RC- e envia comandos 0/1",13,0xffaabbcc,false));gap(base);
  info=text("Aguardando Bluetooth...",13,0xffaabbcc,false);base.addView(info);
  base.addView(btn("PROCURAR ROBÔS POR BLUETOOTH",this::scan));base.addView(btn("PARAR BUSCA",this::stop));
  macInput=new EditText(this);macInput.setTextColor(Color.WHITE);macInput.setHintTextColor(0xffaabbcc);macInput.setHint("MAC BLE AA:BB:CC:DD:EE:FF");macInput.setSingleLine(true);base.addView(macInput);
  base.addView(btn("ADICIONAR MAC",()->addMac(macInput.getText().toString().trim())));
  found=col();base.addView(found);
  base.addView(text("PLACAR MANUAL",18,Color.WHITE,true));
  LinearLayout scores=row();scoreA=text("AZUL 0",20,0xff6cbcff,true);scoreB=text("VERMELHO 0",20,0xffff7777,true);
  Button ap=btn("Azul +",()->{blue++;draw();}),am=btn("Azul −",()->{blue=Math.max(0,blue-1);draw();});
  Button bp=btn("Verm. +",()->{red++;draw();}),bm=btn("Verm. −",()->{red=Math.max(0,red-1);draw();});
  base.addView(scoreA);base.addView(scoreB);base.addView(ap);base.addView(am);base.addView(bp);base.addView(bm);
  base.addView(text("TEMPO DA PARTIDA",18,Color.WHITE,true));
  clock=text("10:00",29,Color.WHITE,true);base.addView(clock);
  base.addView(btn("INICIAR / PAUSAR",()->{
   if(match){seconds=(int)Math.max(0,(clockEnds-SystemClock.elapsedRealtime()+999)/1000);match=false;sendAllZero();}
   else{if(seconds<=0)seconds=600;clockEnds=SystemClock.elapsedRealtime()+seconds*1000L;match=true;}draw();
  }));
  base.addView(btn("ALTERAR DURAÇÃO (minutos)",()->{
   EditText input=new EditText(this);input.setInputType(2);input.setText("10");
   new AlertDialog.Builder(this).setTitle("Minutos de jogo").setView(input).setPositiveButton("Aplicar",(d,w)->{
    try{int m=Integer.parseInt(input.getText().toString());if(m<1||m>240)throw new Exception();
     match=false;seconds=m*60;sendAllZero();draw();
    }catch(Exception e){toast("Use de 1 a 240 minutos");}}).setNegativeButton("Cancelar",null).show();
  }));
  base.addView(text("MEUS ROBÔS · TOQUE DUAS VEZES PARA 0/1",18,Color.WHITE,true));
  base.addView(btn("PARAR TODOS",()->{for(Peer p:peers.values()){p.wanted=false;write(p,"0");}draw();}));
  list=col();base.addView(list);
  base.addView(text("Vermelho = ativo; verde = parado; laranja = penalizado.\nO ESP32 de teste controla LED/estado. Integre ao firmware dos motores antes de jogar.",12,0xffaabbcc,false));
  if(!hasPerm())requestPerm();draw();
  h.postDelayed(this::tick,600);
 }
 boolean hasPerm(){
  if(Build.VERSION.SDK_INT>=31)return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED
   &&checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;
  return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;
 }
 void requestPerm(){
  if(Build.VERSION.SDK_INT>=31)requestPermissions(new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT},10);
  else requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION},10);
 }
 @Override public void onRequestPermissionsResult(int q,String[] p,int[] r){super.onRequestPermissionsResult(q,p,r);if(q==10&&hasPerm())scan();}
 @Override public void onResume(){super.onResume();appVisible=true;}
 @Override public void onPause(){for(Peer p:peers.values()){p.wanted=false;write(p,"0");}appVisible=false;super.onPause();}
 @Override public void onDestroy(){stop();for(Peer p:peers.values())if(p.gatt!=null)try{p.gatt.disconnect();p.gatt.close();}catch(Exception e){}h.removeCallbacksAndMessages(null);super.onDestroy();}
 final ScanCallback scanCb=new ScanCallback(){
  @Override public void onScanResult(int cb,ScanResult result){
   if(!hasPerm())return;
   BluetoothDevice d=result.getDevice();String addr=d.getAddress().toUpperCase(Locale.ROOT);
   String name=result.getScanRecord()==null?null:result.getScanRecord().getDeviceName();
   if(name==null)try{name=d.getName();}catch(Exception e){}
   if((name==null||!name.startsWith("RC-"))&&!peers.containsKey(addr))return;
   if(!discovered.containsKey(addr)){discovered.put(addr,d);h.post(MainActivity.this::showFound);}
  }
  @Override public void onScanFailed(int code){h.post(()->toast("Erro de scan: "+code));}
 };
 void scan(){
  if(!hasPerm()){requestPerm();return;}
  if(bt==null){toast("Celular sem Bluetooth");return;}
  if(!bt.isEnabled()){startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE));return;}
  if(scanning)return;
  try{scanner=bt.getBluetoothLeScanner();scanning=true;discovered.clear();
   scanner.startScan(null,new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scanCb);
   info.setText("Procurando RC-...");
  }catch(Exception e){scanning=false;toast("Falha BLE: "+e.getMessage());}
 }
 void stop(){if(!scanning||scanner==null)return;try{if(hasPerm())scanner.stopScan(scanCb);}catch(Exception e){}scanning=false;}
 void showFound(){
  found.removeAllViews();for(Map.Entry<String,BluetoothDevice> entry:discovered.entrySet()){
   String mac=entry.getKey();BluetoothDevice device=entry.getValue();boolean registered=peers.containsKey(mac);
   found.addView(btn((registered?"CONECTAR ":"ADICIONAR RC-  ")+mac,()->{
    Peer p=peers.get(mac);if(p==null){p=new Peer(mac,"Robô "+(peers.size()+1));peers.put(mac,p);cards();}
    connect(p,device);
   }));
  }
  info.setText(discovered.size()+" ESP32 RoboCup encontrados.");
 }
 void addMac(String raw){
  String mac=raw.toUpperCase(Locale.ROOT);
  if(!BluetoothAdapter.checkBluetoothAddress(mac)){toast("MAC inválido");return;}
  Peer p=peers.get(mac);if(p==null){p=new Peer(mac,"Robô "+(peers.size()+1));peers.put(mac,p);cards();}
  macInput.setText("");if(hasPerm()&&bt!=null)try{connect(p,bt.getRemoteDevice(mac));}catch(Exception e){toast("Use Procurar Bluetooth");}
 }
 void connect(Peer p,BluetoothDevice d){
  if(!hasPerm()){requestPerm();return;}
  if(p.gatt!=null)return;try{p.device=d;p.connecting=true;p.gatt=d.connectGatt(this,false,new CB(p),BluetoothDevice.TRANSPORT_LE);
  toast("Conectando "+p.mac);draw();}catch(Exception e){p.connecting=false;p.gatt=null;toast("Falha de conexão");}
 }
 class CB extends BluetoothGattCallback{
  final Peer p;CB(Peer x){p=x;}
  @Override public void onConnectionStateChange(BluetoothGatt g,int status,int state){
   if(state==BluetoothProfile.STATE_CONNECTED&&status==BluetoothGatt.GATT_SUCCESS){
    h.post(()->{p.connected=true;p.connecting=false;draw();});
    try{g.discoverServices();}catch(Exception e){}
   }else if(state==BluetoothProfile.STATE_DISCONNECTED||status!=BluetoothGatt.GATT_SUCCESS){
    h.post(()->{p.connected=false;p.connecting=false;p.ready=false;p.busy=false;p.wanted=false;p.command=null;
     if(p.gatt==g)p.gatt=null;try{g.close();}catch(Exception e){}draw();});
   }
  }
  @Override public void onServicesDiscovered(BluetoothGatt g,int status){
   BluetoothGattService service=status==BluetoothGatt.GATT_SUCCESS?g.getService(SERVICE):null;
   if(service==null){h.post(()->toast("Firmware sem serviço BLE RoboCup"));try{g.disconnect();}catch(Exception e){}return;}
   p.command=service.getCharacteristic(COMMAND);
   if(p.command==null){h.post(()->toast("UUID de comando não encontrado"));return;}
   p.ready=true;p.busy=false;p.wanted=false;p.lastWrite=0;
   BluetoothGattCharacteristic state=service.getCharacteristic(STATE);
   if(state!=null)try{
    g.setCharacteristicNotification(state,true);
    BluetoothGattDescriptor cccd=state.getDescriptor(CCCD);
    if(cccd!=null){if(Build.VERSION.SDK_INT>=33)g.writeDescriptor(cccd,BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
    else{cccd.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);g.writeDescriptor(cccd);}}
   }catch(Exception e){}
   h.post(()->{draw();toast(p.label+" conectado!");});
  }
  @Override public void onDescriptorWrite(BluetoothGatt g,BluetoothGattDescriptor d,int status){h.post(()->write(p,"0"));}
  @Override public void onCharacteristicWrite(BluetoothGatt g,BluetoothGattCharacteristic c,int status){h.post(()->{p.busy=false;if(status!=BluetoothGatt.GATT_SUCCESS)toast("Erro de envio "+status);});}
  @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c){state(c.getValue());}
  @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] val){state(val);}
  void state(byte[] val){if(val!=null){String v=new String(val,StandardCharsets.UTF_8).trim();
   if(v.equals("0")||v.equals("1"))h.post(()->{p.effective=v;draw();});}}
 }
 void write(Peer p,String v){
  if(!hasPerm()||!p.ready||p.gatt==null||p.command==null||p.busy)return;
  try{p.busy=true;p.lastWrite=SystemClock.elapsedRealtime();byte[] bytes=v.getBytes(StandardCharsets.UTF_8);
   int result;if(Build.VERSION.SDK_INT>=33)result=p.gatt.writeCharacteristic(p.command,bytes,BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
   else{p.command.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);p.command.setValue(bytes);result=p.gatt.writeCharacteristic(p.command)?0:-1;}
   if(result!=0)p.busy=false;
  }catch(Exception e){p.busy=false;}
 }
 void sendAllZero(){for(Peer p:peers.values())write(p,"0");}
 void cards(){
  if(list==null)return;list.removeAllViews();
  for(Peer p:peers.values()){
   LinearLayout card=col();pad(card,13);card.setBackgroundColor(0xff213043);
   p.card=card;p.name=text(p.label,18,Color.WHITE,true);card.addView(p.name);
   p.state=text("PARADO",16,0xff21c88b,true);card.addView(p.state);
   p.details=text("",12,0xffcad7e6,false);card.addView(p.details);
   card.addView(btn("OUT OF BOUNDS (+1 saída / 1 minuto)",()->{
    p.outs++;p.penaltyUntil=SystemClock.elapsedRealtime()+60000;write(p,"0");draw();
   }));
   card.addView(btn("EDITAR NOME E TIME",()->edit(p)));
   card.setOnClickListener(v->{long now=SystemClock.elapsedRealtime();
    if(now-p.lastTap<550){p.lastTap=0;
     if(p.penaltyUntil>now){toast("Aguarde penalidade");return;}
     p.wanted=!p.wanted;if(!p.wanted)write(p,"0");draw();
    }else{p.lastTap=now;toast("Toque novamente para 0/1");}});
   list.addView(card);gap(list);
  }draw();
 }
 void edit(Peer p){
  LinearLayout layout=col();pad(layout,15);
  EditText name=new EditText(this);name.setText(p.label);layout.addView(name);
  Spinner team=new Spinner(this);String[] opts={"Azul","Vermelho"};
  team.setAdapter(new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,opts));
  team.setSelection(p.team.equals("Azul")?0:1);layout.addView(team);
  new AlertDialog.Builder(this).setTitle("Editar robô").setView(layout).setPositiveButton("Salvar",(d,w)->{
   p.label=name.getText().toString().trim();if(p.label.isEmpty())p.label="Robô";
   p.team=team.getSelectedItem().toString();draw();
  }).setNegativeButton("Cancelar",null).show();
 }
 void tick(){
  long now=SystemClock.elapsedRealtime();
  if(match){seconds=(int)Math.max(0,(clockEnds-now+999)/1000);if(seconds==0){match=false;sendAllZero();}}
  for(Peer p:peers.values()){
   if(p.penaltyUntil!=0&&now>=p.penaltyUntil)p.penaltyUntil=0;
   boolean desired=p.wanted&&p.penaltyUntil==0&&match&&appVisible;
   if(p.ready&&now-p.lastWrite>=(desired?900:1250)&&(desired||p.effective.equals("1")))write(p,desired?"1":"0");
  }draw();h.postDelayed(this::tick,250);
 }
 void draw(){
  if(clock==null)return;
  clock.setText(String.format(Locale.ROOT,"%02d:%02d%s",seconds/60,seconds%60,match?"  • EM JOGO":"  • PAUSADO"));
  scoreA.setText("AZUL "+blue);scoreB.setText("VERMELHO "+red);
  int online=0;for(Peer p:peers.values())if(p.ready&&p.connected)online++;
  if(info!=null&&!scanning)info.setText(online+" de "+peers.size()+" robôs conectados");
  long now=SystemClock.elapsedRealtime();
  for(Peer p:peers.values())if(p.card!=null){
   boolean penalty=p.penaltyUntil>now,active=p.ready&&p.connected&&p.effective.equals("1")&&!penalty;
   p.card.setBackgroundColor(penalty?0xff493621:active?0xff48262a:0xff1c372d);
   p.name.setText(p.label+" • "+p.team);
   p.state.setText(penalty?"PENALIZADO "+((p.penaltyUntil-now+999)/1000)+" s":active?"ATIVO (1)":p.ready?"PARADO (0)":"DESCONECTADO");
   p.state.setTextColor(penalty?0xffffc15b:active?0xffff6262:0xff22d08d);
   p.details.setText("BLE MAC: "+p.mac+"   |   saídas: "+p.outs+"\n"+
     (p.ready?"Conectado":"Sem conexão")+(p.wanted?" • comando desejado 1":""));
  }
 }
}
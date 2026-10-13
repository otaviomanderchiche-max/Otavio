import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'species_panel.dart';

class SpeciesDashboardPage extends StatefulWidget {
  const SpeciesDashboardPage({super.key});
  @override
  State<SpeciesDashboardPage> createState() => _SpeciesDashboardPageState();
}
class _SpeciesDashboardPageState extends State<SpeciesDashboardPage> {
  Timer? timer;
  double? temperature;
  double? humidity;
  String? error;
  bool busy=false;

  @override
  void initState() {
    super.initState();
    load();
    timer=Timer.periodic(const Duration(seconds:7),(_)=>load());
  }
  @override
  void dispose() {timer?.cancel();super.dispose();}
  Future<void> load() async {
    if(busy)return;
    busy=true;
    final client=HttpClient()..connectionTimeout=const Duration(seconds:5);
    try {
      final request=await client.getUrl(Uri.parse('http://192.168.4.1/api/readings')).timeout(const Duration(seconds:7));
      final response=await request.close().timeout(const Duration(seconds:7));
      if(response.statusCode!=200)throw const HttpException('ESP32 nao respondeu');
      final json=await utf8.decoder.bind(response).join();
      final data=jsonDecode(json) as Map<String,dynamic>;
      final t=(data['temp'] as num?)?.toDouble();
      final h=(data['hum'] as num?)?.toDouble();
      if(data['scdOk']!=true||t==null||h==null||h<0||h>100)
        throw const FormatException('Aguardando leitura SCD40/SCD41');
      if(mounted)setState((){temperature=t;humidity=h;error=null;});
    }catch(e){if(mounted)setState(()=>error='Erro ao atualizar: '+e.toString());}
    finally{client.close(force:true);busy=false;}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFFF5F7F5),
    appBar:AppBar(title:const Text('Espécies recomendadas',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
      backgroundColor:const Color(0xFF087D40),foregroundColor:Colors.white,
      actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))]),
    body:RefreshIndicator(onRefresh:load,child:ListView(children:[
      Container(padding:const EdgeInsets.all(22),
        decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF083B25),Color(0xFF13884E)])),
        child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('NATUREZA INTELIGENTE',style:TextStyle(color:Color(0xFFC4F6CE),fontSize:11,fontWeight:FontWeight.w800)),
          SizedBox(height:8),
          Text('Qual árvore combina com este ambiente?',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:23)),
        ])),
      if(error!=null)Padding(padding:const EdgeInsets.all(14),
        child:Text(error!,style:const TextStyle(color:Color(0xFFA7630D)))),
      if(temperature==null||humidity==null)
        const Padding(padding:EdgeInsets.all(28),child:Center(child:Text('Aguardando dados reais do ESP32...')))
      else ...[
        Padding(padding:const EdgeInsets.fromLTRB(20,16,20,0),
          child:Text('Temperatura: '+temperature!.toStringAsFixed(1)+'°C · Umidade do ar: '+humidity!.toStringAsFixed(0)+'%',
            style:const TextStyle(color:Color(0xFF52655B),fontWeight:FontWeight.w700))),
        RecommendedSpeciesPanel(temperature:temperature!,humidity:humidity!),
      ],
      const Padding(padding:EdgeInsets.fromLTRB(20,8,20,30),
        child:Text('Compatibilidade estimada a partir da temperatura e umidade do ar. '
          'O ranking é demonstrativo e não substitui análise de solo, luz e clima.',
          style:TextStyle(color:Color(0xFF637468),fontSize:12,height:1.5))),
    ])),
  );
}

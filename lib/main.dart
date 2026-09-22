import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'household_engine.dart';

void main() => runApp(const HomeFoodApp());

class HomeFoodApp extends StatefulWidget {
  const HomeFoodApp({super.key});
  @override State<HomeFoodApp> createState() => _HomeFoodAppState();
}

class _HomeFoodAppState extends State<HomeFoodApp> {
  int tab = 0;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  bool _listening = false;
  bool _speaking = false;
  String _transcript = '';
  String lang = 'EN';
  double budget = 250000, spent = 0;
  double gasLevel = 1.0, gasCapacity = 1.0, gasSpent = 0;
  final gasLogs = <Map<String,dynamic>>[];
  final meals = <List<dynamic>>[
    ['Ndolé + plantain','Littoral',4500], ['Eru + water fufu','Southwest',5000],
    ['Koki + ripe plantain','Centre',3500], ['Achombo + vegetables','West',4000],
    ['Rice + tomato chicken','All',4500], ['Beans + boiled plantain','All',3000],
    ['Cornchaff','Southwest',3500], ['Fufu corn + okra soup','Centre',3500],
  ];
  final pantry = <Map<String,dynamic>>[
    {'name':'Rice','qty':5.0,'unit':'kg','min':2.0,'location':'Dry store','useBy':'2027-01-01'}, {'name':'Beans','qty':3.0,'unit':'kg','min':1.0,'location':'Dry store','useBy':'2027-01-01'},
    {'name':'Plantain','qty':8.0,'unit':'bunches','min':2.0,'location':'Fridge','useBy':'2026-10-01'}, {'name':'Palm oil','qty':1.5,'unit':'L','min':0.5,'location':'Dry store','useBy':'2027-03-01'},
    {'name':'Tomatoes','qty':1.0,'unit':'kg','min':1.0,'location':'Fridge','useBy':'2026-09-28'}, {'name':'Onions','qty':1.2,'unit':'kg','min':0.5,'location':'Dry store','useBy':'2026-10-15'},
  ];
  final plan = <Map<String,dynamic>>[];
  final shopping = <Map<String,dynamic>>[];
  final purchaseHistory = <Map<String,dynamic>>[];
  final leftovers = <Map<String,dynamic>>[];
  final snacks = <Map<String,dynamic>>[
    {'child':'Child 1','day':'Mon','item':'banana + bread + water','qty':1,'cost':500.0,'prepared':false},
  ];
  final tasks = <Map<String,dynamic>>[
    {'task':'Sweep & mop','done':false},{'task':'Clean kitchen','done':false},{'task':'Clean fridge','done':false},{'task':'Check gas cylinder','done':false},{'task':'Laundry','done':false},
  ];

  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final p=await SharedPreferences.getInstance(); setState((){budget=p.getDouble('budget')??250000;spent=p.getDouble('spent')??0;lang=p.getString('lang')??'EN';}); final a=p.getString('pantry'),b=p.getString('tasks'),m=p.getString('meals'),pl=p.getString('plan'),sh=p.getString('shopping'),ph=p.getString('purchaseHistory'),sn=p.getString('snacks'),gl=p.getString('gasLogs'),lo=p.getString('leftovers'); if(a!=null){final x=jsonDecode(a) as List; pantry..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(b!=null){final x=jsonDecode(b) as List; tasks..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(m!=null){final x=jsonDecode(m) as List; meals..clear()..addAll(x.map((e)=>List<dynamic>.from(e as List)));} if(pl!=null){final x=jsonDecode(pl) as List; plan..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(sh!=null){final x=jsonDecode(sh) as List; shopping..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(ph!=null){final x=jsonDecode(ph) as List; purchaseHistory..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(sn!=null){final x=jsonDecode(sn) as List; snacks..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} gasLevel=p.getDouble('gasLevel')??1.0; gasCapacity=p.getDouble('gasCapacity')??1.0; gasSpent=p.getDouble('gasSpent')??0; if(gl!=null){final x=jsonDecode(gl) as List; gasLogs..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(lo!=null){final x=jsonDecode(lo) as List; leftovers..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(plan.isEmpty)_autoPlan(save:false); _refreshShopping(save:false); if(mounted)setState((){}); }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setDouble('budget',budget); await p.setDouble('spent',spent); await p.setString('lang',lang); await p.setString('meals',jsonEncode(meals)); await p.setString('pantry',jsonEncode(pantry)); await p.setString('tasks',jsonEncode(tasks)); await p.setString('plan',jsonEncode(plan)); await p.setString('shopping',jsonEncode(shopping)); await p.setString('purchaseHistory',jsonEncode(purchaseHistory)); await p.setString('snacks',jsonEncode(snacks)); await p.setDouble('gasLevel',gasLevel); await p.setDouble('gasCapacity',gasCapacity); await p.setDouble('gasSpent',gasSpent); await p.setString('gasLogs',jsonEncode(gasLogs)); await p.setString('leftovers',jsonEncode(leftovers)); }
  String t(String en,String fr)=>lang=='FR'?fr:en;
  double get remaining=>budget-spent;
  int get lowStock=>pantry.where((x)=>x['qty']<=x['min']).length;
  String _todayMeal(){
    if(leftovers.isNotEmpty) return leftovers.first['name'].toString();
    return plan.isEmpty?'Plan your week':plan[DateTime.now().weekday-1]['meal'].toString();
  }
  String _dinnerMeal()=>plan.isEmpty?'':plan[DateTime.now().weekday%7]['meal'].toString();
  void _refreshShopping({bool save=true}){
    final weekly=HouseholdEngine.weeklyShopping(plan,pantry);
    final low=HouseholdEngine.shoppingList(pantry);
    final merged=<String,Map<String,dynamic>>{};
    for(final x in low){merged[x['name'].toString().toLowerCase()]=Map<String,dynamic>.from(x);}
    for(final x in weekly){
      final key=x['name'].toString().toLowerCase();
      final existing=merged[key];
      if(existing!=null){
        existing['suggestedQty']=max(
          (existing['suggestedQty'] as num? ?? 0).toDouble(),
          (x['purchaseQty'] as num? ?? 0).toDouble(),
        );
        existing['priority']='planned';
      }else{
        merged[key]={
          'name':x['name'],
          'suggestedQty':x['purchaseQty'],
          'unit':x['unit'],
          'priority':'planned',
          'purchased':false,
        };
      }
    }
    final next=merged.values.toList();
    setState((){shopping..clear()..addAll(next);});
    if(save)_save();
  }
  void _autoPlan({bool save=true}){final next=HouseholdEngine.generateWeek(meals:meals,pantry:pantry,budgetRemaining:remaining);setState((){plan..clear()..addAll(next);});_refreshShopping(save:false);if(save)_save();}

  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'MY HOME FOOD OS',
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.green,scaffoldBackgroundColor:const Color(0xfff7f8f4)),
    home:Scaffold(
      appBar:AppBar(title:const Text('MY HOME FOOD OS',style:TextStyle(fontWeight:FontWeight.w800)),
        actions:[TextButton(onPressed:(){setState(()=>lang=lang=='EN'?'FR':'EN');_save();},child:Text(lang)),IconButton(onPressed:_showCopilot,icon:const Icon(Icons.auto_awesome))]),
      body:_page(),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:t('Home','Accueil')),
        NavigationDestination(icon:Icon(Icons.restaurant_menu),label:t('Meals','Repas')),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:t('Storage','Stock')),
        NavigationDestination(icon:Icon(Icons.cleaning_services_outlined),label:t('Care','Maison')),
        NavigationDestination(icon:Icon(Icons.bar_chart),label:t('Reports','Rapports')),
      ])));
  Widget _page()=>[_homePage(),_mealsPage(),_storagePage(),_carePage(),_reportsPage()][tab];

  Widget _homePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _hero(),const SizedBox(height:12),
    Row(children:[Expanded(child:_metric(t('Budget left','Budget restant'),remaining.toStringAsFixed(0)+' FCFA',Icons.account_balance_wallet)),const SizedBox(width:10),Expanded(child:_metric(t('Low stock','Stock bas'),lowStock.toString(),Icons.warning_amber))]),
    const SizedBox(height:12),
    _card(t('Today','Aujourd’hui'),[
      _line(Icons.restaurant,t('Lunch: ','Déjeuner : ')+_todayMeal()),
      _line(Icons.school,t('School snack: ','Goûter école : ')+(snacks.isEmpty?'—':snacks.first['item'].toString())),
      _line(Icons.nightlight,t('Dinner: ','Dîner : ')+_dinnerMeal()),
      const SizedBox(height:6),
      FilledButton.icon(onPressed:_cookTodayLunch,icon:const Icon(Icons.soup_kitchen),label:Text(t('Cook & consume lunch','Cuisiner & consommer le déjeuner'))),
    ]),
    const SizedBox(height:12),
    _card(t('School snack plan','Plan des goûters'),[
      for(final s in snacks.take(5)) _line(Icons.school,s['child'].toString()+' • '+s['day'].toString()+' • '+s['item'].toString()),
      TextButton.icon(onPressed:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:Text(t('School snacks','Goûters scolaires')),content:_snackPage())),icon:const Icon(Icons.edit),label:Text(t('Manage snacks','Gérer les goûters')))
    ]),
    const SizedBox(height:12),
    _card(t('Smart household insight','Conseil intelligent'),[_line(Icons.auto_awesome,lowStock>0?t('Some food is running low. Add it to shopping.','Certains aliments diminuent. Ajoutez-les aux achats.'):t('Stock is healthy. Reuse planned leftovers before cooking new food.','Le stock est bon. Utilisez les restes avant de cuisiner autre chose.'))]),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:_showCopilot,icon:const Icon(Icons.mic),label:Text(t('Talk to Home Copilot','Parler au Copilote Maison')))
  ]);

  Widget _hero()=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xff1b5e20),Color(0xff43a047)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.home_work,color:Colors.white,size:36),const SizedBox(height:10),
    Text(t('Your family food command center','Le centre de contrôle alimentaire de la famille'),style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800)),
    const SizedBox(height:8),Text(t('Offline • Budget-aware • Cameroon meals • Pantry • House care','Hors ligne • Budget • Repas camerounais • Stock • Maison'),style:const TextStyle(color:Colors.white70))
  ]));

  Widget _metric(String a,String b,IconData i)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i),const SizedBox(height:8),Text(a),Text(b,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))])));
  Widget _card(String title,List<Widget> children)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),...children])));
  Widget _line(IconData i,String s)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Icon(i,size:20),const SizedBox(width:10),Expanded(child:Text(s))]));

  Widget _mealsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Row(children:[Expanded(child:Text(t('Weekly menu','Menu de la semaine'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800))),IconButton(onPressed:_showAddMeal,icon:const Icon(Icons.add_circle))]),const SizedBox(height:10),
    _card(t('Live weekly plan','Plan hebdomadaire dynamique'),plan.map((x)=>_line(Icons.restaurant,'${x['day']} — ${x['meal']} • ${x['estimatedCost']} FCFA')).toList()),
    const SizedBox(height:12),Text(t('Cameroon meal library','Bibliothèque de repas camerounais'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
    ...meals.map((m)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.restaurant)),title:Text(m[0] as String),subtitle:Text(m[1].toString()+' • '+m[2].toString()+' FCFA'),trailing:IconButton(icon:const Icon(Icons.add_circle),onPressed:()=>_addExpense((m[2] as num).toDouble())))))
  ]);

  Widget _snackPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('School snacks','Goûters scolaires'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    const SizedBox(height:10),
    _card(t('Weekly snack plan','Plan hebdomadaire des goûters'),[
      ...snacks.map((x)=>CheckboxListTile(
        value:x['prepared']==true,
        onChanged:(v){if(v==true){_prepareSnack(snacks.indexOf(x));}else{setState(()=>x['prepared']=false);_save();}},
        title:Text(x['child'].toString()+' • '+x['day'].toString()),
        subtitle:Text(x['item'].toString()+' • '+x['qty'].toString()+' • '+x['cost'].toString()+' FCFA'),
      ))
    ]),
    FilledButton.icon(onPressed:_showAddSnack,icon:const Icon(Icons.add),label:Text(t('Add school snack','Ajouter un goûter')))
  ]);

  List<Map<String,dynamic>> _snackIngredients(String item){
    final q=item.toLowerCase();
    if(q.contains('banana')||q.contains('banane')) return [
      {'name':'Banana','qty':1.0,'unit':'piece'}
    ];
    if(q.contains('bread')||q.contains('pain')) return [
      {'name':'Bread','qty':1.0,'unit':'piece'}
    ];
    if(q.contains('groundnut')||q.contains('arachide')) return [
      {'name':'Groundnuts','qty':0.1,'unit':'kg'}
    ];
    if(q.contains('fruit')||q.contains('fruit')) return [
      {'name':'Banana','qty':1.0,'unit':'piece'}
    ];
    return [];
  }

  void _prepareSnack(int index){
    if(index<0||index>=snacks.length)return;
    final snack=snacks[index];
    if(snack['prepared']==true)return;
    final recipe=_snackIngredients(snack['item'].toString());
    if(recipe.isNotEmpty){
      setState(()=>pantry..clear()..addAll(HouseholdEngine.consumeRecipe(pantry,recipe)));
    }
    final cost=(snack['cost'] as num? ?? 0).toDouble();
    if(cost>0)_addExpense(cost);
    setState(()=>snack['prepared']=true);
    _refreshShopping(save:false);
    _save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
      t('Snack prepared: pantry and budget updated.','Goûter préparé : stock et budget mis à jour.')
    )));
  }

  void _showAddSnack(){
    final item=TextEditingController(), child=TextEditingController(text:'Child 1'), cost=TextEditingController(text:'500'), qty=TextEditingController(text:'1');
    showDialog(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(t('Add school snack','Ajouter un goûter scolaire')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:child,decoration:InputDecoration(labelText:t('Child','Enfant'))),
        TextField(controller:item,decoration:InputDecoration(labelText:t('Snack','Goûter'))),
        TextField(controller:qty,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Quantity','Quantité'))),
        TextField(controller:cost,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Cost FCFA','Coût FCFA'))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(t('Cancel','Annuler'))),
        FilledButton(onPressed:(){
          setState(()=>snacks.add({'child':child.text.trim().isEmpty?'Child 1':child.text.trim(),'day':['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][snacks.length%7],'item':item.text.trim(),'qty':double.tryParse(qty.text)||1,'cost':double.tryParse(cost.text)||0.0,'prepared':false}));
          _save();Navigator.pop(dialogContext);
        },child:Text(t('Add','Ajouter')))]
    ));
  }

  void _editStock(int index){
    if(index<0||index>=pantry.length)return;
    final item=pantry[index];
    final q=TextEditingController(text:item['qty'].toString());
    final min=TextEditingController(text:item['min'].toString());
    final useBy=TextEditingController(text:item['useBy']?.toString()??'');
    String location=item['location']?.toString()??'Dry store';
    showDialog(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setDialogState)=>AlertDialog(
      title:Text(t('Edit storage item','Modifier le stock')),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(item['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
        TextField(controller:q,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Quantity','Quantité'))),
        TextField(controller:min,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Minimum stock','Stock minimum'))),
        DropdownButtonFormField<String>(
          value:location,
          items:['Dry store','Fridge','Freezer'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
          onChanged:(v){if(v!=null)setDialogState(()=>location=v);},
          decoration:InputDecoration(labelText:t('Location','Emplacement')),
        ),
        TextField(controller:useBy,decoration:InputDecoration(labelText:t('Use-by date YYYY-MM-DD','Date limite AAAA-MM-JJ'))),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(t('Cancel','Annuler'))),
        FilledButton(onPressed:(){
          setState((){
            item['qty']=double.tryParse(q.text)||0;
            item['min']=double.tryParse(min.text)||0;
            item['location']=location;
            item['useBy']=useBy.text.trim();
          });
          _refreshShopping(save:false);_save();Navigator.pop(dialogContext);
        },child:Text(t('Save','Enregistrer')))
      ],
    )));
  }

  void _consumeStock(int index){
    if(index<0||index>=pantry.length)return;
    final q=TextEditingController(text:'1');
    showDialog(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(t('Consume stock','Consommer le stock')),
      content:TextField(controller:q,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Quantity to consume','Quantité à consommer'))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(t('Cancel','Annuler'))),
        FilledButton(onPressed:(){
          final amount=double.tryParse(q.text)||0;
          setState(()=>pantry[index]['qty']=max(0,(pantry[index]['qty'] as num? ?? 0).toDouble()-amount));
          _refreshShopping(save:false);_save();Navigator.pop(dialogContext);
        },child:Text(t('Consume','Consommer')))
      ],
    ));
  }

  void _deleteStock(int index){
    if(index<0||index>=pantry.length)return;
    setState(()=>pantry.removeAt(index));_refreshShopping(save:false);_save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Item removed from storage.','Article retiré du stock.'))));
  }

  Widget _storagePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('Pantry, fridge & freezer','Garde-manger, frigo & congélateur'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    const SizedBox(height:10),
    _card(t('Storage intelligence','Intelligence du stockage'),[
      _line(Icons.inventory_2,t('Dry store: long-life goods','Garde-manger : produits longue conservation')),
      _line(Icons.kitchen,t('Fridge: short-life fresh food','Frigo : produits frais à courte durée')),
      _line(Icons.ac_unit,t('Freezer: batch-cooked and frozen food','Congélateur : plats préparés et aliments congelés')),
      _line(Icons.shopping_cart,lowStock.toString()+' '+t('items need shopping','articles nécessitent des achats')),
    ]),
    ...pantry.map((x){
      final useBy=x['useBy']?.toString() ?? '';
      final d=DateTime.tryParse(useBy);
      final days=d==null?999:d.difference(DateTime.now()).inDays;
      final exp=days<=2;
      return Card(child:ListTile(
        leading:Icon(x['location']=='Freezer'?Icons.ac_unit:x['location']=='Fridge'?Icons.kitchen:Icons.inventory_2),
        title:Text(x['name'].toString()),
        subtitle:Text(x['qty'].toString()+' '+x['unit'].toString()+' • '+x['location'].toString()+' • '+(useBy.isEmpty?'No use-by':useBy)),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(onPressed:()=>_consumeStock(pantry.indexOf(x)),icon:const Icon(Icons.remove_circle_outline)),
          IconButton(onPressed:()=>_editStock(pantry.indexOf(x)),icon:const Icon(Icons.edit)),
          IconButton(onPressed:()=>_deleteStock(pantry.indexOf(x)),icon:const Icon(Icons.delete_outline)),
          exp?Chip(label:Text(days<0?t('EXPIRED','EXPIRÉ'):t('USE SOON','À UTILISER'))):x['qty']<=x['min']?const Chip(label:Text('BUY')):const Icon(Icons.check_circle,color:Colors.green),
        ]),
      ));
    }),
    if(shopping.isNotEmpty)_card(t('Live shopping list','Liste d’achats dynamique'),[
      for(var i=0;i<shopping.length;i++)CheckboxListTile(value:shopping[i]['purchased']==true,onChanged:(v)=>_purchaseShopping(i,v??false),title:Text(shopping[i]['name'].toString()),subtitle:Text(shopping[i]['suggestedQty'].toString()+' '+shopping[i]['unit'].toString()+' • '+shopping[i]['priority'].toString()))
    ]),
    FilledButton.icon(onPressed:_showAddStock,icon:const Icon(Icons.add),label:Text(t('Add stock','Ajouter stock'))),
    FilledButton.icon(onPressed:_showAddMeal,icon:const Icon(Icons.restaurant_menu),label:Text(t('Add meal','Ajouter un repas')))
  ]);

  Widget _carePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('House care','Entretien de la maison'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _card(t('Today’s checklist','Checklist du jour'),tasks.map((e)=>CheckboxListTile(value:e['done'],onChanged:(v){setState(()=>e['done']=v??false);_save();},title:Text(e['task'].toString()),controlAffinity:ListTileControlAffinity.leading)).toList()),
    _card(t('Gas management','Gestion du gaz'),[
      LinearProgressIndicator(value:gasCapacity<=0?0:(gasLevel/gasCapacity).clamp(0,1)),
      const SizedBox(height:8),
      _line(Icons.local_fire_department,(gasLevel*100).toStringAsFixed(0)+'% '+t('remaining','restant')),
      _line(Icons.payments,(gasSpent).toStringAsFixed(0)+' FCFA '+t('gas spending','dépenses gaz')),
      if(gasLevel/gasCapacity<=0.2)_line(Icons.warning,t('Gas is running low — consider a refill.','Le gaz est presque fini — prévoyez une recharge.')),
      FilledButton.icon(onPressed:_showGasRefill,icon:const Icon(Icons.add),label:Text(t('Record gas refill','Enregistrer une recharge')))
    ]),
    if(gasLogs.isNotEmpty)_card(t('Gas history','Historique du gaz'),[
      ...gasLogs.take(10).map((x)=>_line(Icons.receipt_long,x['date'].toString()+' • '+x['amount'].toString()+' FCFA'))
    ])
  ]);

  void _showGasRefill(){
    final cost=TextEditingController();
    final fill=TextEditingController(text:'1');
    showDialog(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(t('Gas refill','Recharge de gaz')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:fill,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Refill amount (fraction of cylinder)','Quantité rechargée (fraction de bouteille)'))),
        TextField(controller:cost,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Cost FCFA','Coût FCFA'))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(t('Cancel','Annuler'))),
        FilledButton(onPressed:(){
          final amount=(double.tryParse(fill.text)||0).clamp(0,1);
          final price=double.tryParse(cost.text)||0;
          setState(()=>gasLevel=(gasLevel+amount).clamp(0,gasCapacity));
          if(price>0){gasSpent+=price;_addExpense(price);}
          gasLogs.insert(0,{'date':DateTime.now().toIso8601String(),'amount':price,'fill':amount});
          _save();Navigator.pop(dialogContext);
        },child:Text(t('Save','Enregistrer')))
      ],
    ));
  }

  Widget _reportsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('Monthly report','Rapport mensuel'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _metric(t('Monthly budget','Budget mensuel'),budget.toStringAsFixed(0)+' FCFA',Icons.account_balance_wallet),
    _metric(t('Food spending','Dépenses nourriture'),spent.toStringAsFixed(0)+' FCFA',Icons.restaurant),
    _metric(t('Remaining','Reste'),remaining.toStringAsFixed(0)+' FCFA',Icons.savings),
    if(purchaseHistory.isNotEmpty)_card(t('Purchase history','Historique des achats'),[
      ...purchaseHistory.take(12).map((x)=>_line(Icons.receipt_long,
        x['name'].toString()+' — '+x['qty'].toString()+' '+x['unit'].toString()+
        (((x['cost'] as num?) ?? 0)>0 ? ' • '+((x['cost'] as num).toStringAsFixed(0))+' FCFA' : '')),
    ]),
    _card(t('Household intelligence','Intelligence du foyer'),[
      _line(Icons.trending_down,t('Reuse leftovers to reduce repeated cooking.','Réutilisez les restes pour réduire les cuissons répétées.')),
      _line(Icons.inventory,t('Buy long-life dry goods in bulk when budget permits.','Achetez les produits secs longue conservation en gros lorsque le budget le permet.')),
      _line(Icons.calendar_month,t('Repeat efficient meals instead of cooking something new every day.','Répétez les repas efficaces au lieu de cuisiner du nouveau chaque jour.'))
    ])
  ]);

  List<String> _ingredientsForMeal(String name){
    final q=name.toLowerCase();
    if(q.contains('ndolé')) return ['Plantain','Palm oil'];
    if(q.contains('eru')) return ['Palm oil'];
    if(q.contains('koki')) return ['Beans','Plantain','Palm oil'];
    if(q.contains('rice')) return ['Rice','Tomatoes'];
    if(q.contains('beans')) return ['Beans','Plantain','Onions'];
    if(q.contains('cornchaff')) return ['Beans','Palm oil'];
    if(q.contains('fufu corn')) return ['Palm oil'];
    return [];
  }
  void _useGas(double amount,String activity){
    if(amount<=0)return;
    setState(()=>gasLevel=(gasLevel-amount).clamp(0,gasCapacity));
    gasLogs.insert(0,{'date':DateTime.now().toIso8601String(),'amount':0.0,'fill':-amount,'activity':activity});
    _save();
  }

  void _cookTodayLunch(){
    final meal=_todayMeal();
    final usingLeftover=leftovers.isNotEmpty && leftovers.first['name'].toString()==meal;
    if(plan.isEmpty && !usingLeftover || meal=='Plan your week') return;
    final recipe=HouseholdEngine.recipeFor(meal);
    final ingredients=recipe.map((x)=>x['name']).toList();
    if(recipe.isNotEmpty){
      final next=HouseholdEngine.consumeRecipe(pantry,recipe);
      setState(()=>pantry..clear()..addAll(next));
      _refreshShopping();
      setState(()=>usingLeftover ? leftovers.removeAt(0) : leftovers.add({'name':meal,'portions':1,'useBy':'Tomorrow'}));
      _useGas(0.05,'Lunch: '+meal);
      _save();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Lunch cooked: pantry updated and a leftover portion saved.','Déjeuner cuisiné : stock mis à jour et une portion de reste enregistrée.'))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('No ingredient mapping is defined for this meal yet.','Les ingrédients de ce repas ne sont pas encore définis.'))));
    }
  }
  void _purchaseShopping(int index,bool purchased){
    if(index<0||index>=shopping.length)return;
    final item=shopping[index];
    setState(()=>item['purchased']=purchased);
    if(!purchased){_save();return;}
    final name=item['name'].toString().toLowerCase();
    final qty=(item['suggestedQty'] as num? ?? 0).toDouble();
    final pi=pantry.indexWhere((x)=>x['name'].toString().toLowerCase()==name);
    if(pi>=0){
      setState(()=>pantry[pi]['qty']=(pantry[pi]['qty'] as num? ?? 0).toDouble()+qty);
    } else {
      setState(()=>pantry.add({'name':item['name'],'qty':qty,'unit':item['unit'],'min':0.0}));
    }
    _refreshShopping(save:false);
    _save();
    _showPurchaseCost(item['name'].toString(),qty,item['unit'].toString());
  }

  void _showPurchaseCost(String itemName,double qty,String unit){
    final c=TextEditingController();
    showDialog(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(t('Record purchase cost','Enregistrer le coût de l’achat')),
      content:TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(
        labelText:t('Amount in FCFA (optional)','Montant en FCFA (facultatif)'),
      )),
      actions:[
        TextButton(onPressed:(){
          _recordPurchase(itemName,qty,unit,null);
          Navigator.pop(dialogContext);
        },child:Text(t('Skip','Ignorer'))),
        FilledButton(onPressed:(){
          final amount=double.tryParse(c.text.trim());
          _recordPurchase(itemName,qty,unit,amount);
          Navigator.pop(dialogContext);
        },child:Text(t('Save cost','Enregistrer')))
      ],
    ));
  }

  void _recordPurchase(String name,double qty,String unit,double? cost){
    final now=DateTime.now();
    setState(()=>purchaseHistory.insert(0,{
      'name':name,'qty':qty,'unit':unit,'cost':cost??0.0,'date':now.toIso8601String(),
    }));
    if(cost!=null && cost>=0 && cost>0)_addExpense(cost);
    else _save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
      t('Purchase recorded.','Achat enregistré.')
    )));
  }


  void _addExpense(double amount){setState(()=>spent+=amount);_save();ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(amount.toStringAsFixed(0)+' FCFA '+t('added to food spending','ajoutés aux dépenses nourriture'))));}
  void _showAddStock(){final c=TextEditingController();showDialog(context:context,builder:(_)=>AlertDialog(title:Text(t('Add pantry item','Ajouter un article')),content:TextField(controller:c,decoration:InputDecoration(labelText:t('Name','Nom'))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(t('Cancel','Annuler'))),FilledButton(onPressed:(){if(c.text.trim().isNotEmpty){setState(()=>pantry.add({'name':c.text.trim(),'qty':1.0,'unit':'item','min':0.0}));_refreshShopping();}Navigator.pop(context);},child:Text(t('Add','Ajouter')))]));}
  void _showCopilot() async {
    await _initSpeech();
    if(!mounted)return;
    _transcript='';
    final input=TextEditingController();
    showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Padding(
      padding:EdgeInsets.only(left:18,right:18,top:10,bottom:MediaQuery.of(ctx).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const CircleAvatar(child:Icon(Icons.auto_awesome)),const SizedBox(width:10),Expanded(child:Text(t('Home Copilot','Copilote Maison'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800))),IconButton(onPressed:()=>_speak(t('I can manage meals, stock, budget, shopping and house care.','Je peux gérer les repas, le stock, le budget, les achats et la maison.')),icon:Icon(_speaking?Icons.volume_up:Icons.volume_down))]),
        Text(t('Voice + local household actions','Voix + actions locales du foyer')),const SizedBox(height:10),
        TextField(controller:input,minLines:1,maxLines:3,decoration:InputDecoration(hintText:t('Type a command','Écrivez une commande'),border:const OutlineInputBorder())),
        const SizedBox(height:8),
        Row(children:[Expanded(child:FilledButton.icon(onPressed:_listening?null:()=>_listen(input,setSheet),icon:const Icon(Icons.mic),label:Text(_listening?t('Listening…','Écoute…'):t('Speak','Parler')))),const SizedBox(width:8),IconButton(onPressed:()=>_runVoiceCommand(input.text),icon:const Icon(Icons.send))]),
        if(_transcript.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(_transcript)),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:[
          ActionChip(label:Text(t('Plan my week','Planifie ma semaine')),onPressed:()=>_runVoiceCommand(t('plan my week','planifie ma semaine'))),
          ActionChip(label:Text(t('What is low?','Qu’est-ce qui finit ?')),onPressed:()=>_runVoiceCommand(t('what is low','qu’est-ce qui finit'))),
          ActionChip(label:Text(t('Shopping list','Liste d’achats')),onPressed:()=>_runVoiceCommand(t('shopping list','liste d’achats'))),
          ActionChip(label:Text(t('Budget status','État du budget')),onPressed:()=>_runVoiceCommand(t('budget status','état du budget'))),
        ])
      ])),
    )));
  }

  Future<void> _initSpeech() async {
    if(_speechReady)return;
    _speechReady=await _speech.initialize(onStatus:(_){if(mounted)setState(()=>_listening=_speech.isListening);},onError:(_){if(mounted)setState(()=>_listening=false);});
  }

  Future<void> _listen(TextEditingController input, StateSetter setSheet) async {
    await _initSpeech();
    if(!_speechReady)return;
    setSheet(()=>_listening=true);
    await _speech.listen(
      listenOptions:stt.SpeechListenOptions(listenFor:const Duration(seconds:12),pauseFor:const Duration(seconds:3),partialResults:true,onDevice:true,localeId:lang=='FR'?'fr_FR':'en_US'),
      onResult:(SpeechRecognitionResult r){
        input.text=r.recognizedWords;
        if(mounted)setSheet(()=>_transcript=r.recognizedWords);
        if(r.finalResult){setSheet(()=>_listening=false);_runVoiceCommand(r.recognizedWords);}
      },
    );
  }

  Future<void> _speak(String text) async {
    if(!mounted)return;
    setState(()=>_speaking=true);
    await _tts.setLanguage(lang=='FR'?'fr-FR':'en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
    if(mounted)setState(()=>_speaking=false);
  }

  Future<void> _runVoiceCommand(String raw) async {
    final q=raw.toLowerCase().trim();
    if(q.isEmpty)return;
    String answer;
    if(q.contains('plan')||q.contains('menu')||q.contains('week')||q.contains('semaine')){
      _autoPlan(); answer=t('The weekly menu has been planned from your meal library.','Le menu hebdomadaire a été planifié depuis votre bibliothèque de repas.');
    } else if(q.contains('low')||q.contains('stock')||q.contains('finit')||q.contains('manque')){
      answer=lowStock==0?t('Nothing is below the minimum stock level.','Aucun article n’est sous le seuil minimum.'):lowStock.toString()+' '+t('items are low. Open Storage.','articles sont bas. Ouvrez Stock.'); setState(()=>tab=2);
    } else if(q.contains('shopping')||q.contains('achat')){
      _refreshShopping(); setState(()=>tab=2); answer=t('Your live shopping list is ready.','Votre liste d’achats dynamique est prête.');
    } else if(q.contains('budget')||q.contains('money')||q.contains('argent')){
      answer=t('You have ','Il vous reste ')+remaining.toStringAsFixed(0)+' FCFA '+t('remaining.','restants.'); setState(()=>tab=4);
    } else if(q.contains('care')||q.contains('house')||q.contains('maison')||q.contains('tâche')||q.contains('task')){
      setState(()=>tab=3); answer=t('I opened house care.','J’ai ouvert l’entretien de la maison.');
    } else {
      answer=t('Try: plan my week, what is low, shopping list, budget status, or house care.','Essayez : planifie ma semaine, qu’est-ce qui finit, liste d’achats, état du budget ou entretien de la maison.');
    }
    if(mounted)setState(()=>_transcript=answer);
    await _speak(answer);
  }

  Future<void> _showAddMeal() async {
    final name=TextEditingController(),region=TextEditingController(text:'All'),cost=TextEditingController(text:'3500');
    await showDialog(context:context,builder:(_)=>AlertDialog(title:Text(t('Add meal','Ajouter un repas')),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:InputDecoration(labelText:t('Meal name','Nom du repas'))),
      TextField(controller:region,decoration:InputDecoration(labelText:t('Region','Région'))),
      TextField(controller:cost,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Estimated cost FCFA','Coût estimé FCFA'))),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(t('Cancel','Annuler'))),FilledButton(onPressed:(){if(name.text.trim().isNotEmpty){setState(()=>meals.add([name.text.trim(),region.text.trim(),double.tryParse(cost.text)??0]));_save();}Navigator.pop(context);},child:Text(t('Add','Ajouter')))]));
  }

  @override void dispose(){_speech.stop();_tts.stop();super.dispose();}
}

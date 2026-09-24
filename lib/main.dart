import 'dart:math';
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
  double _freezerCapacity = 6.0;
  final budgetHistory = <Map<String,dynamic>>[];
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
    {'task':'Sweep & mop','done':false,'frequency':'Daily','next':'Today'},
    {'task':'Clean kitchen','done':false,'frequency':'Daily','next':'Today'},
    {'task':'Clean fridge','done':false,'frequency':'Weekly','next':'Saturday'},
    {'task':'Check gas cylinder','done':false,'frequency':'Weekly','next':'Monday'},
    {'task':'Laundry','done':false,'frequency':'Weekly','next':'Saturday'},
  ];

  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final p=await SharedPreferences.getInstance(); setState((){budget=p.getDouble('budget')??250000;spent=p.getDouble('spent')??0;lang=p.getString('lang')??'EN';}); final a=p.getString('pantry'),b=p.getString('tasks'),m=p.getString('meals'),pl=p.getString('plan'),sh=p.getString('shopping'),ph=p.getString('purchaseHistory'),sn=p.getString('snacks'),gl=p.getString('gasLogs'),lo=p.getString('leftovers'),bh=p.getString('budgetHistory'); if(a!=null){final x=jsonDecode(a) as List; pantry..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(b!=null){final x=jsonDecode(b) as List; tasks..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(m!=null){final x=jsonDecode(m) as List; meals..clear()..addAll(x.map((e)=>List<dynamic>.from(e as List)));} if(pl!=null){final x=jsonDecode(pl) as List; plan..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(sh!=null){final x=jsonDecode(sh) as List; shopping..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(ph!=null){final x=jsonDecode(ph) as List; purchaseHistory..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(sn!=null){final x=jsonDecode(sn) as List; snacks..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} gasLevel=p.getDouble('gasLevel')??1.0; gasCapacity=p.getDouble('gasCapacity')??1.0; gasSpent=p.getDouble('gasSpent')??0; _freezerCapacity=p.getDouble('freezerCapacity')??6.0; if(gl!=null){final x=jsonDecode(gl) as List; gasLogs..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(lo!=null){final x=jsonDecode(lo) as List; leftovers..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(bh!=null){final x=jsonDecode(bh) as List; budgetHistory..clear()..addAll(x.map((e)=>Map<String,dynamic>.from(e)));} if(plan.isEmpty)_autoPlan(save:false); _refreshShopping(save:false); if(mounted)setState((){}); }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setDouble('budget',budget); await p.setDouble('freezerCapacity',_freezerCapacity); await p.setDouble('spent',spent); await p.setString('lang',lang); await p.setString('meals',jsonEncode(meals)); await p.setString('pantry',jsonEncode(pantry)); await p.setString('tasks',jsonEncode(tasks)); await p.setString('plan',jsonEncode(plan)); await p.setString('shopping',jsonEncode(shopping)); await p.setString('purchaseHistory',jsonEncode(purchaseHistory)); await p.setString('snacks',jsonEncode(snacks)); await p.setDouble('gasLevel',gasLevel); await p.setDouble('gasCapacity',gasCapacity); await p.setDouble('gasSpent',gasSpent); await p.setString('gasLogs',jsonEncode(gasLogs)); await p.setString('leftovers',jsonEncode(leftovers)); await p.setString('budgetHistory',jsonEncode(budgetHistory)); }
  String t(String en,String fr)=>lang=='FR'?fr:en;
  void _feedback(String en,String fr,{bool important=false}) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior:SnackBarBehavior.floating,
      duration:Duration(seconds:important?4:2),
      content:Text(t(en,fr)),
      action:SnackBarAction(label:'OK',onPressed:(){}),
    ));
  }
  Future<void> _performNextBestAction() async {
    if(remaining<0){setState(()=>tab=2);_feedback('Budget is over. I opened Storage so we can use what is already at home.','Le budget est dépassé. J’ai ouvert Stock pour utiliser ce qui est déjà à la maison.',important:true);return;}
    final urgent=pantry.where((x){
      final d=DateTime.tryParse(x['useBy']?.toString()??'');
      return d!=null&&d.difference(DateTime.now()).inDays<=2&&(x['qty'] as num? ?? 0)>0;
    }).toList();
    if(urgent.isNotEmpty){
      final name=urgent.first['name'].toString();
      final index=pantry.indexWhere((x)=>x['name'].toString()==name);
      if(index>=0){
        final unit=pantry[index]['unit'].toString();
        final current=(pantry[index]['qty'] as num? ?? 0).toDouble();
        setState(()=>pantry[index]['qty']=max(0,current-1));
        _refreshShopping(save:false);await _save();
        _feedback('I used 1 '+unit+' of '+name+' to reduce waste.','J’ai utilisé 1 '+unit+' de '+name+' pour réduire le gaspillage.');
      }
      return;
    }
    if(leftovers.isNotEmpty){
      final used=leftovers.removeAt(0);
      await _save();setState((){});
      _feedback('I moved the saved leftover '+used['name'].toString()+' to first priority.','J’ai mis le reste '+used['name'].toString()+' en priorité.');
      return;
    }
    if(lowStock>0){setState(()=>tab=2);_feedback('I opened Storage: '+lowStock.toString()+' item(s) need attention.','J’ai ouvert Stock : '+lowStock.toString()+' article(s) nécessitent votre attention.');return;}
    final snackIndex=snacks.indexWhere((x)=>x['prepared']!=true);
    if(snackIndex>=0){setState(()=>tab=5);_feedback('I opened the next school snack.','J’ai ouvert le prochain goûter scolaire.');return;}
    final openTasks=tasks.where((x)=>x['done']!=true).length;
    if(openTasks>0){setState(()=>tab=3);_feedback('I opened House Care: '+openTasks.toString()+' task(s) are waiting.','J’ai ouvert Maison : '+openTasks.toString()+' tâche(s) attendent.');return;}
    _showCopilot();
  }
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
      floatingActionButton:FloatingActionButton.extended(onPressed:_showCopilot,icon:Icon(_listening?Icons.mic:Icons.auto_awesome),label:Text(_listening?t('Listening…','J’écoute…'):t('Talk to me','Parler'))),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:t('Home','Accueil')),
        NavigationDestination(icon:Icon(Icons.restaurant_menu),label:t('Meals','Repas')),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:t('Storage','Stock')),
        NavigationDestination(icon:Icon(Icons.cleaning_services_outlined),label:t('Care','Maison')),
        NavigationDestination(icon:Icon(Icons.bar_chart),label:t('Reports','Rapports')),
        NavigationDestination(icon:Icon(Icons.school_outlined),selectedIcon:Icon(Icons.school),label:t('Snacks','Goûters')),
      ])));
  Widget _page()=>[_homePage(),_mealsPage(),_storagePage(),_carePage(),_reportsPage(),_snackPage()][tab];

  Widget _homePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _hero(),
    const SizedBox(height:12),
    _card(t('HOME COPILOT','COPILOTE MAISON'),[
      Text(_humanGreeting(),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        ActionChip(avatar:const Icon(Icons.restaurant,size:18),label:Text(t('What can I cook?','Que puis-je cuisiner ?')),onPressed:()=>_executeVoiceCommand(t('what can I cook','que puis-je cuisiner'))),
        ActionChip(avatar:const Icon(Icons.shopping_cart,size:18),label:Text(t('What should I buy?','Que dois-je acheter ?')),onPressed:()=>_executeVoiceCommand(t('shopping list','liste d’achats'))),
        ActionChip(avatar:const Icon(Icons.account_balance_wallet,size:18),label:Text(t('Budget','Budget')),onPressed:_showBudgetEditor),
      ]),
    ]),
    const SizedBox(height:12),
    _card(t('MONTHLY BUDGET','BUDGET MENSUEL'),[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(budget.toStringAsFixed(0)+' FCFA',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(t('Spent: ','Dépensé : ')+spent.toStringAsFixed(0)+' FCFA • '+t('Left: ','Reste : ')+remaining.toStringAsFixed(0)+' FCFA')])),IconButton(onPressed:_showBudgetEditor,icon:const Icon(Icons.edit_note),tooltip:t('Edit budget','Modifier le budget'))]),
      const SizedBox(height:8),LinearProgressIndicator(value:budget<=0?0:(spent/budget).clamp(0,1),minHeight:8,borderRadius:BorderRadius.circular(8)),
    ]),


    Text(t('HOME INTELLIGENCE','INTELLIGENCE MAISON'),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),
    _card(t('Today at a glance','Vue d’ensemble du jour'),[
      _line(Icons.restaurant,t('Lunch: ','Déjeuner : ')+_todayMeal()),
      _line(Icons.nightlight,t('Dinner: ','Dîner : ')+_dinnerMeal()),
      _line(Icons.school,t('School snack: ','Goûter école : ')+(snacks.isEmpty?'—':snacks.first['item'].toString())),
      _line(Icons.inventory_2,t('Low stock: ','Stock bas : ')+lowStock.toString()),
      _line(Icons.shopping_cart,t('Shopping items: ','Articles à acheter : ')+shopping.where((x)=>x['purchased']!=true).length.toString()),
    ]),
    const SizedBox(height:12),

    Row(children:[
      Expanded(child:_metric(t('Budget left','Budget restant'),remaining.toStringAsFixed(0)+' FCFA',Icons.account_balance_wallet)),
      const SizedBox(width:10),
      Expanded(child:_metric(t('Gas level','Niveau de gaz'),(gasLevel*100).toStringAsFixed(0)+'%',Icons.local_fire_department)),
    ]),
    const SizedBox(height:12),

    _card(t('DO IT NOW','À FAIRE MAINTENANT'),[
      Row(children:[
        Expanded(child:FilledButton.icon(onPressed:_cookTodayLunch,icon:const Icon(Icons.soup_kitchen),label:Text(t('Cook now','Cuisiner')))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(
          onPressed:(){
            if(leftovers.isEmpty){
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('No saved leftover to use first.','Aucun reste enregistré à utiliser.'))));
              return;
            }
            final used=leftovers.removeAt(0);
            _save();
            setState((){});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Used leftover: ','Reste utilisé : ')+used['name'].toString())));
          },
          icon:const Icon(Icons.replay),
          label:Text(t('Use first','Utiliser d’abord')),
        )),
      ]),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()=>setState(()=>tab=2),icon:const Icon(Icons.shopping_cart),label:Text(t('Buy today','Acheter')))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:()=>setState(()=>tab=4),icon:const Icon(Icons.shield),label:Text(t('Budget & reports','Budget & rapports')))),
      ]),
    ]),
    const SizedBox(height:12),

    Builder(builder:(context){
      final decisions=HouseholdEngine.mealDecisions(
        meals:meals,
        pantry:pantry,
        leftovers:leftovers,
        budgetLimit:remaining>0?remaining:0,
      );
      final ready=decisions.where((x)=>x['pantryReady']==true && x['withinBudget']==true).take(3).toList();
      return _card(t('COOK NOW INTELLIGENCE','INTELLIGENCE CUISINE'),[
        if(ready.isEmpty)
          _line(Icons.info_outline,t('No fully ready meal fits the current budget. Check shopping.','Aucun repas prêt ne respecte le budget actuel. Vérifiez les achats.'))
        else
          ...ready.map((x)=>_line(
            x['usesLeftover']==true?Icons.replay:Icons.check_circle,
            x['name'].toString()+' • '+(x['estimatedCost'] as double).toStringAsFixed(0)+' FCFA'
          )),
        const SizedBox(height:4),
        OutlinedButton.icon(
          onPressed:()=>_executeVoiceCommand('what can I cook'),
          icon:const Icon(Icons.restaurant),
          label:Text(t('Ask what can be cooked','Demander quoi cuisiner')),
        ),
      ]);
    }),
    const SizedBox(height:12),

    Builder(builder:(context){
      final rows=HouseholdEngine.planNextDays(
        meals:meals,
        pantry:pantry,
        leftovers:leftovers,
        budgetLimit:remaining>0?remaining:0,
        days:3,
      );
      return _card(t('NEXT 3 DAYS','LES 3 PROCHAINS JOURS'),[
        if(rows.isEmpty)
          _line(Icons.event_busy,t('No three-day plan fits the current constraints.','Aucun plan de trois jours ne respecte les contraintes actuelles.'))
        else
          ...rows.map((x)=>_line(
            x['source']=='leftover'?Icons.replay:Icons.calendar_today,
            x['meal'].toString()+' • '+x['source'].toString()
          )),
        const SizedBox(height:4),
        FilledButton.icon(
          onPressed:()=>_executeVoiceCommand('next 3 days'),
          icon:const Icon(Icons.auto_awesome),
          label:Text(t('Plan next 3 days','Planifier les 3 prochains jours')),
        ),
      ]);
    }),
    const SizedBox(height:12),

    _card(t('HOUSEHOLD GUARDRAILS','GARDE-FOUS DU FOYER'),[
      _line(Icons.inventory,t('Use-first items: ','À utiliser en priorité : ')+lowStock.toString()),
      _line(Icons.local_fire_department,t('Gas: ','Gaz : ')+(gasLevel*100).toStringAsFixed(0)+'% '+t('remaining','restant')),
      _line(Icons.account_balance_wallet,t('Budget: ','Budget : ')+remaining.toStringAsFixed(0)+' FCFA '+t('remaining','restant')),
      _line(Icons.kitchen,t('Storage: ','Stock : ')+pantry.length.toString()+' '+t('tracked items','articles suivis')),
      Row(children:[
        Expanded(child:OutlinedButton.icon(
          onPressed:()=>_executeVoiceCommand('save gas'),
          icon:const Icon(Icons.local_fire_department),
          label:Text(t('Gas intelligence','Intelligence gaz')),
        )),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(
          onPressed:_showCopilot,
          icon:const Icon(Icons.swap_horiz),
          label:Text(t('Substitution','Substitution')),
        )),
      ]),
    ]),
    const SizedBox(height:12),

    _card(t('SCHOOL + HOUSE','ÉCOLE + MAISON'),[
      _line(Icons.school,t('Next snack: ','Prochain goûter : ')+(snacks.where((x)=>x['prepared']!=true).isEmpty?'—':snacks.firstWhere((x)=>x['prepared']!=true)['item'].toString())),
      _line(Icons.cleaning_services,t('Open care tasks: ','Tâches maison ouvertes : ')+tasks.where((x)=>x['done']!=true).length.toString()),
      const SizedBox(height:4),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()=>setState(()=>tab=3),icon:const Icon(Icons.cleaning_services),label:Text(t('House care','Maison')))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:_showCopilot,icon:const Icon(Icons.mic),label:Text(t('Talk to Copilot','Parler au Copilote')))),
      ]),
    ]),
  ]);

  Widget _sectionHeader(String title,String subtitle,IconData icon)=>Padding(
    padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:48,height:48,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:Theme.of(context).colorScheme.onPrimaryContainer)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(subtitle,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))]))
    ]));
  Widget _hero()=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xff1b5e20),Color(0xff43a047)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.home_work,color:Colors.white,size:36),const SizedBox(height:10),
    Text(t('Your family food command center','Le centre de contrôle alimentaire de la famille'),style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800)),
    const SizedBox(height:8),Text(t('Offline • Budget-aware • Cameroon meals • Pantry • House care','Hors ligne • Budget • Repas camerounais • Stock • Maison'),style:const TextStyle(color:Colors.white70))
  ]));

  Widget _metric(String a,String b,IconData i)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i),const SizedBox(height:8),Text(a),Text(b,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))])));
  Widget _card(String title,List<Widget> children)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),...children])));
  Widget _line(IconData i,String s)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Icon(i,size:20),const SizedBox(width:10),Expanded(child:Text(s))]));

  Widget _mealsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _sectionHeader(t('Living menu','Menu vivant'),t('Your meals are editable, teachable and used by the planner.','Vos repas sont modifiables, enrichissables et utilisés par le planificateur.'),Icons.restaurant_menu),
    Row(children:[
      Expanded(child:FilledButton.icon(onPressed:()=>_showMealEditor(),icon:const Icon(Icons.add),label:Text(t('Teach a meal','Ajouter un repas')))),
      const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:_autoPlan,icon:const Icon(Icons.auto_awesome),label:Text(t('Replan','Replanifier')))),
    ]),
    const SizedBox(height:12),
    _card(t('Live weekly plan','Plan hebdomadaire dynamique'),[
      Row(children:[
        Expanded(child:FilledButton.icon(onPressed:_showWeeklyMenuEditor,icon:const Icon(Icons.edit_calendar),label:Text(t('Edit week','Modifier la semaine')))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:_autoPlan,icon:const Icon(Icons.auto_awesome),label:Text(t('Auto-plan','Plan auto')))),
      ]),
      const SizedBox(height:10),
      ...List.generate(7,(i){
        final day=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i];
        final row=plan.length>i?plan[i]:<String,dynamic>{};
        final meal=row['meal']?.toString()??t('Not planned','Non planifié');
        final cost=(row['estimatedCost'] as num? ?? 0).toDouble();
        return Card(margin:const EdgeInsets.only(bottom:7),child:ListTile(
          leading:CircleAvatar(child:Text(day.substring(0,1))),
          title:Text(t(day,{'Mon':'Lun','Tue':'Mar','Wed':'Mer','Thu':'Jeu','Fri':'Ven','Sat':'Sam','Sun':'Dim'}[day]!)),
          subtitle:Text(meal+(cost>0?' • '+cost.toStringAsFixed(0)+' FCFA':'')),
          trailing:IconButton(icon:const Icon(Icons.swap_horiz),tooltip:t('Change meal','Changer le repas'),onPressed:()=>_showDayMealEditor(i)),
        ));
      }),
    ]),
    const SizedBox(height:12),_card(t('Meal library','Bibliothèque des repas'),[
      ...List.generate(meals.length,(i){final m=meals[i];final hasRecipe=m.length>3&&m[3] is List;return Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(onTap:()=>_showMealEditor(i),leading:CircleAvatar(child:Icon(hasRecipe?Icons.psychology:Icons.restaurant)),title:Text(m[0].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${m[1]} • ${m[2]} FCFA${hasRecipe?' • '+t('learned recipe','recette apprise'):''}'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_showMealEditor(i);if(v=='delete')_deleteMeal(i);},itemBuilder:(_)=>[PopupMenuItem(value:'edit',child:Text(t('Edit','Modifier'))),PopupMenuItem(value:'delete',child:Text(t('Remove','Retirer')))])));}),
    ]),
  ]);

  void _smartSwapDay(int dayIndex, {bool closeSheet = false}) {
    if (dayIndex < 0 || dayIndex > 6) return;
    final current = plan.length > dayIndex ? plan[dayIndex]['meal']?.toString() ?? '' : '';
    final decisions = HouseholdEngine.mealDecisions(
      meals: meals,
      pantry: pantry,
      leftovers: leftovers,
      budgetLimit: remaining > 0 ? remaining : 0,
    ).where((x) => x['name'].toString() != current).toList();
    if (decisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('No better live option is available right now.', 'Aucune meilleure option en direct n’est disponible maintenant.'))),
      );
      return;
    }
    final pick = decisions.first;
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final row = <String,dynamic>{
      'day': days[dayIndex],
      'meal': pick['name'],
      'region': pick['region'],
      'estimatedCost': pick['estimatedCost'],
      'leftoverPlan': pick['usesLeftover'] == true
          ? 'Use this saved leftover first.'
          : 'Use leftovers first when available.',
      'reason': pick['usesLeftover'] == true
          ? 'Smart swap: prioritized a saved leftover.'
          : pick['pantryReady'] == true
              ? 'Smart swap: prioritized current pantry stock.'
              : pick['withinBudget'] == true
                  ? 'Smart swap: fits the current budget.'
                  : 'Smart swap: selected from the live meal library.',
    };
    setState(() {
      while (plan.length < 7) {
        final j = plan.length;
        plan.add({'day': days[j], 'meal': '', 'region': 'All', 'estimatedCost': 0.0});
      }
      plan[dayIndex] = row;
    });
    _refreshShopping(save:false);
    _save();
    if (closeSheet) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        t(days[dayIndex]+' smart-swapped to '+pick['name'].toString()+'.',
          'Le repas du '+days[dayIndex]+' a été remplacé intelligemment par '+pick['name'].toString()+'.')
      )),
    );
  }

  Future<void> _showWeeklyMenuEditor() async {
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet){
        return Padding(
          padding:EdgeInsets.only(left:16,right:16,top:8,bottom:MediaQuery.of(sheet).viewInsets.bottom+16),
          child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('My living weekly menu','Mon menu hebdomadaire vivant'),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text(t('Every day is editable. Choose a meal, swap it, or regenerate the whole week.','Chaque jour est modifiable. Choisissez un repas, échangez-le ou régénérez toute la semaine.')),
            const SizedBox(height:10),
            Card(color:Theme.of(sheet).colorScheme.secondaryContainer,child:Padding(padding:const EdgeInsets.all(12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Icon(Icons.auto_awesome,color:Theme.of(sheet).colorScheme.onSecondaryContainer),
              const SizedBox(width:10),
              Expanded(child:Text(_weeklyMenuInsight(),style:TextStyle(color:Theme.of(sheet).colorScheme.onSecondaryContainer,fontWeight:FontWeight.w600))),
            ]))),
            const SizedBox(height:14),
            ...List.generate(7,(i){
              final row=plan.length>i?plan[i]:<String,dynamic>{};
              final day=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i];
              final meal=row['meal']?.toString()??'';
              return Card(
                margin:const EdgeInsets.only(bottom:10),
                child:Padding(
                  padding:const EdgeInsets.all(12),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Row(children:[
                      CircleAvatar(child:Text(day.substring(0,1))),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(t(day,{'Mon':'Lun','Tue':'Mar','Wed':'Mer','Thu':'Jeu','Fri':'Ven','Sat':'Sam','Sun':'Dim'}[day]!),style:const TextStyle(fontWeight:FontWeight.w800)),
                        Text(meal.isEmpty?t('No meal selected yet','Aucun repas choisi'):meal,overflow:TextOverflow.ellipsis),
                      ])),
                    ]),
                    const SizedBox(height:8),
                    Row(children:[
                      Expanded(child:FilledButton.icon(
                        onPressed:(){Navigator.pop(sheet);_showDayMealEditor(i);},
                        icon:const Icon(Icons.edit),
                        label:Text(t('Choose meal','Choisir le repas')),
                      )),
                      const SizedBox(width:8),
                      Expanded(child:OutlinedButton.icon(
                        onPressed:(){_smartSwapDay(i);setSheet((){});},
                        icon:const Icon(Icons.auto_awesome),
                        label:Text(t('Smart swap','Échange intelligent')),
                      )),
                    ]),
                  ]),
                ),
              );
            }),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:OutlinedButton.icon(onPressed:(){_autoPlan();Navigator.pop(sheet);},icon:const Icon(Icons.auto_awesome),label:Text(t('Regenerate week','Régénérer la semaine')))),
              const SizedBox(width:8),
              Expanded(child:FilledButton.icon(onPressed:(){Navigator.pop(sheet);_showCopilot();},icon:const Icon(Icons.mic),label:Text(t('Ask Copilot','Demander au Copilote')))),
            ]),
          ])),
        );
      }),
    );
  }

  Future<void> _showDayMealEditor(int dayIndex) async {
    if(dayIndex<0||dayIndex>6)return;
    final dayNames=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final current=plan.length>dayIndex?plan[dayIndex]['meal']?.toString():'';
    String selected=current??'';
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet){
        final candidates=HouseholdEngine.mealDecisions(meals:meals,pantry:pantry,leftovers:leftovers,budgetLimit:remaining>0?remaining:0);
        final selectedDecision=candidates.where((x)=>x['name'].toString()==selected).toList();
        return Padding(
          padding:EdgeInsets.only(left:16,right:16,top:12,bottom:MediaQuery.of(sheet).viewInsets.bottom+18),
          child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t('Choose '+dayNames[dayIndex]+' meal','Choisir le repas du '+dayNames[dayIndex]),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),
            Text(t('I show budget and pantry intelligence before you save.','Je montre l’intelligence budget et stock avant l’enregistrement.')),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              initialValue:meals.any((m)=>m.isNotEmpty&&m[0].toString()==selected)?selected:null,
              items:meals.where((m)=>m.isNotEmpty).map((m){
                final name=m[0].toString();
                final d=candidates.where((x)=>x['name'].toString()==name).toList();
                final label=d.isEmpty?name:name+' • '+(d.first['estimatedCost'] as double).toStringAsFixed(0)+' FCFA';
                return DropdownMenuItem<String>(value:name,child:Text(label,overflow:TextOverflow.ellipsis));
              }).toList(),
              onChanged:(v){if(v!=null)setSheet(()=>selected=v);},
              decoration:InputDecoration(labelText:t('Meal','Repas')),
            ),
            const SizedBox(height:10),
            if(selected.isNotEmpty)
              Builder(builder:(context){
                final m=meals.firstWhere((x)=>x[0].toString()==selected,orElse:()=>[selected,'All',0]);
                final d=selectedDecision.isNotEmpty?selectedDecision.first:null;
                return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(t('Decision support','Aide à la décision'),style:const TextStyle(fontWeight:FontWeight.w800)),
                  const SizedBox(height:6),
                  Text(t('Estimated cost: ','Coût estimé : ')+(m[2] as num).toStringAsFixed(0)+' FCFA'),
                  if(d!=null)...[
                    Text(d['pantryReady']==true?t('✓ Pantry ready','✓ Stock disponible'):t('• Shopping needed','• Achat nécessaire')),
                    Text(d['withinBudget']==true?t('✓ Within current budget','✓ Dans le budget actuel'):t('• Above current remaining budget','• Au-dessus du budget restant')),
                    if((d['missingItems'] as List).isNotEmpty)Text(t('Missing: ','Manquant : ')+(d['missingItems'] as List).join(', ')),
                  ],
                ])));
              }),
            const SizedBox(height:14),
            SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){
              if(selected.isEmpty)return;
              final m=meals.firstWhere((x)=>x[0].toString()==selected);
              final row=<String,dynamic>{'day':dayNames[dayIndex],'meal':m[0].toString(),'region':m.length>1?m[1].toString():'All','estimatedCost':(m[2] as num).toDouble(),'leftoverPlan':'Use leftovers first when available.','reason':'Selected with live household decision support.'};
              setState((){while(plan.length<7){final j=plan.length;plan.add({'day':dayNames[j],'meal':'','region':'All','estimatedCost':0.0});}plan[dayIndex]=row;});
              _refreshShopping(save:false);_save();Navigator.pop(sheet);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t(dayNames[dayIndex]+' updated. Shopping and household intelligence refreshed.','Repas du '+dayNames[dayIndex]+' mis à jour. Les achats et l’intelligence maison ont été actualisés.'))));
            },icon:const Icon(Icons.check),label:Text(t('Save this day','Enregistrer ce jour')))),
          ])),
        );
      }),
    );
  }
  Widget _snackPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _sectionHeader(
      t('School snacks','Goûters scolaires'),
      t('Prepare, track and budget the snacks your children take to school.','Préparez, suivez et budgétisez les goûters scolaires des enfants.'),
      Icons.school,
    ),
    FilledButton.icon(onPressed:_showAddSnack,icon:const Icon(Icons.add),label:Text(t('Add school snack','Ajouter un goûter'))),
    const SizedBox(height:12),
    _card(t('Weekly snack plan','Plan hebdomadaire des goûters'),[
      if(snacks.isEmpty)
        Text(t('No snacks yet. Tap “Add school snack” to create the first one.','Aucun goûter. Appuyez sur « Ajouter un goûter » pour créer le premier.'))
      else
        ...snacks.asMap().entries.map((entry){
          final i=entry.key; final x=entry.value; final prepared=x['prepared']==true;
          return Card(
            margin:const EdgeInsets.only(bottom:8),
            child:Padding(
              padding:const EdgeInsets.all(10),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[
                  Icon(prepared?Icons.check_circle:Icons.lunch_dining),
                  const SizedBox(width:10),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(x['child'].toString()+' • '+x['day'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
                    Text(x['item'].toString()+' • '+x['qty'].toString()+' • '+x['cost'].toString()+' FCFA'),
                  ])),
                ]),
                const SizedBox(height:8),
                Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:prepared?null:()=>_prepareSnack(i),
                    icon:Icon(prepared?Icons.check:Icons.restaurant),
                    label:Text(prepared?t('Prepared','Préparé'):t('Prepare now','Préparer')),
                  )),
                  const SizedBox(width:8),
                  Expanded(child:OutlinedButton.icon(
                    onPressed:()=>setState(()=>tab=2),
                    icon:const Icon(Icons.inventory_2),
                    label:Text(t('Check stock','Voir le stock')),
                  )),
                ]),
              ]),
            ),
          );
        }),
    ]),
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
          setState(()=>snacks.add({'child':child.text.trim().isEmpty?'Child 1':child.text.trim(),'day':['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][snacks.length%7],'item':item.text.trim(),'qty':double.tryParse(qty.text) ??1,'cost':double.tryParse(cost.text) ??0.0,'prepared':false}));
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
          initialValue:location,
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
            item['qty']=double.tryParse(q.text) ??0;
            item['min']=double.tryParse(min.text) ??0;
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
          final amount=double.tryParse(q.text) ??0;
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

  void _quickStockDelta(int index, double delta){
    if(index<0||index>=pantry.length)return;
    final current=(pantry[index]['qty'] as num? ?? 0).toDouble();
    setState(()=>pantry[index]['qty']=max(0,current+delta));
    _refreshShopping(save:false);_save();
  }

  Future<void> _setFreezerCapacity() async {
    final controller=TextEditingController(text:_freezerCapacity.toStringAsFixed(0));
    await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(t('Freezer capacity','Capacité du congélateur')),
      content:TextField(controller:controller,keyboardType:TextInputType.number,decoration:InputDecoration(
        labelText:t('Capacity in storage slots','Capacité en emplacements'),
        helperText:t('Use one slot for a practical family batch/container.','Utilisez un emplacement par bac/récipient familial.'),
      )),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog),child:Text(t('Cancel','Annuler'))),
        FilledButton(onPressed:(){
          final value=double.tryParse(controller.text.replaceAll(' ',''))??_freezerCapacity;
          if(value>0){setState(()=>_freezerCapacity=value);_save();}
          Navigator.pop(dialog);
        },child:Text(t('Save','Enregistrer')))
      ],
    ));
  }

  double _freezerUsage(){
    return pantry.where((x)=>x['location']=='Freezer'&&(x['qty'] as num? ?? 0)>0).length.toDouble();
  }

  Widget _storagePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _sectionHeader(t('Smart storage','Stock intelligent'),t('Fast controls keep your pantry alive and your family decisions connected.','Des contrôles rapides gardent votre stock vivant et vos décisions familiales connectées.'),Icons.inventory_2),
    Row(children:[
      Expanded(child:FilledButton.icon(onPressed:_showAddStock,icon:const Icon(Icons.add),label:Text(t('Add stock','Ajouter')))),
      const SizedBox(width:8),
      Expanded(child:OutlinedButton.icon(onPressed:_showMealEditor,icon:const Icon(Icons.restaurant_menu),label:Text(t('Teach meal','Repas')))),
    ]),
    const SizedBox(height:12),
    _card(t('Storage intelligence','Intelligence du stockage'),[
      _line(Icons.inventory_2,t('Dry store: long-life goods','Garde-manger : produits longue conservation')),
      _line(Icons.kitchen,t('Fridge: short-life fresh food','Frigo : produits frais à courte durée')),
      _line(Icons.ac_unit,t('Freezer: batch-cooked and frozen food','Congélateur : plats préparés et aliments congelés')),
      _line(Icons.shopping_cart,lowStock.toString()+' '+t('items need shopping','articles nécessitent des achats')),
    ]),
    const SizedBox(height:12),
    _card(t('Freezer capacity','Capacité du congélateur'),[
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(_freezerUsage().toStringAsFixed(0)+' / '+_freezerCapacity.toStringAsFixed(0)+' '+t('slots used','emplacements utilisés'),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),
          LinearProgressIndicator(value:_freezerCapacity<=0?0:(_freezerUsage()/_freezerCapacity).clamp(0.0,1.0),minHeight:8,borderRadius:BorderRadius.circular(8)),
        ])),
        IconButton(onPressed:_setFreezerCapacity,icon:const Icon(Icons.settings),tooltip:t('Set capacity','Définir la capacité')),
      ]),
    ]),
    const SizedBox(height:12),
    if(pantry.any((x){
      final d=DateTime.tryParse(x['useBy']?.toString()??'');
      return d!=null&&d.difference(DateTime.now()).inDays<=3;
    }))
      _card(t('USE SOON','À UTILISER BIENTÔT'),[
        ...pantry.where((x){
          final d=DateTime.tryParse(x['useBy']?.toString()??'');
          return d!=null&&d.difference(DateTime.now()).inDays<=3;
        }).map((x){
          final i=pantry.indexOf(x);
          final d=DateTime.tryParse(x['useBy']?.toString()??'');
          final days=d==null?0:d.difference(DateTime.now()).inDays;
          return ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.priority_high),title:Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(x['qty'].toString()+' '+x['unit'].toString()+' • '+(days<0?t('expired','expiré'):days==0?t('today','aujourd’hui'):days.toString()+' '+t('days','jours'))),trailing:FilledButton.tonal(onPressed:()=>_consumeStock(i),child:Text(t('Use','Utiliser'))));
        }),
      ]),
    const SizedBox(height:8),
    ...List.generate(pantry.length,(i){
      final x=pantry[i];
      final useBy=x['useBy']?.toString() ?? '';
      final d=DateTime.tryParse(useBy);
      final days=d==null?999:d.difference(DateTime.now()).inDays;
      final urgent=days<=3;
      final low=(x['qty'] as num? ?? 0).toDouble()<=((x['min'] as num? ?? 0).toDouble());
      return Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(children:[
        ListTile(
          leading:Icon(x['location']=='Freezer'?Icons.ac_unit:x['location']=='Fridge'?Icons.kitchen:Icons.inventory_2),
          title:Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
          subtitle:Text(x['qty'].toString()+' '+x['unit'].toString()+' • '+x['location'].toString()+' • '+(useBy.isEmpty?'No use-by':useBy)),
          trailing:PopupMenuButton<String>(onSelected:(v){if(v=='consume')_consumeStock(i);if(v=='edit')_editStock(i);if(v=='delete')_deleteStock(i);},itemBuilder:(_)=>[
            PopupMenuItem(value:'consume',child:Text(t('Consume','Consommer'))),
            PopupMenuItem(value:'edit',child:Text(t('Edit','Modifier'))),
            PopupMenuItem(value:'delete',child:Text(t('Remove','Retirer'))),
          ]),
        ),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
          IconButton(onPressed:()=>_quickStockDelta(i,-1),icon:const Icon(Icons.remove_circle_outline),tooltip:t('Quick consume 1','Consommer 1')),
          Expanded(child:Center(child:Text(x['qty'].toString()+' '+x['unit'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)))),
          IconButton(onPressed:()=>_quickStockDelta(i,1),icon:const Icon(Icons.add_circle_outline),tooltip:t('Quick add 1','Ajouter 1')),
          if(urgent)Padding(padding:const EdgeInsets.only(left:6),child:Chip(label:Text(days<0?t('EXPIRED','EXPIRÉ'):t('USE SOON','À UTILISER')))),
          if(!urgent&&low)const Padding(padding:EdgeInsets.only(left:6),child:Chip(label:Text('BUY'))),
          if(!urgent&&!low)const Padding(padding:EdgeInsets.only(left:6),child:Icon(Icons.check_circle,color:Colors.green)),
        ])),
      ])));
    }),
    if(shopping.isNotEmpty)_card(t('Live shopping list','Liste d’achats dynamique'),[
      for(var i=0;i<shopping.length;i++)CheckboxListTile(value:shopping[i]['purchased']==true,onChanged:(v)=>_purchaseShopping(i,v??false),title:Text(shopping[i]['name'].toString()),subtitle:Text(shopping[i]['suggestedQty'].toString()+' '+shopping[i]['unit'].toString()+' • '+shopping[i]['priority'].toString()))
    ]),
  ]);

  Widget _carePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('House care','Entretien de la maison'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _card(t('House-care schedule','Planning entretien'),tasks.map((e)=>CheckboxListTile(value:e['done']==true,onChanged:(v){setState(()=>e['done']=v??false);_save();},title:Text(e['task'].toString()),subtitle:Text(e['frequency'].toString()+' • '+e['next'].toString()),controlAffinity:ListTileControlAffinity.leading)).toList()),
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
          final amount=(double.tryParse(fill.text) ??0).clamp(0,1);
          final price=double.tryParse(cost.text) ??0;
          setState(()=>gasLevel=(gasLevel+amount).clamp(0,gasCapacity));
          if(price>0){gasSpent+=price;_addExpense(price);}
          gasLogs.insert(0,{'date':DateTime.now().toIso8601String(),'amount':price,'fill':amount});
          _save();Navigator.pop(dialogContext);
        },child:Text(t('Save','Enregistrer')))
      ],
    ));
  }

  Widget _reportsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    _sectionHeader(
      t('Budget & reports','Budget & rapports'),
      t('See what is happening, change the budget, and jump directly to the next action.','Voyez ce qui se passe, modifiez le budget et allez directement à l’action suivante.'),
      Icons.insights,
    ),
    Row(children:[
      Expanded(child:FilledButton.icon(onPressed:_showBudgetEditor,icon:const Icon(Icons.edit_note),label:Text(t('Edit budget','Modifier le budget')))),
      const SizedBox(width:8),
      Expanded(child:OutlinedButton.icon(onPressed:_showCopilot,icon:const Icon(Icons.auto_awesome),label:Text(t('Ask Copilot','Copilote')))),
    ]),
    const SizedBox(height:12),
    Row(children:[
      Expanded(child:_metric(t('Monthly budget','Budget mensuel'),budget.toStringAsFixed(0)+' FCFA',Icons.account_balance_wallet)),
      const SizedBox(width:10),
      Expanded(child:_metric(t('Spent','Dépensé'),spent.toStringAsFixed(0)+' FCFA',Icons.restaurant)),
    ]),
    const SizedBox(height:10),
    _metric(t('Money available','Argent disponible'),remaining.toStringAsFixed(0)+' FCFA',Icons.savings),
    const SizedBox(height:12),
    _card(t('Quick actions','Actions rapides'),[
      ListTile(
        leading:const Icon(Icons.restaurant_menu),
        title:Text(t('Open meal planning','Ouvrir la planification des repas')),
        subtitle:Text(t('Choose meals, teach new meals or replan the week.','Choisir des repas, ajouter des repas ou replanifier la semaine.')),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>setState(()=>tab=1),
      ),
      ListTile(
        leading:const Icon(Icons.inventory_2),
        title:Text(t('Open shopping & storage','Ouvrir les achats et le stock')),
        subtitle:Text(t('Add stock, consume items, mark purchases and see low stock.','Ajouter, consommer, valider les achats et voir les stocks faibles.')),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>setState(()=>tab=2),
      ),
      ListTile(
        leading:const Icon(Icons.school),
        title:Text(t('Open school snacks','Ouvrir les goûters scolaires')),
        subtitle:Text(t('Prepare and track children’s school snacks.','Préparer et suivre les goûters scolaires des enfants.')),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>setState(()=>tab=5),
      ),
    ]),
    if(purchaseHistory.isNotEmpty)_card(t('Purchase history','Historique des achats'),[
      ...purchaseHistory.take(12).map((x)=>_line(
        Icons.receipt_long,
        x['name'].toString()+' — '+x['qty'].toString()+' '+x['unit'].toString()+
        (((x['cost'] as num?) ?? 0)>0 ? ' • '+((x['cost'] as num).toStringAsFixed(0))+' FCFA' : ''),
      )),
    ]),
    _card(t('What these numbers mean','Ce que signifient ces chiffres'),[
      _line(Icons.account_balance_wallet,t('Budget = your monthly food ceiling.','Budget = votre plafond alimentaire mensuel.')),
      _line(Icons.restaurant,t('Spent = purchases and snack costs recorded in the app.','Dépensé = achats et coûts de goûters enregistrés dans l’application.')),
      _line(Icons.savings,t('Available = budget minus recorded spending.','Disponible = budget moins les dépenses enregistrées.')),
    ]),
  ]);

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
    final recipe=_mealRecipe(meal);
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
  Future<void> _showAddStock() async {
    final name=TextEditingController(),qty=TextEditingController(text:'1'),min=TextEditingController(text:'0'),useBy=TextEditingController();
    String unit='item',location='Dry store';
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet)=>Padding(
      padding:EdgeInsets.only(left:20,right:20,top:10,bottom:MediaQuery.of(sheet).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(children:[
        Text(t('Add something to the home','Ajouter quelque chose à la maison'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
        TextField(controller:name,decoration:InputDecoration(labelText:t('Item name','Nom de l’article'))),
        Row(children:[Expanded(child:TextField(controller:qty,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Quantity','Quantité')))),const SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(initialValue:unit,items:['item','kg','g','L','ml','piece','bunches'].map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),onChanged:(v){if(v!=null)setSheet(()=>unit=v);},decoration:InputDecoration(labelText:t('Unit','Unité'))))]),
        TextField(controller:min,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Alert below','Alerte en dessous de'))),
        DropdownButtonFormField<String>(initialValue:location,items:['Dry store','Fridge','Freezer'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)setSheet(()=>location=v);},decoration:InputDecoration(labelText:t('Where','Où'))),
        TextField(controller:useBy,decoration:InputDecoration(labelText:t('Use-by date (optional)','Date limite (facultatif)'))),
        const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){final n=name.text.trim();if(n.isEmpty)return;setState(()=>pantry.add({'name':n,'qty':double.tryParse(qty.text.replaceAll(',','.'))??1,'unit':unit,'min':double.tryParse(min.text.replaceAll(',','.'))??0,'location':location,'useBy':useBy.text.trim()}));_refreshShopping(save:false);_save();Navigator.pop(sheet);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Added to live storage.','Ajouté au stock vivant.'))));},icon:const Icon(Icons.add),label:Text(t('Add to live storage','Ajouter au stock vivant')))),
      ])))));
  }


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
          ActionChip(label:Text(t('What should I do now?','Que dois-je faire maintenant ?')),onPressed:()=>_runVoiceCommand(t('what should I do now','que dois-je faire maintenant'))),
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
        if(r.finalResult){setSheet(()=>_listening=false);_executeVoiceCommand(r.recognizedWords);}
      },
    );
  }

  String _weeklyMenuInsight() {
    final rows = HouseholdEngine.mealDecisions(
      meals: meals,
      pantry: pantry,
      leftovers: leftovers,
      budgetLimit: remaining > 0 ? remaining : 0,
    );
    if (rows.isEmpty) {
      return t('I need more meal options to build a smart week.', 'J’ai besoin de plus de repas pour construire une semaine intelligente.');
    }
    final ready = rows.where((x) => x['pantryReady'] == true).length;
    final leftover = rows.where((x) => x['usesLeftover'] == true).length;
    final shopping = rows.where((x) => x['source'] == 'shopping').length;
    return t(
      'Live menu intelligence: '+ready.toString()+' meal(s) can use pantry stock, '+leftover.toString()+' can reuse leftovers, and '+shopping.toString()+' may need shopping.',
      'Intelligence du menu : '+ready.toString()+' repas peuvent utiliser le stock, '+leftover.toString()+' peuvent réutiliser les restes et '+shopping.toString()+' peuvent nécessiter des achats.',
    );
  }

  String _nextBestAction(){
    if(remaining<0)return t('Pause new food spending and use pantry stock first.','Mettez les nouveaux achats en pause et utilisez d’abord le stock disponible.');
    final urgent=pantry.where((x){
      final d=DateTime.tryParse(x['useBy']?.toString()??'');
      return d!=null&&d.difference(DateTime.now()).inDays<=2&&(x['qty'] as num? ?? 0)>0;
    }).toList();
    if(urgent.isNotEmpty)return t('Use '+urgent.first['name'].toString()+' soon to reduce waste.','Utilisez bientôt '+urgent.first['name'].toString()+' pour réduire le gaspillage.');
    if(leftovers.isNotEmpty)return t('Use the saved leftover first: '+leftovers.first['name'].toString()+'.','Utilisez d’abord le reste enregistré : '+leftovers.first['name'].toString()+'.');
    if(lowStock>0)return t('Check shopping: '+lowStock.toString()+' item(s) are at or below minimum stock.','Vérifiez les achats : '+lowStock.toString()+' article(s) sont au seuil minimum ou en dessous.');
    final snackIndex=snacks.indexWhere((x)=>x['prepared']!=true);
    if(snackIndex>=0)return t('Prepare the next school snack for '+snacks[snackIndex]['child'].toString()+'.','Préparez le prochain goûter scolaire pour '+snacks[snackIndex]['child'].toString()+'.');
    final openTasks=tasks.where((x)=>x['done']!=true).length;
    if(openTasks>0)return t('There are '+openTasks.toString()+' open house-care task(s).','Il reste '+openTasks.toString()+' tâche(s) d’entretien ouvertes.');
    return t('Your home is balanced. Ask me to plan, cook, shop or organize.','Votre maison est équilibrée. Demandez-moi de planifier, cuisiner, acheter ou organiser.');
  }

  Future<void> _executeVoiceCommand(String command) async {
    final q=command.toLowerCase().trim();
    if(q.isEmpty)return;

    double? parsedQty(){
      final m=RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(q);
      if(m!=null)return double.tryParse(m.group(1)!.replaceAll(',','.'));
      const words={'one':1.0,'a':1.0,'an':1.0,'two':2.0,'three':3.0,'four':4.0,'five':5.0,'un':1.0,'une':1.0,'deux':2.0,'trois':3.0,'quatre':4.0,'cinq':5.0};
      for(final e in words.entries){if(RegExp(r'(^|\s)'+RegExp.escape(e.key)+r'(\s|$)').hasMatch(q))return e.value;}
      return null;
    }
    String parsedUnit(){
      if(RegExp(r'\bkg\b|kilograms?|kilogrammes?|kilos?').hasMatch(q))return 'kg';
      if(RegExp(r'\bg\b|grams?|grammes?').hasMatch(q))return 'g';
      if(RegExp(r'\bml\b|milliliters?|millilitres?').hasMatch(q))return 'ml';
      if(RegExp(r'\bl\b|liters?|litres?').hasMatch(q))return 'L';
      if(q.contains('bunch')||q.contains('régime')||q.contains('regime'))return 'bunches';
      if(q.contains('piece')||q.contains('pièce'))return 'piece';
      if(q.contains('bottle')||q.contains('bouteille'))return 'bottle';
      return '';
    }
    double convert(double amount,String from,String to){
      final a=from.toLowerCase(),b=to.toLowerCase();
      if(a.isEmpty||b.isEmpty||a==b)return amount;
      if(a=='g'&&b=='kg')return amount/1000;
      if(a=='kg'&&b=='g')return amount*1000;
      if(a=='ml'&&b=='l')return amount/1000;
      if(a=='l'&&b=='ml')return amount*1000;
      return amount;
    }
    int findItem(){
      for(var i=0;i<pantry.length;i++){
        final n=pantry[i]['name'].toString().toLowerCase();
        if(q.contains(n))return i;
      }
      return -1;
    }
    int findMeal(){
      var best=-1; var bestScore=0;
      for(var i=0;i<meals.length;i++){
        final name=meals[i][0].toString().toLowerCase();
        if(q.contains(name))return i;
        final tokens=name.split(RegExp(r'\\s*[+&]\\s*|\\s+')).where((x)=>x.length>3);
        final score=tokens.where((x)=>q.contains(x)).length;
        if(score>bestScore){bestScore=score;best=i;}
      }
      return bestScore>0?best:-1;
    }
    bool hasAny(List<String> words)=>words.any(q.contains);

    if(hasAny(['which meal','what meal','meal save gas','save gas','économiser le gaz','economise le gaz'])) {
      final candidates=HouseholdEngine.gasEfficiencyCandidates(meals);
      final names=candidates.take(3).map((x)=>x['name'].toString()).join(', ');
      await _speak(t('Gas-efficiency heuristic: '+names+'. This is a planning estimate, not measured fuel consumption.',
        'Heuristique d’économie de gaz : '+names+'. C’est une estimation de planification, pas une mesure réelle de consommation.'));
      return;
    }

    if(hasAny(['next 3 days','three days','3 days','trois jours','3 jours','prochains jours'])) {
      final ceiling=remaining>0?remaining:0.0;
      final rows=HouseholdEngine.planNextDays(
        meals:meals, pantry:pantry, leftovers:leftovers,
        budgetLimit:ceiling, days:3,
      );
      if(rows.isEmpty){
        await _speak(t('I could not build a three-day plan within the current budget and meal library.',
          'Je ne peux pas construire un plan de trois jours avec le budget et la bibliothèque actuels.'));
        return;
      }
      if(plan.length<7)_autoPlan(save:false);
      for(var i=0;i<rows.length;i++){
        final idx=(DateTime.now().weekday-1+i)%7;
        if(idx<plan.length){
          final row=rows[i];
          plan[idx]={
            'day':['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][idx],
            'meal':row['meal'],'region':row['region'],
            'estimatedCost':row['estimatedCost'],
            'leftoverPlan':'Use leftovers first when available.',
            'reason':row['reason'],
          };
        }
      }
      _refreshShopping(save:false);
      await _save();
      await _speak(t(
        'Next three days: '+rows.map((x)=>x['meal'].toString()).join(', ')+'.',
        'Les trois prochains jours : '+rows.map((x)=>x['meal'].toString()).join(', ')+'.'));
      return;
    }

    if(hasAny(['replace','replacement','substitute','remplacer','remplacement'])) {
      final targets=['tomatoes','tomate','tomates','onions','oignons','plantain','banane plantain','palm oil','huile de palme','beans','haricots'];
      final target=targets.firstWhere((x)=>q.contains(x),orElse:()=> '');
      if(target.isEmpty){
        await _speak(t('Tell me which ingredient is missing and I will suggest available planning substitutes.',
          'Dites-moi quel ingrédient manque et je proposerai des substituts de planification.'));
        return;
      }
      final canonical=target.contains('tomat')?'tomatoes':
          target.contains('oignon')?'onions':
          target.contains('plantain')||target.contains('banane')?'plantain':
          target.contains('palme')||target.contains('oil')?'palm oil':'beans';
      final options=HouseholdEngine.substitutionSuggestions(canonical);
      await _speak(options.isEmpty
        ? t('No configured substitute is available for '+canonical+'.','Aucun substitut configuré pour '+canonical+'.')
        : t('Configured planning substitutes for '+canonical+': '+options.join(', ')+'.',
            'Substituts de planification configurés pour '+canonical+' : '+options.join(', ')+'.'));
      return;
    }

    if(hasAny(['what should i do now','what do i do now','next action','que dois-je faire','que faire maintenant','quoi faire maintenant'])){
      final answer=_nextBestAction();
      if(mounted)setState(()=>_transcript=answer);
      await _speak(answer);
      return;
    }

    if(hasAny(['gas','gaz'])){
      await _speak((gasLevel*100).toStringAsFixed(0)+'% '+t('gas remaining.','de gaz restant.')+' '+t('Use batch cooking when the cylinder is low.','Privilégiez la cuisson en lot lorsque le gaz est bas.'));
      return;
    }
    if(hasAny(['budget','argent'])){
      final days=DateTime(DateTime.now().year,DateTime.now().month+1,0).day-DateTime.now().day+1;
      final insight=HouseholdEngine.budgetInsight(budget,spent,days.toDouble());
      setState(()=>tab=4);
      await _speak(t('Budget remaining: ','Budget restant : ')+insight['remaining'].toStringAsFixed(0)+' FCFA. '+t('Daily ceiling: ','Plafond quotidien : ')+insight['dailyLimit'].toStringAsFixed(0)+' FCFA.' );
      return;
    }

    if(hasAny(['what can i cook','what can i make','que puis-je cuisiner','que cuisiner','cuisiner avec','cook with'])){
      final options=HouseholdEngine.cookableMeals(meals:meals,pantry:pantry,leftovers:leftovers,prioritizeLeftovers:true);
      if(options.isEmpty){await _speak(t('Nothing in the current meal library can be cooked completely from your available stock. I can plan an affordable meal and build the shopping list.','Aucun repas de la bibliothèque ne peut être cuisiné entièrement avec le stock actuel. Je peux planifier un repas abordable et préparer la liste d’achats.'));return;}
      final names=options.take(3).map((x)=>x['name'].toString()).join(', ');
      await _speak(t('You can cook: '+names+'.','Vous pouvez cuisiner : '+names+'.'));
      return;
    }

    if((q.contains('plan')||q.contains('menu'))&&(q.contains('tomorrow')||q.contains('demain'))){
      final numberMatch=RegExp(r'(?:under|below|less than|moins de|maximum|max)\s+(\d[\d .]*)').firstMatch(q);
      final ceiling=numberMatch==null?double.infinity:double.tryParse(numberMatch.group(1)!.replaceAll(RegExp(r'[^0-9]'),''))??double.infinity;
      final result=HouseholdEngine.planDay(meals:meals,pantry:pantry,budgetLimit:ceiling,leftovers:leftovers,prioritizeLeftovers:true);
      if(result['meal'].toString().isEmpty){await _speak(t('No meal fits that budget ceiling.','Aucun repas ne respecte ce plafond.'));return;}
      final nextIndex=DateTime.now().weekday%7;
      final existing=plan.length==7?plan[nextIndex]:null;
      if(existing==null){_autoPlan(save:false);}
      if(plan.length==7){setState(()=>plan[nextIndex]={
        'day':['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][nextIndex],
        'meal':result['meal'],'region':'Smart plan','estimatedCost':result['estimatedCost'],'leftoverPlan':'Use leftovers first when available.','reason':result['reason']});}
      _refreshShopping(save:false);await _save();
      await _speak(t('Tomorrow is planned: '+result['meal'].toString()+'. Estimated meal cost: '+result['estimatedCost'].toStringAsFixed(0)+' FCFA.','Demain est planifié : '+result['meal'].toString()+'. Coût estimé : '+result['estimatedCost'].toStringAsFixed(0)+' FCFA.'));
      return;
    }

    if(hasAny(['tomorrow','demain'])){
      if(plan.isEmpty)_autoPlan(save:false);
      final idx=DateTime.now().weekday%7;
      final tomorrow=plan.isEmpty?'':plan[idx]['meal'].toString();
      await _speak(tomorrow.isEmpty?t('Tomorrow has no meal planned yet.','Aucun repas n’est encore planifié pour demain.'):t('Tomorrow: '+tomorrow+'.','Demain : '+tomorrow+'.'));
      return;
    }

    if(hasAny(['leftover','leftovers','reste','restes'])){
      if(hasAny(['use','eat','manger','utiliser'])){
        if(leftovers.isEmpty){await _speak(t('There are no saved leftovers.','Il n’y a aucun reste enregistré.'));return;}
        final used=leftovers.removeAt(0);await _save();
        await _speak(t('Using leftover: '+used['name'].toString()+'. No new recipe stock was consumed.','Reste utilisé : '+used['name'].toString()+'. Aucun nouveau stock de recette n’a été consommé.'));return;
      }
      await _speak(leftovers.isEmpty?t('There are no saved leftovers.','Il n’y a aucun reste enregistré.'):t('Saved leftovers: '+leftovers.map((x)=>x['name'].toString()).join(', ')+'.','Restes enregistrés : '+leftovers.map((x)=>x['name'].toString()).join(', ')+'.'));return;
    }

    if(hasAny(['snack','goûter','gouter'])){
      final i=snacks.indexWhere((x)=>x['prepared']!=true);
      if(hasAny(['prepare','prépare','préparer'])){
        if(i<0){await _speak(t('All scheduled snacks are prepared.','Tous les goûters planifiés sont préparés.'));return;}
        _prepareSnack(i);final s=snacks[i];await _speak(t('Snack prepared for '+s['child'].toString()+': '+s['item'].toString()+'.','Goûter préparé pour '+s['child'].toString()+': '+s['item'].toString()+'.'));return;
      }
      await _speak(i<0?t('All scheduled snacks are prepared.','Tous les goûters sont préparés.'):t('Next snack: '+snacks[i]['item'].toString()+' for '+snacks[i]['child'].toString()+'.','Prochain goûter : '+snacks[i]['item'].toString()+' pour '+snacks[i]['child'].toString()+'.'));return;
    }

    final mealIndex=findMeal();
    if(mealIndex>=0 && hasAny(['cook','cuisine','cuisiner','prepare','prépare'])){
      final mealName=meals[mealIndex][0].toString();
      if(leftovers.isNotEmpty && q.contains('leftover')){leftovers.removeAt(0);await _save();await _speak(t('I used the saved leftover of '+mealName+'.','J’ai utilisé le reste enregistré de '+mealName+'.'));return;}
      final recipe=_mealRecipe(mealName);
      if(recipe.isEmpty){await _speak(t('The recipe for '+mealName+' is not defined yet.','La recette de '+mealName+' n’est pas encore définie.'));return;}
      setState(()=>pantry..clear()..addAll(HouseholdEngine.consumeRecipe(pantry,recipe)));
      leftovers.add({'name':mealName,'portions':1,'useBy':'Tomorrow'});_useGas(0.05,'Voice cooking: '+mealName);_refreshShopping(save:false);await _save();
      await _speak(t(mealName+' cooked. Pantry, leftovers, shopping and gas were updated.',mealName+' cuisiné. Stock, restes, achats et gaz mis à jour.'));return;
    }

    final item=findItem();
    final qty=parsedQty()??1.0; final unit=parsedUnit();
    if(item>=0 && hasAny(['buy','bought','purchase','acheter','acheté','achète'])){
      final name=pantry[item]['name'].toString();final storageUnit=pantry[item]['unit'].toString();final effectiveUnit=unit.isEmpty?storageUnit:unit;final storageQty=convert(qty,effectiveUnit,storageUnit);
      setState(()=>pantry[item]['qty']=(pantry[item]['qty'] as num? ?? 0).toDouble()+storageQty);_refreshShopping(save:false);
      final priceMatch=RegExp(r'(?:for|cost|prix|coût|à|a)\s+(\d[\d .]*)\s*(?:fcfa|f|francs?)?').firstMatch(q);
      final price=priceMatch==null?null:double.tryParse(priceMatch.group(1)!.replaceAll(RegExp(r'[^0-9]'),''));
      _recordPurchase(name,qty,effectiveUnit,price);_refreshShopping(save:false);await _save();
      await _speak(price==null?t(qty.toString()+' '+effectiveUnit+' of '+name+' added to storage.',''+qty.toString()+' '+effectiveUnit+' de '+name+' ajouté au stock.'):t('Purchase recorded: '+qty.toString()+' '+effectiveUnit+' of '+name+' for '+price.toStringAsFixed(0)+' FCFA.','Achat enregistré : '+qty.toString()+' '+effectiveUnit+' de '+name+' pour '+price.toStringAsFixed(0)+' FCFA.'));return;
    }
    if(item>=0 && hasAny(['consume','consommer','use','utilise','utiliser'])){
      final storageUnit=pantry[item]['unit'].toString();final storageQty=convert(qty,unit.isEmpty?storageUnit:unit,storageUnit);final current=(pantry[item]['qty'] as num? ?? 0).toDouble();
      setState(()=>pantry[item]['qty']=max(0,current-storageQty));_refreshShopping(save:false);await _save();await _speak(t(qty.toString()+' '+(unit.isEmpty?storageUnit:unit)+' consumed from '+pantry[item]['name'].toString()+'.',qty.toString()+' '+(unit.isEmpty?storageUnit:unit)+' consommé(s) de '+pantry[item]['name'].toString()+'.'));return;
    }
    if(item>=0 && hasAny(['add','ajoute','ajouter'])){
      final storageUnit=pantry[item]['unit'].toString();final storageQty=convert(qty,unit.isEmpty?storageUnit:unit,storageUnit);setState(()=>pantry[item]['qty']=(pantry[item]['qty'] as num? ?? 0).toDouble()+storageQty);_refreshShopping(save:false);await _save();await _speak(t(qty.toString()+' '+(unit.isEmpty?storageUnit:unit)+' added to '+pantry[item]['name'].toString()+'.',qty.toString()+' '+(unit.isEmpty?storageUnit:unit)+' ajouté(s) à '+pantry[item]['name'].toString()+'.'));return;
    }
    if(hasAny(['expire','expir','use soon','bientôt'])){
      final soon=pantry.where((x){final d=DateTime.tryParse(x['useBy']?.toString()??'');return d!=null&&d.difference(DateTime.now()).inDays<=2;}).map((x)=>x['name'].toString()).toList();
      await _speak(soon.isEmpty?t('Nothing is expiring soon.','Rien n’expire bientôt.'):t('Use soon: '+soon.join(', '),'À utiliser bientôt : '+soon.join(', ')));return;
    }
    if(hasAny(['shopping','achat'])){setState(()=>tab=2);await _speak(shopping.isEmpty?t('Shopping list is clear.','La liste d’achats est vide.'):t('Shopping list has '+shopping.length.toString()+' items.','La liste d’achats contient '+shopping.length.toString()+' articles.'));return;}
    if(hasAny(['plan','menu','week','semaine'])){_autoPlan();await _speak(t('The weekly menu has been replanned from your current stock and budget.','Le menu hebdomadaire a été replanifié selon le stock et le budget actuels.'));return;}
    if(hasAny(['care','house','maison','tâche','task'])){setState(()=>tab=3);await _speak(t('I opened house care.','J’ai ouvert l’entretien de la maison.'));return;}
    await _speak(t('Try: what can I cook, plan tomorrow under 3000 FCFA, use leftovers, buy 2 kg rice for 4000 FCFA, consume 500 g beans, or check gas.','Essayez : que puis-je cuisiner, planifier demain sous 3000 FCFA, utiliser les restes, acheter 2 kg de riz pour 4000 FCFA, consommer 500 g de haricots ou vérifier le gaz.'));
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


  String _humanGreeting(){
    final hour=DateTime.now().hour;
    final hello=hour<12?t('Good morning','Bonjour'):hour<18?t('Good afternoon','Bon après-midi'):t('Good evening','Bonsoir');
    if(remaining<0)return hello+', your food budget is over. Let us slow spending down and use what is already at home.';
    if(lowStock>0)return hello+', I noticed '+lowStock.toString()+' item'+(lowStock>1?'s':'')+' running low. I can help you plan around them.';
    if(leftovers.isNotEmpty)return hello+', you have a saved leftover. I would use that first to avoid waste.';
    return hello+', your home is ready. Tell me what you want to cook, buy, plan or organize.';
  }
  List<Map<String,dynamic>> _mealRecipe(String name){
    final i=meals.indexWhere((m)=>m.isNotEmpty&&m[0].toString().toLowerCase()==name.toLowerCase());
    if(i>=0&&meals[i].length>3&&meals[i][3] is List)return (meals[i][3] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    return HouseholdEngine.recipeFor(name);
  }
  List<Map<String,dynamic>> _parseRecipe(String raw){
    final out=<Map<String,dynamic>>[];
    for(final part in raw.split(',')){
      final p=part.trim();
      if(p.isEmpty)continue;
      final m=RegExp(
        r'^(.+?)\s*:\s*(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|piece|pieces|bunch|bunches|régime|régimes)?',
        caseSensitive:false,
      ).firstMatch(p);
      if(m==null)continue;
      final name=m.group(1)!.trim();
      final qty=double.tryParse(m.group(2)!.replaceAll(',','.'))??0;
      var unit=(m.group(3)??'item').toLowerCase();
      if(unit=='pieces')unit='piece';
      if(unit=='bunch'||unit=='régime'||unit=='régimes')unit='bunches';
      out.add({'name':name,'qty':qty,'unit':unit});
    }
    return out;
  }
  Future<void> _showBudgetEditor() async {
    final controller=TextEditingController(text:budget.toStringAsFixed(0));
    var liveBudget=budget.clamp(50000.0,1000000.0);
    final daysLeft=DateTime(DateTime.now().year,DateTime.now().month+1,0).day-DateTime.now().day+1;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(sheet,setSheet){
        final daily=((liveBudget-spent).clamp(0.0,double.infinity))/max(1,daysLeft);
        final weekly=daily*7.0;
        final progress=liveBudget<=0.0?0.0:(spent/liveBudget).clamp(0.0,1.0);
        return Padding(
          padding:EdgeInsets.only(left:20,right:20,top:10,bottom:MediaQuery.of(sheet).viewInsets.bottom+20),
          child:SingleChildScrollView(
            child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Container(width:46,height:46,decoration:BoxDecoration(color:Theme.of(sheet).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14)),child:Icon(Icons.account_balance_wallet,color:Theme.of(sheet).colorScheme.onPrimaryContainer)),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(t('Your food budget companion','Votre assistant budget alimentaire'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
                  Text(t('Move the budget and I will recalculate your daily guardrail.','Déplacez le budget et je recalcule votre garde-fou quotidien.')),
                ])),
              ]),
              const SizedBox(height:16),
              Text(liveBudget.toStringAsFixed(0)+' FCFA',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),
              Text(t('About ','Environ ')+daily.toStringAsFixed(0)+' FCFA '+t('per day • ','par jour • ')+weekly.toStringAsFixed(0)+' FCFA '+t('per week','par semaine')),
              Slider(min:50000,max:1000000,divisions:190,value:liveBudget,label:liveBudget.toStringAsFixed(0)+' FCFA',onChanged:(v){setSheet((){liveBudget=v;controller.text=v.round().toString();});}),
              TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:false),decoration:InputDecoration(labelText:t('Monthly budget (FCFA)','Budget mensuel (FCFA)'),prefixIcon:const Icon(Icons.edit)),onChanged:(v){final parsed=double.tryParse(v.replaceAll(' ',''));if(parsed!=null)setSheet(()=>liveBudget=parsed.clamp(50000.0,1000000.0));}),
              const SizedBox(height:10),
              Wrap(spacing:8,runSpacing:8,children:[
                ...[100000,150000,250000,350000,500000].map((value)=>ActionChip(label:Text((value~/1000).toString()+'k'),onPressed:(){setSheet((){liveBudget=value.toDouble();controller.text=value.toString();});})),
              ]),
              const SizedBox(height:14),
              Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Expanded(child:Text(t('Budget health','Santé du budget'),style:const TextStyle(fontWeight:FontWeight.w800))),Text((progress*100).toStringAsFixed(0)+'%')]),
                const SizedBox(height:8),
                LinearProgressIndicator(value:progress,minHeight:8,borderRadius:BorderRadius.circular(8)),
                const SizedBox(height:8),
                Text(t('Spent ','Dépensé ')+spent.toStringAsFixed(0)+' FCFA • '+t('available ','disponible ')+(liveBudget-spent).clamp(0.0,double.infinity).toStringAsFixed(0)+' FCFA'),
              ]))),
              if(budgetHistory.isNotEmpty) ...[
                const SizedBox(height:12),
                Text(t('Recent budget changes','Derniers changements de budget'),style:const TextStyle(fontWeight:FontWeight.w800)),
                ...budgetHistory.take(3).map((x)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.history),title:Text((x['amount'] as num).toStringAsFixed(0)+' FCFA'),subtitle:Text(x['date'].toString()))),
              ],
              const SizedBox(height:14),
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:(){
                  final value=liveBudget.roundToDouble();
                  setState(()=>budget=value);
                  budgetHistory.insert(0,{'amount':value,'date':DateTime.now().toIso8601String()});
                  _autoPlan(save:false);_refreshShopping(save:false);_save();
                  Navigator.pop(sheet);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Budget updated. Your plan and shopping guardrails were refreshed.','Budget mis à jour. Le plan et les garde-fous d’achat ont été actualisés.'))));
                },
                icon:const Icon(Icons.auto_awesome),
                label:Text(t('Save & refresh my home','Enregistrer et actualiser ma maison')),
              )),
            ]),
          ),
        );
      }),
    );
  }
  Future<void> _showMealEditor([int? index]) async {
    final existing=index==null?null:meals[index];
    final name=TextEditingController(text:existing?[0]?.toString()??'');
    final region=TextEditingController(text:existing?[1]?.toString()??'Centre');
    final cost=TextEditingController(text:existing?[2]?.toString()??'3500');
    final recipeText=TextEditingController(text:existing!=null&&existing.length>3&&existing[3] is List?(existing[3] as List).map((e)=>e['name'].toString()+':'+e['qty'].toString()+' '+e['unit'].toString()).join(', '):'');
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheet)=>Padding(
      padding:EdgeInsets.only(left:20,right:20,top:10,bottom:MediaQuery.of(sheet).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(index==null?t('Teach me a new meal','Apprenez-moi un nouveau repas'):t('Let’s improve this meal','Améliorons ce repas'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
        const SizedBox(height:6),Text(t('This meal becomes part of the living menu and can be used by the planner and Copilot.','Ce repas devient une partie du menu vivant et peut être utilisé par le planificateur et le Copilote.')),
        const SizedBox(height:14),TextField(controller:name,decoration:InputDecoration(labelText:t('Meal name','Nom du repas'))),
        TextField(controller:region,decoration:InputDecoration(labelText:t('Region','Région'))),
        TextField(controller:cost,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t('Estimated cost FCFA','Coût estimé FCFA'))),
        TextField(controller:recipeText,maxLines:3,decoration:InputDecoration(labelText:t('Ingredients (optional)','Ingrédients (facultatif)'),hintText:t('rice:1 kg, tomatoes:0.5 kg, onions:0.2 kg','riz:1 kg, tomates:0.5 kg, oignons:0.2 kg'))),
        const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){
          final n=name.text.trim();if(n.isEmpty)return;final rr=_parseRecipe(recipeText.text);
          final row=<dynamic>[n,region.text.trim().isEmpty?'All':region.text.trim(),double.tryParse(cost.text.replaceAll(' ',''))??0];if(rr.isNotEmpty)row.add(rr);
          setState(()=>index==null?meals.add(row):meals[index]=row);_autoPlan(save:false);_refreshShopping(save:false);_save();Navigator.pop(sheet);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(index==null?t('Meal added. The home intelligence has learned it.','Repas ajouté. L’intelligence maison l’a appris.'):t('Meal updated and replanned.','Repas mis à jour et planifié à nouveau.'))));
        },icon:const Icon(Icons.auto_awesome),label:Text(index==null?t('Add to living menu','Ajouter au menu vivant'):t('Save & replan','Enregistrer et replanifier')))),
      ])),
    ));
  }
  void _deleteMeal(int index){
    if(index<0||index>=meals.length)return;final name=meals[index][0].toString();
    showDialog(context:context,builder:(dialog)=>AlertDialog(title:Text(t('Remove meal?','Retirer le repas ?')),content:Text(t('Remove '+name+' from your living menu?','Retirer '+name+' de votre menu vivant ?')),actions:[
      TextButton(onPressed:()=>Navigator.pop(dialog),child:Text(t('Keep','Garder'))),
      FilledButton(onPressed:(){setState(()=>meals.removeAt(index));_autoPlan(save:false);_refreshShopping(save:false);_save();Navigator.pop(dialog);},child:Text(t('Remove','Retirer')))
    ]));
  }

  @override void dispose(){_speech.stop();_tts.stop();super.dispose();}
}
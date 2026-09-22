import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const HomeFoodApp());

class HomeFoodApp extends StatefulWidget {
  const HomeFoodApp({super.key});
  @override State<HomeFoodApp> createState() => _HomeFoodAppState();
}

class _HomeFoodAppState extends State<HomeFoodApp> {
  int tab = 0;
  String lang = 'EN';
  double budget = 250000, spent = 0;
  final meals = const [
    ['Ndolé + plantain','Littoral',4500], ['Eru + water fufu','Southwest',5000],
    ['Koki + ripe plantain','Centre',3500], ['Achombo + vegetables','West',4000],
    ['Rice + tomato chicken','All',4500], ['Beans + boiled plantain','All',3000],
    ['Cornchaff','Southwest',3500], ['Fufu corn + okra soup','Centre',3500],
  ];
  final pantry = <Map<String,dynamic>>[
    {'name':'Rice','qty':5.0,'unit':'kg','min':2.0}, {'name':'Beans','qty':3.0,'unit':'kg','min':1.0},
    {'name':'Plantain','qty':8.0,'unit':'bunches','min':2.0}, {'name':'Palm oil','qty':1.5,'unit':'L','min':0.5},
    {'name':'Tomatoes','qty':1.0,'unit':'kg','min':1.0}, {'name':'Onions','qty':1.2,'unit':'kg','min':0.5},
  ];
  final plan = const ['Mon — Beans + plantain','Tue — Ndolé + plantain','Wed — Rice + chicken','Thu — Eru + water fufu','Fri — Koki + plantain','Sat — Cornchaff','Sun — Fufu corn + okra soup'];
  final tasks = <Map<String,dynamic>>[
    {'task':'Sweep & mop','done':false},{'task':'Clean kitchen','done':false},{'task':'Clean fridge','done':false},{'task':'Check gas cylinder','done':false},{'task':'Laundry','done':false},
  ];

  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final p=await SharedPreferences.getInstance(); setState((){budget=p.getDouble('budget')??250000;spent=p.getDouble('spent')??0;lang=p.getString('lang')??'EN';}); }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setDouble('budget',budget); await p.setDouble('spent',spent); await p.setString('lang',lang); }
  String t(String en,String fr)=>lang=='FR'?fr:en;
  double get remaining=>budget-spent;
  int get lowStock=>pantry.where((x)=>x['qty']<=x['min']).length;

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
      _line(Icons.restaurant,t('Lunch: ','Déjeuner : ')+plan[DateTime.now().weekday-1].split('—').last.trim()),
      _line(Icons.school,t('School snack: ','Goûter école : ')+'banana + bread + water'),
      _line(Icons.nightlight,t('Dinner: ','Dîner : ')+plan[DateTime.now().weekday%7].split('—').last.trim()),
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
    Text(t('Weekly menu','Menu de la semaine'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _card(t('Optimized for budget + leftovers','Optimisé pour budget + restes'),plan.map((x)=>_line(Icons.restaurant,x)).toList()),
    const SizedBox(height:12),Text(t('Cameroon meal library','Bibliothèque de repas camerounais'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
    ...meals.map((m)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.restaurant)),title:Text(m[0] as String),subtitle:Text(m[1].toString()+' • '+m[2].toString()+' FCFA'),trailing:IconButton(icon:const Icon(Icons.add_circle),onPressed:()=>_addExpense((m[2] as num).toDouble())))))
  ]);

  Widget _storagePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('Pantry & freezer','Garde-manger & congélateur'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _card(t('Stock status','État du stock'),[_line(Icons.ac_unit,t('Freezer capacity: 65% used','Capacité congélateur : 65% utilisée')),_line(Icons.shopping_cart,lowStock.toString()+' '+t('items need shopping','articles nécessitent des achats'))]),
    ...pantry.map((x)=>Card(child:ListTile(title:Text(x['name'].toString()),subtitle:Text(x['qty'].toString()+' '+x['unit'].toString()),trailing:x['qty']<=x['min']?const Chip(label:Text('BUY')):const Icon(Icons.check_circle,color:Colors.green)))),
    FilledButton.icon(onPressed:_showAddStock,icon:const Icon(Icons.add),label:Text(t('Add stock','Ajouter stock')))
  ]);

  Widget _carePage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('House care','Entretien de la maison'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _card(t('Today’s checklist','Checklist du jour'),tasks.map((e)=>CheckboxListTile(value:e['done'],onChanged:(v)=>setState(()=>e['done']=v??false),title:Text(e['task'].toString()),controlAffinity:ListTileControlAffinity.leading)).toList()),
    _card(t('Gas & kitchen','Gaz & cuisine'),[_line(Icons.local_fire_department,t('Record each gas refill and cost.','Enregistrez chaque recharge de gaz et son coût.')),_line(Icons.local_fire_department,t('Include oven usage in monthly household cost.','Incluez l’usage du four dans le coût mensuel.'))])
  ]);

  Widget _reportsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(t('Monthly report','Rapport mensuel'),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    _metric(t('Monthly budget','Budget mensuel'),budget.toStringAsFixed(0)+' FCFA',Icons.account_balance_wallet),
    _metric(t('Food spending','Dépenses nourriture'),spent.toStringAsFixed(0)+' FCFA',Icons.restaurant),
    _metric(t('Remaining','Reste'),remaining.toStringAsFixed(0)+' FCFA',Icons.savings),
    _card(t('Household intelligence','Intelligence du foyer'),[
      _line(Icons.trending_down,t('Reuse leftovers to reduce repeated cooking.','Réutilisez les restes pour réduire les cuissons répétées.')),
      _line(Icons.inventory,t('Buy long-life dry goods in bulk when budget permits.','Achetez les produits secs longue conservation en gros lorsque le budget le permet.')),
      _line(Icons.calendar_month,t('Repeat efficient meals instead of cooking something new every day.','Répétez les repas efficaces au lieu de cuisiner du nouveau chaque jour.'))
    ])
  ]);

  void _addExpense(double amount){setState(()=>spent+=amount);_save();ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(amount.toStringAsFixed(0)+' FCFA '+t('added to food spending','ajoutés aux dépenses nourriture'))));}
  void _showAddStock(){final c=TextEditingController();showDialog(context:context,builder:(_)=>AlertDialog(title:Text(t('Add pantry item','Ajouter un article')),content:TextField(controller:c,decoration:InputDecoration(labelText:t('Name','Nom'))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(t('Cancel','Annuler'))),FilledButton(onPressed:(){if(c.text.trim().isNotEmpty)setState(()=>pantry.add({'name':c.text.trim(),'qty':1.0,'unit':'item','min':0.0}));Navigator.pop(context);},child:Text(t('Add','Ajouter')))]));}
  void _showCopilot() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.auto_awesome)),
                  const SizedBox(width: 10),
                  Text(
                    t('Home Copilot', 'Copilote Maison'),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  'Work with local household data. Try: “Plan tomorrow with what we have”, “What is running out?”, or “Keep this week under 60,000 FCFA”.',
                  'Travaillez avec les données locales. Essayez : « Planifie demain avec ce que nous avons », « Qu’est-ce qui finit ? » ou « Garde la semaine sous 60 000 FCFA ».',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text(t('Plan tomorrow', 'Planifier demain')),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => tab = 1);
                    },
                  ),
                  ActionChip(
                    label: Text(t('Shopping list', 'Liste d’achats')),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => tab = 2);
                    },
                  ),
                  ActionChip(
                    label: Text(t('Budget check', 'Vérifier budget')),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => tab = 4);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

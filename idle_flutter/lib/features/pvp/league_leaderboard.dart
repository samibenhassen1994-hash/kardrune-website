import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../localization/kr_localizations.dart';

class LeagueLeaderboard extends StatefulWidget {
  const LeagueLeaderboard({super.key,required this.api,required this.onClaimed});
  final ApiClient api;
  final Future<void> Function() onClaimed;
  @override State<LeagueLeaderboard> createState()=>_LeagueLeaderboardState();
}
class _LeagueLeaderboardState extends State<LeagueLeaderboard>{
  Map<String,dynamic>? data;
  String? error;
  bool loading=true;
  String? claiming;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async{
    try{final result=await widget.api.get('/api/pvp/leaderboard');if(mounted)setState((){data=result;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _claim(String league) async{
    setState(()=>claiming=league);
    try{
      final result=await widget.api.post('/api/pvp/league-claim',{'league':league});
      if(result['claimed']==true)await widget.onClaimed();
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['claimed']==true?context.tr('League reward claimed!'):context.tr('Reward already claimed.'))));await _load();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}
    finally{if(mounted)setState(()=>claiming=null);}
  }
  @override Widget build(BuildContext context){
    final me=data?['you'] as Map?;
    final leaders=data?['leaders'] as List? ?? [];
    final leagues=data?['leagues'] as List? ?? [];
    final claimed=(data?['claimed'] as List? ?? []).toSet();
    return SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
      Row(children:[Expanded(child:Text(context.tr('PVP LEAGUES'),style:Theme.of(context).textTheme.titleLarge)),
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
      if(loading)const CircularProgressIndicator(),
      if(error!=null)Text(error!,style:const TextStyle(color:Colors.redAccent)),
      if(me!=null)...[
        Text('${context.tr('YOUR LEAGUE')}: ${me['league']} · ${me['points']} ${context.tr('POINTS')}'),
        Text(me['next']==null?context.tr('MAX LEAGUE'): '${me['remaining']} ${context.tr('POINTS TO NEXT LEAGUE')}'),
      ],
      const SizedBox(height:8),
      Expanded(child:ListView(children:[
        for(final value in leagues)
          if(value is Map)
            Card(child:ListTile(
              leading:const Icon(Icons.military_tech,color:Color(0xffe4bb76)),
              title:Text('${value['name']} · ${value['points']} pt'),
              subtitle:Text(value['reward']==0?context.tr('STARTING LEAGUE'):'${value['reward']} Shards'),
              trailing:(value['reward'] is num&&value['reward']>0 && me!=null && (me['points'] as num? ?? 0)>=(value['points'] as num? ?? 0))
                ? TextButton(onPressed:claimed.contains(value['name'])||claiming!=null?null:()=>_claim(value['name'] as String),
                    child:Text(claimed.contains(value['name'])?context.tr('CLAIMED'):context.tr('CLAIM'))):null,
            )),
        const Divider(),
        Text(context.tr('GLOBAL LEADERBOARD'),style:Theme.of(context).textTheme.titleMedium),
        for(final value in leaders)
          if(value is Map)
            ListTile(
              leading:CircleAvatar(child:Text('${value['position']}')),
              title:Text(value['name']?.toString()??'Runebearer',
                style:TextStyle(fontWeight:value['isYou']==true?FontWeight.bold:FontWeight.normal)),
              subtitle:Text('${value['league']} · ${value['wins']} ${context.tr('WINS')}'),
              trailing:Text('${value['points']} pt'),
            ),
      ])),
      Text(context.tr('Win PvP matches to earn points. Only completed matches count (max 10 wins/day, 3 per opponent/day).'),
        textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
    ])));
  }
}

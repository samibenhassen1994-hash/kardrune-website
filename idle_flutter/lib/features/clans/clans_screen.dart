import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../localization/kr_localizations.dart';
import 'clan_emblem.dart';
import 'clan_share.dart';

class ClansScreen extends StatefulWidget {
 const ClansScreen({super.key, required this.api, required this.signedIn, required this.onLogin, this.invite, this.accountCurrent});
 final ApiClient api; final bool signedIn; final VoidCallback onLogin;
 final String? invite; final bool Function()? accountCurrent;
 @override State<ClansScreen> createState()=>_ClansScreenState();
}
class _ClansScreenState extends State<ClansScreen> {
 final List<Map<String,dynamic>> clans=[], members=[];
 Map<String,dynamic>? own, selected;
 bool loading=false,busy=false,more=false,memberMore=false,canDelete=false;
 String? error;
 final Map<String,String> requests={};
 String requestId(String operation)=>requests.putIfAbsent(operation,()=>List.generate(32,(_)=>Random.secure().nextInt(16).toRadixString(16)).join());
 @override void initState(){super.initState();_load();}
 void _error(Object e){if(mounted)setState(()=>error=e is ApiFailure && e.message.startsWith('CLAN_') ? e.message : 'CLAN_ERROR');}
 Future<void> _load({bool next=false}) async {
  if(loading)return;setState((){loading=true;error=null;});
  try {
   if(!next&&widget.signedIn){final me=await widget.api.get('/api/clans?me=1');own=me['clan'] as Map<String,dynamic>?;canDelete=me['canDelete']==true;}
   final result=await widget.api.getPublic('/api/clans?offset=${next?clans.length:0}');
   if(!mounted)return;
   setState((){if(!next)clans.clear();clans.addAll((result['clans'] as List).cast<Map<String,dynamic>>());more=result['hasMore']==true;});
   if(!next&&widget.invite!=null){await _detail(invite:widget.invite);}
   else if(!next&&own!=null){await _detail(id:own!['id'] as String);}
  }catch(e){_error(e);}finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> _detail({String? id,String? invite,bool next=false}) async {
  try {
   final result=await widget.api.getPublic('/api/clans?${invite!=null?'invite=$invite':'id=$id'}&offset=${next?members.length:0}');
   if(!mounted)return;
   setState((){selected=result['clan'] as Map<String,dynamic>;if(!next)members.clear();members.addAll((result['members'] as List).cast<Map<String,dynamic>>());memberMore=result['hasMore']==true;error=null;});
  }catch(e){_error(e);}
 }
 Future<void> _mutate(String action,Map<String,dynamic> values) async {
  if(busy)return;
  if(!widget.signedIn){widget.onLogin();return;}
  if(widget.accountCurrent?.call()==false){_error(const ApiFailure(401,'CLAN_LOGIN'));return;}
  final operation='$action:${values.toString()}';
  setState((){busy=true;error=null;});
  try {
   await widget.api.post('/api/clans',{'action':action,'requestId':requestId(operation),...values});
   requests.remove(operation);
   if(!mounted)return;
   selected=null;await _load();
  }catch(e){_error(e);}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _create() async {
  if(!widget.signedIn){widget.onLogin();return;}
  final name=TextEditingController(),description=TextEditingController();int emblem=0;
  final form=GlobalKey<FormState>();
  final result=await showDialog<Map<String,dynamic>>(context:context,builder:(context)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
   title:Text(context.tr('CREATE CLAN')),
   content:SizedBox(width:340,child:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextFormField(controller:name,maxLength:24,decoration:InputDecoration(labelText:context.tr('CLAN NAME')),validator:(v)=>v==null||v.trim().isEmpty?context.tr('CLAN_INVALID'):null),
    TextFormField(controller:description,maxLength:160,maxLines:3,decoration:InputDecoration(labelText:context.tr('DESCRIPTION'))),
    ClanEmblem(emblem,size:80),
    Wrap(spacing:4,children:[for(var i=0;i<5;i++)Tooltip(message:context.tr(clanEmblems[i]),child:InkWell(key:Key('clan-emblem-$i'),onTap:()=>update(()=>emblem=i),child:Container(decoration:BoxDecoration(border:Border.all(color:emblem==i?const Color(0xffffd98a):Colors.transparent)),child:ClanEmblem(i,size:42))))]),
   ])))),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(context.tr('CANCEL'))),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(context,{'name':name.text.trim(),'description':description.text.trim(),'emblem':emblem});},child:Text(context.tr('CREATE CLAN')))],
  )));
  // Controllers can be referenced until the dialog route finishes animating.
  await Future<void>.delayed(const Duration(milliseconds:300));name.dispose();description.dispose();
  if(result!=null&&mounted)await _mutate('create',result);
 }
 Future<void> _openInvite() async {
  final input=TextEditingController();
  final text=await showDialog<String>(context:context,builder:(context)=>AlertDialog(
   title:Text(context.tr('OPEN CLAN INVITE')),
   content:TextField(controller:input,decoration:InputDecoration(labelText:context.tr('PASTE INVITE LINK'))),
   actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(context.tr('CANCEL'))),FilledButton(onPressed:()=>Navigator.pop(context,input.text.trim()),child:Text(context.tr('OPEN')))],
  ));
  await Future<void>.delayed(const Duration(milliseconds:300));input.dispose();
  if(text==null||!mounted)return;
  final code=Uri.tryParse(text)?.queryParameters['clan']??text;
  if(!RegExp(r'^[a-f0-9-]{32,36}$').hasMatch(code)){_error(const ApiFailure(400,'CLAN_INVALID'));return;}
  await _detail(invite:code);
 }
 Future<void> _leave() async {
  final id=selected!['id'];
  final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(context.tr('LEAVE CLAN')),content:Text(context.tr('CLAN LEAVE CONFIRM')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(context.tr('CANCEL'))),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(context.tr('CONFIRM')))]));
  if(yes==true&&mounted)await _mutate('leave',{'clanId':id,'confirm':true});
 }
 Future<void> _delete() async {
  final id=selected!['id'];
  final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
   title:Text(context.tr('DELETE CLAN')),
   content:Text('${selected!['name']}\n${context.tr('CLAN DELETE CONFIRM')}'),
   actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(context.tr('CANCEL'))),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(context.tr('DELETE CLAN')))],
  ));
  if(yes==true&&mounted)await _mutate('delete',{'clanId':id,'confirm':true});
 }
 Future<void> _copyInvite() async {
  await Clipboard.setData(ClipboardData(text:'https://kardrune.com/idle/?clan=${selected!['inviteCode']}'));
  if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(context.tr('LINK COPIED'))));
 }
 Future<void> _invite() async {
  final url='https://kardrune.com/idle/?clan=${selected!['inviteCode']}';
  if(!await shareClan(url)) {
   await Clipboard.setData(ClipboardData(text:url));
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(context.tr('LINK COPIED'))));
  }
 }
 @override Widget build(BuildContext context)=>_glass(Column(children:[
  Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[IconButton(tooltip:context.tr('CLOSE'),onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),Expanded(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(context.tr('RUNE CLANS'),style:const TextStyle(color:Color(0xffffd98a),fontSize:24)))),IconButton(key:const Key('clan-create'),tooltip:context.tr('CREATE CLAN'),onPressed:busy||own!=null?null:_create,icon:const Icon(Icons.add))])),
  if(loading||busy)const LinearProgressIndicator(),
  if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Column(children:[Text(context.tr(error!),textAlign:TextAlign.center),TextButton(onPressed:loading?null:()=>_load(),child:Text(context.tr('RETRY')))])),
  Expanded(child:ListView(padding:const EdgeInsets.all(12),children:selected==null?[
   OutlinedButton.icon(onPressed:_openInvite,icon:const Icon(Icons.link),label:Text(context.tr('OPEN CLAN INVITE'))),
   if(!loading&&clans.isEmpty&&error==null)Text(context.tr('NO CLANS YET'),textAlign:TextAlign.center),
   for(final clan in clans)Card(color:const Color(0x9916253c),shape:RoundedRectangleBorder(side:const BorderSide(color:Color(0xffb79453)),borderRadius:BorderRadius.circular(10)),child:ListTile(leading:ClanEmblem(clan['emblem'] as int),title:Text(clan['name'] as String),subtitle:Text('${clan['description']}\n${clan['memberCount']} ${context.tr('MEMBERS')}'),trailing:const Icon(Icons.chevron_right),onTap:()=>_detail(id:clan['id'] as String))),
   if(more)TextButton(onPressed:loading?null:()=>_load(next:true),child:Text(context.tr('LOAD MORE'))),
  ]:[
   TextButton(onPressed:()=>setState(()=>selected=null),child:Text(context.tr('ALL CLANS'))),
   Center(child:ClanEmblem(selected!['emblem'] as int,size:100)),
   Text(selected!['name'] as String,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,color:Color(0xffffd98a))),
   Text(selected!['description'] as String,textAlign:TextAlign.center),
   Text('${context.tr('FOUNDER')}: ${selected!['founder']}',textAlign:TextAlign.center),
   const SizedBox(height:12),
   if(!widget.signedIn)...[
    Text(context.tr('CLAN PWA INVITE HELP'),textAlign:TextAlign.center),
    TextButton(onPressed:_copyInvite,child:Text(context.tr('COPY LINK'))),
   ],
   if(own?['id']==selected!['id'])...[
    FilledButton(onPressed:busy?null:_invite,child:Text(context.tr('INVITE FRIENDS'))),
    TextButton(onPressed:busy?null:() async {
      await Clipboard.setData(ClipboardData(text:'https://kardrune.com/idle/?clan=${selected!['inviteCode']}'));
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(context.tr('LINK COPIED'))));
    },child:Text(context.tr('COPY LINK'))),
    TextButton(onPressed:busy?null:_leave,child:Text(context.tr('LEAVE CLAN'))),
   ]else if(own==null)FilledButton(key:const Key('clan-join'),onPressed:busy?null:()=>_mutate('join',{'clanId':selected!['id']}),child:Text(context.tr(widget.signedIn?'JOIN CLAN':'CLAN_LOGIN')))
   else Text(context.tr('CLAN_ALREADY_MEMBER')),
   if(canDelete)TextButton.icon(key:const Key('clan-delete'),onPressed:busy?null:_delete,icon:const Icon(Icons.delete_forever,color:Colors.redAccent),label:Text(context.tr('DELETE CLAN'),style:const TextStyle(color:Colors.redAccent))),
   Text('${selected!['memberCount']} ${context.tr('MEMBERS')}'),
   for(final member in members)ListTile(leading:ClipOval(child:Image.asset('assets/idle/avatars/avatar_${RegExp(r'^[a-z0-9_]+$').hasMatch(member['avatar'] as String? ?? '')?member['avatar']:'player'}.webp',width:42,height:42,errorBuilder:(_,e,s)=>const Icon(Icons.person))),title:Text(member['name'] as String)),
   if(memberMore)TextButton(onPressed:()=>_detail(id:selected!['id'] as String,next:true),child:Text(context.tr('LOAD MORE'))),
  ])),
 ]));
 Widget _glass(Widget child) => Dialog.fullscreen(
  backgroundColor: const Color(0xff091426),
  child: Stack(fit:StackFit.expand,children:[
   ImageFiltered(imageFilter:ImageFilter.blur(sigmaX:3,sigmaY:3),child:Image.asset('assets/idle/arena/arena_background.webp',fit:BoxFit.cover,cacheWidth:1080)),
   SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Container(
    decoration:BoxDecoration(color:const Color(0xd0142034),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xbbdfbb79)),boxShadow:const [BoxShadow(color:Color(0x66000000),blurRadius:16)]),
    child:child,
   ))),
  ]),
 );
}

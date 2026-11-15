import 'dart:math';
import 'dart:convert';
import '../../services/api_client.dart';
import 'package:flutter/material.dart';
import '../../localization/kr_localizations.dart';
import 'cloud_account_controller.dart';

class AdminTestTools extends StatefulWidget {
 const AdminTestTools({super.key,required this.cloud});
 final CloudAccountController cloud;
 @override State<AdminTestTools> createState()=>_AdminTestToolsState();
}
class _AdminTestToolsState extends State<AdminTestTools> {
 bool admin=false,enabled=false;
 @override void initState(){super.initState();_load();}
 Future<void> _load() async {final uid=widget.cloud.identity?.uid;
  try {final r=await widget.cloud.api.get('/api/admin/test-resources');
   if(mounted&&widget.cloud.identity?.uid==uid)setState((){admin=r['admin']==true;enabled=r['enabled']==true;});
  }catch(_){ /* Hidden for non-admin accounts. */ }
 }
 @override Widget build(BuildContext context)=>!admin?const SizedBox.shrink():IconButton(
  key:const Key('admin-test-resources'),tooltip:context.tr('ADMIN_TEST_RESOURCES'),
  padding:EdgeInsets.zero,constraints:const BoxConstraints.tightFor(width:24,height:24),iconSize:18,
  icon:const Icon(Icons.admin_panel_settings_outlined),onPressed:()=>showDialog<void>(context:context,
   builder:(_)=>_GrantDialog(cloud:widget.cloud,enabled:enabled)));
}
class _GrantDialog extends StatefulWidget {
 const _GrantDialog({required this.cloud,required this.enabled});
 final CloudAccountController cloud;final bool enabled;
 @override State<_GrantDialog> createState()=>_GrantDialogState();
}
class _GrantDialogState extends State<_GrantDialog> {
 final shards=TextEditingController(text:'12000'),keys=TextEditingController(text:'50');
 final requestId=List.generate(16,(_)=>Random.secure().nextInt(256).toRadixString(16).padLeft(2,'0')).join();
 bool busy=false;String? error;Map<String,Object?>? submitted;
 late final String pendingKey;
 @override void initState(){super.initState();pendingKey='idle-admin-grant-${widget.cloud.identity?.uid}';
  try {final raw=widget.cloud.local.storage.read(pendingKey);
   if(raw!=null&&raw.isNotEmpty){submitted=Map<String,Object?>.from(jsonDecode(raw) as Map);shards.text='${submitted!['shards']}';keys.text='${submitted!['keysEach']}';}
  }catch(_){submitted=null;}
 }
 Future<void> _grant() async {
  final uid=widget.cloud.identity?.uid;if(uid==null||busy)return;
  final amount=int.tryParse(shards.text),count=int.tryParse(keys.text);
  if(amount==null||count==null||amount<0||amount>100000||count<0||count>1000||amount+count==0){setState(()=>error='0–100000 Shards · 0–1000');return;}
  setState(()=>busy=true);submitted??={'requestId':requestId,'shards':amount,'keysEach':count};
  widget.cloud.local.storage.write(pendingKey,jsonEncode(submitted));
  try {final r=await widget.cloud.api.post('/api/admin/test-resources',{...submitted!,'revision':widget.cloud.revision});
   if(!mounted||widget.cloud.identity?.uid!=uid)return;
   widget.cloud.applyServerSave(r);widget.cloud.local.storage.write(pendingKey,'');Navigator.pop(context);
  }catch(e){if(e is SaveConflict&&widget.cloud.identity?.uid==uid)await widget.cloud.loadCloud();if(mounted)setState(()=>error=e is SaveConflict?context.tr('RETRY'):e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override void dispose(){shards.dispose();keys.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>AlertDialog(title:Text(context.tr('ADMIN_TEST_RESOURCES')),
  content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(!widget.enabled)Text(context.tr('ADMIN_MIGRATION_REQUIRED')),
   TextField(controller:shards,enabled:submitted==null&&!busy,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Shards (0–100000)')),
   TextField(controller:keys,enabled:submitted==null&&!busy,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:context.tr('KEYS_EACH_COLOR'))),
   if(error!=null)Text(error!,style:const TextStyle(color:Colors.redAccent)),
  ])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:Text(context.tr('CLOSE'))),
   TextButton(onPressed:busy||!widget.enabled?null:_grant,child:Text(context.tr('CONFIRM')))]);
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/clans/clans_screen.dart';
import 'package:idle_kardrune/features/clans/clan_emblem.dart';
import 'package:idle_kardrune/services/api_client.dart';
import 'package:idle_kardrune/localization/kr_localizations.dart';
class Token implements AuthTokenProvider { @override Future<String> idToken() async=>'test'; }
class Transport implements ApiTransport {
 final requests=<ApiRequest>[];
 bool member=false,admin=false;
 final clan={'id':'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','name':'Runes','description':'Test clan','emblem':2,'founder':'Sam','memberCount':1,'inviteCode':'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'};
 @override Future<ApiResponse> send(ApiRequest request) async {
  requests.add(request);
  if(request.method=='POST'){member=true;return const ApiResponse(200,'{"ok":true}');}
  if(request.path.contains('me=1'))return ApiResponse(200,jsonEncode({'clan':member?clan:null,'canDelete':admin}));
  if(request.path.contains('invite=')||request.path.contains('id='))return ApiResponse(200,jsonEncode({'clan':clan,'members':[{'name':'Other player','avatar':'player','power':164}],'hasMore':false}));
  return ApiResponse(200,jsonEncode({'clans':[clan],'hasMore':false}));
 }
}
void main(){
 testWidgets('clan dialog dismisses outside and member profile opens',(tester)async{
  final transport=Transport()..member=true;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()=>showDialog<void>(context:context,builder:(_)=>ClansScreen(api:ApiClient(Token(),transport),signedIn:true,onLogin:(){})),child:const Text('open')))));
  await tester.tap(find.text('open'));await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Other player'));await tester.tap(find.text('Other player'));await tester.pumpAndSettle();
  expect(find.text('DECK POWER: 164'),findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton,'CLOSE'));await tester.pumpAndSettle();
  await tester.tapAt(const Offset(2,2));await tester.pumpAndSettle();
  expect(find.byType(ClansScreen),findsNothing);
 });
 for(final language in KrLanguage.values){
 testWidgets('clan form usable with 300px keyboard in ${language.code}',(tester)async{
  tester.view.physicalSize=const Size(320,568);tester.view.devicePixelRatio=1;tester.view.viewInsets=const FakeViewPadding(bottom:300);
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetViewInsets);
  final transport=Transport();
  await tester.pumpWidget(MaterialApp(builder:(context,child)=>KrLocaleScope(language:language,child:child!),home:ClansScreen(api:ApiClient(Token(),transport),signedIn:true,onLogin:(){})));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('clan-create')));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first,'Keyboard clan');
  await tester.ensureVisible(find.byType(TextFormField).last);await tester.enterText(find.byType(TextFormField).last,'Description');
  final submit=find.widgetWithText(FilledButton,KrTranslations.translate(language,'CREATE CLAN'));
  await tester.ensureVisible(submit);await tester.tap(submit);await tester.pumpAndSettle();
  expect(transport.requests.where((r)=>r.method=='POST'),hasLength(1));expect(tester.takeException(),isNull);
 });
 }

 testWidgets('only game admin sees delete and must confirm',(tester)async{
  final transport=Transport()..member=true;
  Widget screen(int version)=>MaterialApp(home:ClansScreen(key:ValueKey(version),api:ApiClient(Token(),transport),signedIn:true,onLogin:(){}));
  await tester.pumpWidget(screen(0));await tester.pumpAndSettle();
  expect(find.byKey(const Key('clan-delete')),findsNothing);
  transport.admin=true;
  await tester.pumpWidget(screen(1));await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('clan-delete')));
  await tester.tap(find.byKey(const Key('clan-delete')));await tester.pumpAndSettle();
  expect(transport.requests.where((r)=>r.method=='POST'),isEmpty);
  await tester.tap(find.widgetWithText(FilledButton,'DELETE CLAN'));await tester.pumpAndSettle();
  final body=jsonDecode(transport.requests.lastWhere((r)=>r.method=='POST').body!);
  expect(body['action'],'delete');expect(body['confirm'],true);
 });
 testWidgets('pasted invite reuses authenticated session',(tester)async{
  final transport=Transport();
  await tester.pumpWidget(MaterialApp(home:ClansScreen(api:ApiClient(Token(),transport),signedIn:true,onLogin:()=>fail('must reuse session'))));await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN CLAN INVITE'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'https://kardrune.com/idle/?clan=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
  await tester.tap(find.widgetWithText(FilledButton,'OPEN'));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('clan-join')));await tester.pumpAndSettle();
  expect(jsonDecode(transport.requests.lastWhere((r)=>r.method=='POST').body!)['action'],'join');
 });

 for(final language in KrLanguage.values){
  testWidgets('clans create controls fit 320px in ${language.code}',(tester)async{
   tester.view.physicalSize=const Size(320,568);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   final transport=Transport();
   await tester.pumpWidget(MaterialApp(builder:(context,child)=>KrLocaleScope(language:language,child:child!),home:ClansScreen(api:ApiClient(Token(),transport),signedIn:true,onLogin:(){})));
   await tester.pumpAndSettle();
   expect(find.text('Runes'),findsOneWidget);
   await tester.tap(find.byKey(const Key('clan-create')));await tester.pumpAndSettle();
   expect(clanEmblems.length,5);
   for(var i=0;i<5;i++){expect(find.byKey(Key('clan-emblem-$i')),findsOneWidget);}
   await tester.ensureVisible(find.byKey(const Key('clan-emblem-4')));
   await tester.tap(find.byKey(const Key('clan-emblem-4')));await tester.pump();
   expect(tester.takeException(),isNull);
   await tester.enterText(find.byType(TextFormField).first,'Night Ravens');
   await tester.tap(find.widgetWithText(FilledButton,KrTranslations.translate(language,'CREATE CLAN')));
   await tester.pumpAndSettle();
   final mutation=transport.requests.where((r)=>r.method=='POST').last;
   expect(jsonDecode(mutation.body!)['emblem'],4);
   expect(jsonDecode(mutation.body!)['name'],'Night Ravens');
   expect(tester.takeException(),isNull);
  });
 }
 testWidgets('invite resolves, guest enters login and authenticated member joins',(tester)async{
  final transport=Transport();var login=false;
  Widget screen(bool signedIn)=>MaterialApp(home:ClansScreen(key:ValueKey(signedIn),api:ApiClient(Token(),transport),signedIn:signedIn,invite:'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',onLogin:()=>login=true));
  await tester.pumpWidget(screen(false));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('clan-join')));await tester.pump();expect(login,true);
  expect(transport.requests.where((r)=>r.method=='POST'),isEmpty);
  await tester.pumpWidget(screen(true));await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('clan-join')));await tester.pumpAndSettle();
  expect(jsonDecode(transport.requests.lastWhere((r)=>r.method=='POST').body!)['action'],'join');
  expect(find.text('INVITE FRIENDS'),findsOneWidget);
 });
 test('clan errors have translations for all seven languages',(){
  for(final language in KrLanguage.values){
   for(final key in ['CLAN_UNAVAILABLE','CLAN_LOGIN','CLAN_NAME_TAKEN','CLAN_ALREADY_MEMBER','CLAN_CREATE_LIMIT','CLAN LEAVE CONFIRM']){
    expect(KrTranslations.translate(language,key),isNot(key));
   }
  }
 });
}

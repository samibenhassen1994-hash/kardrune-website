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
 bool member=false;
 final clan={'id':'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','name':'Runes','description':'Test clan','emblem':2,'founder':'Sam','memberCount':1,'inviteCode':'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'};
 @override Future<ApiResponse> send(ApiRequest request) async {
  requests.add(request);
  if(request.method=='POST'){member=true;return const ApiResponse(200,'{"ok":true}');}
  if(request.path.contains('me=1'))return ApiResponse(200,jsonEncode({'clan':member?clan:null}));
  if(request.path.contains('invite=')||request.path.contains('id='))return ApiResponse(200,jsonEncode({'clan':clan,'members':[],'hasMore':false}));
  return ApiResponse(200,jsonEncode({'clans':[clan],'hasMore':false}));
 }
}
void main(){
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

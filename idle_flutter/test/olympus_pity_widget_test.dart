import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/features/summon/summon_screen.dart';
void main(){testWidgets('Event displays server guarantee and refreshes after tenth pull',(tester) async {
 int pull=10,rate=100;
 await tester.pumpWidget(MaterialApp(home:Scaffold(body:SummonScreen(header:const SizedBox(),shards:12000,
  active:true,accountKey:'u',loadFreeStatus:()async=>{'available':0,'olympus':{'nextPull':pull,'rate':rate}},
  onSummon:(_)async{},onFreeSummon:()async{},onEventSummon:()async{pull=1;rate=20;}))));
 await tester.pumpAndSettle();await tester.tap(find.text('EVENT'));await tester.pumpAndSettle();
 expect(find.textContaining('10/10 · 100%'),findsOneWidget);
 await tester.tap(find.byKey(const Key('summon-event-button')));await tester.pumpAndSettle();
 expect(find.textContaining('1/10 · 20%'),findsOneWidget);
 await tester.pumpWidget(const SizedBox());
});}

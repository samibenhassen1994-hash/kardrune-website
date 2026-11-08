import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/game/deck_power.dart';
void main(){
 test('power uses legal stats, stage and skill; ignores duplicates and unowned cards',(){
  expect(DeckPower.calculate(['sam:1','sam:1','tor:3'],['sam:1'],{'sam:1':50},{'sam:1':8},{'sam:1':'C1'}),164);
  expect(DeckPower.calculate(['sam:3'],['sam:3'],{'sam:3':999},{'sam:3':99},{'sam:3':'U1'}),525);
  expect(DeckPower.calculate([],[],{},{},{}),0);
  expect(DeckPower.calculate(['sam:2'],['sam:2'],{'sam:2':75},{'sam:2':16},{'sam:2':'N1'}),307);
 });
}

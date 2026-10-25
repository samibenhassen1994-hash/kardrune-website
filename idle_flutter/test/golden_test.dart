import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/app.dart';

void main(){
  testWidgets('mobile tournament candidate screenshot',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const KardRuneApp());await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),matchesGoldenFile('goldens/tournament_390x844.png'));
  });
}

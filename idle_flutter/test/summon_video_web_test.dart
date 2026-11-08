@TestOn('browser')
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:idle_kardrune/features/summon/summon_video_web.dart';
void main(){
 testWidgets('video has no Play overlay or native controls; Skip completes once',(tester)async{
  var completed=0;
  await tester.pumpWidget(MaterialApp(home:SizedBox.expand(child:SummonVideo(onComplete:()=>completed++))));
  await tester.pump(const Duration(milliseconds:100));
  final video=web.document.querySelector('video') as web.HTMLVideoElement;
  expect(video.controls,false);
  expect(video.playsInline,true);
  final root=video.parentElement!;
  expect(root.querySelectorAll('button').length,1);
  final skip=root.querySelector('button') as web.HTMLButtonElement;
  expect(skip.textContent,'SKIP');
  skip.click();skip.click();
  expect(completed,1);
  await tester.pumpWidget(const SizedBox());
  expect(video.getAttribute('src'),'');
 });
}

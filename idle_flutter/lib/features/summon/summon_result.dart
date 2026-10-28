import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_stat_badges.dart';
import '../../game/skill_catalog.dart';

class SummonResult extends StatefulWidget {
  const SummonResult({super.key, required this.heroName, required this.stage, required this.asset,
    required this.hp, required this.newAttack, required this.newCrit,
    required this.onKeep, required this.onReplace, required this.onContinue,
    this.onLater,
    this.oldAttack, this.oldCrit, this.oldSkillId, this.newSkillId});
  final String heroName, asset;
  final int stage, hp, newAttack, newCrit;
  final int? oldAttack, oldCrit;
  final String? oldSkillId, newSkillId;
  final VoidCallback onKeep, onReplace, onContinue;
  final VoidCallback? onLater;
  bool get duplicate => oldAttack != null && oldCrit != null;
  @override State<SummonResult> createState() => _SummonResultState();
}

class _SummonResultState extends State<SummonResult> with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(vsync:this,
    duration: const Duration(milliseconds: 1050));
  bool started = false;
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) { started=true; if (MediaQuery.of(context).disableAnimations) { animation.value=1; } else { animation.forward(); } }
  }
  @override void dispose() { animation.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => PopScope(canPop:false,
    child: Dialog(insetPadding: const EdgeInsets.all(10), backgroundColor: const Color(0xff101c32),
      shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),
        side:const BorderSide(color:Color(0xffd6b16a))),
      child: SizedBox(width:430,height:math.min(630,MediaQuery.sizeOf(context).height*.9),
        child: AnimatedBuilder(animation:animation,builder:(context,child) =>
          animation.value < .99 ? _portal(animation.value) : _result()))));
  Widget _portal(double t) => Stack(alignment:Alignment.center,children:[
    Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:RadialGradient(
      colors:[Color.lerp(const Color(0xff6a4387),const Color(0xffbd9bed),t)!,
        const Color(0xff34265b),const Color(0xff071124)])))),
    for(var i=0;i<12;i++) Transform.translate(offset:Offset(
      math.cos(i*math.pi/6+t*3)*108,math.sin(i*math.pi/6+t*3)*108),
      child:Text(i.isEven?'✦':'✧',style:TextStyle(fontSize:18+(i%3)*5,
        color:const Color(0xfff8da95).withValues(alpha:.5+t*.5)))),
    Transform.rotate(angle:t*math.pi*1.7,child:Container(width:145,height:145,
      alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,
        border:Border.all(color:const Color(0xfff9db9c),width:3),
        boxShadow:const [BoxShadow(color:Color(0x77cfabfb),blurRadius:42,spreadRadius:7)]),
      child:const Text('✦',style:TextStyle(fontSize:75,color:Color(0xffffdf9b))))),
    const Positioned(bottom:32,child:Text('SUMMONING…',
      style:TextStyle(color:Color(0xffffe3a1),fontSize:16,fontWeight:FontWeight.w900,letterSpacing:3))),
  ]);
  Widget _result() => Column(children:[
    const SizedBox(height:14),
    Text(widget.duplicate?'DUPLICATE CARD':'NEW HERO UNLOCKED',
      style:const TextStyle(fontFamily:'Georgia',fontSize:20,fontWeight:FontWeight.bold,color:Color(0xffffd88b))),
    const SizedBox(height:4),
    Text('${widget.heroName.toUpperCase()} · STAGE ${widget.stage}',
      style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1)),
    Padding(padding:const EdgeInsets.all(8),child:Text(widget.duplicate
      ? 'Compare both cards, then choose which one to keep.'
      : 'A new champion joins your collection!',
      textAlign:TextAlign.center,style:const TextStyle(color:Color(0xffb4c2d6),fontSize:10))),
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:12),
      child:widget.duplicate?_compare():_newCard())),
    Padding(padding:const EdgeInsets.fromLTRB(10,8,10,13),child:widget.duplicate
      ?Column(children:[
        Row(children:[
          Expanded(child:_button('KEEP CURRENT · +100',const Key('summon-keep'),widget.onKeep,false)),
          const SizedBox(width:7),
          Expanded(child:_button('REPLACE',const Key('summon-replace'),widget.onReplace,true)),
        ]),
        const SizedBox(height:7),
        const Text('KEEP = +100 SHARDS  ·  REPLACE = NEW STATS',textAlign:TextAlign.center,
          style:TextStyle(color:Color(0xffacbdd5),fontSize:8)),
        if(widget.onLater!=null) TextButton(onPressed:widget.onLater,child:const Text('LATER')),
      ])
      :_button('CONTINUE',const Key('summon-continue'),widget.onContinue,true))
  ]);
  // Full-height card comparison. Keep actions pinned below the scrollable area.
  Widget _compare() => Column(children:[
    SizedBox(height:290,child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Expanded(child:_card('YOUR CARD',widget.oldAttack!,widget.oldCrit!,true)),
      const SizedBox(width:8),
      Expanded(child:_card('NEW CARD',widget.newAttack,widget.newCrit,false)),
    ])),
    const SizedBox(height:12),
    _stat('ATK',widget.oldAttack!,widget.newAttack),
    const SizedBox(height:6),
    _stat('CRIT',widget.oldCrit!,widget.newCrit,percent:true),
    const SizedBox(height:6),
    _stat('HP',widget.hp,widget.hp),
    const SizedBox(height:8),
    Row(children:[
      Expanded(child:_skillSummary(widget.oldSkillId)),
      const SizedBox(width:8),
      Expanded(child:_skillSummary(widget.newSkillId)),
    ]),
    const SizedBox(height:10),
    const Text('▲ GREEN: BETTER    ▼ RED: WORSE',
      style:TextStyle(color:Color(0xffd2dfef),fontSize:11,fontWeight:FontWeight.bold)),
  ]);

  Widget _card(String label,int atk,int crit,bool old) => Column(children:[
    Text(label,style:TextStyle(color:old?const Color(0xffd9e3ee):const Color(0xffffd88b),
      fontSize:12,fontWeight:FontWeight.w900,letterSpacing:1)),
    const SizedBox(height:7),
    Expanded(child:Container(
      key:Key(old?'summon-old-card':'summon-new-card'),
      decoration:BoxDecoration(color:const Color(0xff080f22),
        borderRadius:BorderRadius.circular(9),
        border:Border.all(color:old?const Color(0xff647892):const Color(0xffdbb369),width:1.5)),
      clipBehavior:Clip.antiAlias,
      child:Stack(fit:StackFit.expand,children:[
        Padding(padding:const EdgeInsets.only(top:47),child:Image.asset(widget.asset,
          fit:BoxFit.contain,alignment:Alignment.center)),
        if (SkillCatalog.byId(old ? widget.oldSkillId : widget.newSkillId) case final skill?)
          CardSkillOverlay(skill: skill),
        Positioned(top:3,left:3,right:3,child:Row(children:[
          Expanded(child:_cardStat('ATK','$atk',old?null:atk-widget.oldAttack!)),
          const SizedBox(width:3),
          Expanded(child:_cardStat('CRIT','$crit%',old?null:crit-widget.oldCrit!)),
          const SizedBox(width:3),
          Expanded(child:_cardStat('HP','${widget.hp}',null)),
        ])),
      ]))),
  ]);

  // Green/red feedback is displayed ON the new card, not hidden below it.
  Widget _cardStat(String label,String value,int? delta) {
    final better=delta!=null && delta>0;
    final worse=delta!=null && delta<0;
    final color=better?const Color(0xff79ffae):worse?const Color(0xffff9999):const Color(0xffffe0a0);
    return Semantics(label:'$label $value${better ? ' improved' : worse ? ' worse' : ''}',
      child:Container(height:43,
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(5),
          color:better?const Color(0xff10472e):worse?const Color(0xff542329):const Color(0xee172237),
          border:Border.all(color:better?const Color(0xff3fe58f):worse?const Color(0xffff7474):const Color(0xff647892))),
        padding:const EdgeInsets.symmetric(horizontal:1),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(label,maxLines:1,style:const TextStyle(color:Color(0xffeff5ff),
            fontSize:9,fontWeight:FontWeight.w800)),
          FittedBox(fit:BoxFit.scaleDown,child:Text('${better ? '▲ ' : worse ? '▼ ' : ''}$value',
            maxLines:1,style:TextStyle(color:color,fontSize:14,fontWeight:FontWeight.w900))),
        ])));
  }
  Widget _stat(String label,int old,int next,{bool percent=false}) {
    final delta=next-old;
    final color=delta>0?const Color(0xff77e6a4):delta<0?const Color(0xffff8989):const Color(0xffc9d5e2);
    String fmt(int v)=>percent?'$v%':'$v';
    return Container(height:37,padding:const EdgeInsets.symmetric(horizontal:9),
      decoration:BoxDecoration(color:const Color(0xff192941),borderRadius:BorderRadius.circular(7),
        border:Border.all(color:const Color(0x66798da8))),
      child:Row(children:[
        SizedBox(width:47,child:Text(label,style:const TextStyle(color:Color(0xffffd88b),
          fontWeight:FontWeight.w900,fontSize:11))),
        Expanded(child:Text(fmt(old),textAlign:TextAlign.center,
          style:const TextStyle(fontSize:13,color:Color(0xffd0deed)))),
        const Icon(Icons.arrow_forward,color:Color(0xff9caec8),size:15),
        Expanded(child:Row(key:Key('summon-delta-${label.toLowerCase()}'),
          mainAxisAlignment:MainAxisAlignment.end,children:[
          Icon(delta==0?Icons.remove:delta>0?Icons.arrow_upward:Icons.arrow_downward,color:color,size:17),
          Flexible(child:Text(' ${fmt(next)}',maxLines:1,overflow:TextOverflow.fade,
            style:TextStyle(color:color,fontSize:13,fontWeight:FontWeight.w900)))
        ]))
      ]));
  }
  Widget _newCard()=>Column(children:[
    SizedBox(height:300,child:CharacterCardArt(key:const Key('summon-new-card'),
      asset:widget.asset,hp:widget.hp,attack:widget.newAttack,crit:widget.newCrit,
      skillId:widget.newSkillId)),
    const SizedBox(height:12),
    const Text('ADDED TO YOUR COLLECTION',style:TextStyle(
      color:Color(0xff85e4b0),fontSize:11,fontWeight:FontWeight.w900))
  ]);
  Widget _skillSummary(String? id) {
    final skill = SkillCatalog.byId(id);
    if (skill == null) return const SizedBox.shrink();
    return Column(children:[
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 145),
        child: SkillRarityBadge(skill: skill, compact: true))),
      const SizedBox(height:3),
      Text(skill.description,textAlign:TextAlign.center,
        style:const TextStyle(color:Color(0xffc9d6e5),fontSize:9)),
    ]);
  }
  Widget _button(String label,Key key,VoidCallback action,bool gold) =>
    ElevatedButton(key:key,onPressed:action,
      style:ElevatedButton.styleFrom(backgroundColor:gold?const Color(0xffe5bf79):const Color(0xff29405c),
        foregroundColor:gold?const Color(0xff241b12):const Color(0xffffe6ba),
        minimumSize:const Size.fromHeight(45),padding:const EdgeInsets.symmetric(horizontal:4)),
      child:FittedBox(fit:BoxFit.scaleDown,child:Text(label,maxLines:1,
        style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))));
}

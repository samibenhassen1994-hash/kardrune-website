import 'package:flutter/material.dart';
const clanEmblems = ['DRAGON', 'WOLF', 'PHOENIX', 'RUNIC SHIELD', 'RAVEN'];
class ClanEmblem extends StatelessWidget {
 const ClanEmblem(this.emblem,{super.key,this.size=54});
 final int emblem;final double size;
 @override Widget build(BuildContext context)=>Image.asset('assets/idle/clans/emblem_${emblem.clamp(0,4)}.webp',width:size,height:size,fit:BoxFit.contain,cacheWidth:(size*3).round());
}

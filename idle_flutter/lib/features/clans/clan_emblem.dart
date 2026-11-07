import 'package:flutter/material.dart';
const clanEmblems = ['DRAGON', 'WOLF', 'PHOENIX', 'RUNIC SHIELD', 'RAVEN'];
class ClanEmblem extends StatelessWidget {
 const ClanEmblem(this.emblem, {super.key, this.size=54});
 final int emblem; final double size;
 @override Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _EmblemPainter(emblem));
}
class _EmblemPainter extends CustomPainter {
 const _EmblemPainter(this.id); final int id;
 @override void paint(Canvas c, Size size) {
  c.save(); c.scale(size.width/100,size.height/100);
  final shield=Path()..moveTo(12,10)..lineTo(50,3)..lineTo(88,10)..lineTo(84,66)..quadraticBezierTo(70,90,50,98)..quadraticBezierTo(30,90,16,66)..close();
  c.drawPath(shield,Paint()..color=const Color(0xff14233d));
  c.drawPath(shield,Paint()..color=const Color(0xffebc571)..style=PaintingStyle.stroke..strokeWidth=3);
  final gold=Paint()..color=const Color(0xffffd98a)..strokeWidth=3..strokeJoin=StrokeJoin.round;
  Path polygon(List<Offset> points) => Path()..addPolygon(points,true);
  switch(id) {
   case 0: // Dragon: horned head, open jaw, curling neck.
    c.drawPath(polygon(const [Offset(26,76),Offset(35,55),Offset(28,37),Offset(33,18),Offset(44,32),Offset(64,26),Offset(76,38),Offset(65,43),Offset(76,48),Offset(59,53),Offset(50,66),Offset(59,80),Offset(42,85)]),gold);
    c.drawCircle(const Offset(56,36),3,Paint()..color=const Color(0xff16243b));
   case 1: // Wolf: ears, cheek fur and muzzle.
    c.drawPath(polygon(const [Offset(23,24),Offset(42,34),Offset(58,34),Offset(77,24),Offset(72,57),Offset(61,76),Offset(50,85),Offset(39,76),Offset(28,57)]),gold);
    final dark=Paint()..color=const Color(0xff14233d);
    c.drawPath(polygon(const [Offset(31,48),Offset(45,53),Offset(38,57)]),dark);
    c.drawPath(polygon(const [Offset(69,48),Offset(55,53),Offset(62,57)]),dark);
    c.drawPath(polygon(const [Offset(44,68),Offset(56,68),Offset(50,75)]),dark);
   case 2: // Phoenix: upward flame wings and three tail feathers.
    c.drawPath(polygon(const [Offset(50,30),Offset(58,38),Offset(76,19),Offset(72,45),Offset(83,38),Offset(73,62),Offset(59,59),Offset(67,85),Offset(53,74),Offset(50,90),Offset(47,74),Offset(33,85),Offset(41,59),Offset(27,62),Offset(17,38),Offset(28,45),Offset(24,19),Offset(42,38)]),gold);
   case 3: // Runic ward.
    gold.style=PaintingStyle.stroke;
    c.drawPath(polygon(const [Offset(50,20),Offset(72,50),Offset(50,80),Offset(28,50)]),gold);
    c.drawLine(const Offset(50,20),const Offset(50,80),gold);
    c.drawLine(const Offset(28,50),const Offset(72,50),gold);
    c.drawCircle(const Offset(50,50),8,gold);
   default: // Raven: hooked beak, feathered wing and tail.
    c.drawPath(polygon(const [Offset(23,70),Offset(39,38),Offset(55,27),Offset(67,31),Offset(80,44),Offset(66,43),Offset(63,56),Offset(49,70),Offset(41,85),Offset(39,71),Offset(31,83),Offset(33,66)]),gold);
    c.drawCircle(const Offset(60,36),2.5,Paint()..color=const Color(0xff14233d));
  }
  c.restore();
 }
 @override bool shouldRepaint(_EmblemPainter old) => id!=old.id;
}

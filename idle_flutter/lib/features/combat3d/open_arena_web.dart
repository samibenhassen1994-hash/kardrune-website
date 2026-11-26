import 'package:web/web.dart' as web;
const bool arenaAvailable = true;
void openTrialArena() {
  web.window.location.assign(Uri.parse(web.document.baseURI).resolve('combat3d/duel.html?hero=atena').toString());
}

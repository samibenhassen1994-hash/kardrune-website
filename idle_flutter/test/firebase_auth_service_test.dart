import 'package:flutter_test/flutter_test.dart';
import 'package:idle_kardrune/services/firebase_auth_service.dart';

void main(){
  test('Firebase config preserves the Pages API fields',(){
    final config=FirebaseWebConfig.fromApi({'enabled':true,'firebase':{'projectId':'p','apiKey':'k','authDomain':'p.firebaseapp.com','appId':'a'}});
    expect(config.enabled,isTrue);expect(config.projectId,'p');expect(config.apiKey,'k');expect(config.authDomain,'p.firebaseapp.com');expect(config.appId,'a');
  });
  test('incomplete or disabled config stays unavailable',(){
    expect(FirebaseWebConfig.fromApi({'enabled':false}).enabled,isFalse);
    expect(FirebaseWebConfig.fromApi({'enabled':true,'firebase':{'projectId':'p'}}).enabled,isFalse);
  });
}

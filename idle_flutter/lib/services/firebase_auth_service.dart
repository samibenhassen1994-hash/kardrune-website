import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'api_client.dart';

class FirebaseWebConfig {
  const FirebaseWebConfig({
    required this.enabled,
    this.projectId,
    this.apiKey,
    this.authDomain,
    this.appId,
  });
  final bool enabled;
  final String? projectId, apiKey, authDomain, appId;
  factory FirebaseWebConfig.fromApi(Map<String, dynamic> value) {
    final raw = value['firebase'];
    if (value['enabled'] != true || raw is! Map) {
      return const FirebaseWebConfig(enabled: false);
    }
    final project = raw['projectId'],
        key = raw['apiKey'],
        domain = raw['authDomain'];
    if (project is! String ||
        project.isEmpty ||
        key is! String ||
        key.isEmpty ||
        domain is! String ||
        domain.isEmpty) {
      return const FirebaseWebConfig(enabled: false);
    }
    return FirebaseWebConfig(
      enabled: true,
      projectId: project,
      apiKey: key,
      authDomain: domain,
      appId: raw['appId'] is String ? raw['appId'] as String : null,
    );
  }
}

class FirebaseAuthService implements AuthTokenProvider {
  FirebaseAuthService(this.auth);
  final FirebaseAuth auth;
  User? get currentUser => auth.currentUser;
  Stream<User?> get changes => auth.authStateChanges();
  @override
  Future<String> idToken() async {
    final token = await auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ApiFailure(401, 'Sign in first');
    }
    return token;
  }

  Future<UserCredential> signInWithGoogle() =>
      auth.signInWithPopup(GoogleAuthProvider());
  Future<UserCredential> signInWithEmail(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email, password: password);
  Future<UserCredential> registerWithEmail(String email, String password) =>
      auth.createUserWithEmailAndPassword(email: email, password: password);
  Future<void> signOut() => auth.signOut();

  static Future<FirebaseAuthService?> initialize(ApiClient client) async {
    final config = FirebaseWebConfig.fromApi(
      await client.getPublic('/api/config'),
    );
    if (!config.enabled) return null;
    final app = await Firebase.initializeApp(
      name: 'idle-kardrune-cloud',
      options: FirebaseOptions(
        apiKey: config.apiKey!,
        appId: config.appId ?? 'idle-kardrune-web',
        messagingSenderId: '',
        projectId: config.projectId!,
        authDomain: config.authDomain,
      ),
    );
    return FirebaseAuthService(FirebaseAuth.instanceFor(app: app));
  }
}

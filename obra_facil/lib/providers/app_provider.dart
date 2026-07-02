// lib/providers/app_provider.dart
import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../models/obra_model.dart';
import '../models/lancamento_model.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/ia_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  final IaService _iaService = IaService();

  UsuarioModel? _usuario;
  List<ObraModel> _obras = [];
  ObraModel? _obraSelecionada;
  bool _carregando = false;
  String? _erro;

  UsuarioModel? get usuario => _usuario;
  List<ObraModel> get obras => _obras;
  ObraModel? get obraSelecionada => _obraSelecionada;
  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get isLogado => _usuario != null;
  AuthService get authService => _authService;
  FirebaseService get firebaseService => _firebaseService;
  IaService get iaService => _iaService;

  void setCarregando(bool valor) {
    _carregando = valor;
    notifyListeners();
  }

  void setErro(String? erro) {
    _erro = erro;
    notifyListeners();
  }

  void setUsuario(UsuarioModel? usuario) {
    _usuario = usuario;
    notifyListeners();
  }

  void setObras(List<ObraModel> obras) {
    _obras = obras;
    notifyListeners();
  }

  void selecionarObra(ObraModel obra) {
    _obraSelecionada = obra;
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    setCarregando(true);
    setErro(null);
    try {
      final usuario = await _authService.login(email, senha);
      if (usuario != null) {
        setUsuario(usuario);
        return true;
      }
      return false;
    } catch (e) {
      setErro(e.toString());
      return false;
    } finally {
      setCarregando(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _obras = [];
    _obraSelecionada = null;
    notifyListeners();
  }

  Stream<List<ObraModel>> streamObras() {
    if (_usuario == null) return const Stream.empty();
    if (_usuario!.isDono) {
      return _firebaseService.streamObras(_usuario!.id);
    } else {
      return _firebaseService.streamObrasMestre(_usuario!.id);
    }
  }
}

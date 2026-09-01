import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/animal.dart';
import 'animal_repository.dart';

/// Implementación real, contra el backend de Milena (Express + TS sobre
/// Neon). Las rutas asumidas son `GET /animales`, `GET /animales/:id` y
/// `POST /animales` — AJUSTAR cuando Milena confirme el contrato real
/// de la API (nombres de ruta, forma exacta del JSON, autenticación).
///
/// No se activa todavía: `AppConfig.useRealApi` sigue en `false` hasta
/// que el backend esté desplegado y probado.
class ApiAnimalRepository implements AnimalRepository {
  final http.Client _client;

  ApiAnimalRepository({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  @override
  Future<List<Animal>> getAll() async {
    final res = await _client.get(_uri('/animales'));
    _checkOk(res);
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => Animal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Animal> getById(String id) async {
    final res = await _client.get(_uri('/animales/$id'));
    _checkOk(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<Animal> create(CreateAnimalDTO dto) async {
    final res = await _client.post(
      _uri('/animales'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    );
    _checkOk(res);
    return Animal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error de API (${res.statusCode}): ${res.body}');
    }
  }
}

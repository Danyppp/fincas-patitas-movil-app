import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/reproduccion/event_type.dart';
import '../models/reproduccion/reproductive_event.dart';
import 'reproduction_repository.dart';

/// Implementación real contra el backend de Milena. Rutas asumidas:
/// `GET /reproduccion`, `POST /reproduccion`,
/// `PATCH /reproduccion/:id/estado` — AJUSTAR cuando el contrato real
/// esté confirmado (ver GIT_WORKFLOW.md, sección de módulos compartidos).
/// Desactivada mientras `AppConfig.useRealApi` sea `false`.
class ApiReproductionRepository implements ReproductionRepository {
  final http.Client _client;

  ApiReproductionRepository({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  @override
  Future<List<ReproductiveEvent>> getAll() async {
    final res = await _client.get(_uri('/reproduccion'));
    _checkOk(res);
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => ReproductiveEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReproductiveEvent> create(CreateReproductiveEventDTO dto) async {
    final res = await _client.post(
      _uri('/reproduccion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    );
    _checkOk(res);
    return ReproductiveEvent.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<ReproductiveEvent> updateGestationStatus(
    String eventId,
    GestationStatus status,
  ) async {
    final res = await _client.patch(
      _uri('/reproduccion/$eventId/estado'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'gestation_status': status.toJson()}),
    );
    _checkOk(res);
    return ReproductiveEvent.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error de API (${res.statusCode}): ${res.body}');
    }
  }
}

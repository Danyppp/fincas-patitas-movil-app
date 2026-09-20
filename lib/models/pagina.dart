/// Envoltorio de paginación que usa el backend en `GET /api/animales`:
/// `{ data: T[], paginacion: { pagina, limite, total, totalPaginas } }`.
class Pagina<T> {
  final List<T> data;
  final int pagina;
  final int limite;
  final int total;
  final int totalPaginas;

  const Pagina({
    required this.data,
    required this.pagina,
    required this.limite,
    required this.total,
    required this.totalPaginas,
  });

  factory Pagina.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    final paginacion = json['paginacion'] as Map<String, dynamic>;
    return Pagina(
      data: (json['data'] as List<dynamic>)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(),
      pagina: paginacion['pagina'] as int,
      limite: paginacion['limite'] as int,
      total: paginacion['total'] as int,
      totalPaginas: paginacion['totalPaginas'] as int,
    );
  }

  bool get hayMasPaginas => pagina < totalPaginas;
}

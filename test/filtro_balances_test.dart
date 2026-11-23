import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/models/financiera/balance.dart';
import 'package:fincas_patitas_movil_app/models/financiera/filtro_balances.dart';

void main() {
  Balance balance(int id, DateTime inicio, DateTime? fin) => Balance(
        id: id,
        periodo: inicio,
        totalVentas: 0,
        totalGastos: 0,
        balanceNeto: 0,
        fechaInicio: fin == null ? null : inicio,
        fechaFin: fin,
      );

  final nov = balance(1, DateTime(2026, 11, 1), DateTime(2026, 11, 23));
  final oct = balance(2, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
  final sinRango = balance(3, DateTime(2026, 9, 1), null);
  final todos = [nov, oct, sinRango];

  group('FiltroBalances.filtrar', () {
    test('sin fechas devuelve todos', () {
      expect(FiltroBalances.filtrar(todos).length, 3);
    });

    test('muestra los que se cruzan con el rango', () {
      final r = FiltroBalances.filtrar(todos,
          desde: DateTime(2026, 11, 10), hasta: DateTime(2026, 11, 20));
      expect(r.map((b) => b.id), [1]);
    });

    test('un rango que solo toca el borde también cuenta', () {
      final r = FiltroBalances.filtrar(todos,
          desde: DateTime(2026, 10, 31), hasta: DateTime(2026, 11, 1));
      expect(r.map((b) => b.id), [1, 2]);
    });

    test('solo Desde: todo lo que termine ese día o después', () {
      final r = FiltroBalances.filtrar(todos, desde: DateTime(2026, 11, 5));
      expect(r.map((b) => b.id), [1]);
    });

    test('solo Hasta: todo lo que empiece ese día o antes', () {
      final r = FiltroBalances.filtrar(todos, hasta: DateTime(2026, 10, 15));
      expect(r.map((b) => b.id), [2, 3]);
    });

    test('un balance sin rango se compara por su fecha de periodo', () {
      final r = FiltroBalances.filtrar(todos,
          desde: DateTime(2026, 9, 1), hasta: DateTime(2026, 9, 1));
      expect(r.map((b) => b.id), [3]);
    });
  });

  group('FiltroBalances paginación', () {
    final doce = [
      for (var i = 1; i <= 12; i++)
        balance(i, DateTime(2026, 1, i), DateTime(2026, 1, i)),
    ];

    test('total de páginas', () {
      expect(FiltroBalances.totalPaginas(0), 1);
      expect(FiltroBalances.totalPaginas(5), 1);
      expect(FiltroBalances.totalPaginas(6), 2);
      expect(FiltroBalances.totalPaginas(12), 3);
    });

    test('5 por página y la última trae el resto', () {
      expect(FiltroBalances.pagina(doce, 0).map((b) => b.id), [1, 2, 3, 4, 5]);
      expect(FiltroBalances.pagina(doce, 1).map((b) => b.id), [6, 7, 8, 9, 10]);
      expect(FiltroBalances.pagina(doce, 2).map((b) => b.id), [11, 12]);
    });

    test('una página fuera de rango usa la última; lista vacía no falla', () {
      expect(FiltroBalances.pagina(doce, 9).map((b) => b.id), [11, 12]);
      expect(FiltroBalances.pagina([], 0), isEmpty);
    });
  });
}

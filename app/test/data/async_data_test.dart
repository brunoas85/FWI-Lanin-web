import 'package:flutter_test/flutter_test.dart';
import 'package:fwi_lanin/data/async_data.dart';

void main() {
  test('arranca en loading y pasa a success', () async {
    final vm = AsyncData<int>(() async => 42, autoLoad: false);
    expect(vm.state, isA<DataLoading<int>>());

    await vm.load();

    expect((vm.state as DataSuccess<int>).data, 42);
  });

  test('autoLoad dispara la carga sin llamar a load() a mano', () async {
    final vm = AsyncData<int>(() async => 1);
    await Future<void>.delayed(Duration.zero);

    expect(vm.state, isA<DataSuccess<int>>());
  });

  test('un error sin carga previa no tiene dato de respaldo', () async {
    final vm = AsyncData<int>(() async => throw Exception('falló'), autoLoad: false);

    await vm.load();

    final error = vm.state as DataError<int>;
    expect(error.staleData, isNull);
  });

  test('reintentar y fallar conserva el último dato bueno', () async {
    var fallar = false;
    final vm = AsyncData<int>(() async {
      if (fallar) throw Exception('sin conexión');
      return 7;
    }, autoLoad: false);

    await vm.load();
    expect((vm.state as DataSuccess<int>).data, 7);

    fallar = true;
    await vm.load();

    final error = vm.state as DataError<int>;
    expect(error.staleData, 7);
  });

  test('notifica a los listeners en cada transición de estado', () async {
    final vm = AsyncData<int>(() async => 5, autoLoad: false);
    var notificaciones = 0;
    vm.addListener(() => notificaciones++);

    await vm.load();

    // Una notificación al pasar a loading, otra al pasar a success.
    expect(notificaciones, 2);
  });
}

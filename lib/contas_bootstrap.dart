import 'contas_bootstrap_stub.dart'
    if (dart.library.ffi) 'contas_bootstrap_ffi.dart' as impl;

Future<void> configureContasDatabaseIfNeeded() => impl.configureContasDatabaseIfNeeded();

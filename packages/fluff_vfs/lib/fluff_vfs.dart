/// Fluff virtual file-system.
///
/// Defines the storage seam used by every Fluff screen. Concrete
/// providers (local, archive, network, vault) implement [FsProvider].
library;

export 'src/fs_capabilities.dart';
export 'src/fs_node.dart';
export 'src/fs_path.dart';
export 'src/fs_provider.dart';
export 'src/mem_fs_provider.dart';

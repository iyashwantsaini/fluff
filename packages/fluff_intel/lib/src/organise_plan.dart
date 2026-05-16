import 'package:meta/meta.dart';

/// A single proposed change to one file.
@immutable
class OrganiseAction {
  const OrganiseAction({
    required this.sourcePath,
    required this.targetPath,
    required this.reason,
  });

  final String sourcePath;
  final String targetPath;
  final String reason;

  bool get isRename {
    final si = sourcePath.lastIndexOf('/');
    final ti = targetPath.lastIndexOf('/');
    return sourcePath.substring(0, si) == targetPath.substring(0, ti);
  }
}

/// A grouped batch of [OrganiseAction]s the user can accept or
/// reject as a whole.
@immutable
class OrganisePlan {
  const OrganisePlan({required this.title, required this.actions});

  final String title;
  final List<OrganiseAction> actions;

  int get renameCount => actions.where((a) => a.isRename).length;
  int get moveCount => actions.length - renameCount;
}

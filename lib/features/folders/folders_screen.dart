import 'package:flutter/material.dart';

// TODO(design): implemented in a later milestone against /specs/design/.
class FoldersScreen extends StatelessWidget {
  const FoldersScreen({this.folderId, super.key});

  final int? folderId;

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Folders', style: Theme.of(context).textTheme.titleLarge),
  );
}

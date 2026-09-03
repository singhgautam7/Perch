import 'package:flutter/material.dart';

// TODO(design): implemented in a later milestone against /specs/design/.
class LinkDetailScreen extends StatelessWidget {
  const LinkDetailScreen({required this.linkId, super.key});

  final int linkId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text('Link $linkId', style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

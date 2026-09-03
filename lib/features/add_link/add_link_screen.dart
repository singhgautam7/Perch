import 'package:flutter/material.dart';

// TODO(design): implemented in a later milestone against /specs/design/.
class AddLinkScreen extends StatelessWidget {
  const AddLinkScreen({this.sharedUrl, super.key});

  final String? sharedUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text('Add link', style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

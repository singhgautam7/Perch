import 'package:flutter/material.dart';

// TODO(design): implemented in a later milestone against /specs/design/.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('More', style: Theme.of(context).textTheme.titleLarge),
  );
}

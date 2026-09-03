import 'package:flutter/material.dart';

// TODO(design): implemented in a later milestone against /specs/design/.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Welcome', style: Theme.of(context).textTheme.titleLarge),
  );
}

import 'package:flutter/material.dart';

import '../app.dart';
import '../application/vault_controller.dart';
import '../domain/vault_entry.dart';
import 'widgets.dart';

class GeneratorPanel extends StatefulWidget {
  final VaultController vault;
  final ValueChanged<String>? onUse;
  const GeneratorPanel({super.key, required this.vault, this.onUse});
  @override
  State<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends State<GeneratorPanel> {
  int length = 20;
  bool digits = true, symbols = true;
  late String password = generatePassword();
  void regenerate() => setState(
    () => password = generatePassword(
      length: length,
      digits: digits,
      symbols: symbols,
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 20),
      Text(
        'Un secret\nbien à vous.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Un mot de passe unique, en un geste.',
        style: TextStyle(color: Color(0xFF718174)),
      ),
      const SizedBox(height: 26),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          password,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: accent,
            fontSize: 25,
            height: 1.5,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Text('Longueur', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$length caractères'),
        ],
      ),
      Slider(
        value: length.toDouble(),
        min: 12,
        max: 64,
        divisions: 52,
        label: '$length',
        onChanged: (v) {
          length = v.round();
          regenerate();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Chiffres'),
        value: digits,
        onChanged: (v) {
          digits = v;
          regenerate();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Symboles'),
        value: symbols,
        onChanged: (v) {
          symbols = v;
          regenerate();
        },
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: regenerate,
          icon: const Icon(Icons.refresh),
          label: const Text('Générer un nouveau mot de passe'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            try {
              await widget.vault.storage.copySecret(password);
              if (context.mounted) message(context, 'Copié pour 30 secondes.');
            } catch (_) {
              if (context.mounted) message(context, 'Copie impossible.');
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copier'),
        ),
      ),
      if (widget.onUse != null)
        TextButton(
          onPressed: () => widget.onUse!(password),
          child: const Text('Utiliser ce mot de passe'),
        ),
      const Notice(
        'Généré avec le générateur aléatoire sécurisé du système. Le presse-papiers est effacé après 30 secondes ou au verrouillage.',
      ),
    ],
  );
}

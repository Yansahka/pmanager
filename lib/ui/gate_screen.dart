import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../application/vault_controller.dart';
import 'widgets.dart';

class GateScreen extends StatefulWidget {
  final VaultController vault;
  const GateScreen({super.key, required this.vault});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> with WidgetsBindingObserver {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  String? backup;
  bool acknowledged = false;
  late final Timer ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      password.clear();
      confirmation.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.cancel();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final p = password.text, c = confirmation.text;
    password.clear();
    confirmation.clear();
    await widget.vault.open(p, confirmation: c, backup: backup);
  }

  Future<void> restore() async {
    if (widget.vault.exists) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurer une sauvegarde ?'),
          content: const Text(
            'Après vérification de sa phrase secrète, la sauvegarde remplacera le coffre actuel. Exportez d’abord le coffre actuel si vous souhaitez le conserver.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Choisir le fichier'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    try {
      final source = await widget.vault.importBackup();
      if (mounted && source != null) {
        setState(() {
          backup = source;
          password.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        message(
          context,
          'Fichier illisible ou format non pris en charge. Le coffre actuel est conservé.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = widget.vault;
    if (vault.readFailed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Brand(),
                  Notice(vault.error ?? 'Lecture impossible.', error: true),
                  FilledButton(
                    onPressed: vault.initialize,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final creating = !vault.exists && backup == null;
    final canSubmit =
        !vault.busy && vault.retrySeconds == 0 && (!creating || acknowledged);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Brand(),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    backup != null
                        ? 'Votre coffre,\nretrouvé.'
                        : creating
                        ? 'Vos secrets.\nBien gardés.'
                        : 'Ravi de\nvous retrouver.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    backup != null
                        ? 'Saisissez la phrase secrète de la sauvegarde pour vérifier et restaurer son contenu.'
                        : creating
                        ? 'Un espace à vous, pour tous vos mots de passe. Local, chiffré et simplement sécurisé.'
                        : 'Votre coffre est verrouillé. Votre phrase secrète est la seule clé.',
                    style: const TextStyle(
                      color: Color(0xFF667970),
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SecretField(
                    controller: password,
                    label: creating
                        ? 'Créer une phrase secrète'
                        : 'Phrase secrète',
                    onSubmitted: (_) {
                      if (canSubmit) submit();
                    },
                  ),
                  if (creating) ...[
                    const SizedBox(height: 14),
                    SecretField(
                      controller: confirmation,
                      label: 'Confirmer la phrase secrète',
                    ),
                    const Notice(
                      '16 caractères minimum. Préférez une longue phrase unique composée de plusieurs mots.',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acknowledged,
                      onChanged: vault.busy
                          ? null
                          : (v) => setState(() => acknowledged = v!),
                      title: const Text(
                        'Je comprends que cette phrase ne peut pas être récupérée en cas d’oubli.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  if (vault.error != null) Notice(vault.error!, error: true),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canSubmit ? submit : null,
                      icon: vault.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(
                        vault.retrySeconds > 0
                            ? 'Réessayez dans ${vault.retrySeconds} s'
                            : vault.busy
                            ? 'Ouverture sécurisée…'
                            : backup != null
                            ? 'Vérifier et restaurer'
                            : creating
                            ? 'Créer mon coffre'
                            : 'Déverrouiller',
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: vault.busy
                          ? null
                          : backup != null
                          ? () => setState(() {
                              backup = null;
                              password.clear();
                            })
                          : restore,
                      child: Text(
                        backup != null
                            ? 'Annuler la restauration'
                            : 'Restaurer une sauvegarde chiffrée',
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color(0xFF667970),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AES-256-GCM  ·  Aucune donnée en ligne',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667970),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../application/vault_controller.dart';
import '../domain/vault_entry.dart';
import 'generator_panel.dart';
import 'widgets.dart';

class EntryEditor extends StatefulWidget {
  final VaultController vault;
  final VaultEntry? entry;
  const EntryEditor({super.key, required this.vault, this.entry});
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title);
  late final username = TextEditingController(text: widget.entry?.username);
  late final password = TextEditingController(text: widget.entry?.password);
  late final website = TextEditingController(text: widget.entry?.website);
  late final notes = TextEditingController(text: widget.entry?.notes);
  late String category = widget.entry?.category ?? categories.first;
  late bool favorite = widget.entry?.favorite ?? false;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    for (final c in [title, username, password, website, notes]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || password.text.isEmpty) {
      setState(() => error = 'Renseignez au moins un nom et un mot de passe.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final e = VaultEntry(
      id: widget.entry?.id ?? newId(),
      title: title.text.trim(),
      username: username.text.trim(),
      password: password.text,
      website: website.text.trim(),
      notes: notes.text,
      category: category,
      favorite: favorite,
      updatedAt: DateTime.now(),
    );
    final next = widget.vault.entries.where((v) => v.id != e.id).toList()
      ..add(e);
    final ok = await widget.vault.saveEntries(next);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = widget.vault.error ?? 'Le coffre est verrouillé.';
      });
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    int lines = 1,
    int max = 512,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      maxLength: max,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      validator: c == title
          ? (v) => v == null || v.trim().isEmpty
                ? 'Donnez un nom à cet identifiant.'
                : null
          : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.entry == null
                      ? 'Un nouveau secret.'
                      : 'Modifier l’identifiant',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                field(title, 'Nom du service', max: 100),
                field(username, 'Identifiant ou adresse e-mail'),
                SecretField(controller: password, label: 'Mot de passe'),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (context) => Dialog(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: GeneratorPanel(
                                    vault: widget.vault,
                                    onUse: (value) {
                                      password.text = value;
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Générer un mot de passe'),
                  ),
                ),
                field(website, 'Adresse du site (facultatif)'),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 14),
                field(notes, 'Note privée (facultatif)', lines: 3, max: 10000),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ajouter aux favoris'),
                  value: favorite,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => favorite = v),
                ),
                if (error != null) Notice(error!, error: true),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Chiffrement…' : 'Enregistrer'),
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

class EntryDetail extends StatefulWidget {
  final VaultController vault;
  final VaultEntry entry;
  final VoidCallback onEdit;
  const EntryDetail({
    super.key,
    required this.vault,
    required this.entry,
    required this.onEdit,
  });
  @override
  State<EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<EntryDetail> {
  bool reveal = false, deleting = false;
  Future<void> copy(String value) async {
    if (!widget.vault.unlocked) return;
    try {
      await widget.vault.storage.copySecret(value);
      if (mounted) message(context, 'Copié pour 30 secondes.');
    } catch (_) {
      if (mounted) message(context, 'Copie impossible.');
    }
  }

  Future<void> remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet identifiant ?'),
        content: const Text(
          'Cette action est définitive dans le coffre actuel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || !widget.vault.unlocked) return;
    setState(() => deleting = true);
    final saved = await widget.vault.saveEntries(
      widget.vault.entries.where((e) => e.id != widget.entry.id).toList(),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => deleting = false);
      message(context, widget.vault.error ?? 'Suppression impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Chip(label: Text(e.category)),
              const SizedBox(height: 16),
              const Text(
                'IDENTIFIANT',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.username.isEmpty ? 'Non renseigné' : e.username,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier l’identifiant',
                    onPressed: e.username.isEmpty
                        ? null
                        : () => copy(e.username),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'MOT DE PASSE',
                style: TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reveal ? e.password : '••••••••••••',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 19,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: reveal ? 'Masquer' : 'Afficher',
                    onPressed: () => setState(() => reveal = !reveal),
                    icon: Icon(
                      reveal
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier le mot de passe',
                    onPressed: () => copy(e.password),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              if (e.website.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'SITE',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(e.website),
              ],
              if (e.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'NOTE PRIVÉE',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(e.notes),
              ],
              const SizedBox(height: 20),
              Text(
                'Modifié le ${e.updatedAt.toLocal().day}/${e.updatedAt.toLocal().month}/${e.updatedAt.toLocal().year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: deleting || widget.vault.busy ? null : remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: deleting || widget.vault.busy
                        ? null
                        : widget.onEdit,
                    child: const Text('Modifier'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final VaultController vault;
  const ChangePasswordDialog({super.key, required this.vault});
  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in [current, next, confirm]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final p = current.text, n = next.text, c = confirm.text;
    current.clear();
    next.clear();
    confirm.clear();
    final ok = await widget.vault.changePassword(p, n, c);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      message(
        context,
        'Phrase secrète modifiée. Créez une nouvelle sauvegarde.',
      );
    } else {
      setState(() {
        saving = false;
        error = widget.vault.error ?? 'Le coffre est verrouillé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Une nouvelle clé.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              SecretField(controller: current, label: 'Phrase actuelle'),
              const SizedBox(height: 14),
              SecretField(
                controller: next,
                label: 'Nouvelle phrase (16 caractères min.)',
              ),
              const SizedBox(height: 14),
              SecretField(
                controller: confirm,
                label: 'Confirmer la nouvelle phrase',
              ),
              const Notice(
                'Les anciennes sauvegardes restent protégées par leur ancienne phrase secrète.',
              ),
              if (error != null) Notice(error!, error: true),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Chiffrement…' : 'Modifier'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

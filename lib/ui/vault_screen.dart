import 'package:flutter/material.dart';

import '../app.dart';
import '../application/vault_controller.dart';
import '../domain/vault_entry.dart';
import 'entry_editor.dart';
import 'generator_panel.dart';
import 'widgets.dart';

class VaultScreen extends StatefulWidget {
  final VaultController vault;
  const VaultScreen({super.key, required this.vault});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int tab = 0;
  String query = '', category = 'Tout';
  final search = TextEditingController();
  VaultController get vault => widget.vault;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> edit([VaultEntry? entry]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntryEditor(vault: vault, entry: entry),
    );
  }

  Future<void> detail(VaultEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EntryDetail(
        vault: vault,
        entry: entry,
        onEdit: () {
          Navigator.pop(context);
          edit(entry);
        },
      ),
    );
  }

  Widget entryTile(VaultEntry e) {
    final color = switch (e.category) {
      'Travail' => const Color(0xFFEDE8FF),
      'Finance' => const Color(0xFFFFECCD),
      'Réseaux' => const Color(0xFFE0EEFF),
      _ => const Color(0xFFEAF1E1),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            e.title.characters.first.toUpperCase(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          e.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          e.username.isEmpty ? e.category : e.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF758478)),
        ),
        trailing: IconButton(
          tooltip: e.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          onPressed: vault.busy
              ? null
              : () async {
                  if (!await vault.saveEntries(
                        vault.entries
                            .map((v) => v.id == e.id ? v.toggleFavorite() : v)
                            .toList(),
                      ) &&
                      mounted) {
                    message(
                      context,
                      vault.error ?? 'Le coffre est verrouillé.',
                    );
                  }
                },
          icon: Icon(
            e.favorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: ink,
          ),
        ),
        onTap: () => detail(e),
      ),
    );
  }

  Widget overview() {
    final all = vault.entries;
    final filtered =
        all
            .where(
              (e) =>
                  (tab != 1 || e.favorite) &&
                  (category == 'Tout' || category == e.category) &&
                  '${e.title} ${e.username} ${e.website}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          tab == 1 ? 'Vos essentiels.' : 'L’esprit tranquille.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Vos mots de passe ont trouvé leur place.',
          style: TextStyle(color: Color(0xFF718174)),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOTRE ESPACE PRIVÉ',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${all.length} mot${all.length == 1 ? '' : 's'} de passe',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chiffrés sur cet appareil',
                      style: TextStyle(color: Color(0xFFB8CEC2)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_user_outlined, size: 42, color: accent),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: search,
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Rechercher dans le coffre',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Tout', ...categories]
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => category = c),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              tab == 1 ? 'Favoris' : 'Tous les identifiants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Text(
              '${filtered.length}',
              style: const TextStyle(color: Color(0xFF718174)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.key_outlined,
                    size: 44,
                    color: Color(0xFF8DA080),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    all.isEmpty
                        ? 'Votre premier secret vous attend.'
                        : 'Aucun résultat pour le moment.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    all.isEmpty
                        ? 'Ajoutez un identifiant avec le bouton ci-dessous.'
                        : 'Essayez une autre recherche ou catégorie.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...filtered.map(entryTile),
      ],
    );
  }

  Widget security() {
    final all = vault.entries;
    final counts = <String, int>{};
    for (final e in all) {
      counts.update(e.password, (v) => v + 1, ifAbsent: () => 1);
    }
    final weak = all.where((e) => isWeak(e.password)).toList();
    final reused = all.where((e) => counts[e.password]! > 1).toList();
    final flagged = all
        .where((e) => isWeak(e.password) || counts[e.password]! > 1)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Prenez soin\nde vos accès.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        const Notice(
          'Analyse locale indicative. Aucun mot de passe n’est transmis à un service de recherche de fuites.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metric('${weak.length}', 'À renforcer'),
                _metric('${reused.length}', 'Réutilisés'),
                _metric('${all.length}', 'Au total'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('À vérifier', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (flagged.isEmpty)
          const Notice(
            'Aucun problème détecté par les contrôles locaux. Utilisez une phrase unique pour chaque service.',
          ),
        ...flagged.map(
          (e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  [
                    if (isWeak(e.password)) 'À renforcer',
                    if (counts[e.password]! > 1) 'Réutilisé',
                  ].join(' · '),
                  style: const TextStyle(
                    color: Color(0xFF99602B),
                    fontSize: 12,
                  ),
                ),
              ),
              entryTile(e),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Protection du coffre',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Notice(
          '✓ AES-256-GCM et Argon2id\n✓ Verrouillage après 2 minutes d’inactivité\n✓ Verrouillage dès le passage en arrière-plan\n✓ Presse-papiers effacé après 30 secondes\n✓ Captures d’écran bloquées sur Android',
        ),
      ],
    );
  }

  Widget _metric(String value, String label) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineMedium),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Text('À votre main.', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 10),
      const Text('Un coffre simple. Des protections essentielles.'),
      const SizedBox(height: 28),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Changer la phrase secrète'),
              subtitle: const Text('Vérifie votre phrase actuelle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: vault.busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ChangePasswordDialog(vault: vault),
                    ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Sauvegarder le coffre'),
              subtitle: const Text(
                'Fichier chiffré .sesame · verrouille le coffre',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: vault.busy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final saved = await vault.exportBackup();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              saved
                                  ? 'Sauvegarde chiffrée enregistrée.'
                                  : 'Sauvegarde annulée.',
                            ),
                          ),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Impossible d’enregistrer la sauvegarde.',
                            ),
                          ),
                        );
                      }
                    },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Verrouiller maintenant'),
              onTap: vault.lock,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Notice(
        'Conservez une sauvegarde chiffrée dans un endroit sûr. Une désinstallation efface le coffre local. En cas d’oubli de la phrase secrète, aucune récupération n’est possible.',
      ),
      const Notice(
        'Pour restaurer un fichier, utilisez « Restaurer une sauvegarde chiffrée » sur l’écran verrouillé. Une restauration remplace les données actuelles après vérification.',
      ),
      const SizedBox(height: 20),
      const Text(
        'SÉSAME  /  VERSION 1.0',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.8,
          color: Color(0xFF718174),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Conçu pour rester sur votre appareil.\nSans compte, sans publicité, sans suivi.',
        style: TextStyle(height: 1.6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFFF5F6F1),
      scrolledUnderElevation: 0,
      title: const Brand(),
      actions: [
        IconButton(
          onPressed: vault.lock,
          tooltip: 'Verrouiller le coffre',
          icon: const Icon(Icons.lock_outline),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
            child: tab <= 1
                ? overview()
                : tab == 2
                ? GeneratorPanel(vault: vault)
                : tab == 3
                ? security()
                : settings(),
          ),
        ),
      ),
    ),
    floatingActionButton: tab <= 1
        ? FloatingActionButton.extended(
            elevation: 0,
            backgroundColor: ink,
            foregroundColor: Colors.white,
            onPressed: vault.busy ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un identifiant'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      backgroundColor: Colors.white,
      indicatorColor: accent,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Coffre',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_outline_rounded),
          label: 'Favoris',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          label: 'Générer',
        ),
        NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          label: 'Sécurité',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          label: 'Réglages',
        ),
      ],
    ),
  );
}

import 'dart:math';

const categories = ['Personnel', 'Travail', 'Finance', 'Réseaux', 'Autre'];

class VaultEntry {
  final String id, title, username, password, website, notes, category;
  final bool favorite;
  final DateTime updatedAt;

  const VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.website = '',
    this.notes = '',
    this.category = 'Personnel',
    this.favorite = false,
    required this.updatedAt,
  });

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    final entry = VaultEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      website: json['website'] as String,
      notes: json['notes'] as String,
      category: json['category'] as String,
      favorite: json['favorite'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    if (entry.id.isEmpty ||
        entry.title.trim().isEmpty ||
        entry.password.isEmpty ||
        !categories.contains(entry.category)) {
      throw const FormatException('Entrée invalide');
    }
    return entry;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'website': website,
    'notes': notes,
    'category': category,
    'favorite': favorite,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  VaultEntry toggleFavorite() => VaultEntry(
    id: id,
    title: title,
    username: username,
    password: password,
    website: website,
    notes: notes,
    category: category,
    favorite: !favorite,
    updatedAt: updatedAt,
  );
}

String newId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

String generatePassword({
  int length = 20,
  bool symbols = true,
  bool digits = true,
}) {
  if (length < 12 || length > 64) throw ArgumentError('Longueur invalide');
  final random = Random.secure();
  final groups = [
    'abcdefghijkmnopqrstuvwxyz',
    'ABCDEFGHJKLMNPQRSTUVWXYZ',
    if (digits) '23456789',
    if (symbols) '!@#\$%&*+-=?',
  ];
  final alphabet = groups.join();
  final result = groups.map((g) => g[random.nextInt(g.length)]).toList();
  while (result.length < length) {
    result.add(alphabet[random.nextInt(alphabet.length)]);
  }
  for (var i = result.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result.join();
}

// Conservative local heuristic, never presented as a breach or entropy check.
bool isWeak(String password) =>
    password.length < 14 ||
    RegExp(r'^(.)\1+$').hasMatch(password) ||
    [
      'password',
      'motdepasse',
      'azerty',
      'qwerty',
      '123456',
      'sesame',
    ].any((word) => password.toLowerCase().contains(word));

String? masterPasswordError(String value) {
  if (value.length < 16) {
    return 'Utilisez au moins 16 caractères, idéalement plusieurs mots.';
  }
  if (value.length > 256) return 'Maximum : 256 caractères.';
  if (isWeak(value)) {
    return 'Cette phrase est trop prévisible. Choisissez-en une autre.';
  }
  return null;
}

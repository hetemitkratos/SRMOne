// lib/scrapers/faculty/faculty_name.dart
// Turns an Academia faculty name such as "Dr.J.Shobana (102927)" into the
// search terms and profile slugs www.srmist.edu.in actually understands.
// Ported from the legacy `/faculty` route in academia-backend/backend/api/server.js.

class FacultyNameQuery {
  /// Name without the staff ID, e.g. "Dr.J.Shobana".
  final String cleanName;

  /// Name without title or leading initials, e.g. "Shobana".
  final String searchName;

  /// WordPress search terms, best first.
  final List<String> searchTerms;

  /// Profile slugs to try directly when search finds nothing, best first.
  final List<String> slugCandidates;

  /// Stable key for caching lookups of the same person.
  final String cacheKey;

  const FacultyNameQuery._({
    required this.cleanName,
    required this.searchName,
    required this.searchTerms,
    required this.slugCandidates,
    required this.cacheKey,
  });

  static final _staffId = RegExp(r'\([^)]*\)');
  // A title must be followed by a dot or a space, so "Drishya" keeps its "Dr".
  static final _title =
      RegExp(r'^(prof|mrs|ms|mr|dr)(\.\s*|\s+)', caseSensitive: false);
  static final _leadingInitials = RegExp(r'^([A-Za-z]\.\s*)+');
  static final _nonAlnum = RegExp(r'[^a-z0-9]+');
  static const _titlePrefixes = ['dr', 'mr', 'mrs', 'prof'];

  static String slugify(String s) => s
      .toLowerCase()
      .replaceAll(_nonAlnum, '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Lowercase letters-only form of a person's name without the title, for
  /// comparing an Academia name with a profile page's name.
  static String normalizeForMatch(String name) {
    final noId = name.replaceAll(_staffId, ' ').trim();
    var s = noId.replaceFirst(_title, '');
    s = s.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ').trim();
    return s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }

  factory FacultyNameQuery.parse(String rawName) {
    final cleanName = rawName
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(_staffId, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final noTitle = cleanName.replaceFirst(_title, '').trim();
    final hasLeadingInitial = RegExp(r'^[A-Za-z]\.').hasMatch(noTitle);
    final searchName = noTitle
        .replaceFirst(_leadingInitials, '')
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = searchName.split(' ').where((w) => w.isNotEmpty).toList();
    final longest = words.isEmpty
        ? searchName
        : (List.of(words)..sort((a, b) => b.length.compareTo(a.length))).first;
    final terms = <String>{
      if (searchName.isNotEmpty) searchName,
      if ((hasLeadingInitial || words.length > 1) && longest.length > 1)
        longest,
    }.toList();

    // SRM profile slugs vary wildly ("mr-kaviyaraj-r", "dr-m-monica-bhavani",
    // "mangalagowri-r"), so build the same permutations the web app tried.
    final parts =
        noTitle.split(RegExp(r'[\s.]+')).where((p) => p.isNotEmpty).toList();
    final trailing = parts.length > 1 && parts.last.length == 1
        ? parts.last.toLowerCase()
        : null;
    final leading = <String>[];
    var start = 0;
    while (start < parts.length - 1 && parts[start].length == 1) {
      leading.add(parts[start].toLowerCase());
      start++;
    }
    final leadingInit = leading.isEmpty ? null : leading.join();
    final bodyParts =
        (trailing != null ? parts.sublist(0, parts.length - 1) : parts)
            .skip(start)
            .map((p) => p.toLowerCase())
            .toList();
    final body = slugify(bodyParts.join('-'));

    final slugs = <String>{
      slugify(cleanName),
      if (body.isNotEmpty) ...[
        if (trailing != null) ...[
          for (final t in _titlePrefixes) '$t-$body-$trailing',
          for (final t in _titlePrefixes) '$t-$trailing-$body',
          '$body-$trailing',
          '$trailing-$body',
        ],
        for (final t in _titlePrefixes) '$t-$body',
        body,
        slugify(cleanName.replaceAll('.', ' ')),
        if (leadingInit != null) ...[
          '$body-$leadingInit',
          for (final t in _titlePrefixes) '$t-$body-$leadingInit',
          for (final t in _titlePrefixes) '$t-$leadingInit-$body',
        ],
      ],
    }.where((s) => s.isNotEmpty).toList();

    return FacultyNameQuery._(
      cleanName: cleanName,
      searchName: searchName,
      searchTerms: terms,
      slugCandidates: slugs,
      cacheKey: slugify(cleanName),
    );
  }
}

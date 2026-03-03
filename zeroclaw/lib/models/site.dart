class NewsSite {
  final String id;
  final String name;
  final String baseUrl;
  final String? loginUrl;
  final String? iconUrl;
  final bool isLoggedIn;
  final bool isEnabled;
  final String phase; // 'p0', 'p1', 'p2'
  final List<String> categories;

  const NewsSite({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.loginUrl,
    this.iconUrl,
    this.isLoggedIn = false,
    this.isEnabled = true,
    this.phase = 'p0',
    this.categories = const [],
  });

  factory NewsSite.fromJson(Map<String, dynamic> json) {
    return NewsSite(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['base_url'] as String,
      loginUrl: json['login_url'] as String?,
      iconUrl: json['icon_url'] as String?,
      isLoggedIn: json['is_logged_in'] as bool? ?? false,
      isEnabled: json['is_enabled'] as bool? ?? true,
      phase: json['phase'] as String? ?? 'p0',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'base_url': baseUrl,
        'login_url': loginUrl,
        'icon_url': iconUrl,
        'is_logged_in': isLoggedIn,
        'is_enabled': isEnabled,
        'phase': phase,
        'categories': categories,
      };

  NewsSite copyWith({bool? isLoggedIn, bool? isEnabled}) {
    return NewsSite(
      id: id,
      name: name,
      baseUrl: baseUrl,
      loginUrl: loginUrl,
      iconUrl: iconUrl,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isEnabled: isEnabled ?? this.isEnabled,
      phase: phase,
      categories: categories,
    );
  }

  static List<NewsSite> defaultSites() {
    return [
      const NewsSite(
        id: 'ft',
        name: 'Financial Times',
        baseUrl: 'https://www.ft.com',
        loginUrl: 'https://accounts.ft.com/login',
        phase: 'p0',
        categories: ['world', 'business', 'markets', 'technology'],
      ),
      const NewsSite(
        id: 'reuters',
        name: 'Reuters',
        baseUrl: 'https://www.reuters.com',
        phase: 'p0',
        categories: ['world', 'business', 'markets', 'technology'],
      ),
      const NewsSite(
        id: 'bloomberg',
        name: 'Bloomberg',
        baseUrl: 'https://www.bloomberg.com',
        loginUrl: 'https://www.bloomberg.com/account/signin',
        phase: 'p0',
        categories: ['markets', 'business', 'technology', 'politics'],
      ),
      const NewsSite(
        id: 'cnbc',
        name: 'CNBC',
        baseUrl: 'https://www.cnbc.com',
        phase: 'p0',
        categories: ['markets', 'business', 'technology'],
      ),
      const NewsSite(
        id: 'wsj',
        name: 'Wall Street Journal',
        baseUrl: 'https://www.wsj.com',
        loginUrl: 'https://www.wsj.com/login',
        phase: 'p0',
        categories: ['markets', 'business', 'technology', 'us'],
      ),
      const NewsSite(
        id: 'bbc',
        name: 'BBC News',
        baseUrl: 'https://www.bbc.com/news',
        phase: 'p1',
        categories: ['world', 'technology', 'business'],
      ),
      const NewsSite(
        id: 'guardian',
        name: 'The Guardian',
        baseUrl: 'https://www.theguardian.com',
        phase: 'p1',
        categories: ['world', 'business', 'technology'],
      ),
      const NewsSite(
        id: 'caixin',
        name: '财新网',
        baseUrl: 'https://www.caixin.com',
        loginUrl: 'https://user.caixin.com/c-login/',
        phase: 'p1',
        categories: ['finance', 'economy', 'business'],
      ),
      const NewsSite(
        id: 'ftchinese',
        name: 'FT 中文网',
        baseUrl: 'https://www.ftchinese.com',
        phase: 'p1',
        categories: ['business', 'markets', 'technology'],
      ),
    ];
  }
}

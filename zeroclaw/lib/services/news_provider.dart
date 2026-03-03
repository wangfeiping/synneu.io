import 'package:flutter/foundation.dart';
import '../models/news.dart';
import '../models/site.dart';
import 'database_service.dart';
import 'zeroclaw_service.dart';

enum CollectStatus { idle, collecting, done, error }

class NewsProvider extends ChangeNotifier {
  final DatabaseService _db;
  final ZeroClawService _zeroclaw;

  List<NewsItem> _news = [];
  List<NewsSite> _sites = NewsSite.defaultSites();
  CollectStatus _status = CollectStatus.idle;
  String? _error;
  String? _selectedSiteId;
  bool _zeroclawOnline = false;

  NewsProvider(this._db, this._zeroclaw);

  List<NewsItem> get news => _news;
  List<NewsSite> get sites => _sites;
  CollectStatus get status => _status;
  String? get error => _error;
  String? get selectedSiteId => _selectedSiteId;
  bool get zeroclawOnline => _zeroclawOnline;

  List<NewsItem> get filteredNews {
    if (_selectedSiteId == null) return _news;
    return _news.where((n) => n.siteId == _selectedSiteId).toList();
  }

  List<NewsSite> get enabledSites =>
      _sites.where((s) => s.isEnabled).toList();

  Future<void> init() async {
    await _loadFromDb();
    await _checkZeroClawStatus();
  }

  Future<void> _loadFromDb() async {
    _news = await _db.getNews(
      siteId: _selectedSiteId,
      limit: 100,
    );
    notifyListeners();
  }

  Future<void> _checkZeroClawStatus() async {
    _zeroclawOnline = await _zeroclaw.isOnline();
    notifyListeners();
  }

  void selectSite(String? siteId) {
    _selectedSiteId = siteId;
    _loadFromDb();
  }

  Future<void> collectFromSite(String siteId) async {
    _status = CollectStatus.collecting;
    _error = null;
    notifyListeners();

    try {
      final items = await _zeroclaw.collectNews(siteId: siteId);
      await _db.insertNewsBatch(items);
      await _loadFromDb();
      _status = CollectStatus.done;
    } catch (e) {
      _error = e.toString();
      _status = CollectStatus.error;
    }
    notifyListeners();
  }

  Future<void> collectAll() async {
    _status = CollectStatus.collecting;
    _error = null;
    notifyListeners();

    for (final site in enabledSites) {
      try {
        final items = await _zeroclaw.collectNews(siteId: site.id);
        await _db.insertNewsBatch(items);
      } catch (_) {
        // 单个网站失败不中断整体
      }
    }

    await _loadFromDb();
    _status = CollectStatus.done;
    notifyListeners();
  }

  Future<void> addLocalNews(List<NewsItem> items) async {
    await _db.insertNewsBatch(items);
    await _loadFromDb();
  }

  Future<void> markAsRead(String newsId) async {
    await _db.markAsRead(newsId);
    _news = _news.map((n) => n.id == newsId ? n.copyWith(isRead: true) : n).toList();
    notifyListeners();
  }

  void updateSiteLoginStatus(String siteId, bool isLoggedIn) {
    _sites = _sites.map((s) {
      if (s.id == siteId) return s.copyWith(isLoggedIn: isLoggedIn);
      return s;
    }).toList();
    notifyListeners();
  }

  void toggleSiteEnabled(String siteId) {
    _sites = _sites.map((s) {
      if (s.id == siteId) return s.copyWith(isEnabled: !s.isEnabled);
      return s;
    }).toList();
    notifyListeners();
  }

  Future<void> refresh() async {
    await _checkZeroClawStatus();
    await _loadFromDb();
  }
}

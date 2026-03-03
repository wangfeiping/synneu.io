import 'package:intl/intl.dart';

class NewsItem {
  final String id;
  final String title;
  final String url;
  final String summary;
  final String siteId;
  final String siteName;
  final DateTime? publishedAt;
  final String? category;
  final bool isRead;

  const NewsItem({
    required this.id,
    required this.title,
    required this.url,
    required this.summary,
    required this.siteId,
    required this.siteName,
    this.publishedAt,
    this.category,
    this.isRead = false,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String? ?? Uri.parse(json['url'] as String).hashCode.toString(),
      title: json['title'] as String,
      url: json['url'] as String,
      summary: json['summary'] as String? ?? '',
      siteId: json['site_id'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      category: json['category'] as String?,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'summary': summary,
        'site_id': siteId,
        'site_name': siteName,
        'published_at': publishedAt?.toIso8601String(),
        'category': category,
        'is_read': isRead,
      };

  NewsItem copyWith({bool? isRead}) {
    return NewsItem(
      id: id,
      title: title,
      url: url,
      summary: summary,
      siteId: siteId,
      siteName: siteName,
      publishedAt: publishedAt,
      category: category,
      isRead: isRead ?? this.isRead,
    );
  }

  String get formattedTime {
    if (publishedAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(publishedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return DateFormat('MM-dd HH:mm').format(publishedAt!);
  }
}

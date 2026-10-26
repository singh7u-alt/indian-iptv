import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../model/channel.dart';
import '../model/stream_source.dart';

class ChannelsProvider with ChangeNotifier {
  static const String streamsCatalogUrl =
      'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';

  static const List<StreamSource> defaultStreamSources = [
    StreamSource(
      name: 'Indian TV (Categorized)',
      streamUrl: 'https://iptv-org.github.io/iptv/countries/in.m3u',
      icon: Icons.tv,
    ),
    StreamSource(
      name: 'Indian TV (500+ Combined)',
      streamUrl:
          'https://raw.githubusercontent.com/FunctionError/PiratesTv/main/combined_playlist.m3u',
      icon: Icons.live_tv,
    ),
    StreamSource(
      name: 'Entertainment',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/entertainment.m3u',
      icon: Icons.theater_comedy,
    ),
    StreamSource(
      name: 'News',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/news.m3u',
      icon: Icons.newspaper,
    ),
    StreamSource(
      name: 'Movies',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/movies.m3u',
      icon: Icons.movie,
    ),
    StreamSource(
      name: 'Music',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/music.m3u',
      icon: Icons.music_note,
    ),
    StreamSource(
      name: 'Sports',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
      icon: Icons.sports_cricket,
    ),
    StreamSource(
      name: 'Kids & Animation',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/animation.m3u',
      icon: Icons.child_care,
    ),
    StreamSource(
      name: 'Family',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/family.m3u',
      icon: Icons.family_restroom,
    ),
    StreamSource(
      name: 'Documentary',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/documentary.m3u',
      icon: Icons.public,
    ),
    StreamSource(
      name: 'Comedy',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/comedy.m3u',
      icon: Icons.sentiment_very_satisfied,
    ),
    StreamSource(
      name: 'Series',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/series.m3u',
      icon: Icons.video_library,
    ),
    StreamSource(
      name: 'Lifestyle',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/lifestyle.m3u',
      icon: Icons.spa,
    ),
    StreamSource(
      name: 'Business',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/business.m3u',
      icon: Icons.trending_up,
    ),
    StreamSource(
      name: 'Education',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/education.m3u',
      icon: Icons.school,
    ),
    StreamSource(
      name: 'Science',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/science.m3u',
      icon: Icons.science,
    ),
    StreamSource(
      name: 'Culture',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/culture.m3u',
      icon: Icons.account_balance,
    ),
    StreamSource(
      name: 'Cooking',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/cooking.m3u',
      icon: Icons.restaurant,
    ),
    StreamSource(
      name: 'Travel',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/travel.m3u',
      icon: Icons.flight_takeoff,
    ),
    StreamSource(
      name: 'Weather',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/weather.m3u',
      icon: Icons.cloud,
    ),
    StreamSource(
      name: 'Classic',
      streamUrl: 'https://iptv-org.github.io/iptv/categories/classic.m3u',
      icon: Icons.history_edu,
    ),
  ];

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  List<String> subCategories = ['All'];

  Future<List<StreamSource>> fetchStreamSources() async {
    final Map<String, StreamSource> merged = {
      for (final s in defaultStreamSources) s.name.toLowerCase(): s,
    };

    try {
      final response = await http
          .get(Uri.parse(streamsCatalogUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('name,')) {
            continue;
          }
          final commaIndex = trimmed.indexOf(',');
          if (commaIndex != -1) {
            final name = trimmed.substring(0, commaIndex).trim();
            final streamUrl = trimmed.substring(commaIndex + 1).trim();
            if (name.isNotEmpty && streamUrl.isNotEmpty) {
              final key = name.toLowerCase();
              if (!merged.containsKey(key) && key != 'indian tv') {
                merged[key] = StreamSource(
                  name: name,
                  streamUrl: streamUrl,
                  icon: iconForCategory(name),
                );
              }
            }
          }
        }
      }
    } catch (_) {
      // Fall back cleanly to built-in defaultStreamSources
    }

    return merged.values.toList();
  }

  Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
    channels.clear();
    filteredChannels.clear();
    subCategories = ['All'];

    final response = await http.get(Uri.parse(sourceUrl));
    if (response.statusCode == 200) {
      final String fileText = response.body;
      final List<String> lines = fileText.split('\n');

      String? name;
      String logoUrl = getDefaultLogoUrl();
      String category = 'General';

      for (final String rawLine in lines) {
        final String line = rawLine.trim();
        if (line.startsWith('#EXTINF:')) {
          name = extractChannelName(line);
          logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
          category = extractGroupTitle(line);
        } else if (line.isNotEmpty && !line.startsWith('#')) {
          final String streamUrl = line;
          if (name != null && name.isNotEmpty) {
            channels.add(Channel(
              name: name,
              logoUrl: logoUrl,
              streamUrl: streamUrl,
              category: category,
            ));
          }
          name = null;
          logoUrl = getDefaultLogoUrl();
          category = 'General';
        }
      }

      final Set<String> categorySet = <String>{};
      for (final ch in channels) {
        if (ch.category.isNotEmpty) {
          categorySet.add(ch.category);
        }
      }
      final List<String> sortedCats = categorySet.toList()..sort();
      subCategories = ['All', ...sortedCats];
      filteredChannels = List.from(channels);
      return channels;
    } else {
      throw Exception('Failed to load M3U file');
    }
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    final List<String> parts = line.split(',');
    return parts.last.trim();
  }

  String extractGroupTitle(String line) {
    final RegExp groupRegex =
        RegExp(r'group-title="([^"]*)"', caseSensitive: false);
    final Match? match = groupRegex.firstMatch(line);
    if (match != null) {
      final String raw = match.group(1)?.trim() ?? '';
      if (raw.isNotEmpty) {
        // If multiple semicolon-separated categories exist (e.g. "Entertainment;News"), take primary
        final String primary = raw.split(';').first.trim();
        if (primary.isNotEmpty) {
          return primary[0].toUpperCase() + primary.substring(1);
        }
      }
    }
    return 'General';
  }

  String? extractLogoUrl(String line) {
    final RegExp logoRegex =
        RegExp(r'tvg-logo="([^"]+)"', caseSensitive: false);
    final Match? match = logoRegex.firstMatch(line);
    if (match != null && match.group(1) != null) {
      final String candidate = match.group(1)!.trim();
      if (isValidUrl(candidate)) {
        return candidate;
      }
    }
    final List<String> parts = line.split('"');
    if (parts.length > 1 && isValidUrl(parts[1])) {
      return parts[1];
    } else if (parts.length > 5 && isValidUrl(parts[5])) {
      return parts[5];
    }
    return null;
  }

  bool isValidUrl(String url) {
    return url.startsWith('https') || url.startsWith('http');
  }

  List<Channel> filterChannels({
    String query = '',
    String selectedCategory = 'All',
  }) {
    final String normalizedQuery = query.trim().toLowerCase();
    filteredChannels = channels.where((channel) {
      final bool matchesCategory = selectedCategory == 'All' ||
          channel.category.toLowerCase() == selectedCategory.toLowerCase();
      final bool matchesQuery = normalizedQuery.isEmpty ||
          channel.name.toLowerCase().contains(normalizedQuery) ||
          channel.category.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();
    return filteredChannels;
  }

  static IconData iconForCategory(String name) {
    final String lower = name.toLowerCase();
    if (lower.contains('entertainment')) return Icons.theater_comedy;
    if (lower.contains('news')) return Icons.newspaper;
    if (lower.contains('movie')) return Icons.movie;
    if (lower.contains('music')) return Icons.music_note;
    if (lower.contains('sport')) return Icons.sports_cricket;
    if (lower.contains('kid') || lower.contains('animation')) {
      return Icons.child_care;
    }
    if (lower.contains('doc')) return Icons.public;
    if (lower.contains('comedy')) return Icons.sentiment_very_satisfied;
    if (lower.contains('edu')) return Icons.school;
    if (lower.contains('bus')) return Icons.trending_up;
    return Icons.live_tv;
  }
}

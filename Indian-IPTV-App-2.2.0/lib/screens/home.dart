import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/channel.dart';
import '../model/stream_source.dart';
import '../provider/channels_provider.dart';
import 'player.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  List<StreamSource> streamSources = [];
  List<String> subCategories = ['All'];
  String selectedSubCategory = 'All';
  StreamSource? selectedSource;

  final TextEditingController searchController = TextEditingController();
  final ChannelsProvider channelsProvider = ChannelsProvider();
  bool _isLoading = true;
  bool _showSearch = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    fetchStreamSources();
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchStreamSources() async {
    setState(() => _isLoading = true);
    try {
      final sources = await channelsProvider.fetchStreamSources();
      setState(() {
        streamSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There was a problem loading stream categories'),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchChannels(StreamSource source) async {
    setState(() {
      _isLoading = true;
      selectedSource = source;
      selectedSubCategory = 'All';
      searchController.clear();
    });

    try {
      final data = await channelsProvider.fetchM3UFile(source.streamUrl);
      setState(() {
        channels = data;
        filteredChannels = data;
        subCategories = channelsProvider.subCategories;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load channels for ${source.name}'),
          ),
        );
      }
      setState(() {
        selectedSource = null;
        _isLoading = false;
      });
    }
  }

  void applyFilters({String? query, String? category}) {
    final String nextQuery = query ?? searchController.text;
    final String nextCategory = category ?? selectedSubCategory;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        selectedSubCategory = nextCategory;
        filteredChannels = channelsProvider.filterChannels(
          query: nextQuery,
          selectedCategory: nextCategory,
        );
      });
    });
  }

  void selectSubCategoryImmediately(String category) {
    setState(() {
      selectedSubCategory = category;
      filteredChannels = channelsProvider.filterChannels(
        query: searchController.text,
        selectedCategory: category,
      );
    });
  }

  void backToCategories() {
    setState(() {
      selectedSource = null;
      channels = [];
      filteredChannels = [];
      subCategories = ['All'];
      selectedSubCategory = 'All';
      _showSearch = false;
      searchController.clear();
    });
  }

  int _countForSubCategory(String cat) {
    if (cat == 'All') return channels.length;
    return channels
        .where((c) => c.category.toLowerCase() == cat.toLowerCase())
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: selectedSource == null,
      onPopInvoked: (didPop) {
        if (!didPop && selectedSource != null) {
          backToCategories();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selectedSource != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Categories',
                  onPressed: backToCategories,
                )
              : const Icon(Icons.tv, color: Colors.amberAccent),
          title: Text(
            selectedSource != null
                ? '${selectedSource!.name} (${filteredChannels.length})'
                : 'Indian IPTV — Select Category',
          ),
          actions: [
            if (selectedSource != null)
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                tooltip: 'Search Channels',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      searchController.clear();
                      selectSubCategoryImmediately(selectedSubCategory);
                    }
                  });
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: () {
                if (selectedSource != null) {
                  fetchChannels(selectedSource!);
                } else {
                  fetchStreamSources();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : selectedSource == null
                ? _buildCategoryGrid()
                : _buildChannelView(),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    if (streamSources.isEmpty) {
      return const Center(child: Text('No stream categories available'));
    }

    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14.0,
          mainAxisSpacing: 14.0,
          childAspectRatio: 1.45,
        ),
        itemCount: streamSources.length,
        itemBuilder: (context, index) {
          final source = streamSources[index];
          return Card(
            color: const Color(0xFF1E293B),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              autofocus: index == 0,
              focusColor: Colors.indigoAccent.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              onTap: () => fetchChannels(source),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      source.icon,
                      size: 38,
                      color: Colors.amberAccent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      source.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelView() {
    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (val) => applyFilters(query: val),
              decoration: InputDecoration(
                labelText: 'Search channels or categories (e.g. News, Sony)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          applyFilters(query: '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (subCategories.length > 1)
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: subCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final String cat = subCategories[index];
                final bool isSelected = cat == selectedSubCategory;
                final int count = _countForSubCategory(cat);
                return ChoiceChip(
                  label: Text('$cat ($count)'),
                  selected: isSelected,
                  selectedColor: Colors.indigoAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => selectSubCategoryImmediately(cat),
                );
              },
            ),
          ),
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(
                  child: Text(
                    'No channels found in this category',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14.0,
                    mainAxisSpacing: 14.0,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    return Card(
                      color: const Color(0xFF1E293B),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        autofocus: index == 0,
                        focusColor: Colors.indigoAccent.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Player(
                                channel: channel,
                                playlist: filteredChannels,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Image.network(
                                  channel.logoUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/tv-icon.png',
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                channel.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                channel.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.amberAccent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

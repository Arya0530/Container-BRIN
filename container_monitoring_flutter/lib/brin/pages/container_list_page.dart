import 'package:flutter/material.dart';
import '../data.dart';
import '../widgets.dart';
import '../navigation.dart';
import 'container_detail_page.dart';

class ContainerListPage extends StatefulWidget {
  const ContainerListPage({super.key});
  @override
  State<ContainerListPage> createState() => _ContainerListPageState();
}

class _ContainerListPageState extends State<ContainerListPage> {
  late Future<List<UiContainer>> _future;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final Set<int> _deletedIds = {};

  @override
  void initState() {
    super.initState();
    _future = UiApi.instance.containers();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    UiApi.instance.clearLatestCache();
    setState(() => _future = UiApi.instance.containers());
    try {
      await _future;
    } catch (_) {
      /* Handled by FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'List Container',
      drawer: brinDrawer(context, 'list'),
      onSearch: () => _searchFocus.requestFocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search container series, company, destination...',
                hintStyle: const TextStyle(fontSize: 11, color: brinMuted),
                prefixIcon: const Icon(Icons.search, color: brinRed),
                filled: true,
                fillColor: brinSoft,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFFFD4D6)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UiContainer>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return loadError(snapshot.error, _refresh);
                final query = _search.text.trim().toLowerCase();
                final results = (snapshot.data ?? [])
                    .where((c) => !_deletedIds.contains(c.id))
                    .where(
                      (c) => '${c.series} ${c.company} ${c.destination}'
                          .toLowerCase()
                          .contains(query),
                    )
                    .toList();
                if (results.isEmpty)
                  return const Center(
                    child: Text('No matching containers found.'),
                  );
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 13),
                    itemBuilder: (context, index) => ContainerCard(
                      container: results[index],
                      onView: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ContainerDetailPage(container: results[index]),
                        ),
                      ),
                      onDelete: () async {
                        final container = results[index];
                        if (await confirmDeleteContainer(context, container)) {
                          if (!mounted) return;
                          setState(() => _deletedIds.add(container.id));
                          await _refresh();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

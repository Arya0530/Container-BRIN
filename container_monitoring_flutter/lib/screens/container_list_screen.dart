import 'package:flutter/material.dart';

import '../models/container_model.dart';
import '../services/api_service.dart';
import 'container_detail_screen.dart';

class ContainerListScreen extends StatefulWidget {
  const ContainerListScreen({super.key});

  @override
  State<ContainerListScreen> createState() =>
      _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  final ApiService _apiService = ApiService();

  List<ContainerModel> _containers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContainers();
  }

  // Fetch containers and update the UI state.
  Future<void> _loadContainers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getContainers();

      if (!mounted) return;

      setState(() {
        _containers = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List Container'),
        actions: [
          IconButton(
            onPressed: _loadContainers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadContainers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_containers.isEmpty) {
      return const Center(
        child: Text('No containers found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _containers.length,
      itemBuilder: (context, index) {
        final container = _containers[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContainerDetailScreen(
                      container: container,
                    ),
                  ),
                );
              },
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              'Container ${container.series}',
            ),
            subtitle: Text(
              '${container.companyName}\n'
              'Destination: ${container.destination}\n'
              'Device: ${container.deviceId}',
            ),
            isThreeLine: true,
            trailing: Text(container.status),
          ),
        );
      },
    );
  }
}

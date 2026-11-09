import 'package:flutter/material.dart';
import '../data.dart';
import '../widgets.dart';
import 'container_list_page.dart';

class AddContainerPage extends StatefulWidget {
  const AddContainerPage({super.key});
  @override
  State<AddContainerPage> createState() => _AddContainerPageState();
}

class _AddContainerPageState extends State<AddContainerPage> {
  final _formKey = GlobalKey<FormState>();
  final _series = TextEditingController();
  final _deviceId = TextEditingController();
  final _package = TextEditingController();
  bool _saving = false;
  final _destination = TextEditingController();
  final _contents = TextEditingController();
  final _company = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _series,
      _deviceId,
      _destination,
      _contents,
      _package,
      _company,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await UiApi.instance.createContainer(
        series: _series.text,
        deviceId: _deviceId.text,
        company: _company.text,
        destination: _destination.text,
        contents: _contents.text,
        packageName: _package.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Container added successfully')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ContainerListPage()),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Add failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrinPage(
      title: 'Add Container',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('Series', 'e.g. XX4028', _series),
                  _field('Device ID', 'e.g. STM32-002', _deviceId),
                  _field(
                    'Destination',
                    'e.g. Semarang - Makassar',
                    _destination,
                  ),
                  _field('Contents', 'e.g. Rice, Electronics, etc.', _contents),
                  _field('Package', 'e.g. Karung', _package),
                  _field('Company', 'e.g. PT Padi', _company),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: brinRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: brinRed,
                          ),
                          onPressed: _saving ? null : _save,
                          child: const Text('Add Container'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: brinMuted),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required field' : null,
          ),
        ],
      ),
    );
  }
}

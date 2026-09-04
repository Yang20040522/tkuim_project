import 'package:flutter/material.dart';

import '../../models/therapist_patient.dart';
import '../custom_exercise/services/custom_exercise_api_client.dart';
import 'repositories/therapist_patient_repository.dart';
import 'repositories/therapist_patient_repository_selection.dart';

class BindPatientPage extends StatefulWidget {
  final TherapistPatientRepository? repository;

  const BindPatientPage({super.key, this.repository});

  @override
  State<BindPatientPage> createState() => _BindPatientPageState();
}

class _BindPatientPageState extends State<BindPatientPage> {
  final TextEditingController _bindingCodeController = TextEditingController();
  late final TherapistPatientRepository _repository;

  TherapistPatientPreview? _preview;
  String? _error;
  bool _searching = false;
  bool _binding = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? therapistPatientRepository;
  }

  @override
  void dispose() {
    _bindingCodeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _bindingCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _preview = null;
        _error = '請輸入患者綁定碼';
      });
      return;
    }
    setState(() {
      _searching = true;
      _preview = null;
      _error = null;
    });
    try {
      final preview = await _repository.lookupPatient(code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeMessage(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _bind() async {
    if (_preview == null || _binding) return;
    setState(() {
      _binding = true;
      _error = null;
    });
    try {
      await _repository.bindPatient(_bindingCodeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _safeMessage(error));
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  String _safeMessage(Object error) {
    if (error is CustomExerciseApiException) return error.message;
    return '網路連線失敗，請稍後再試';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('綁定新患者'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '輸入患者提供的綁定碼',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '搜尋後請核對患者姓名與 Email，再確認綁定。',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('patient-binding-code-field'),
            controller: _bindingCodeController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '患者綁定碼',
              hintText: 'ABC12345',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_preview == null && _error == null) return;
              setState(() {
                _preview = null;
                _error = null;
              });
            },
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('search-patient-binding-code'),
              onPressed: _searching || _binding ? null : _search,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: const Text('搜尋'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('bind-patient-error'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 20),
            Card(
              key: const Key('patient-binding-preview'),
              margin: EdgeInsets.zero,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '找到患者',
                      style: TextStyle(
                        color: Color(0xFF4A65FF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _preview!.patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _preview!.patientEmail,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('confirm-bind-patient'),
                        onPressed: _binding ? null : _bind,
                        child: _binding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('確認綁定'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

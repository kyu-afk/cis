import 'dart:async';
import 'package:flutter/material.dart';
import '../../../module/data_petugas/data_petugas_notifier.dart';
import '../../../repository/collector_repository.dart';
import '../../../pref/pref.dart';
import '../user_level.dart';
import '../colors.dart';

class SearchableDropdownPetugas extends StatefulWidget {
  final TextEditingController controller;
  final Function(DataPetugasModel) onPetugasSelected;
  final String hintText;
  final bool isReadOnly;
  final bool Function(DataPetugasModel)? additionalFilter;

  const SearchableDropdownPetugas({
    super.key,
    required this.controller,
    required this.onPetugasSelected,
    this.hintText = 'Cari nama petugas...',
    this.isReadOnly = false,
    this.additionalFilter,
  });

  @override
  State<SearchableDropdownPetugas> createState() => _SearchableDropdownPetugasState();
}

class _SearchableDropdownPetugasState extends State<SearchableDropdownPetugas> {
  List<DataPetugasModel> _allPetugas = [];
  List<DataPetugasModel> _filteredList = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _internalController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _internalController.text = widget.controller.text;
    _loadAllPetugas();
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _internalController.text.trim().isNotEmpty && _filteredList.isNotEmpty) {
        setState(() => _showDropdown = true);
      } else if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showDropdown = false);
        });
      }
    });
  }

  Future<void> _loadAllPetugas() async {
    setState(() => _isLoading = true);

    final sessionUser = await Pref().getUsers();
    final result = await CollectorRepository.inquiryCollector(limit: 500);
    if (result['value'] == 1) {
      final List<dynamic> data = result['data'] ?? [];
      final allAktif = data
          .map((item) => DataPetugasModel.fromJson(item as Map<String, dynamic>))
          .where((p) {
            if (p.status?.toLowerCase() != 'aktif') return false;
            if (widget.additionalFilter != null && !widget.additionalFilter!(p)) return false;
            return true;
          })
          .toList();

      // Filter per kode kantor untuk user biasa (lvl1)
      _allPetugas = UserLevelHelper.applyKantorFilter(
        list: allAktif,
        users: sessionUser,
        getKdKantor: (p) => p.kdKantor,
      );
    }

    setState(() => _isLoading = false);
  }

  void _filterPetugas(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          _filteredList = [];
          _showDropdown = false;
        } else {
          _filteredList = _allPetugas.where((p) {
            final nama = p.nama?.toLowerCase() ?? '';
            final search = query.toLowerCase();
            return nama.contains(search);
          }).toList();
          _showDropdown = _filteredList.isNotEmpty;
        }
      });
    });
  }

  void _selectPetugas(DataPetugasModel petugas) {
    _internalController.text = petugas.nama ?? '';
    widget.controller.text = petugas.nama ?? '';
    widget.onPetugasSelected(petugas);
    setState(() => _showDropdown = false);
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _internalController,
          focusNode: _focusNode,
          readOnly: widget.isReadOnly,
          onChanged: (value) {
            widget.controller.text = value;
            _filterPetugas(value);
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: colorPrimary, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Nama petugas wajib diisi';
            }
            return null;
          },
        ),
        if (_showDropdown && _filteredList.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredList.length,
              itemBuilder: (context, index) {
                final petugas = _filteredList[index];
                return InkWell(
                  onTap: () => _selectPetugas(petugas),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      petugas.nama ?? '-',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
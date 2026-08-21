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
    this.hintText = 'Cari nama kolektor...',
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

  // Field ini dipakai supaya daftar saran tampil MENGAMBANG (overlay) di atas
  // konten lain, bukan render inline yang mendorong layout ke bawah.
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _internalController.text = widget.controller.text;
    _loadAllPetugas();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _internalController.text.trim().isNotEmpty && _filteredList.isNotEmpty) {
        _setShowDropdown(true);
      } else if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _setShowDropdown(false);
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
      final allFiltered = data
          .map((item) => DataPetugasModel.fromJson(item as Map<String, dynamic>))
          .where((p) {
            if (widget.additionalFilter != null && !widget.additionalFilter!(p)) return false;
            return true;
          })
          .toList();

      // Filter per kode kantor untuk user biasa (lvl1)
      _allPetugas = UserLevelHelper.applyKantorFilter(
        list: allFiltered,
        users: sessionUser,
        getKdKantor: (p) => p.kdKantor,
      );
    }

    setState(() => _isLoading = false);
  }

  void _filterPetugas(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        _filteredList = [];
        _setShowDropdown(false);
      } else {
        _filteredList = _allPetugas.where((p) {
          final nama = p.nama?.toLowerCase() ?? '';
          final search = query.toLowerCase();
          return nama.contains(search);
        }).toList();
        _setShowDropdown(_filteredList.isNotEmpty);
      }
    });
  }

  void _selectPetugas(DataPetugasModel petugas) {
    _internalController.text = petugas.nama ?? '';
    widget.controller.text = petugas.nama ?? '';
    widget.onPetugasSelected(petugas);
    _setShowDropdown(false);
    _focusNode.unfocus();
  }

  // ==================== OVERLAY (dropdown mengambang) ====================
  void _setShowDropdown(bool value) {
    setState(() => _showDropdown = value);
    _syncOverlay();
  }

  void _syncOverlay() {
    final shouldShow = _showDropdown && _filteredList.isNotEmpty;
    if (shouldShow) {
      if (_overlayEntry == null) {
        _insertOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    } else {
      _removeOverlay();
    }
  }

  void _insertOverlay() {
    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
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
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.dispose();
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _fieldKey,
        child: TextFormField(
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
              return 'Nama kolektor wajib diisi';
            }
            return null;
          },
        ),
      ),
    );
  }
}
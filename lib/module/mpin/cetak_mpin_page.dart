import 'package:cis_menu/module/mpin/cetak_mpin_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:cis_menu/utils/widgets/searchable_dropdown_petugas.dart';  // TAMBAHKAN IMPORT

class CetakMpinPage extends StatelessWidget {
  const CetakMpinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CetakMpinNotifier(context: context),
      child: Consumer<CetakMpinNotifier>(
        builder: (context, notifier, child) => SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xffF3F5F4),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Expanded(
                  child: notifier.isSearching && !notifier.showResult
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                              child: Form(
                                key: notifier.keyForm,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildInfoBanner(),
                                    const SizedBox(height: 16),
                                    _buildSearchSection(notifier),
                                    if (notifier.showResult) ...[
                                      const SizedBox(height: 16),
                                      _buildResultSection(notifier),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (notifier.showResult)
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: MediaQuery.of(context).size.height * 0.04,
                                child: _buildButtonSection(notifier),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      color: colorPrimary,
      child: const Text(
        "Cetak MPIN",
        style: TextStyle(
          color: colortextwhite,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorInfoBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colorInfoIcon,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Proses cetak MPIN untuk mencetak MPIN yang belum tercetak.",
                  style: TextStyle(
                    fontSize: 13,
                    color: colorInfoText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PERUBAHAN DI SINI: Ganti TextField + Button dengan SearchableDropdownPetugas
  Widget _buildSearchSection(CetakMpinNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colortextwhite,
        border: Border.all(color: const Color(0xffDCE3DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nama Petugas",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
         SearchableDropdownPetugas(
          key: ValueKey(notifier.refreshKey),
          controller: notifier.namaPetugasInput,
          onPetugasSelected: notifier.onPetugasSelected,
          hintText: 'Cari nama petugas...',
          additionalFilter: (petugas) {
            final mpin = petugas.mpin ?? '';
            final mpinCetak = petugas.mpinCetak?.toUpperCase() ?? '';
            return mpin.isNotEmpty && mpinCetak == 'N';
          },
        )
        ],
      ),
    );
  }

  Widget _buildResultSection(CetakMpinNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colortextwhite,
        border: Border.all(color: const Color(0xffDCE3DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Data Petugas",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colorPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xffDCE3DF), height: 1),
          const SizedBox(height: 20),
          _infoRow("Nama Petugas", notifier.namaPetugasResult.text),
          const SizedBox(height: 20),
          const Divider(color: Color(0xffF0F0F0), height: 1),
          const SizedBox(height: 20),
          _infoRow("No HP", notifier.noHpResult.text),
          const SizedBox(height: 20),
          const Divider(color: Color(0xffF0F0F0), height: 1),
          const SizedBox(height: 20),
          _infoRow("NIP", notifier.nipResult.text),
          const SizedBox(height: 20),
          const Divider(color: Color(0xffF0F0F0), height: 1),
          const SizedBox(height: 20),
          _infoRow("No SBB Petugas", notifier.noSbbPetugasResult.text),
          const SizedBox(height: 20),
          const Divider(color: Color(0xffF0F0F0), height: 1),
          const SizedBox(height: 20),
          _infoRow("Nama SBB", notifier.namaSbbResult.text),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            val.isEmpty ? '-' : val,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colortextblack,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonSection(CetakMpinNotifier notifier) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () => notifier.reset(),
            style: OutlinedButton.styleFrom(
              backgroundColor: colorcancel,
              side: const BorderSide(color: colorcancel, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colortextwhite,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: ElevatedButton(
            onPressed: notifier.isPrinting ? null : () => notifier.cetakMpin(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrimary,
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: notifier.isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colortextwhite,
                    ),
                  )
                : const Text(
                    "Cetak MPIN",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }
}
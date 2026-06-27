import 'package:cis_menu/module/setup/setup_transaksi/setup_transaksi_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:flutter/services.dart';

class SetupTransaksiPage extends StatelessWidget {
  const SetupTransaksiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SetupTransaksiNotifier(context: context),
      child: Consumer<SetupTransaksiNotifier>(
        builder: (context, value, child) => SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xffF3F5F4),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Expanded(
                  child: value.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => value.loadData(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: value.keyForm,
                              child: Column(
                                children: [
                                  _buildInfoBanner(),
                                  const SizedBox(height: 16),
                                  _buildMasterSection(value),
                                  if (value.showDetail) ...[
                                    const SizedBox(height: 24),
                                    _buildDetailSection(value),
                                    const SizedBox(height: 20),
                                    _buildButtonSection(value),
                                  ],
                                ],
                              ),
                            ),
                          ),
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
        "Transaksi Collector",
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF1ECFB),
        border: Border.all(color: const Color(0xffD9CDF5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Daftar TCODE beserta status konfigurasinya ditampilkan di bawah ini.",
              style: TextStyle(fontSize: 13, color: Color(0xFF4B3F6B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSection(SetupTransaksiNotifier value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colortextwhite,
        border: Border.all(color: const Color(0xffDCE3DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(flex: 2, child: Text("TCODE", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              SizedBox(width: 12),
              Expanded(flex: 4, child: Text("Keterangan", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              SizedBox(width: 12),
              Expanded(flex: 1, child: Text("Status", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              SizedBox(width: 12),
              SizedBox(width: 100),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(value.tcodeList.length, (index) {
            final row = value.tcodeList[index];
            final code = row['tcode'] ?? '';
            final name = row['keterangan'] ?? '';
            final isConfigured = row['is_configured'] == true;
            final isSelected = value.selectedTcode == code;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _readonlyBox(code)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _readonlyBox(name)),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: _statusBox(isConfigured)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.green : colorPrimary,
                        foregroundColor: colortextwhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => value.openTcode(row),
                      child: Text(isSelected ? "Tampil" : "Pilih"),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailSection(SetupTransaksiNotifier value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAF9),
        border: Border.all(color: const Color(0xffDCE3DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Card header dengan field
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  decoration: const BoxDecoration(
    color: colorPrimary,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    ),
  ),
  child: Row(
    children: [
      const SizedBox(
        width: 120,
        child: Text(
          "Transaksi Code",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colortextwhite,
          ),
        ),
      ),
      Expanded(
        child: Row(
          children: [
            Expanded(flex: 2, child: _readonlyFieldOnPrimary(value.selectedTcodeController, "TCODE")),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _readonlyFieldOnPrimary(value.ketTcode, "Keterangan")),
          ],
        ),
      ),
    ],
  ),
),
const SizedBox(height: 20),

          // DEBET SECTION
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 120, child: Text("DEBET", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8B5CF6)))),
                    const Spacer(),
                    if (!value.isEditMode) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorcancel,
                          side: const BorderSide(color: colorcancel),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => value.closeTcode(),
                        child: const Text("Tutup"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorPrimary,
                          foregroundColor: colortextwhite,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => value.enableEdit(),
                        child: const Text("Ubah"),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 120, child: Text("Jenis Debit", style: TextStyle(fontSize: 12))),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: value.selectedJenisDebit,
                        decoration: InputDecoration(
                          hintText: "Pilih Jenis Debit",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: value.isEditMode
                            ? SetupTransaksiNotifier.jenisOptions.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                .toList()
                            : (value.selectedJenisDebit != null
                                ? [DropdownMenuItem(
                                    value: value.selectedJenisDebit,
                                    child: Text(SetupTransaksiNotifier.jenisOptions[value.selectedJenisDebit] ?? value.selectedJenisDebit!),
                                  )]
                                : []),
                        onChanged: value.isEditMode ? value.onJenisDebitChanged : null,
                        validator: (_) => value.validateJenisDebit(null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (SetupTransaksiNotifier.isNoRekRequired(value.selectedJenisDebit) || !SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisDebit)) ...[
                  Row(
                    children: [
                      const SizedBox(width: 120, child: Text("No Debit", style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: value.noDebit,
                                readOnly: !value.isEditMode || SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisDebit),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly,],
                                decoration: InputDecoration(
                                  hintText: SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisDebit)
                                      ? "Tidak diperlukan untuk jenis ini"
                                      : "Nomor Rekening Debit",
                                  filled: true,
                                  fillColor: SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisDebit)
                                      ? const Color(0xffF0F0F0)
                                      : Colors.white,
                                ),
                                validator: value.validateNoDebit,
                              ),
                            ),
                            if (value.isEditMode && SetupTransaksiNotifier.isNoRekRequired(value.selectedJenisDebit)) ...[
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorPrimary,
                                  foregroundColor: colortextwhite,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: value.isVerifying ? null : () => value.verifyDebit(),
                                child: value.isVerifying
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                                    : const Text("Cari"),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 120, child: Text("Nama Rek Debit", style: TextStyle(fontSize: 12))),
                      Expanded(child: _readonlyField(value.namaDebit, "Nama Rekening Debit")),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // KREDIT SECTION
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    SizedBox(width: 120, child: Text("KREDIT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8B5CF6)))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 120, child: Text("Jenis Kredit", style: TextStyle(fontSize: 12))),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: value.selectedJenisKredit,
                        decoration: InputDecoration(
                          hintText: "Pilih Jenis Kredit",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: value.isEditMode
                            ? SetupTransaksiNotifier.jenisOptions.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                .toList()
                            : (value.selectedJenisKredit != null
                                ? [DropdownMenuItem(
                                    value: value.selectedJenisKredit,
                                    child: Text(SetupTransaksiNotifier.jenisOptions[value.selectedJenisKredit] ?? value.selectedJenisKredit!),
                                  )]
                                : []),
                        onChanged: value.isEditMode ? value.onJenisKreditChanged : null,
                        validator: (_) => value.validateJenisKredit(null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (SetupTransaksiNotifier.isNoRekRequired(value.selectedJenisKredit) || !SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisKredit)) ...[
                  Row(
                    children: [
                      const SizedBox(width: 120, child: Text("No Kredit", style: TextStyle(fontSize: 12))),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: value.noKredit,
                                readOnly: !value.isEditMode || SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisKredit),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly,],
                                decoration: InputDecoration(
                                  hintText: SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisKredit)
                                      ? "Tidak diperlukan untuk jenis ini"
                                      : "Nomor Rekening Kredit",
                                  filled: true,
                                  fillColor: SetupTransaksiNotifier.isNoRekDisabled(value.selectedJenisKredit)
                                      ? const Color(0xffF0F0F0)
                                      : Colors.white,
                                ),
                                validator: value.validateNoKredit,
                              ),
                            ),
                            if (value.isEditMode && SetupTransaksiNotifier.isNoRekRequired(value.selectedJenisKredit)) ...[
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorPrimary,
                                  foregroundColor: colortextwhite,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: value.isVerifying ? null : () => value.verifyKredit(),
                                child: value.isVerifying
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                                    : const Text("Cari"),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 120, child: Text("Nama Rek Kredit", style: TextStyle(fontSize: 12))),
                      Expanded(child: _readonlyField(value.namaKredit, "Nama Rekening Kredit")),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection(SetupTransaksiNotifier value) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => value.cancel(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorcancel,
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Batal"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: value.isSaving ? null : () => value.submit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrimary,
              foregroundColor: colortextwhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: value.isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colortextwhite))
                : const Text("Simpan"),
          ),
        ),
      ],
    );
  }

  Widget _readonlyBox(String text) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAF9),
        border: Border.all(color: const Color(0xffDCE3DF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBox(bool isConfigured) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isConfigured ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(color: isConfigured ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isConfigured ? "Y" : "N",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isConfigured ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _readonlyField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xffF8FAF9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

Widget _readonlyFieldWhite(TextEditingController controller, String label) {
  return TextFormField(
    controller: controller,
    readOnly: true,
    style: const TextStyle(color: colortextwhite),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: colortextwhite),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white54),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white54),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: colortextwhite),
      ),
    ),
  );
}

Widget _readonlyFieldOnPrimary(TextEditingController controller, String label) {
  return TextFormField(
    controller: controller,
    readOnly: true,
    style: const TextStyle(color: colortextwhite, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      floatingLabelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: colortextwhite),
      ),
    ),
  );
}
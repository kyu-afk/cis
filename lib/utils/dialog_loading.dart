import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'button_custom.dart';
import 'images_path.dart';
import 'colors.dart';

class DialogCustom {
  void showLoading(BuildContext context) {
    Future.delayed(Duration.zero).then((value) {
      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: colortextwhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 32,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        ImageAssets.logo,
                        height: 80,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text(
                      "Silahkan Tunggu..",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    const CupertinoActivityIndicator(
                      radius: 20,
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }

  void showMessage(BuildContext context, String error) {
    Future.delayed(Duration.zero).then((value) {
      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: colortextwhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 32,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        ImageAssets.logo,
                        height: 80,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Text(
                      "$error ",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }

  void showBPJS(
    BuildContext context,
    String noKaru,
    String nama,
    String tglLahir,
    String kdKlinik,
    String nmKlinik,
    String kelas,
    String sex,
    Function save,
    Function batal,
  ) {
    Future.delayed(Duration.zero).then((value) {
      showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: colortextwhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 32,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        ImageAssets.logo,
                        height: 80,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Text(
                      "Nama Lengkap : $nama ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      "No Kartu BPJS : $noKaru ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      "Jenis Kelamin : $sex ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      "Kode Klinik : $kdKlinik ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      "Nama Klinik : $nmKlinik ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      "Kelas : $kelas ",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Row(
                      children: [
                        Expanded(
                            child: ButtonSecondary(
                          onTap: () => batal(),
                          name: "Batalkan",
                        )),
                        const SizedBox(
                          width: 16,
                        ),
                        Expanded(
                            child: ButtonPrimary(
                          onTap: () => save(),
                          name: "Simpan",
                        )),
                      ],
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }
}

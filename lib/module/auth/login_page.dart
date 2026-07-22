import 'package:cis_menu/module/auth/login_notifier.dart';
import 'package:cis_menu/utils/button_custom.dart';
import 'package:cis_menu/utils/colors.dart';
import 'package:cis_menu/utils/images_path.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginNotifier(context: context),
      child: Consumer<LoginNotifier>(
        builder: (context, value, child) => SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xffF3F5F4),
            body: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Image.asset(
                    ImageAssets.bodyPattern,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
                
                // Form Login - Box lebih besar
                Positioned(
                  top: 60,
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 900,  // Lebar box diperbesar dari 800 ke 900
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2), 
                            color: Colors.grey[300] ?? Colors.transparent, 
                            blurRadius: 5
                          )
                        ],
                        borderRadius: BorderRadius.circular(16),
                        color: colortextwhite,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sidebar kiri (hijau) - diperlebar
                          Container(
                            width: 250,  // Lebar sidebar diperbesar dari 200 ke 250
                            decoration: const BoxDecoration(
                              color: const Color(0xff0EA5A0), 
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16), 
                                bottomLeft: Radius.circular(16)
                              )
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // LOGO MEDFO dengan efek bubble
                                Container(
                                  height: 150,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  child: Center(
                                    child: SizedBox(
                                      width: 145,
                                      height: 145,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Bubble ring terluar (paling transparan)
                                          Container(
                                            width: 145,
                                            height: 145,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colortextwhite.withOpacity(0.07),
                                            ),
                                          ),
                                          // Bubble ring tengah
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colortextwhite.withOpacity(0.14),
                                              border: Border.all(
                                                color: colortextwhite.withOpacity(0.25),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          // Bubble ring dalam
                                          Container(
                                            width: 98,
                                            height: 98,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colortextwhite.withOpacity(0.22),
                                            ),
                                          ),
                                          // Logo utama dengan shadow melayang
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                ImageAssets.logo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    color: colortextwhite.withOpacity(0.2),
                                                    child: const Icon(Icons.business, size: 36, color: colortextwhite),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const Text(
                                  "CIS",
                                  style: TextStyle(
                                    fontFamily: "Arial Black",
                                    fontSize: 36,
                                    color: colortextwhite,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Collme Information System",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colortextwhite,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "ver. 1.2.0",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colortextwhite.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "last update 7/7/26",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colortextwhite.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Form kanan
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: value.keyForm,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Judul
                                    const Text(
                                      "Selamat Datang",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xff0EA5A0),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Silakan login untuk melanjutkan",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    
                                    // Field Username
                                    const Text(
                                      "User ID",
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: value.username,
                                      validator: (e) {
                                        if (e == null || e.isEmpty) {
                                          return "User ID wajib diisi";
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Masukkan user id",
                                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                                        fillColor: Colors.grey[100],
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10), 
                                          borderSide: BorderSide.none
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xff0EA5A0), width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Field Password
                                    const Text(
                                      "Password",
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: value.password,
                                      obscureText: value.obscure,
                                      validator: (e) {
                                        if (e == null || e.isEmpty) {
                                          return "Password wajib diisi";
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Masukkan password",
                                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                        suffixIcon: IconButton(
                                          onPressed: () => value.gantiobscure(),
                                          icon: Icon(
                                            value.obscure 
                                              ? Icons.visibility_off 
                                              : Icons.visibility,
                                            size: 20,
                                          ),
                                        ),
                                        fillColor: Colors.grey[100],
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10), 
                                          borderSide: BorderSide.none
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xff0EA5A0), width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    
                                    // Tombol Login
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await value.cek();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xff0EA5A0),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          "Masuk",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 30),
                                    
                                    // Footer Copyright
                                    Center(
                                      child: Text(
                                        "© 2026 CIS",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 20),

                                    Center(
                                      child: Image.asset(
                                        ImageAssets.logotambahan,
                                        height: 45,  // sesuaikan dengan ukuran logo asli
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.business, size: 60, color: Color(0xff0EA5A0));
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
}
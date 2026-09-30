# Electric Wallet

Proyek Flutter untuk **belajar animasi dan efek 3D**. Tampilannya mengikuti aplikasi dompet digital.

> [!IMPORTANT]
> **Ini bukan aplikasi keuangan.** Proyek ini hanya untuk belajar.
>
> - Tidak ada uang sungguhan. Saldo, transaksi, dan top up hanyalah angka tiruan yang disimpan di HP.
> - Aplikasi ini tidak terhubung ke bank, e-wallet, atau layanan pembayaran apa pun.
> - Nama brand (**VoltPay**), nama pengguna, nama orang, dan nama merchant semuanya fiktif. Kemiripan dengan nama asli tidak disengaja.
> - **Jangan gunakan** aplikasi ini untuk menipu orang, misalnya sebagai bukti saldo atau bukti transfer palsu.

## Yang bisa dipelajari

| Topik                               | File                                                       | Isi                                                                                                                                                                                                                      |
| ----------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ikon 3D tanpa model 3D              | [wallet_3d.dart](lib/widgets/wallet_3d.dart)               | Dompet dibentuk dari lapisan widget bertumpuk di sumbu Z, lalu diproyeksikan dengan `Matrix4` (`setEntry(3, 2, …)`, `rotateX`, `rotateY`). Urutan gambar dari belakang ke depan membuat dompet terlihat punya ketebalan. |
| Interaksi dan animasi pegas         | [wallet_3d.dart](lib/widgets/wallet_3d.dart)               | Swipe horizontal untuk memutar dompet, lalu dompet memantul balik dengan `Curves.elasticOut`. Ada juga animasi melayang dan kilau yang bergeser mengikuti sudut putar.                                                   |
| Partikel dengan `CustomPainter`     | [energy_particles.dart](lib/widgets/energy_particles.dart) | Percikan listrik yang posisinya dihitung dari waktu (deterministik, tanpa menyimpan state per partikel).                                                                                                                 |
| Transisi halaman transparan         | [charging_overlay.dart](lib/screens/charging_overlay.dart) | `PageRouteBuilder` dengan `opaque: false`, `BackdropFilter` blur, serta gabungan fade dan scale.                                                                                                                         |
| Angka berjalan dan UI glassmorphism | [home_screen.dart](lib/screens/home_screen.dart)           | `TweenAnimationBuilder` untuk saldo, `AnimatedSize`, `AnimatedSwitcher`, chip "+Rp" melayang, latar belakang dengan blob gradasi yang bergerak.                                                                          |
| Membaca status baterai              | [wallet_controller.dart](lib/wallet_controller.dart)       | `battery_plus` untuk mendeteksi charger, `ChangeNotifier` untuk state, `shared_preferences` untuk menyimpan saldo.                                                                                                       |

## Menjalankan

```bash
flutter pub get
flutter run
```

Mulai simulasi charging otomatis 2 detik setelah app dibuka:

```bash
flutter run --dart-define=AUTO_SIM=true
```

### Catatan soal platform

- **HP asli (Android/iPhone):** colok charger, dan saldo langsung mulai bertambah.
- **Chrome / macOS:** status charger laptop ikut terbaca.
- **iOS Simulator:** status baterai tidak terbaca (selalu "unknown"), jadi charger laptop tidak berpengaruh. Pakai pemicu tersembunyi di bawah atau `AUTO_SIM`.

## Pemicu tersembunyi

Tidak terlihat di layar, supaya tidak mengganggu saat merekam:

- **Tahan kartu saldo:** simulasi charging tanpa charger sungguhan. Tahan lagi untuk berhenti.
- **Tahan avatar:** saldo dan riwayat kembali ke kondisi awal.

## Mengubah isi

- Nama brand dan nama pengguna: `appName` dan `userName` di [theme.dart](lib/theme.dart).
- Besar tambahan saldo per detik: `_tick` di [wallet_controller.dart](lib/wallet_controller.dart).
- Saldo awal dan contoh transaksi: `_startBalance` dan `_seedTransactions` di [wallet_controller.dart](lib/wallet_controller.dart).

Tombol aksi, grid layanan, dan tab navbar masih pajangan. Menekannya hanya memunculkan snackbar.

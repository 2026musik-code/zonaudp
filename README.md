# UDP Custom (ZIVPN Native) Manager

Script Auto-Install dan Manajemen untuk UDP Custom (ZIVPN Native) di VPS Ubuntu/Debian.

Repository: [https://github.com/2026musik-code/zonaudp](https://github.com/2026musik-code/zonaudp)

## Fitur

*   **Auto Install**: Otomatis download binary, setup config, dan service systemd.
*   **User Management**: Tambah, hapus, dan lihat user dengan mudah lewat menu.
*   **Auto Redirect**: Otomatis setting iptables redirect port `6000-19999` ke `6000`.
*   **Optimasi**: Fitur optimasi TCP BBR dan UDP Buffer untuk gaming.
*   **Service Status**: Cek status service dan log aktif.
*   **Uninstall**: Hapus bersih semua file dan rule iptables.

## Persyaratan (Requirements)

*   VPS dengan OS **Ubuntu** (18.04/20.04/22.04) atau **Debian** (9/10/11).
*   Akses **Root**.
*   Koneksi Internet.

## Cara Install (Installation)

Login ke VPS Anda sebagai root, lalu jalankan perintah berikut:

```bash
wget -qO udp-custom.sh https://raw.githubusercontent.com/2026musik-code/zonaudp/main/udp-custom.sh && chmod +x udp-custom.sh && ./udp-custom.sh
```

## Panduan Penggunaan (Tutorial)

Setelah menjalankan perintah di atas, Anda akan melihat menu utama:

### 1. Install UDP Custom
Pilih opsi `1` untuk memulai instalasi.
*   Script akan mengupdate VPS dan install dependency.
*   Anda akan diminta memasukkan **Obfs Key** (Default: `zivpn`).
*   Anda akan diminta membuat **Username** dan **Password** pertama.
*   Script akan mendownload binary `udp-custom` dan menjalankannya.

### 2. Manage Users
Pilih opsi `2` untuk mengelola user.
*   **Add User**: Tambah user baru.
*   **Remove User**: Hapus user yang ada.
*   **List Users**: Lihat daftar user dan password.
*   Setiap perubahan user akan otomatis me-restart service agar efeknya langsung jalan.

### 3. Check Service Status
Pilih opsi `3` untuk melihat apakah service berjalan (`Active: running`) dan melihat log koneksi terakhir.

### 4. Optimize Speed
Pilih opsi `4` untuk menerapkan settingan sysctl:
*   Mengaktifkan **TCP BBR**.
*   Memperbesar **UDP Buffer** (rmem/wmem) untuk mengurangi packet loss dan latency (cocok untuk game online).

### 5. Uninstall
Pilih opsi `5` jika ingin menghapus script, service, dan semua konfigurasi dari VPS.

## Struktur File

*   **Config**: `/etc/udp-custom/config.json`
*   **Binary**: `/usr/local/bin/udp-custom`
*   **Service**: `/etc/systemd/system/udp-custom.service`

## Troubleshooting

### Error: Failed to download binary

Jika Anda melihat error ini saat instalasi:
```
[ERROR] Failed to download binary from https://raw.githubusercontent.com/2026musik-code/zonaudp/main/udp-custom
```
**Penyebab:** Anda belum mengupload file binary `udp-custom` ke repository GitHub Anda.

**Solusi:**
1. Upload file binary UDP Custom (biasanya bernama `udp-custom-linux-amd64` atau `udp-custom`) ke repository GitHub Anda (`2026musik-code/zonaudp`).
2. Pastikan nama filenya adalah **`udp-custom`** (tanpa ekstensi .exe atau lainnya).
3. Jalankan ulang script instalasi.
4. Atau, jika Anda memiliki link download lain, pilih opsi **1) Enter an alternative URL** saat error muncul.

## Catatan Penting

*   **Wajib Upload Binary**: Script ini dirancang untuk mendownload binary dari repository Anda sendiri. Pastikan file ada.
*   Port UDP `6000` digunakan sebagai port utama, dan port `6000-19999` di-redirect ke `6000`. Pastikan port-port ini tidak digunakan oleh service lain.

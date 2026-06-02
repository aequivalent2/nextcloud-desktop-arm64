Write-Host "Building libp11 for ARM64..."

git clone https://github.com/OpenSC/libp11.git C:\build\libp11-src
Set-Location C:\build\libp11-src\src

$cl = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.51.36231\bin\Hostarm64\arm64\cl.exe"
$env:CC = $cl
$env:CXX = $cl

cl.exe /nologo /W3 /MT /O2 /D_WIN32_WINNT=0x0600 /DWIN32_LEAN_AND_MEAN `
    /DWIN32 /D_WINDOWS /I"C:\build\openssl-arm64\include" /I"." `
    /c eng_back.c eng_err.c eng_front.c libpkcs11.c p11_atfork.c `
       p11_attr.c p11_cert.c p11_ckr.c p11_ec.c p11_eddsa.c p11_err.c `
       p11_front.c p11_key.c p11_load.c p11_misc.c p11_pkey.c `
       p11_rsa.c p11_slot.c util_uri.c

mkdir -Force C:\build\libp11-arm64

@"
EXPORTS
PKCS11_CTX_new
PKCS11_CTX_free
PKCS11_CTX_load
PKCS11_CTX_unload
PKCS11_enumerate_slots
PKCS11_release_all_slots
PKCS11_find_token
PKCS11_find_next_token
PKCS11_open_session
PKCS11_is_logged_in
PKCS11_login
PKCS11_logout
PKCS11_enumerate_certs
PKCS11_enumerate_keys
PKCS11_find_key
PKCS11_get_key_type
PKCS11_get_private_key
PKCS11_get_public_key
PKCS11_CTX_init_args
PKCS11_CTX_new_ex
"@ | Set-Content libp11_all.def

link.exe /DLL /NOLOGO /MACHINE:ARM64 `
    /OUT:C:\build\libp11-arm64\libp11.dll `
    /IMPLIB:C:\build\libp11-arm64\libp11.lib `
    /DEF:libp11_all.def *.obj `
    C:\build\openssl-arm64\lib\libcrypto.lib `
    ws2_32.lib user32.lib advapi32.lib crypt32.lib

Copy-Item libp11.lib C:\build\libp11-arm64\p11.lib
Copy-Item libp11.h, p11_ver.h, p11_err.h, pkcs11.h C:\build\libp11-arm64\

# pkgconfig
@"
prefix=C:/build/libp11-arm64
exec_prefix=`${prefix}
libdir=`${prefix}
includedir=`${prefix}

Name: libp11
Description: PKCS11 library
Version: 0.4.12
Libs: -L`${prefix} -lp11
Cflags: -I`${prefix}
"@ | Set-Content C:\build\libp11-arm64\libp11.pc

Write-Host "libp11 build complete."

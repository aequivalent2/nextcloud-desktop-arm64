Nextcloud Desktop – Windows ARM64
Inoffizieller nativer ARM64-Build des Nextcloud Desktop Clients für Windows ARM64 Geräte.

Download
👉 Neueste Version unter Releases

Unterstützte Geräte
Microsoft Surface Pro X / Surface Pro 11
Snapdragon X Elite / X Plus Laptops
Alle anderen Windows ARM64 Geräte
Installation
ZIP aus den Releases herunterladen
In einen Ordner entpacken
nextcloud.exe starten
Warum dieser Fork?
Der offizielle Nextcloud Client unterstützt Windows ARM64 noch nicht nativ. Auf ARM64-Geräten läuft der offizielle Client nur über die x64-Emulationsschicht (Prism), was zu erhöhtem Akkuverbrauch führt.

Dieser Build wurde vollständig nativ für ARM64 kompiliert – keine Emulation.

Technische Details
Komponente	Version
Qt	6.11.1 ARM64
OpenSSL	3.3.x ARM64
Compiler	MSVC 2026 ARM64
libp11	0.4.12 ARM64
Updates
Neue Builds erscheinen automatisch wenn Nextcloud upstream ein neues Release veröffentlicht.

Disclaimer
⚠️ Dies ist kein offizielles Nextcloud-Produkt. Kein Support durch Nextcloud GmbH.

Quellcode des Clients: https://github.com/nextcloud/desktop (GPL-2.0)
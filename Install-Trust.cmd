@echo off
REM Right-click -> Run as administrator
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Certificate -FilePath '%~dp0DeviceSwitch-cert.cer' -CertStoreLocation Cert:\LocalMachine\Root; Import-Certificate -FilePath '%~dp0DeviceSwitch-cert.cer' -CertStoreLocation Cert:\LocalMachine\TrustedPublisher; Write-Host 'TRUST INSTALLED OK'; pause"

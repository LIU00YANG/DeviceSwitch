# Elevated: install DeviceSwitch cert into LocalMachine trust stores
$cer = 'C:\Users\HUAWEI\WorkBuddy AI\2026-11-01-22-03-39\DeviceSwitch\DeviceSwitch-cert.cer'
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' | Out-Null
'TRUST INSTALLED OK'

# SSL Protocols

By default, the server chooses the allowed SSL/TLS protocols based on the operating system’s native support.

For example, on Windows 11 and Windows Server 2022 only TLS 1.2 and TLS 1.3 are enabled, while older systems (such as Windows Vista/Server 2008) allow SSL 2.0 and SSL 3.0. This behavior follows the table below:

| Operating System                   | SSL 2.0             | SSL 3.0             | TLS 1.0             | TLS 1.1             | TLS 1.2            | TLS 1.3            |
|------------------------------------|---------------------|---------------------|---------------------|---------------------|--------------------|--------------------|
| Windows Vista / Server 2008        | Enabled             | Enabled             | Not Supported       | Not Supported       | Not Supported      | Not Supported      |
| Windows 7 / Server 2008 R2         | Enabled             | Enabled             | Disabled            | Disabled            | Disabled           | Not Supported      |
| Windows 8 / Server 2012            | Disabled by Default | Enabled by Default  | Enabled by Default  | Enabled by Default  | Enabled by Default | Not Supported      |
| Windows 10 (Build 20170 and later) | No                  | Disabled by Default | Enabled by Default  | Enabled by Default  | Enabled by Default | Enabled by Default |
| Windows 11 / Server 2022           | No                  | Disabled by Default | Disabled by Default | Disabled by Default | Enabled by Default | Enabled by Default |
| macOS 10.8 - 10.10                 | No                  | Yes                 | Yes                 | Yes                 | Yes                | No                 |
| macOS 10.11                        | No                  | No                  | Yes                 | Yes                 | Yes                | No                 |
| macOS 10.13 and later              | No                  | No                  | Yes                 | Yes                 | Yes                | Yes                |
| Linux (OpenSSL 1.0.1 - 1.0.1f)     | No                  | Yes                 | Yes                 | Yes                 | Yes                | No                 |
| Linux (OpenSSL 1.0.1g and later)   | No                  | No                  | Yes                 | Yes                 | Yes                | No                 |
| Linux (OpenSSL 1.1.1 and later)    | No                  | No                  | Yes                 | Yes                 | Yes                | Yes                |

**Notes:**

- **Windows Operating Systems:**
  - TLS 1.3 is supported starting from Windows 10 Build 20170 and Windows Server 2022.
  - Earlier versions (like Windows 7 and Windows Server 2008 R2) support up to TLS 1.2, but may require manual configuration to enable it.

- **macOS:**
  - TLS 1.3 support begins with macOS 10.13.

- **Linux:**
  - The supported SSL/TLS protocols on Linux systems depend on the version of OpenSSL installed:
    - OpenSSL versions 1.0.1 to 1.0.1f support up to TLS 1.2, with SSL 3.0 enabled by default.
    - OpenSSL version 1.0.1g and later disable SSL 3.0 by default.
    - OpenSSL version 1.1.1 and later add support for TLS 1.3.

## Override the Default Values

If you wish to override the defaults, you can customize the allowed protocols in your `server.psd1` configuration file. For example, if you want to allow only TLS protocols (excluding the deprecated SSL versions), you can configure it as follows:

```powershell
@{
    Server = @{
        Ssl = @{
            Protocols = @('Tls', 'Tls11', 'Tls12')
        }
    }
}
```

Or, to include TLS 1.3 where supported:

```powershell
@{
    Server = @{
        Ssl = @{
            Protocols = @('Tls', 'Tls11', 'Tls12', 'Tls13')
        }
    }
}
```

This configuration allows you to explicitly set the protocols from the following list of supported values: `'Ssl2'`, `'Ssl3'`, `'Tls'`, `'Tls11'`, `'Tls12'`, and `'Tls13'`.

> **Important:** Overriding these default values in your configuration file does **not** automatically enable the corresponding protocols at the operating system level. The OS may block a protocol unless its native settings are also changed. In other words, even if you add `'Ssl3'` to your allowed protocols, Windows 11 will still reject SSLv3 connections unless you modify the OS settings.

### Example: Enabling SSLv3 on Windows 11

By default, Windows 11 disables SSLv3 in its Schannel settings. To enable SSLv3, you need to change the registry settings. **Proceed with caution** as enabling SSLv3 can expose your system to known vulnerabilities (such as the POODLE attack).

You can enable SSLv3 on Windows 11 using PowerShell as follows:

```powershell
# Create the registry keys for SSL 3.0 if they don't already exist
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0" -Force | Out-Null
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -Force | Out-Null
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -Force | Out-Null

# Enable SSLv3 for both client and server by setting the Enabled DWORD to 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -Name "Enabled" -Value 1 -Type DWord

Write-Output "SSLv3 has been enabled. A system restart may be required for the changes to take effect."
```

After making these changes, your Windows 11 system will accept SSLv3 connections. Remember that this registry modification is an OS-level change, and overriding the configuration in `server.psd1` alone will not suffice.

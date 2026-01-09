# YouTube Ad Blocker Setup

Automated PowerShell script that configures YouTube ad blocking with zero user interaction required. Combines network-level blocking (PAC file) with JavaScript injection (local proxy) for comprehensive ad removal.

## Features

- ✅ **Zero User Input** - Fully automated installation
- ✅ **Network-Level Blocking** - Uses GitHub PAC file for ad domain blocking
- ✅ **JavaScript Injection** - Local proxy injects scripts to skip YouTube ads
- ✅ **Safety First** - Automatic fallback ensures internet always works
- ✅ **One-Click Uninstall** - Simple `-Uninstall` switch removes everything
- ✅ **No Downloads Required** - Uses GitHub PAC URL directly (no local files)

## Requirements

- **Windows 10/11** (64-bit)
- **PowerShell 5.1+** with Administrator privileges
- **.NET Framework 4.7.2+**

## Quick Start

### Installation

```powershell
# Run PowerShell as Administrator
.\YouTubeAdBlockerSetup.ps1
```

That's it! The script will:
1. Start a local proxy server for JavaScript injection
2. Configure system to use GitHub PAC file for ad blocking
3. Verify internet connectivity (restores settings if anything fails)

### Uninstallation

```powershell
# Run PowerShell as Administrator
.\YouTubeAdBlockerSetup.ps1 -Uninstall
```

Removes all configuration and restores original settings.

## How It Works

### Architecture

1. **GitHub PAC File** - Network-level ad blocking
   - Uses: `https://raw.githubusercontent.com/ads-blocker/Pac/refs/heads/main/BlockAds.pac`
   - Blocks ad domains, tracking, XSS attempts
   - Configured via Windows registry (no downloads)

2. **Local Proxy Server** - JavaScript injection
   - Runs on `127.0.0.1:8080`
   - Intercepts YouTube responses
   - Injects JavaScript to skip ads automatically

3. **Combined Protection**
   - PAC file blocks ad network requests
   - Proxy injects JavaScript to skip remaining ads
   - Works together for maximum effectiveness

### Safety Features

- **Pre-Installation Check** - Tests internet connectivity before making changes
- **Post-Installation Verification** - Confirms internet still works after setup
- **Automatic Rollback** - Restores original settings if anything fails
- **Clean Uninstall** - Removes all traces and verifies connectivity

## Configuration

The script uses these default settings (can be modified in script):

```powershell
$Script:Config = @{
    ProxyPort = 8080                    # Local proxy port
    ProxyHost = "127.0.0.1"             # Local proxy host
    PACUrl = "https://raw.githubusercontent.com/ads-blocker/Pac/refs/heads/main/BlockAds.pac"
    InstallDir = "$env:ProgramData\YouTubeAdBlocker"
}
```

## What Gets Configured

### Registry Changes

- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\AutoConfigURL`
  - Set to GitHub PAC file URL
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyEnable`
  - Set to `1` (enabled)
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ProxyOverride`
  - Local network bypasses (localhost, private IPs)

### Files Created

- `C:\ProgramData\YouTubeAdBlocker\proxy.ps1` - Proxy server script
- `C:\ProgramData\YouTubeAdBlocker\proxy.log` - Proxy server logs
- `C:\ProgramData\YouTubeAdBlocker\proxy.pid` - Process ID file

## Troubleshooting

### Internet Not Working After Installation

The script includes automatic safety checks, but if internet stops working:

1. **Run uninstall:**
   ```powershell
   .\YouTubeAdBlockerSetup.ps1 -Uninstall
   ```

2. **Or manually restore:**
   ```powershell
   $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
   Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
   Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 0 -Type DWord -Force
   ```

### Ads Still Appearing

1. **Restart your browser** - Changes require browser restart
2. **Check proxy is running:**
   ```powershell
   Get-Content "C:\ProgramData\YouTubeAdBlocker\proxy.pid"
   ```
3. **Check logs:**
   ```powershell
   Get-Content "C:\ProgramData\YouTubeAdBlocker\proxy.log" -Tail 50
   ```

### Port 8080 Already in Use

Edit the script and change `ProxyPort` in the configuration section to an available port.

## Limitations

- **Browser Restart Required** - Changes take effect after browser restart
- **HTTPS Limitations** - Proxy handles HTTP; HTTPS uses CONNECT tunneling
- **Some Ads May Still Show** - YouTube's ad system is complex; most ads are blocked
- **Windows Only** - Designed for Windows 10/11

## Technical Details

### Proxy Server

The local proxy server:
- Listens on `127.0.0.1:8080`
- Intercepts YouTube HTTP responses
- Injects JavaScript before `</body>` tag
- Forwards all other traffic directly

### JavaScript Injection

Injected script:
- Clicks skip buttons automatically
- Removes ad overlays
- Blocks ad iframes
- Monitors DOM for new ad elements
- Runs every 250ms for responsiveness

### PAC File

The GitHub PAC file provides:
- Comprehensive ad domain blocking
- XSS attack prevention
- Tracking domain blocking
- Whitelist support for trusted sites

## Security Considerations

- ✅ **No External Connections** - Proxy only runs locally
- ✅ **No Data Collection** - All processing is local
- ✅ **Reversible** - Complete uninstall restores original state
- ✅ **Open Source** - Full script available for inspection

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test thoroughly on clean Windows installation
4. Submit pull request with description

## License

MIT License - See LICENSE file for details

## Disclaimer

This software is provided for educational and personal use only. Use at your own risk. The authors are not responsible for any damages or issues arising from use of this software.

## Acknowledgments

- [ads-blocker/Pac](https://github.com/ads-blocker/Pac) - For the comprehensive PAC file
- PowerShell community for best practices

---

**⭐ If you find this useful, please consider giving it a star!**

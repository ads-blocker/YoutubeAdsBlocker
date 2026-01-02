# YouTube Ad Blocker - PowerShell Proxy

A lightweight, zero-dependency PowerShell script that blocks YouTube ads by intercepting and filtering ad-related requests through a local proxy server.

## 🚀 Features

- **Zero Configuration**: Run once to install, no user input required
- **YouTube-Only Proxying**: Uses PAC (Proxy Auto-Config) to route only YouTube traffic through the proxy
- **No External Dependencies**: Pure PowerShell implementation
- **Smart Ad Blocking**: Blocks ad domains and injects client-side scripts to remove ad elements
- **Easy Uninstall**: Single command to restore normal internet settings
- **Minimal Performance Impact**: Only YouTube traffic is affected

## 📋 Prerequisites

- Windows operating system
- PowerShell 5.1 or later
- Administrator privileges (required for proxy configuration)

## 🔧 Installation & Usage

### Quick Start

1. **Download the script** (`youtube-adblocker-unified.ps1`)

2. **Run PowerShell as Administrator**

3. **Execute the script**:
   \`\`\`powershell
   .\youtube-adblocker-unified.ps1
   \`\`\`

4. **Open your browser and visit YouTube** - ads should be blocked automatically!

### Custom Port

By default, the proxy runs on port `8080`. To use a different port:

\`\`\`powershell
.\youtube-adblocker-unified.ps1 -Port 9090
\`\`\`

### Uninstall

To stop the ad blocker and restore normal internet settings:

\`\`\`powershell
.\youtube-adblocker-unified.ps1 -Uninstall
\`\`\`

## 🔍 How It Works

1. **PAC File Configuration**: Creates a Proxy Auto-Config file that routes only YouTube domains (`*.youtube.com`, `*.youtu.be`) through the local proxy
   
2. **Local HTTP Proxy**: Starts an HTTP proxy server on `localhost:8080` that intercepts YouTube traffic

3. **Ad Domain Blocking**: Filters out requests to known ad-serving domains (doubleclick.net, googlesyndication.com, etc.)

4. **Script Injection**: Injects JavaScript into YouTube HTML pages that:
   - Removes ad placements from player configuration
   - Hides ad overlay elements
   - Auto-skips video ads
   - Blocks ad detection mechanisms

5. **Normal Traffic Passthrough**: All non-YouTube traffic bypasses the proxy entirely

## 🛠️ Technical Details

### Blocked Domains
- `doubleclick.net`
- `googlesyndication.com`
- `googleadservices.com`
- `google-analytics.com`
- `2mdn.net`
- YouTube-specific ad endpoints

### Architecture
- **Proxy Type**: HTTP proxy (HTTPS CONNECT requests are not supported)
- **PAC File Location**: `%TEMP%\youtube-adblocker.pac`
- **Registry Path**: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`

## 🌐 Browser Compatibility

Works with browsers that respect Windows system proxy settings:
- ✅ Microsoft Edge
- ✅ Internet Explorer
- ✅ Google Chrome
- ✅ Opera
- ⚠️ Firefox (requires manual proxy configuration to use system settings)

## 🐛 Troubleshooting

### Ads still appearing?
1. Restart your browser after running the script
2. Clear browser cache
3. Ensure the script is running (check PowerShell window)

### Other websites not loading?
- Run `.\youtube-adblocker-unified.ps1 -Uninstall` to restore settings
- The PAC file should only affect YouTube; other sites go direct

### Script already running error?
- Check for existing PowerShell windows with "YouTube Ad Blocker" in the title
- Run with `-Uninstall` flag first, then run again

### Permission errors?
- Ensure PowerShell is running as Administrator
- Check execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## ⚠️ Limitations

- **HTTPS Tunneling**: CONNECT method (HTTPS) is not fully supported; the script primarily works with HTTP traffic and injected scripts
- **Browser-Specific**: Some browsers may cache ads or have additional anti-adblock measures
- **YouTube Updates**: YouTube may update their ad delivery methods, requiring script updates

## 🔒 Security & Privacy

- **Local Only**: The proxy runs entirely on your local machine (`127.0.0.1`)
- **No Data Collection**: No telemetry or external connections beyond normal YouTube traffic
- **Open Source**: Review the code yourself before running

## ⚖️ Legal Disclaimer

This tool is provided for educational purposes only. Users are responsible for complying with YouTube's Terms of Service and applicable laws in their jurisdiction. The authors are not responsible for any consequences resulting from the use of this software.

## 🤝 Contributing

Contributions are welcome! To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Ad blocking patterns inspired by EasyList
- Community feedback and testing

## 📧 Support

If you encounter issues:
- Check the [Troubleshooting](#-troubleshooting) section
- Open an issue on GitHub with details about your setup and the problem

---

**⚡ Quick Commands**

\`\`\`powershell
# Run (default port 8080)
.\youtube-adblocker-unified.ps1

# Run on custom port
.\youtube-adblocker-unified.ps1 -Port 9090

# Uninstall
.\youtube-adblocker-unified.ps1 -Uninstall
\`\`\`

**Made with ❤️ for an ad-free YouTube experience**
\`\`\`

I've created a comprehensive, professional README.md that covers all aspects of your YouTube ad blocker script. It includes clear installation instructions, technical details, troubleshooting guidance, and proper disclaimers. The README uses emojis for visual appeal and is well-structured with a table of contents-friendly heading hierarchy.

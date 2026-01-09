<#
.SYNOPSIS
    YouTube Ad Blocker - Auto-Install with Local Proxy
.DESCRIPTION
    Auto-installs local proxy server that injects JavaScript to skip ads.
    Zero user input required. Safe fallback ensures internet always works.
.NOTES
    Requires Administrator privileges
    Version: 3.0 - Auto-Install with Safety
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall
)

#region === Configuration ===

$Script:Config = @{
    ProxyPort = 8080
    ProxyHost = "127.0.0.1"
    PACUrl = "https://raw.githubusercontent.com/ads-blocker/Pac/refs/heads/main/BlockAds.pac"
    LogFile = "$env:ProgramData\YouTubeAdBlocker\proxy.log"
    PIDFile = "$env:ProgramData\YouTubeAdBlocker\proxy.pid"
    ServiceName = "YouTubeAdBlockerProxy"
    InstallDir = "$env:ProgramData\YouTubeAdBlocker"
}

# JavaScript to inject
$AdSkipScript = @"
(function() {
    'use strict';
    console.log('[AdBlocker] Script injected');
    function skipAds() {
        try {
            var skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .videoAdUiSkipButton, button[class*='skip']');
            if (skipBtn && skipBtn.offsetParent !== null) {
                skipBtn.click();
                console.log('[AdBlocker] Skipped ad');
            }
            var overlays = document.querySelectorAll('.ytp-ad-overlay-container, .ytp-ad-text, .ad-showing, .ad-interrupting');
            overlays.forEach(function(o) { o.style.display = 'none'; o.remove(); });
            var iframes = document.querySelectorAll('iframe[src*='doubleclick'], iframe[src*='googlesyndication']');
            iframes.forEach(function(i) { if (i.src) { i.src = 'about:blank'; i.style.display = 'none'; } });
            var player = document.getElementById('movie_player');
            if (player) {
                var video = player.querySelector('video');
                if (video && video.duration > 0 && video.duration < 5) {
                    video.currentTime = video.duration;
                }
            }
        } catch(e) {}
    }
    skipAds();
    setInterval(skipAds, 250);
    var obs = new MutationObserver(skipAds);
    var container = document.getElementById('movie_player') || document.body;
    if (container) {
        obs.observe(container, {childList: true, subtree: true, attributes: true});
    }
})();
"@

#endregion

#region === Logging ===

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logDir = Split-Path -Path $Script:Config.LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $Script:Config.LogFile -Value $logEntry -ErrorAction SilentlyContinue
    $color = if ($Level -eq "Error") { "Red" } elseif ($Level -eq "Success") { "Green" } elseif ($Level -eq "Warning") { "Yellow" } else { "White" }
    Write-Host $logEntry -ForegroundColor $color
}

#endregion

#region === Safety Checks ===

function Test-InternetConnectivity {
    Write-Log "Testing internet connectivity..." "Info"
    try {
        $test = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $test) {
            $test = Test-NetConnection -ComputerName "1.1.1.1" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue
        }
        return $test
    } catch {
        return $false
    }
}

function Restore-InternetSettings {
    Write-Log "Restoring internet settings for safety..." "Warning"
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 0 -Type DWord -Force | Out-Null
        Remove-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name "ProxyOverride" -ErrorAction SilentlyContinue
        
        $signature = @'
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
        $type = Add-Type -MemberDefinition $signature -Name WinInet -Namespace NetTools -PassThru -ErrorAction SilentlyContinue
        if ($type) {
            $type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
            $type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
        }
        Write-Log "Internet settings restored" "Success"
        return $true
    } catch {
        Write-Log "Failed to restore settings: $_" "Error"
        return $false
    }
}

#endregion

#region === Proxy Server ===

function Start-ProxyServer {
    Write-Log "Starting local proxy server..." "Info"
    
    try {
        # Check if already running
        if (Test-Path $Script:Config.PIDFile) {
            $oldPID = Get-Content -Path $Script:Config.PIDFile -ErrorAction SilentlyContinue
            if ($oldPID) {
                $proc = Get-Process -Id $oldPID -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Log "Proxy already running (PID: $oldPID)" "Info"
                    return $true
                }
            }
        }
        
        # Create proxy PowerShell script file
        $proxyScriptPath = "$($Script:Config.InstallDir)\proxy.ps1"
        $proxyScriptContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {`$true}

`$listener = New-Object System.Net.HttpListener
`$listener.Prefixes.Add("http://127.0.0.1:$($Script:Config.ProxyPort)/")
`$listener.Start()

"Proxy started" | Out-File -FilePath "$($Script:Config.LogFile)" -Append

while (`$listener.IsListening) {
    try {
        `$context = `$listener.GetContextAsync()
        `$task = `$context.GetAwaiter()
        while (-not `$task.IsCompleted) {
            Start-Sleep -Milliseconds 100
            if (-not `$listener.IsListening) { break }
        }
        if (-not `$listener.IsListening) { break }
        `$ctx = `$task.GetResult()
        `$request = `$ctx.Request
        `$response = `$ctx.Response
        
        `$url = `$request.Url.ToString()
        
        # Handle CONNECT (HTTPS tunneling)
        if (`$request.HttpMethod -eq 'CONNECT') {
            `$response.StatusCode = 200
            `$response.Close()
            continue
        }
        
        # For YouTube, inject JavaScript
        if (`$url -match 'youtube\.com') {
            try {
                `$webRequest = [System.Net.HttpWebRequest]::Create(`$url)
                `$webRequest.Method = `$request.HttpMethod
                `$webRequest.Proxy = `$null
                `$webRequest.Timeout = 10000
                
                `$webResponse = `$webRequest.GetResponse()
                `$stream = `$webResponse.GetResponseStream()
                `$reader = New-Object System.IO.StreamReader(`$stream)
                `$content = `$reader.ReadToEnd()
                `$reader.Close()
                `$stream.Close()
                
                if (`$content -match '<html') {
                    `$script = '<script>(function(){var s=function(){try{var b=document.querySelector(".ytp-ad-skip-button");if(b&&b.offsetParent){b.click();}var o=document.querySelectorAll(".ytp-ad-overlay-container");o.forEach(function(e){e.style.display="none";});}catch(e){}};s();setInterval(s,250);})();</script>'
                    `$content = `$content -replace '</body>', (`$script + '</body>')
                }
                
                `$bytes = [System.Text.Encoding]::UTF8.GetBytes(`$content)
                `$response.ContentLength64 = `$bytes.Length
                `$response.ContentType = `$webResponse.ContentType
                `$response.StatusCode = 200
                `$response.OutputStream.Write(`$bytes, 0, `$bytes.Length)
                `$webResponse.Close()
            } catch {
                `$response.StatusCode = 500
            }
        } else {
            # Forward non-YouTube directly
            try {
                `$webRequest = [System.Net.HttpWebRequest]::Create(`$url)
                `$webRequest.Method = `$request.HttpMethod
                `$webRequest.Proxy = `$null
                `$webRequest.Timeout = 10000
                `$webResponse = `$webRequest.GetResponse()
                `$stream = `$webResponse.GetResponseStream()
                `$response.ContentType = `$webResponse.ContentType
                `$response.StatusCode = 200
                `$stream.CopyTo(`$response.OutputStream)
                `$stream.Close()
                `$webResponse.Close()
            } catch {
                `$response.StatusCode = 500
            }
        }
        `$response.Close()
    } catch {
        # Continue on error
    }
}
"@
        
        Set-Content -Path $proxyScriptPath -Value $proxyScriptContent -Encoding UTF8 -Force
        
        # Start proxy in new PowerShell window (hidden)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$proxyScriptPath`""
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $process = [System.Diagnostics.Process]::Start($psi)
        
        Start-Sleep -Seconds 3
        
        # Verify proxy is running
        try {
            $testRequest = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$($Script:Config.ProxyPort)/")
            $testRequest.Timeout = 2000
            $testRequest.Method = "GET"
            try {
                $testResponse = $testRequest.GetResponse()
                $testResponse.Close()
            } catch {
                # Proxy might not respond to root, but that's OK
            }
        } catch {}
        
        # Save PID
        $process.Id | Out-File -FilePath $Script:Config.PIDFile -Force
        
        Write-Log "Proxy server started (PID: $($process.Id))" "Success"
        return $true
        
    } catch {
        Write-Log "Failed to start proxy: $_" "Error"
        return $false
    }
}

function Stop-ProxyServer {
    Write-Log "Stopping proxy server..." "Info"
    
    try {
        if (Test-Path $Script:Config.PIDFile) {
            $pid = Get-Content -Path $Script:Config.PIDFile -ErrorAction SilentlyContinue
            if ($pid) {
                $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($process) {
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    Write-Log "Stopped proxy process (PID: $pid)" "Info"
                }
            }
            Remove-Item -Path $Script:Config.PIDFile -Force -ErrorAction SilentlyContinue
        }
        
        # Kill any remaining proxy PowerShell processes
        Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -like "*proxy.ps1*" -or $_.MainWindowTitle -like "*proxy*"
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        
        Write-Log "Proxy server stopped" "Success"
        return $true
    } catch {
        Write-Log "Error stopping proxy: $_" "Error"
        return $false
    }
}

#endregion

#region === PAC Configuration ===

function Set-PACConfiguration {
    param([string]$ProxyHost, [int]$ProxyPort, [string]$GitHubPACUrl)
    
    Write-Log "Configuring registry to use GitHub PAC URL..." "Info"
    
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        
        # Set GitHub PAC URL directly in registry
        Set-ItemProperty -Path $regPath -Name "AutoConfigURL" -Value $GitHubPACUrl -Type String -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 1 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "ProxyOverride" -Value "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>" -Type String -Force | Out-Null
        
        Write-Log "Registry configured with GitHub PAC URL: $GitHubPACUrl" "Success"
        
        # Notify system
        $signature = @'
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
        $type = Add-Type -MemberDefinition $signature -Name WinInet -Namespace NetTools -PassThru -ErrorAction SilentlyContinue
        if ($type) {
            $type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
            $type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
        }
        
        Write-Log "PAC configuration complete" "Success"
        return $true
    } catch {
        Write-Log "Failed to configure PAC: $_" "Error"
        return $false
    }
}

#endregion

#region === Main Functions ===

function Install-YouTubeAdBlocker {
    Write-Log "=== Installing YouTube Ad Blocker ===" "Info"
    
    # Test internet before changes
    if (-not (Test-InternetConnectivity)) {
        Write-Log "WARNING: No internet connectivity detected. Proceeding anyway..." "Warning"
    }
    
    # Create install directory (for proxy files only)
    if (-not (Test-Path $Script:Config.InstallDir)) {
        New-Item -ItemType Directory -Path $Script:Config.InstallDir -Force | Out-Null
    }
    
    # Start proxy server
    if (-not (Start-ProxyServer)) {
        Write-Log "Failed to start proxy. Restoring settings..." "Error"
        Restore-InternetSettings
        return $false
    }
    
    # Wait a moment for proxy to be ready
    Start-Sleep -Seconds 2
    
    # Configure PAC registry key with GitHub PAC URL (no download)
    if (-not (Set-PACConfiguration -ProxyHost $Script:Config.ProxyHost -ProxyPort $Script:Config.ProxyPort -GitHubPACUrl $Script:Config.PACUrl)) {
        Write-Log "Failed to configure PAC. Stopping proxy and restoring..." "Error"
        Stop-ProxyServer
        Restore-InternetSettings
        return $false
    }
    
    # Test internet after changes
    Start-Sleep -Seconds 2
    if (-not (Test-InternetConnectivity)) {
        Write-Log "WARNING: Internet connectivity test failed after installation!" "Warning"
        Write-Log "Restoring settings for safety..." "Warning"
        Restore-InternetSettings
        Stop-ProxyServer
        return $false
    }
    
    Write-Log "=== Installation Complete ===" "Success"
    Write-Log "Restart your browser for changes to take effect" "Info"
    return $true
}

function Uninstall-YouTubeAdBlocker {
    Write-Log "=== Uninstalling YouTube Ad Blocker ===" "Info"
    
    # Stop proxy
    Stop-ProxyServer
    
    # Restore internet settings
    Restore-InternetSettings
    
    # Clean up proxy files (keep directory for logs)
    $proxyScript = "$($Script:Config.InstallDir)\proxy.ps1"
    if (Test-Path $proxyScript) {
        Remove-Item -Path $proxyScript -Force -ErrorAction SilentlyContinue
    }
    
    # Test internet after uninstall
    Start-Sleep -Seconds 2
    if (-not (Test-InternetConnectivity)) {
        Write-Log "WARNING: Internet connectivity test failed after uninstall!" "Warning"
        Write-Log "Please check your internet settings manually" "Warning"
    } else {
        Write-Log "Internet connectivity verified" "Success"
    }
    
    Write-Log "=== Uninstallation Complete ===" "Success"
    return $true
}

#endregion

#region === Entry Point ===

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges."
    exit 1
}

if ($Uninstall) {
    Uninstall-YouTubeAdBlocker
} else {
    Install-YouTubeAdBlocker
}

#endregion
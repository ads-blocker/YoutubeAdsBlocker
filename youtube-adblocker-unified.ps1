# YouTube Ad Blocker - Unified PowerShell Script
# No external dependencies - Run to install, run with -Uninstall to remove
# Zero user input required

param(
    [switch]$Uninstall,
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# ====================================
# UNINSTALL MODE
# ====================================
if ($Uninstall) {
    Write-Host "`nStopping YouTube Ad Blocker..." -ForegroundColor Cyan
    
    # Find and stop the proxy process
    $processes = Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.MainWindowTitle -like "*YouTube Ad Blocker*"
        } catch {
            $false
        }
    }
    
    if ($processes) {
        $processes | Stop-Process -Force
        Write-Host "Ad blocker process stopped." -ForegroundColor Green
    } else {
        Write-Host "No ad blocker process found running." -ForegroundColor Yellow
    }
    
    Write-Host "Restoring proxy settings..." -ForegroundColor Yellow
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
    Set-ItemProperty -Path $regPath -Name AutoConfigURL -Value "" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name ProxyServer -ErrorAction SilentlyContinue
    
    # Delete PAC file
    $pacFile = "$env:TEMP\youtube-adblocker.pac"
    if (Test-Path $pacFile) {
        Remove-Item $pacFile -Force
        Write-Host "PAC file removed." -ForegroundColor Green
    }
    
    # Refresh Internet Explorer settings
    $signature = @'
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
    
    $INTERNET_OPTION_SETTINGS_CHANGED = 39
    $INTERNET_OPTION_REFRESH = 37
    
    try {
        $wininet = Add-Type -MemberDefinition $signature -Name InternetSettings -Namespace Win32 -PassThru
        $wininet::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_SETTINGS_CHANGED, [IntPtr]::Zero, 0) | Out-Null
        $wininet::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_REFRESH, [IntPtr]::Zero, 0) | Out-Null
    } catch {}
    
    Write-Host "`nYouTube Ad Blocker uninstalled successfully!" -ForegroundColor Green
    Write-Host "Normal internet access restored." -ForegroundColor Cyan
    exit
}

# ====================================
# INSTALL/RUN MODE
# ====================================

Write-Host "`nStarting YouTube Ad Blocker..." -ForegroundColor Cyan

# Check if already running
$existing = Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.MainWindowTitle -like "*YouTube Ad Blocker*"
    } catch {
        $false
    }
}

if ($existing) {
    Write-Host "Ad blocker is already running!" -ForegroundColor Yellow
    Write-Host "Run with -Uninstall to stop it." -ForegroundColor Yellow
    exit
}

Write-Host "Creating PAC file for YouTube-only proxying..." -ForegroundColor Yellow
$pacFile = "$env:TEMP\youtube-adblocker.pac"
$pacContent = @"
function FindProxyForURL(url, host) {
    // Only proxy YouTube domains
    if (shExpMatch(host, "*.youtube.com") || 
        shExpMatch(host, "*.youtu.be") ||
        shExpMatch(host, "youtube.com") ||
        shExpMatch(host, "youtu.be")) {
        return "PROXY 127.0.0.1:$Port";
    }
    
    // Everything else connects directly (no proxy)
    return "DIRECT";
}
"@

Set-Content -Path $pacFile -Value $pacContent -Encoding ASCII
Write-Host "PAC file created: $pacFile" -ForegroundColor Green

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $regPath -Name AutoConfigURL -Value "file:///$($pacFile -replace '\\','/')"
Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0  # Disable manual proxy

# Refresh Internet Explorer settings to apply proxy
$signature = @'
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@

$INTERNET_OPTION_SETTINGS_CHANGED = 39
$INTERNET_OPTION_REFRESH = 37

try {
    $wininet = Add-Type -MemberDefinition $signature -Name InternetSettings -Namespace Win32 -PassThru
    $wininet::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_SETTINGS_CHANGED, [IntPtr]::Zero, 0) | Out-Null
    $wininet::InternetSetOption([IntPtr]::Zero, $INTERNET_OPTION_REFRESH, [IntPtr]::Zero, 0) | Out-Null
} catch {
    Write-Host "Warning: Could not refresh proxy settings. You may need to restart your browser." -ForegroundColor Yellow
}

Write-Host "PAC proxy configured: Only YouTube traffic routes through proxy" -ForegroundColor Green

# ====================================
# PROXY SERVER CODE
# ====================================

# Ad domains to block (EasyList-style patterns)
$script:BlockedDomains = @(
    "doubleclick.net",
    "googlesyndication.com",
    "googleadservices.com",
    "google-analytics.com",
    "2mdn.net",
    "youtube.com/api/stats/ads",
    "youtube.com/pagead/",
    "youtube.com/ptracking",
    "youtube.com/api/stats/qoe",
    "s.youtube.com/api/stats/qoe",
    "static.doubleclick.net"
)

# YouTube-specific scriptlet to inject
$script:YouTubeScriptlet = @"
<script>
(function() {
    'use strict';
    
    console.log('[YT-AdBlock] Initializing...');
    
    // Override ad-related player configs
    if (window.ytInitialPlayerResponse) {
        try {
            if (window.ytInitialPlayerResponse.adPlacements) {
                window.ytInitialPlayerResponse.adPlacements = [];
            }
            if (window.ytInitialPlayerResponse.playerAds) {
                window.ytInitialPlayerResponse.playerAds = [];
            }
        } catch(e) {}
    }
    
    // Block ad detection
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
        set: function(value) {
            if (value && typeof value === 'object') {
                value.adPlacements = [];
                value.playerAds = [];
            }
            this._ytInitialPlayerResponse = value;
        },
        get: function() {
            return this._ytInitialPlayerResponse;
        }
    });
    
    // Remove ad overlays and banners
    const removeAds = () => {
        const selectors = [
            '.video-ads',
            '.ytp-ad-module',
            '.ytp-ad-overlay-container',
            'ytd-display-ad-renderer',
            'ytd-promoted-sparkles-web-renderer',
            '#masthead-ad',
            '.ytd-compact-promoted-item-renderer',
            'ytd-ad-slot-renderer',
            'yt-mealbar-promo-renderer',
            'ytd-popup-container'
        ];
        
        selectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(el => {
                el.remove();
            });
        });
    };
    
    // Auto-skip video ads if they appear
    const skipAds = () => {
        const skipButton = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern');
        if (skipButton) {
            skipButton.click();
        }
        
        // Fast-forward through ad if skip not available
        const video = document.querySelector('video.html5-main-video');
        const adIndicator = document.querySelector('.ytp-ad-player-overlay');
        if (video && adIndicator) {
            video.currentTime = video.duration;
        }
    };
    
    // Run periodically
    setInterval(removeAds, 500);
    setInterval(skipAds, 500);
    removeAds();
    
    // Observer for dynamic content
    const observer = new MutationObserver(removeAds);
    observer.observe(document.body, { childList: true, subtree: true });
    
    console.log('[YT-AdBlock] Active');
})();
</script>
"@

function Test-BlockedDomain {
    param([string]$Url)
    
    foreach ($domain in $script:BlockedDomains) {
        if ($Url -like "*$domain*") {
            return $true
        }
    }
    return $false
}

function Inject-YouTubeScript {
    param([string]$HtmlContent)
    
    # Inject before closing </head> or at start of <body>
    if ($HtmlContent -match '</head>') {
        return $HtmlContent -replace '</head>', "$script:YouTubeScriptlet</head>"
    } elseif ($HtmlContent -match '<body[^>]*>') {
        return $HtmlContent -replace '(<body[^>]*>)', "`$1$script:YouTubeScriptlet"
    }
    
    return $HtmlContent
}

function Handle-Request {
    param($Context)
    
    $request = $Context.Request
    $response = $Context.Response
    
    try {
        $method = $request.HttpMethod
        $url = $request.Url.ToString()
        $requestUrl = $request.RawUrl
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $method $url"
        
        # Handle CONNECT method for HTTPS tunneling
        if ($method -eq "CONNECT") {
            Write-Host "  [TUNNEL] HTTPS connection" -ForegroundColor Cyan
            # For now, reject CONNECT to avoid SSL complexity
            # The PAC file ensures only YouTube goes through proxy
            $response.StatusCode = 501
            $response.StatusDescription = "Not Implemented"
            $response.Close()
            return
        }
        
        # Extract target URL from proxy request
        $targetUrl = if ($requestUrl -match '^http') {
            $requestUrl
        } else {
            "http://$($request.Headers['Host'])$requestUrl"
        }
        
        # Check if domain should be blocked
        if (Test-BlockedDomain -Url $targetUrl) {
            Write-Host "  [BLOCKED] Ad domain detected" -ForegroundColor Red
            $response.StatusCode = 204
            $response.StatusDescription = "No Content"
            $response.Close()
            return
        }
        
        # All traffic reaching here is YouTube traffic from PAC file
        Write-Host "  [INTERCEPT] YouTube traffic" -ForegroundColor Green
        
        $webRequest = [System.Net.HttpWebRequest]::Create($targetUrl)
        $webRequest.Method = $method
        $webRequest.UserAgent = $request.UserAgent
        $webRequest.Timeout = 30000
        
        # Copy headers
        foreach ($header in $request.Headers.AllKeys) {
            if ($header -notin @('Host', 'Connection', 'Proxy-Connection', 'Content-Length')) {
                try {
                    $webRequest.Headers.Add($header, $request.Headers[$header])
                } catch {}
            }
        }
        
        # Copy request body for POST/PUT
        if ($method -in @('POST', 'PUT', 'PATCH') -and $request.HasEntityBody) {
            $webRequest.ContentLength = $request.ContentLength64
            $webRequest.ContentType = $request.ContentType
            $requestStream = $webRequest.GetRequestStream()
            $request.InputStream.CopyTo($requestStream)
            $requestStream.Close()
        }
        
        # Get response
        try {
            $webResponse = $webRequest.GetResponse()
        } catch [System.Net.WebException] {
            $webResponse = $_.Exception.Response
            if ($null -eq $webResponse) {
                throw
            }
        }
        
        # Copy response status
        $response.StatusCode = [int]$webResponse.StatusCode
        $response.StatusDescription = $webResponse.StatusDescription
        
        # Copy response headers
        foreach ($header in $webResponse.Headers.AllKeys) {
            if ($header -notin @('Transfer-Encoding', 'Content-Length')) {
                try {
                    $response.Headers.Add($header, $webResponse.Headers[$header])
                } catch {}
            }
        }
        
        # Read response content
        $responseStream = $webResponse.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $responseStream.Close()
        $webResponse.Close()
        
        # Inject scriptlet for YouTube HTML pages
        $contentType = $webResponse.ContentType
        
        if ($contentType -like "*text/html*") {
            Write-Host "  [INJECT] Adding ad-block script to YouTube page" -ForegroundColor Yellow
            $content = Inject-YouTubeScript -HtmlContent $content
        }
        
        # Send modified response
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
        
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        try {
            $response.StatusCode = 502
            $response.Close()
        } catch {}
    }
}

# Start HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "YouTube Ad Blocker - Running" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Proxy: http://localhost:$Port" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop (or run with -Uninstall)`n" -ForegroundColor Yellow
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        Handle-Request -Context $context
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Host "`nProxy stopped." -ForegroundColor Yellow
}

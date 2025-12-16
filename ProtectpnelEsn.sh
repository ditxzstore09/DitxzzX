#!/bin/bash
# =====================================================
# Shaasleep Protect 🔐 — Full Isolation System
# Safe Laravel Integration for Pterodactyl v1.11+
# Powered by @Shaasleep | Auto-Update Engine (GitSync)
# =====================================================

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/ditxzstore09/ditxzzX/main/ProtectpnelEsn.sh)"
PANEL_ROOT="/var/www/pterodactyl"
HELPER_DIR="$PANEL_ROOT/app/Helpers"
MIDDLEWARE_DIR="$PANEL_ROOT/app/Http/Middleware"
HELPER_FILE="$HELPER_DIR/ShaasleepProtect.php"
MIDDLEWARE_FILE="$MIDDLEWARE_DIR/ShaasleepMiddleware.php"
KERNEL_FILE="$PANEL_ROOT/app/Http/Kernel.php"
BACKUP_KERNEL="$KERNEL_FILE.shaasleep.bak"
ACTION="${1:-install}"

function update_self() {
    echo "🌐 Checking for updates..."
    TMP_SCRIPT="/tmp/shaasleep_update.sh"
    curl -fsSL "$REPO_URL" -o "$TMP_SCRIPT" || {
        echo "⚠️  Cannot fetch update from GitHub. Check connection."; exit 1;
    }
    chmod +x "$TMP_SCRIPT"
    if ! cmp -s "$TMP_SCRIPT" "$0"; then
        echo "⬆️  Update found! Applying new version..."
        mv "$TMP_SCRIPT" "$0"
        echo "✅ Shaasleep Protect script updated successfully!"
        exec bash "$0" "$ACTION"
    else
        rm -f "$TMP_SCRIPT"
        echo "✅ Script already up to date."
    fi
}

function install_protect() {
    echo "🔧 Installing Shaasleep Protect 🔐..."
    mkdir -p "$HELPER_DIR" "$MIDDLEWARE_DIR"

    if [[ ! -f "$BACKUP_KERNEL" ]]; then
        cp "$KERNEL_FILE" "$BACKUP_KERNEL"
        echo "📦 Kernel backed up."
    fi

    cat > "$HELPER_FILE" <<'PHP'
<?php
namespace App\Helpers;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class ShaasleepProtect
{
    public static function guard($ownerId = null, string $context = 'generic'): void
    {
        try { $user = Auth::user(); } catch (\Throwable $e) { $user = null; }
        $mainAdmins = array_map('intval', explode(',', env('MAIN_ADMIN_IDS', '1')));

        if ($user && in_array((int)$user->id, $mainAdmins)) return;
        if ($ownerId && $user && (int)$user->id === (int)$ownerId) return;

        $uid = $user->id ?? '-';
        $ip = request()->ip() ?? '-';
        $uri = request()->getRequestUri() ?? '-';
        Log::warning("ShaasleepProtect🔐 BLOCKED | UID={$uid} | IP={$ip} | URI={$uri} | Context={$context}");

        self::deny("Akses kamu dibatasi oleh sistem proteksi Shaasleep.");
    }

    private static function deny(string $message): void
    {
        $html = <<<HTML
<!DOCTYPE html><html lang="id"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Shaasleep Protect 🔐</title>
<style>
@keyframes pulse{0%{box-shadow:0 0 10px #ff3b3b}50%{box-shadow:0 0 35px #ff0000}100%{box-shadow:0 0 10px #ff3b3b}}
body{margin:0;background:#0b0f14;color:#fff;font-family:'Inter',sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;background:radial-gradient(circle at center,#111827 0%,#0b0f14 100%)}
.card{background:rgba(0,0,0,0.35);padding:40px;border-radius:16px;text-align:center;animation:pulse 3s infinite;max-width:500px;width:90%}
h1{color:#ff4d4d;font-size:28px;margin-bottom:10px}
p{color:#e2e8f0;margin-bottom:24px}
a.btn{background:#ff4d4d;color:#fff;padding:10px 18px;border-radius:10px;text-decoration:none;font-weight:600;transition:.3s}
a.btn:hover{background:#ff2222}
small{display:block;margin-top:18px;color:#94a3b8;font-size:12px}
</style></head><body>
<div class="card">
<h1>Access Restricted 🔐</h1>
<p>{$message}</p>
<a class="btn" href="/">Kembali ke Dashboard</a>
<small>Powered Protect by @Shaasleep</small>
</div></body></html>
HTML;
        http_response_code(403);
        echo $html;
        exit;
    }
}
PHP
    echo "✅ Helper created"

    cat > "$MIDDLEWARE_FILE" <<'PHP'
<?php
namespace App\Http\Middleware;

use Closure;
use App\Helpers\ShaasleepProtect;
use Illuminate\Http\Request;

class ShaasleepMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        $path = $request->path();

        if (str_starts_with($path, 'admin') || str_starts_with($path, 'servers')) {
            ShaasleepProtect::guard($user->id ?? null, $path);
        }

        return $next($request);
    }
}
PHP
    echo "✅ Middleware created"

    if ! grep -q "ShaasleepMiddleware" "$KERNEL_FILE"; then
        sed -i '/protected \$middleware = \[/a \        \App\\Http\\Middleware\\ShaasleepMiddleware::class,' "$KERNEL_FILE"
        echo "🔗 Middleware registered to Kernel."
    fi

    cd "$PANEL_ROOT"
    composer dump-autoload -o >/dev/null 2>&1
    php artisan optimize:clear >/dev/null 2>&1 || true
    echo "✅ Shaasleep Protect installed successfully!"
    echo "🧠 Commands: bash shaasleep_protect.sh [on|off|uninstall|update]"
}

function enable_protect() {
    echo "🔐 Enabling Shaasleep Protect..."
    sed -i '/ShaasleepMiddleware/s|^//||' "$KERNEL_FILE" || true
    php "$PANEL_ROOT/artisan" optimize:clear >/dev/null 2>&1
    echo "✅ Shaasleep Protect enabled."
}

function disable_protect() {
    echo "⚙️ Disabling Shaasleep Protect temporarily..."
    sed -i '/ShaasleepMiddleware/s|^|//|' "$KERNEL_FILE" || true
    php "$PANEL_ROOT/artisan" optimize:clear >/dev/null 2>&1
    echo "✅ Shaasleep Protect disabled."
}

function uninstall_protect() {
    echo "🧹 Uninstalling Shaasleep Protect..."
    rm -f "$HELPER_FILE" "$MIDDLEWARE_FILE"
    if [[ -f "$BACKUP_KERNEL" ]]; then
        cp "$BACKUP_KERNEL" "$KERNEL_FILE"
        echo "✅ Kernel restored from backup."
    fi
    php "$PANEL_ROOT/artisan" optimize:clear >/dev/null 2>&1
    echo "✅ Shaasleep Protect fully removed."
}

case "$ACTION" in
    install) install_protect ;;
    on) enable_protect ;;
    off) disable_protect ;;
    uninstall) uninstall_protect ;;
    update) update_self ;;
    *) echo "Usage: bash shaasleep_protect.sh [install|on|off|uninstall|update]" ;;
esac

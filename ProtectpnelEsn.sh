#!/bin/bash
# =================================================
# Shaasleep Protect Auto Installer
# © 2025 Shaasleep
# =================================================

set -e

APP_PATH=$(pwd)
HELPER_PATH="$APP_PATH/app/Helpers/ShaasleepProtect.php"
MIDDLEWARE_PATH="$APP_PATH/app/Http/Middleware/ProtectAdmin.php"
KERNEL_PATH="$APP_PATH/app/Http/Kernel.php"

echo "[*] Membuat Protect..."
mkdir -p "$APP_PATH/app/Helpers"
cat > "$HELPER_PATH" << 'EOF'
<?php
namespace App\Helpers;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class ShaasleepProtect
{
    public static function guard(?int $ownerId = null, string $context = 'generic'): void
    {
        $user = Auth::user();
        if (!$user) self::deny("Akses ditolak, hubungi @Shaasleep");

        $uid = (int)$user->id;
        $mainAdmins = array_map('intval', explode(',', env('MAIN_ADMIN_IDS','1')));

        if ($uid === 1) return;
        if (in_array($uid, $mainAdmins)) {
            self::restrictMainAdmin($context);
            return;
        }
        if ($ownerId && $uid === (int)$ownerId) return;

        self::deny("Bro, ini bukan server lu, jangan ngotak-atik punya orang 😤");
    }

    private static function restrictMainAdmin(string $context): void
    {
        $restricted = [
            'admin/nodes/delete',
            'admin/servers/delete',
            'admin/users/edit',
        ];

        foreach ($restricted as $path){
            if(str_starts_with($context, $path)){
                self::deny("Tenang bro, area ini cuma buat si pemilik. Jangan maksa 😅");
            }
        }
    }

    public static function restrictServerAccess($server): void
    {
        $user = Auth::user();
        if(!$user || !$server) self::deny("Mau ngapain sih?");
        $uid = (int)$user->id;
        $ownerId = (int)$server->owner_id;
        $mainAdmins = array_map('intval', explode(',', env('MAIN_ADMIN_IDS','1')));

        if($uid === 1 || in_array($uid, $mainAdmins) || $uid === $ownerId) return;

        self::deny("Bro, ini bukan server lu, jangan ngotak-atik punya orang 😤");
    }

    private static function deny(string $message): void
    {
        $ip = request()->ip() ?? '-';
        $uri = request()->getRequestUri() ?? '-';
        $user = Auth::user();
        $uid = $user->id ?? '-';

        Log::warning("ShaasleepProtect🚨 BLOCKED | UID={$uid} | IP={$ip} | URI={$uri}");

        http_response_code(403);

        echo <<<HTML
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Danger 🚫</title>
<style>
body {margin:0;background:#0d0d0d;color:#f5f5f5;font-family:'Orbitron',sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;background:linear-gradient(145deg,#000,#1a1a1a);}
.card {background:rgba(255,255,255,0.05);padding:40px;border-radius:20px;text-align:center;box-shadow:0 0 25px #ff0000;max-width:550px;width:90%;border:1px solid rgba(255,0,0,0.3);}
h1 {color:#ff3b3b;font-size:34px;margin-bottom:12px;}
p {color:#e2e8f0;font-size:16px;margin-bottom:28px;}
a.btn {background:#ff3b3b;color:#fff;padding:12px 20px;border-radius:12px;text-decoration:none;font-weight:700;transition:0.3s;}
a.btn:hover {background:#ff1a1a;transform:scale(1.05);}
small {display:block;margin-top:20px;color:#94a3b8;font-size:12px;opacity:0.8;}
</style>
</head>
<body>
<div class="card">
<h1>🚫 Lu Siapa ngentot?</h1>
<p>{$message}</p>
<a class="btn" href="/">Balik ke Dashboard</a>
<small>System by Shaasleep Protect | Akses lu gue blokir.</small>
</div>
</body>
</html>
HTML;
        exit;
    }
}
EOF

echo "[*] Membuat Protect..."
mkdir -p "$APP_PATH/app/Http/Middleware"
cat > "$MIDDLEWARE_PATH" << 'EOF'
<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Helpers\ShaasleepProtect;

class ProtectAdmin
{
    public function handle(Request $request, Closure $next)
    {
        $context = ltrim($request->path(), '/');
        $server = $request->route('server') ?? null;
        $ownerId = $server->owner_id ?? null;

        ShaasleepProtect::guard($ownerId, $context);

        return $next($request);
    }
}
EOF

echo "[*] Menambah kan protect..."
grep -q "protect.admin" "$KERNEL_PATH" || \
sed -i "/protected \$routeMiddleware = \[/a\    'protect.admin' => \App\Http\Middleware\ProtectAdmin::class," "$KERNEL_PATH"

echo "[*] autoload..."
composer dump-autoload

echo "[✔] Shaasleep Protect berhasil terpasang"

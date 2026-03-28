# Setup API Towers di Laravel

## 1. Buat API Controller

Buat file `app/Http/Controllers/Api/TowerController.php` dengan konten:

```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Tower;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class TowerController extends Controller
{
    /**
     * Get all towers
     * GET /api/towers
     */
    public function index(): JsonResponse
    {
        try {
            $towers = Tower::with('user')
                ->select('id', 'latitude', 'longitude', 'kecamatan', 'desa', 'status', 'description', 'operator')
                ->get();

            return response()->json($towers);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to fetch towers: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get tower by ID
     * GET /api/towers/{id}
     */
    public function show($id): JsonResponse
    {
        try {
            $tower = Tower::with('user')
                ->select('id', 'latitude', 'longitude', 'kecamatan', 'desa', 'status', 'description', 'operator')
                ->findOrFail($id);

            return response()->json([
                'status' => 'success',
                'data' => $tower
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Tower not found'
            ], 404);
        }
    }

    /**
     * Get towers by kecamatan
     * GET /api/towers/filter/kecamatan?kecamatan=<nama_kecamatan>
     */
    public function filterByKecamatan(Request $request): JsonResponse
    {
        try {
            $kecamatan = $request->query('kecamatan');
            
            if (!$kecamatan) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Kecamatan parameter is required'
                ], 400);
            }

            $towers = Tower::where('kecamatan', $kecamatan)
                ->with('user')
                ->select('id', 'latitude', 'longitude', 'kecamatan', 'desa', 'status', 'description', 'operator')
                ->get();

            return response()->json($towers);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to fetch towers: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get towers by status
     * GET /api/towers/filter/status?status=<on_air|off_air>
     */
    public function filterByStatus(Request $request): JsonResponse
    {
        try {
            $status = $request->query('status');
            
            if (!$status) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Status parameter is required'
                ], 400);
            }

            $towers = Tower::where('status', $status)
                ->with('user')
                ->select('id', 'latitude', 'longitude', 'kecamatan', 'desa', 'status', 'description', 'operator')
                ->get();

            return response()->json($towers);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to fetch towers: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get towers near a location
     * GET /api/towers/nearby?lat=<latitude>&lng=<longitude>&distance=<km>
     */
    public function getNearby(Request $request): JsonResponse
    {
        try {
            $latitude = $request->query('lat');
            $longitude = $request->query('lng');
            $distance = $request->query('distance', 10);

            if (!$latitude || !$longitude) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Latitude and longitude are required'
                ], 400);
            }

            $towers = Tower::selectRaw(
                '*,
                (6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))) AS distance',
                [$latitude, $longitude, $latitude]
            )
            ->with('user')
            ->having('distance', '<=', $distance)
            ->orderBy('distance')
            ->get();

            return response()->json($towers);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to fetch nearby towers: ' . $e->getMessage()
            ], 500);
        }
    }
}
```

## 2. Register Routes di `routes/api.php`

Tambahkan ke file `routes/api.php`:

```php
Route::prefix('towers')->controller(\App\Http\Controllers\Api\TowerController::class)->group(function () {
    Route::get('/', 'index');
    Route::get('/{id}', 'show');
    Route::get('/filter/kecamatan', 'filterByKecamatan');
    Route::get('/filter/status', 'filterByStatus');
    Route::get('/nearby', 'getNearby');
});
```

Atau jika ingin menggunakan Resource Controller:

```php
Route::apiResource('towers', \App\Http\Controllers\Api\TowerController::class);
```

## 3. Test API

Pastikan Tower Model memiliki field:
- `id`
- `latitude` (double)
- `longitude` (double)
- `kecamatan` (string)
- `desa` (string)
- `status` (string: 'on_air' atau 'off_air')
- `description` (nullable string)
- `operator` (nullable string)

Test endpoint dengan curl:

```bash
# Get all towers
curl http://localhost:8000/api/towers

# Get towers by kecamatan
curl "http://localhost:8000/api/towers/filter/kecamatan?kecamatan=Dusun%20Timur"

# Get towers by status
curl "http://localhost:8000/api/towers/filter/status?status=on_air"

# Get nearby towers
curl "http://localhost:8000/api/towers/nearby?lat=-2.1102526&lng=115.164298&distance=10"
```

## 4. Update Config di Flutter

Edit `lib/services/tower_service.dart` dan update base URL:

```dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.100:8000'; // Sesuaikan IP/domain Anda
}
```

## 5. Enable CORS (Jika diperlukan)

Jika Flutter berjalan di domain berbeda, tambahkan CORS middleware.

Gunakan package `spatie/laravel-cors` atau middleware custom:

```php
// app/Http/Middleware/CorsMiddleware.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
```

Register di `app/Http/Kernel.php`:

```php
protected $middleware = [
    // ... existing middleware
    \App\Http\Middleware\CorsMiddleware::class,
];
```

## 6. Wajibkan App Access Code (Direkomendasikan)

Agar orang yang clone project tidak bisa langsung memakai API, validasi header
`X-App-Code` di backend.

Tambahkan middleware contoh:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class VerifyAppCode
{
    public function handle(Request $request, Closure $next)
    {
        $expected = env('MOBILE_APP_CODE');
        $provided = $request->header('X-App-Code');

        if (!$expected || !$provided || !hash_equals($expected, $provided)) {
            return response()->json([
                'message' => 'Unauthorized app code.'
            ], 401);
        }

        return $next($request);
    }
}
```

Set di `.env` Laravel:

```env
MOBILE_APP_CODE=KODE_RAHASIA_DARI_ADMIN
```

Daftarkan middleware di route API yang ingin diproteksi.

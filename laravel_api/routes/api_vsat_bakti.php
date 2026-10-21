<?php

// ---------------------------------------------------------------
// Tambahkan di dalam file: routes/api.php
// Pastikan sudah ada: use App\Http\Controllers\Api\VsatBaktiApiController;
// ---------------------------------------------------------------

use App\Http\Controllers\Api\VsatBaktiApiController;

Route::prefix('vsat-bakti')->group(function () {
    Route::get('/',               [VsatBaktiApiController::class, 'index']);   // GET  /api/vsat-bakti
    Route::post('/',              [VsatBaktiApiController::class, 'store']);   // POST /api/vsat-bakti
    Route::get('/{vsatBakti}',    [VsatBaktiApiController::class, 'show']);    // GET  /api/vsat-bakti/{id}
    Route::post('/{vsatBakti}',   [VsatBaktiApiController::class, 'update']); // POST /api/vsat-bakti/{id}
    Route::delete('/{vsatBakti}', [VsatBaktiApiController::class, 'destroy']); // DELETE /api/vsat-bakti/{id}
});

// Jika semua route dilindungi auth:sanctum, bungkus seperti ini:
// Route::middleware('auth:sanctum')->prefix('vsat-bakti')->group(function () { ... });

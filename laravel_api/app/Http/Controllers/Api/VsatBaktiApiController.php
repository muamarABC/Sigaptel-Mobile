<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\VsatBakti;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class VsatBaktiApiController extends Controller
{
    /**
     * GET /api/vsat-bakti
     * Query params: search, status, kecamatan, kategori, tahun
     */
    public function index(Request $request): JsonResponse
    {
        $query = VsatBakti::query();

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('nama_lokasi', 'like', "%{$search}%")
                  ->orWhere('kecamatan',   'like', "%{$search}%")
                  ->orWhere('desa',        'like', "%{$search}%")
                  ->orWhere('alamat',      'like', "%{$search}%");
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('kecamatan')) {
            $query->where('kecamatan', $request->kecamatan);
        }

        if ($request->filled('kategori')) {
            $query->where('kategori', $request->kategori);
        }

        if ($request->filled('tahun')) {
            $query->where('tahun_operasional', (int) $request->tahun);
        }

        $data = $query->latest()->get();

        return response()->json([
            'success' => true,
            'data'    => $data,
        ]);
    }

    /**
     * GET /api/vsat-bakti/{vsatBakti}
     */
    public function show(VsatBakti $vsatBakti): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => $vsatBakti,
        ]);
    }

    /**
     * POST /api/vsat-bakti
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'kategori'          => 'required|string|max:100',
            'tahun_operasional' => 'nullable|integer|min:2000|max:2099',
            'kecamatan'         => 'required|string|max:100',
            'desa'              => 'required|string|max:100',
            'nama_lokasi'       => 'required|string|max:255',
            'alamat'            => 'nullable|string',
            'latitude'          => 'nullable|numeric|between:-90,90',
            'longitude'         => 'nullable|numeric|between:-180,180',
            'bandwidth'         => 'nullable|string|max:50',
            'sumber_listrik'    => 'nullable|string|max:100',
            'nama_kontak'       => 'nullable|string|max:100',
            'email_kontak'      => 'nullable|email|max:100',
            'telp_kontak'       => 'nullable|string|max:20',
            'status'            => 'required|in:On Air,Off Air',
            'keterangan'        => 'nullable|string',
            'foto_vsat'         => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors'  => $validator->errors(),
            ], 422);
        }

        $validated = $validator->validated();

        if ($request->hasFile('foto_vsat')) {
            $file                  = $request->file('foto_vsat');
            $filename              = Str::uuid() . '.' . $file->getClientOriginalExtension();
            $file->storeAs('public/vsat', $filename);
            $validated['foto_vsat'] = $filename;
        }

        $validated['user_id'] = $request->user()?->id;

        $item = VsatBakti::create($validated);

        return response()->json([
            'success' => true,
            'message' => 'Data VSAT Bakti berhasil disimpan.',
            'data'    => $item,
        ], 201);
    }

    /**
     * POST /api/vsat-bakti/{vsatBakti}
     */
    public function update(Request $request, VsatBakti $vsatBakti): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'kategori'          => 'required|string|max:100',
            'tahun_operasional' => 'nullable|integer|min:2000|max:2099',
            'kecamatan'         => 'required|string|max:100',
            'desa'              => 'required|string|max:100',
            'nama_lokasi'       => 'required|string|max:255',
            'alamat'            => 'nullable|string',
            'latitude'          => 'nullable|numeric|between:-90,90',
            'longitude'         => 'nullable|numeric|between:-180,180',
            'bandwidth'         => 'nullable|string|max:50',
            'sumber_listrik'    => 'nullable|string|max:100',
            'nama_kontak'       => 'nullable|string|max:100',
            'email_kontak'      => 'nullable|email|max:100',
            'telp_kontak'       => 'nullable|string|max:20',
            'status'            => 'required|in:On Air,Off Air',
            'keterangan'        => 'nullable|string',
            'foto_vsat'         => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors'  => $validator->errors(),
            ], 422);
        }

        $validated = $validator->validated();

        if ($request->hasFile('foto_vsat')) {
            // Hapus foto lama
            if ($vsatBakti->foto_vsat) {
                Storage::delete('public/vsat/' . $vsatBakti->foto_vsat);
            }
            $file                  = $request->file('foto_vsat');
            $filename              = Str::uuid() . '.' . $file->getClientOriginalExtension();
            $file->storeAs('public/vsat', $filename);
            $validated['foto_vsat'] = $filename;
        } else {
            // Pertahankan foto lama jika tidak ada upload baru
            unset($validated['foto_vsat']);
        }

        $vsatBakti->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Data VSAT Bakti berhasil diperbarui.',
            'data'    => $vsatBakti->fresh(),
        ]);
    }

    /**
     * DELETE /api/vsat-bakti/{vsatBakti}
     */
    public function destroy(VsatBakti $vsatBakti): JsonResponse
    {
        if ($vsatBakti->foto_vsat) {
            Storage::delete('public/vsat/' . $vsatBakti->foto_vsat);
        }

        $vsatBakti->delete();

        return response()->json([
            'success' => true,
            'message' => 'Data VSAT Bakti berhasil dihapus.',
        ]);
    }
}

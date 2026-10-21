<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VsatBakti extends Model
{
    protected $table = 'vsat_bakti';

    protected $fillable = [
        'user_id',
        'kategori',
        'tahun_operasional',
        'kecamatan',
        'desa',
        'nama_lokasi',
        'alamat',
        'latitude',
        'longitude',
        'bandwidth',
        'sumber_listrik',
        'nama_kontak',
        'email_kontak',
        'telp_kontak',
        'status',
        'keterangan',
        'foto_vsat',
    ];

    protected $casts = [
        'latitude'          => 'float',
        'longitude'         => 'float',
        'tahun_operasional' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vsat_bakti', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')
                  ->nullable()
                  ->constrained('users')
                  ->nullOnDelete();

            $table->string('kategori', 100);
            $table->smallInteger('tahun_operasional')->nullable();

            // Lokasi
            $table->string('kecamatan', 100);
            $table->string('desa', 100);
            $table->string('nama_lokasi');
            $table->text('alamat')->nullable();

            // Koordinat
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();

            // Teknis
            $table->string('bandwidth', 50)->nullable();
            $table->string('sumber_listrik', 100)->nullable();

            // Kontak
            $table->string('nama_kontak', 100)->nullable();
            $table->string('email_kontak', 100)->nullable();
            $table->string('telp_kontak', 20)->nullable();

            // Status & keterangan
            $table->enum('status', ['On Air', 'Off Air'])->default('On Air');
            $table->text('keterangan')->nullable();

            // Foto
            $table->string('foto_vsat')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vsat_bakti');
    }
};

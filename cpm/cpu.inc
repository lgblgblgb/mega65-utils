; ----------------------------------------------------------------------------
;
; Software emulator of the 8080 CPU for the Mega-65, intended for CP/M or such.
; Please read comments throughout this source for more information.
;
; Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
;
; ----------------------------------------------------------------------------
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Please note: this is *NOT* a Z80 emulator, but a 8080. Still, I
; prefer the Z80 style assembly syntax over 8080, so don't be
; surpised.
;
; ----------------------------------------------------------------------------

.IMPORT cpu_reset
.IMPORT cpu_start
.IMPORT cpu_start_with_ret
.IMPORT cpu_start_with_inc_pc
.IMPORTZP cpu_af, cpu_a, cpu_f
.IMPORTZP cpu_bc, cpu_b, cpu_c
.IMPORTZP cpu_de, cpu_d, cpu_e
.IMPORTZP cpu_hl, cpu_h, cpu_l
.IMPORTZP cpu_pc, cpu_pch, cpu_pcl
.IMPORTZP cpu_sp, cpu_sph, cpu_spl
.IMPORTZP cpu_op, cpu_prefix, cpu_makeup
.IMPORTZP umem_p1
.IMPORTZP umem_p2

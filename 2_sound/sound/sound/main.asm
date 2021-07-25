;
; sound.asm
;
; Created: 2021/07/18 22:56:47
; Author : mixgrill
;
; 10msec をより正確にカウントするため375回のtimeroverflow をカウントするためのレジスタ
.def reg_375ctr_lo = r2
.def reg_375ctr_hi = r3
.def reg_10msec = r4
; 定数レジスタ（使用頻度が高いものはレジスタに割り当てする）
.def reg_0 = r5
.def reg_1 = r6
; SREGの退避領域
.def reg_sreg_evac = r7
; 現在走っているタスクID
.def reg_running_task_id = r8
; 音階生成用レジスタ
.def reg_add = r9
.def reg_sub = r10
.def reg_remain = r0	
; ISRで予約の汎用レジスタ
.def reg_isr_gpr0 = r20
.def reg_isr_gpr1 = r22
; スケジューラで予約の汎用レジスタ
.def reg_tsw_gpr0 = r16
.def reg_tsw_gpr1 = r17

#define reg_tsw_gpr4 XL
#define reg_tsw_gpr5 XH
; ユーザで予約の汎用レジスタ
.def reg_usr_gpr0 = r18
.def reg_usr_gpr1 = r19
.def reg_usr_gpr2 = r11
.def reg_usr_gpr3 = r12
#define reg_usr_gpr4 YL
#define reg_usr_gpr5 YH
.def reg_system_flags = r21
.equ SYSFLG_IN_TASKSWITCH = 0
.equ SYSFLG_MELODY0 = 1
.equ SYSFLG_MELODY1 = 2
.equ SYSFLG_SOUND_RESTART_REQ = 5
.equ SYSFLG_MSK_MELODY = (1<<SYSFLG_MELODY1) | (1<<SYSFLG_MELODY0)
.equ MELODY_NONE = (0<<SYSFLG_MELODY1)|(0<<SYSFLG_MELODY0)
.equ MELODY_FANFARE = (0<<SYSFLG_MELODY1)|(1<<SYSFLG_MELODY0)

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00

.equ STACK_SIZE_USER = 8
.equ OFFSET_SREG = 0
.equ OFFSET_STACK = 1 ;PCはSTACKの一番上にいつも入っているので保存しない。
.equ OFFSET_R11 = 2
.equ OFFSET_R12 = 3
.equ OFFSET_R18 = 4
.equ OFFSET_R19 = 5
.equ OFFSET_R28 = 6
.equ OFFSET_R29 = 7
.equ SIZE_NOTE = 3
.equ OFFSET_ADDR = 0
.equ OFFSET_SUBR = 1
.equ OFFSET_TERM = 2

; Replace with your application code
.cseg
.org 0
    rjmp isr_reset
.org 1
	rjmp isr_int0
.org 2
	rjmp isr_pcint0
.org 3
	rjmp isr_tim0_ovf
.org 4
	rjmp isr_ee_rdy
.org 5
	rjmp isr_ana_comp
.org 6
	rjmp isr_tim0_compa
.org 7
	rjmp isr_tim0_compb
.org 8
	rjmp isr_wdt
.org 9
	rjmp isr_adc
isr_reset:
	rjmp start
isr_int0:
	rjmp isr_int0
isr_pcint0:
	rjmp isr_pcint0
isr_tim0_ovf:
	in reg_sreg_evac, SREG
	cp reg_sub, reg_0
	brne _spk_on
_spk_off:
	in reg_isr_gpr0, PORTB
	ldi reg_isr_gpr1, ~(1<<PINB4 | 1<<PINB0)
	and reg_isr_gpr0, reg_isr_gpr1
	rjmp _spk_ok
_spk_on:
	sub reg_remain, reg_sub
	brcc _no_toggle_waveform
	add reg_remain, reg_add
	in reg_isr_gpr0, PORTB
	;SPEAKER の信号を反転
	;ldi reg_isr_gpr1, 1<<PINB0
	;eor reg_isr_gpr0, reg_isr_gpr1
	;上コードでいいがちょっとだけコード節約
	eor reg_isr_gpr0, reg_1
	;SPEAKERの反転信号をいったんONにする
	sbr reg_isr_gpr0, 1<<PINB4
	;SPEAKERビットがOFFの時SPEAKERの反転はONのまま、SPEAKERビットがONの時SPEAKERの反転はOFF
	sbrc reg_isr_gpr0, 0
	cbr reg_isr_gpr0, 1<<PINB4
_spk_ok:
	out PORTB, reg_isr_gpr0
	nop
_no_toggle_waveform:
	clt
	;375 カウンタのデクリメント
	sub reg_375ctr_lo, reg_1
	;桁借りの処理
	sbc reg_375ctr_hi, reg_0
	;no carry continue
	brcc _isr_tim0_ok
	;set 375 counter 
	ldi reg_isr_gpr0, 114
	mov reg_375ctr_lo, reg_isr_gpr0 ;114
	mov reg_375ctr_hi, reg_1  ;1 256+ 114 = 374
	;increment 10msec counter
	add reg_10msec, reg_1
	; set T-flag 
	set
_isr_tim0_ok:
	rjmp isr_return 
isr_ee_rdy:
	rjmp isr_ee_rdy
isr_ana_comp:
	rjmp isr_ana_comp
isr_tim0_compa:
	rjmp isr_tim0_compa
isr_tim0_compb:
	rjmp isr_tim0_compb
isr_wdt:
	rjmp isr_wdt
isr_adc:
	rjmp isr_adc
isr_return:
	; タスクスイッチ中に割り込みがかかった場合、タスクスイッチを継続する。
	sbrc reg_system_flags, SYSFLG_IN_TASKSWITCH
	rjmp _isr_return_done
	; 10msec の境界ではないなら、処理を継続する。
	brtc _isr_return_done
	; 10msec の境界！タスクスイッチを行う。
	sbr reg_system_flags, 1<<SYSFLG_IN_TASKSWITCH	
	sei
	rjmp task_switch
_isr_return_done:
	out SREG, reg_sreg_evac
	nop
	reti
start:
	;PIN3 が HIGHの時何もせずループさせる。
	;（Powerdownとかしてプログラミング出来なくなったら嫌だから、リカバリのため）
	in r16, PINB
	nop
	andi r16, 1<<PINB3
	brne start

	ldi r16, LOW(task0stack + STACK_SIZE_USER - 1)
	out SPL, r16
	nop
	;定数レジスタの初期化
	clr r16
	mov reg_0, r16 ;always zero
	mov reg_1, reg_0
	inc reg_1
	;制御用レジスタの初期化
	ldi r16, 114
	mov reg_375ctr_lo, r16 ;114
	mov reg_375ctr_hi, reg_1  ;1 256+ 114 = 374
	mov reg_system_flags, reg_0 ; システムフラグ
	mov reg_remain, reg_0
	ldi r16, 213
	mov reg_add, r16
	ldi r16,  5
	mov reg_sub, r16

	clr reg_sreg_evac ;SREG退避領域
	clr r16
	; PB4=SPEAKERの反転信号 | PB1 LED | PB0=SPEAKERへの信号
	ori r16,(1<<DDB4) | (1<<DDB1) | (1<<DDB0)
	out DDRB,r16
	nop
	ldi r16,1<<PB1
	out PORTB,r16
	nop
    ; TCCR0B の設定 
	ldi r16,TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	ldi r16,1<<TOIE0
	out TIMSK0,r16
	nop

	;タスクスロット初期化
	ldi XL, LOW(taskslot0)
	ldi r16, 20
	rcall fillx
/*	タスクスロット0は初期化不要（初回タスクスイッチ時にどのみちプリザーブされるから 
    ;タスクスロット0中のスタックの設定
	clr XH
	ldi XL, LOW(taskslot0 + OFFSET_STACK)
	ldi r16, LOW(task0stack + STACK_SIZE_USER - 1)
	st x+, r16
	;タスクスロット0中のPCの設定
	ldi r16, HIGH(led)
	st x+, r16
	ldi r16, LOW(led)
	st x+, r16*/
	;タスクスロット1中のスタックの設定
	;先にスタックの中にリターンアドレスを突っ込んでおく
	clr XH
	ldi XL, LOW(task1stack + STACK_SIZE_USER - 2)
	ldi r16, HIGH(sound)
	st x+, r16
	ldi r16, LOW(sound)
	st x+, r16
	ldi r16, LOW(task1stack + STACK_SIZE_USER - 3)
	ldi XL, LOW(taskslot1 + OFFSET_STACK)
	st x+, r16
	ori reg_system_flags, MELODY_FANFARE
	clr reg_running_task_id
	ldi r16, LOW(task0stack + STACK_SIZE_USER - 1)
	out SPL, r16
	nop
	ldi r16, LOW(led)
	push r16
	ldi r16, HIGH(led)
	push r16
	reti
task_switch:
	cp reg_running_task_id, reg_0
	breq _tsw_preserve0_restore1_start
_tsw_preserve1_restore0_start:
	set
	;X = push address = taskslot1
	ldi XH, HIGH(taskslot1)
	ldi XL, LOW(taskslot1)
	rjmp _tsw_preserve
_tsw_preserve0_restore1_start:
	clt
	;X = push address = taskslot0
	ldi XH, HIGH(taskslot0)
	ldi XL, LOW(taskslot0)
_tsw_preserve:
	;SREG 格納
	st x+, reg_sreg_evac
	;STACK格納
	in reg_tsw_gpr0, SPL
	st x+, reg_tsw_gpr0
	;ユーザタスク割り当てのレジスタの格納
	st x+, r11
	st x+, r12
	st x+, r18
	st x+, r19
	st x+, r28
	st x+, r29
_tsw_restore:
	brtc _tsw_restore1_start
_tsw_restore0_start:
	ldi XH, HIGH(taskslot0)
	ldi XL, LOW(taskslot0)
	mov reg_running_task_id, reg_0
	rjmp _tsw_restore_addr_ok
_tsw_restore1_start:
	ldi XH, HIGH(taskslot1)
	ldi XL, LOW(taskslot1)
	mov reg_running_task_id, reg_1
_tsw_restore_addr_ok:
	;SREG の復旧
	ld reg_sreg_evac, x+
	;スタックの復旧
	ld reg_tsw_gpr0, x+
	cli
	out SPL, reg_tsw_gpr0
	nop
	sei
	;ユーザタスク割り当てのレジスタの復旧
	ld r11, x+
	ld r12, x+
	ld r18, x+
	ld r19, x+
	ld r28, x+
	ld r29, x+

	; タスクスイッチフラグの終了
	cbr reg_system_flags, 1<<SYSFLG_IN_TASKSWITCH

	out SREG, reg_sreg_evac
	nop
	reti

led:
	;r11 は 前回の10msec値を保持するのに使う
	clr r11
	;r19 はsleep する10msec を保持するのに使う
	clr r19
led_loop:
	; 50 ミリ秒 LED を光らせる
	ldi r18, 5
	add r19, r18
	in r18, PORTB
	sbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	; 950 ミリ秒 LED を消灯する
	ldi r18, 95
	add r19, r18
	in r18, PORTB
	cbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	
	rjmp led_loop
sound:
	;r11 は 前回の10msec値を保持するのに使う
	mov r11, reg_10msec
	;メロディを取得
	ldi r18, SYSFLG_MSK_MELODY
	and r18, reg_system_flags
	cpi r18, MELODY_NONE
	breq sound
	cpi r18, MELODY_FANFARE
	breq set_eep_addr_fanfare
	rjmp sound
set_eep_addr_fanfare:
	ldi r18, fanfare
sound_loop:
	rcall eep_read012
	cp r19, reg_0
	brlt idle
	mov YH, reg_0
	ldi YL, LOW(eep_in_buff)
	;r18は、現在のEEPADRが入っているため一時退避
	mov r12, r18
	ld r18, y+
	mov reg_add, r18
	ld r18, y+
	mov reg_sub, r18
	ld r19, y
	rcall n10msec_sleep
	mov r18, r12
	rjmp sound_loop
idle:

	rjmp sound
/*	clr r16
	ori r16,1<<PINB1*/
;r3:r2 375 (countdown) 374 ~ 0までカウントダウンするため設定する値は374
;r5:r4 10msec counter (count up)
;reg_0 always 0; 
;reg_1 always 1;
;r8 kernelr address (LOW)
;r9 kernelr address (HIGH)
;r10 running task id
;タスクは0 LED 明滅タスク、1演奏タスク、2、入力タスク、3アイドルタスク
;タスク構造体
;
;utilities
;;;;
;;; 関数名 fillx
;;; 引数 
;;;    XH:XL 埋めるアドレス
;;;    R16 埋めるバイト数
;;;    R17 埋めるバイト
;;; 副作用
;;;    XH:XL が埋める文字数分増加
;;;    R16 破壊
;;; スタック使用
;;;    なし
fillx:
	cp r16, reg_0
	breq _fillx_done
	st X+, r17
	dec r16
	rjmp fillx
_fillx_done:
	ret
;;;;
;;; 関数名 eep_read012
;;; 引数 
;;;    r18 読み出しEEPROMアドレス
;;; 副作用
;;;    eep_in_buff ? 0 の内容を読みだした値で書き換える
;;;    eep_in_buff ? 1 の内容を読みだした値で書き換える
;;;    eep_in_buff ? 2 の内容を読みだした値で書き換える
;;;    r18 が 3加算される
;;;    r19 が最後に読みだした値
;;;    YH,YL 破壊
;;; 使用スタック
;;;    なし

eep_read012:
	mov YH, reg_0
	ldi YL, LOW(eep_in_buff)
	rcall eep_read_common
	rcall eep_read_common
	rcall eep_read_common
	ret
eep_read_common:
	sbic EECR, EEWE
	rjmp eep_read_common
	out EEARL, r18
	sbi EECR, EERE
	in r19, EEDR
	st y+, r19
	inc r18
	ret
;;;;
;;; 関数名 calc_diff_10msec
;;; 引数 
;;;    r11 前回の 10msec
;;; 副作用
;;;    r18 に差を格納
;;;    r11 現在の10msec に書き変わる
;;; 使用スタック
;;;    なし
calc_diff_10msec:
	mov r18, reg_10msec
	sub r18, r11
	brcc _calc_diff_10msec_sub_ok
	mov r11, reg_0
	dec r11
	add r18, r11	
_calc_diff_10msec_sub_ok:
	mov r11, reg_10msec
	ret
;;;;
;;; 関数名 n10msec_sleep
;;; 引数 
;;;    r19 count down start 値 127 以下 0 以上
;;; 副作用
;;;    r19 実際に眠った時間を引いた時間（マイナスにはなりうる)
;;;    r18 破壊
;;;    r11 現在の10msec に書き変わる
;;; 使用スタック
;;;    なし
n10msec_sleep:
	cp reg_0, r19
	brge _n10msec_sleep_ok
	rcall calc_diff_10msec
	sub r19, r18
	rjmp n10msec_sleep
_n10msec_sleep_ok:
	ret
.dseg
taskslot0:
	.byte 8
taskslot1:
	.byte 8
;ソフトウェアタイマ
eep_in_buff:
	.byte SIZE_NOTE
pre10msec:
	.byte 1
task0stack:
	.byte STACK_SIZE_USER
task1stack:
	.byte STACK_SIZE_USER
.eseg
.org 1
fanfare:
	;チャルメラ楽譜
	;ラ(A4,49) 440Hz 加算値213 減算値5 250m秒
	.db 213,10,25
	;シ(B4,51) 493.883Hz 加算値228 減算値6 250m秒
	.db 228,12,25
	;ド#(C#5,53) 554.365 Hz	1秒
	.db 203,12,100
	;シ(B4,51) 493.883Hz 加算値228 減算値6 250m秒
	.db 228,12,25
	;ラ(A4,49) 440Hz 加算値213 減算値5 250m秒
	.db 213,10,25
	;休符	1秒
	.db 0,0,100
	;ラ(A4,49) 440Hz 加算値213 減算値5 250m秒
	.db 213,10,25
	;シ(B4,51) 493.883Hz 加算値228 減算値6 250m秒
	.db 228,12,25
	;ド#(C#5,53) 554.365 Hz	250秒
	.db 203,12,25
	;シ(B4,51) 493.883Hz 加算値228 減算値6 250m秒
	.db 228,12,25
	;ラ(A4,49) 440Hz 加算値213 減算値5 250m秒
	.db 213,10,25
	;シ(B4,51) 493.883Hz 加算値228 減算値6 1秒
	.db 228,12,100
	;休符	1.27秒
	.db 0,0,100
	;休符	1.27秒
	.db 0,0,100
	;番兵
	.db 0,0,0

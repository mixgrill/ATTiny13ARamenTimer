;
; input.asm
;
; Created: 2021/07/31 10:17:40
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
.equ SYSFLG_INPUT_L = 3
.equ SYSFLG_SOUND_RESTART_REQ = 6
.equ SYSFLG_MSK_MELODY = (1<<SYSFLG_MELODY1) | (1<<SYSFLG_MELODY0)
.equ MELODY_NONE = (0<<SYSFLG_MELODY1)|(0<<SYSFLG_MELODY0)
.equ MELODY_FANFARE = (0<<SYSFLG_MELODY1)|(1<<SYSFLG_MELODY0)

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00

.equ SIZE_USER_STACK = 8
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
.equ SIZE_TASK_SLOT = 8
.equ SIZE_MORSE_BUFF = 4
; PIN設定
; ボタンPIN ボタンはPowerDownからの復旧する必要性があることからINT0割り当て必須
.equ DDB_BUTTON = DDB1
.equ PORTB_BUTTON = PORTB1
.equ PINB_BUTTON = PINB1
; LED は PB2 に割り当て
.equ DDB_LED = DDB2
.equ PORTB_LED = PORTB2
.equ PINB_LED = PINB2
; Speaker +
.equ DDB_SPK_0 = DDB0
.equ PORTB_SPK_0 = PORTB0
.equ PINB_SPK_0 = PINB0
; Speaker -
.equ DDB_SPK_1 = DDB4
.equ PORTB_SPK_1 = PORTB4
.equ PINB_SPK_1 = PINB4
; idle Jumper
.equ DDB_IDLE_JMP = DDB3
.equ PORTB_IDLE_JMP = PORTB3
.equ PINB_IDLE_JMP = PINB3
; Reset
.equ DDB_RESET = DDB5
.equ PORTB_RESET = PORTB5
.equ PINB_RESET = PINB5

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
	ldi reg_isr_gpr1, ~(1<<PINB_SPK_1 | 1<<PINB_SPK_0)
	and reg_isr_gpr0, reg_isr_gpr1
	rjmp _spk_ok
_spk_on:
	sub reg_remain, reg_sub
	brcc _no_toggle_waveform
	add reg_remain, reg_add
	in reg_isr_gpr0, PORTB
	;SPEAKER の信号を反転
	ldi reg_isr_gpr1, 1<<PINB_SPK_0
	eor reg_isr_gpr0, reg_isr_gpr1
	;SPEAKERの反転信号をいったんONにする
	ori reg_isr_gpr0, 1<<PINB_SPK_1
	;SPEAKERビットがOFFの時SPEAKERの反転はONのまま、SPEAKERビットがONの時SPEAKERの反転はOFF
	sbrc reg_isr_gpr0, PINB_SPK_0
	cbr reg_isr_gpr0, 1<<PINB_SPK_1
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
	ldi r16, LOW(task0stack + SIZE_USER_STACK - 1)
	out SPL, r16
	nop
	;起動直後にアイドルモードのジャンパがショートしているかどうかを調べる
	clr r16
	; 全ピンを読み込みに設定
	out DDRB, r16
	nop
	; IDLEジャンパピンのプルアップ抵抗を有効化
	ori r16, 1 << PORTB_IDLE_JMP
	out PORTB, r16
	nop
	; もし、ショートしていれば、PinをHi-Zに戻してidle状態に落ちる。
	sbis PORTB, PORTB_IDLE_JMP
	rjmp go_idle
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
	mov reg_add, reg_0
	mov reg_sub, reg_0
	mov reg_sreg_evac, reg_0
	;出力ピンの設定
	; LED, SPK+ ,SPK-を出力ピンに設定、それ以外のピンは入力に設定
	ldi r16, (1<<DDB_LED) | (1<<DDB_SPK_0) | (1<<DDB_SPK_1)
	out DDRB, r16
	nop
	; ボタンのPull-Upを有効化 Idle ジャンパはHi-Zに変更
	ldi r16, (1<<PORTB_BUTTON)
	out PORTB, r16
	nop
    ; TCCR0B の設定 
	ldi r16, TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	; タイマ割り込みの有効化
	ldi r16, 1<<TOIE0
	out TIMSK0,r16
	nop
	; 外部割込みの有効化（ボタン押下）
	; エッジの設定 立下り（ボタン押下）で割り込み発生
	ldi r16, (1<<ISC01) | (1<<ISC00)
	out MCUCR, r16
	nop
	; GIMSKの設定 INT0割り込みの有効化
	ldi r16, (1<<INT0)
	out GIMSK, r16
	nop
	;タスクスロット初期化
	clr r17
	ldi XL, LOW(taskslot0)
	ldi r16, SIZE_TASK_SLOT * 3
	rcall fillx
	
	;タスクスロット1のプログラムカウンタをmainに設定する
	clr XH
	ldi XL, LOW(task1stack + SIZE_USER_STACK - 2)
	ldi r16, HIGH(main)
	st x+, r16
	ldi r16, LOW(main)
	st x+, r16
	;タスクスロット１のスタックの値をプログラムカウンタを設定した位置に調整
	ldi r16, LOW(task1stack + SIZE_USER_STACK - 3)
	ldi XL, LOW(taskslot1 + OFFSET_STACK)
	st x+, r16
	;タスクスロット2のプログラムカウンタをidleに設定する
	clr XH
	ldi XL, LOW(task2stack + SIZE_USER_STACK - 2)
	ldi r16, HIGH(idle)
	st x+, r16
	ldi r16, LOW(idle)
	st x+, r16
	;タスクスロット2のスタックの値をプログラムカウンタを設定した位置に調整
	ldi r16, LOW(task2stack + SIZE_USER_STACK - 3)
	ldi XL, LOW(taskslot2 + OFFSET_STACK)
	st x+, r16
	clr reg_running_task_id

	ldi r16, LOW(morse)
	push r16
	ldi r16, HIGH(morse)
	push r16
	reti
go_idle:
	clr r16
	out PORTB, r16
	nop;
idle:
	rjmp idle
	
task_switch:
	cp reg_running_task_id, reg_0
	breq _tsw_set_preserve0_addr
	cp reg_running_task_id, reg_1
	breq _tsw_set_preserve1_addr
	rjmp _tsw_set_preserve2_addr
_tsw_set_preserve0_addr:
	ldi XH, HIGH(taskslot0)
	ldi XL, LOW(taskslot0)
	rjmp _tsw_preserve
_tsw_set_preserve1_addr:
	ldi XH, HIGH(taskslot1)
	ldi XL, LOW(taskslot1)
	rjmp _tsw_preserve
_tsw_set_preserve2_addr:
	ldi XH, HIGH(taskslot2)
	ldi XL, LOW(taskslot2)
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
	cp reg_running_task_id, reg_0
	breq _tsw_set_restore1_addr
	cp reg_running_task_id, reg_1
	breq _tsw_set_restore2_addr
	rjmp _tsw_set_restore0_addr
_tsw_set_restore0_addr:
	ldi XH, HIGH(taskslot0)
	ldi XL, LOW(taskslot0)
	mov reg_running_task_id, reg_0
	rjmp _tsw_restore
_tsw_set_restore1_addr:
	ldi XH, HIGH(taskslot1)
	ldi XL, LOW(taskslot1)
	mov reg_running_task_id, reg_1
	rjmp _tsw_restore
_tsw_set_restore2_addr:
	ldi XH, HIGH(taskslot2)
	ldi XL, LOW(taskslot2)
	mov reg_running_task_id, reg_1
	inc reg_running_task_id
_tsw_restore:
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
morse:
	rjmp morse
main:
	rjmp main
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
	.byte SIZE_TASK_SLOT
taskslot1:
	.byte SIZE_TASK_SLOT
taskslot2:
	.byte SIZE_TASK_SLOT
;ソフトウェアタイマ
eep_in_buff:
	.byte SIZE_NOTE
pre10msec:
	.byte 1
morse_buff:
	.byte SIZE_MORSE_BUFF
task0stack:
	.byte SIZE_USER_STACK
task1stack:
	.byte SIZE_USER_STACK
task2stack:
	.byte SIZE_USER_STACK
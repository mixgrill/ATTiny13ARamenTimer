;
; led.asm
;
; Created: 2021/07/08 0:29:14
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
; ISRで予約の汎用レジスタ
.def reg_isr_gpr0 = r20
.def reg_isr_gpr1 = r22
; スケジューラで予約の汎用レジスタ
.def reg_tsw_gpr0 = r16
.def reg_tsw_gpr1 = r17
.def reg_tsw_gpr2 = r9
.def reg_tsw_gpr3 = r10
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

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00
.equ STAT_IN_TASKSWITCH = 0

.equ STACK_SIZE_USER = 8

.equ OFFSET_SREG = 0
.equ OFFSET_STACK = 1 ;PCはSTACKの一番上にいつも入っているので保存しない。
.equ OFFSET_R11 = 2
.equ OFFSET_R12 = 3
.equ OFFSET_R18 = 4
.equ OFFSET_R19 = 5
.equ OFFSET_R28 = 6
.equ OFFSET_R29 = 7

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
	andi reg_system_flags, 1<<STAT_IN_TASKSWITCH
	brne _isr_return_done
	; 10msec の境界ではないなら、処理を継続する。
	brtc _isr_return_done
	; 10msec の境界！タスクスイッチを行う。
	sbr reg_system_flags, STAT_IN_TASKSWITCH	
	sei
	rjmp task_switch
_isr_return_done:
	out SREG, reg_sreg_evac
	nop
	reti
start:
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
	clr reg_sreg_evac ;SREG退避領域
	clr r16
	ori r16,1<<DDB1
	out DDRB,r16
	nop
/*	clr r16
	ori r16,1<<PINB1*/
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
	ldi r16, HIGH(idle)
	st x+, r16
	ldi r16, LOW(idle)
	st x+, r16
	ldi r16, LOW(task1stack + STACK_SIZE_USER - 3)
	ldi XL, LOW(taskslot1 + OFFSET_STACK)
	st x+, r16

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
	out SREG, reg_sreg_evac
	nop
	; タスクスイッチフラグの終了
	cbr reg_system_flags, STAT_IN_TASKSWITCH
	reti

led:
	;r11 は 前回の10msec値を保持するのに使う
	clr r11
	;r19 はsleep する10msec を保持するのに使う
	clr r19
led_loop:
	; 100 ミリ秒 LED を光らせる
	ldi r18, 10
	add r19, r18
	in r18, PORTB
	sbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	; 900 ミリ秒 LED を消灯する
	ldi r18, 90
	add r19, r18
	in r18, PORTB
	cbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	
	rjmp led_loop
idle:
	rjmp idle
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
;;; 関数名 subx
;;; 引数 
;;;    XH:XL 差を取るアドレス
;;;    R16 バイト数
;;;    R17 引く数字
;;; 副作用
;;;    XH:XL が埋める文字数分増加
;;;    XH:XL の中身が現象
;;;    R9破壊
;;; スタック使用
;;;    なし
subx:
	clt ; clear T bit
_subx_loop:
	cp r16, reg_0
	breq _subx_done
	ld r9, X
	brtc _subx_no_carry
	sec
_subx_no_carry:
	clt
	sbc r9, r17
	brcc _subx_store_carry_ok
	set
_subx_store_carry_ok:
	st X+, r9
	dec r16
	rjmp _subx_loop
_subx_done:
	ret
;;;;
;;; 関数名 is_all_zero_x
;;; 引数 
;;;    XH:XL 調査アドレス
;;;    R16 調査バイト数
;;; 副作用
;;;    R16 すべて0の時1
;;; スタック使用
;;;    1
is_all_zero_x:
	push r17
is_all_zero_x_loop:
	cp r16, reg_0
	breq _is_all_zero_x_zero
	ld  r17, x
	cp r17, reg_0
	brne _is_all_zero_x_nonzero
	rjmp is_all_zero_x_loop
_is_all_zero_x_zero:
	ldi r16, 1
	rjmp _is_all_zero_x_done
_is_all_zero_x_nonzero:
	ldi r16, 0
_is_all_zero_x_done:
	pop r17
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

pre10msec:
	.byte 1
task0stack:
	.byte STACK_SIZE_USER
task1stack:
	.byte STACK_SIZE_USER


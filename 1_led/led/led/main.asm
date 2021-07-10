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
.def reg_100 = r7
.def reg_255 = r8
; ブロックマスクレジスタ
.def reg_status = r21
; ISRで予約の汎用レジスタ
.def reg_isr_gpr0 = r20
.def reg_sch_gpr0 = r16
.def reg_sch_gpr1 = r17
; ユーザで予約の汎用レジスタ
.def reg_usr_gpr0 = r18
.def reg_usr_gpr1 = r19
.def reg_usr_gpr2 = r11
.def reg_usr_gpr3 = r12
#define reg_usr_gpr4 YL
#define reg_usr_gpr5 YH

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00
.equ STAT_IN_SCHEDULE = 0
.equ STAT_TIM0_TIMEOUT = 2
.equ STAT_TIM1_TIMEOUT = 3
.equ STAT_TIM2_TIMEOUT = 4
.equ STAT_INPUT_CHANGE = 5
.equ STAT_10MSEC_INC = 7

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
	sbr reg_status, STAT_10MSEC_INC
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
	; blockmask に、なんの設定もない場合は即座にリターン（割り込み前の処理継続）
	cp reg_status, reg_0
	breq _isr_return_done
	; schedule 中の割り込みの場合スケジュールを再度呼び出さず、割り込み前のスケジュール処理を継続
	and reg_status, reg_1
	brne _isr_return_done
	; schedule の外での割り込みの場合で何かしらのステータスが発生しているときは処理をスケジュールに委ねる。
	ldi reg_isr_gpr0, LOW(schedule)
	push reg_isr_gpr0
	ldi reg_isr_gpr0, HIGH(schedule)
	push reg_isr_gpr0
	; schedule 実行中であることを示す
	;（これによって、プログラムカウンタ、スタックポインタなど切り替えている途中でユーザタスクが実行されないようにする）
	; 割り込み処理は走っても良い
	sbr reg_status, STAT_IN_SCHEDULE
_isr_return_done:
	reti
start:
	;スタックの準備
    ldi	r16, RAMEND		; load RAMEND into r16
	out	SPL, r16			; store r16 in stack pointer
	nop
	;定数レジスタの初期化
	ldi r16, 100
	mov reg_100, r16
	ldi r16, 255
	mov reg_255, r16
	clr r16
	mov reg_0, r16 ;always zero
	mov reg_1, reg_0
	inc reg_1
	;制御用レジスタの初期化
	mov reg_375ctr_lo, reg_0 ;reset 10msec counter high
	mov reg_375ctr_hi, reg_0 ;usec 10msec conter low
	mov reg_status, reg_0 ; ステータス

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
/* ソフトウェアタイマ リセット */
/* タイマ０は３バイトのタイマ2560分まで対応できる */
	ldi r27, HIGH(timer0)
	ldi r26, LOW(timer0)
	st X+, reg_0 
	st X+, reg_0
	st X, reg_0
/* タイマ１、タイマ２は２バイトのタイマ１０分程度までしか対応できない */
	ldi r27, HIGH(timer1)
	ldi r26, LOW(timer1)
	st X+, reg_0
	st X, reg_0
	ldi r27, HIGH(timer2)
	ldi r26, LOW(timer2)
	st X+, reg_0
	st X, reg_0
	;rcall led_init

	;タスクスロット0にLEDタスクを作成する
	ldi r27, HIGH(taskslot0)
	ldi r26, LOW(taskslot0)
	;ステータス:stopped BlockMask なし
	st X+, reg_0
	;スタックトップの割り当てこのMCUの場合SPがHIGHバイトを持つことがない。
	ldi r16, LOW(task1mem + 9)
	st X+, r16
	;LEDタスクのプログラムカウンタ
	ldi r16, HIGH(led)
	st X+, r16
	ldi r16, LOW(led)
	st X+, r16
	; r11 = reg_usr_gpr2 = 0
	;st X+, reg_0
	; r12 = reg_usr_gpr3 = 0
	;st X+, reg_0
	; r18 = reg_usr_gpr0 = 0
	;st X+, reg_0
	; r19 = reg_usr_gpr1 = 0
	;st X+, reg_0
	; r28 = YL = reg_usr_gpr4 = 0;
	;st X+, reg_0
	; r29 = YH = reg_usr_gpr5 = 0;
	;st X+, r16
/* idle task */
	sei
idle:
    rjmp idle
schedule:
	;前回のスケジューラが呼ばれたときからの10msec時間を計測する
	;r15 には前回スケジュールが呼ばれたときの10msecカウント、が入っておりr4には現在の10msecカウントが入っている。
	; r21 = r15-r4 で差分を求める
	mov r21, r4
	sub r21, r15
	;if (r4 == r15)の時、時間が経過していないため、タイマ関係の処理はない。タイマ関係の処理を飛ばす。
	breq _timer_mask_ok
	;キャリーが発生していた場合、r4がオーバフローしてリセット（１００でリセットされる）されていたためで、計測時間を正に調整する。
	brcc _diff_ok
	ldi r20, 100
	add r21, r20
_diff_ok:
	;r15 現在の10msec カウントを上書き
	mov r15, r4
	;ソフトウェアタイマ
	ldi r27, HIGH(timer0)
	ldi r26, LOW(timer0)
	ld r16, X+
	ld r17, X
	cp r16, reg_0
	brne _dec_timer0
	cp r17, reg_0
	breq _skip_timer0
_dec_timer0:
	sub r16, reg_1
	sbc r17, reg_0
	cp r16, reg_0
	brne _dec_timer0
	cp r17, reg_0
	breq _skip_timer0
_skip_timer0:
	ldi r29, HIGH(timer0)
	ldi r28, LOW(timer0)

_timer_mask_ok:
	rjmp schedule
sleep_timeout0:
	ldi r29, HIGH(timer0)
	ldi r28, LOW(timer0)
	st x+, r18
	st x, r19
;	cbr r22, STAT_TIM0
	rjmp schedule
led_init:
	ret
led:
	in reg_usr_gpr0, PORTB
	ldi reg_usr_gpr1, 1<<PINB1
	eor reg_usr_gpr0, reg_usr_gpr1
	out PORTB, reg_usr_gpr0
	ldi reg_usr_gpr0, LOW(100)
	ldi reg_usr_gpr1, HIGH(100)
	rcall sleep_timeout0
	rjmp led
/*	clr r16
	ori r16,1<<PINB1*/
;r3:r2 375 (countdown) 374 ~ 0までカウントダウンするため設定する値は374
;r5:r4 10msec counter (count up)
;reg_0 always 0; 
;reg_1 always 1;
;r8 scheduler address (LOW)
;r9 scheduler address (HIGH)
;r10 running task id
;タスクは0 LED 明滅タスク、1演奏タスク、2、入力タスク、3アイドルタスク
;タスク構造体
;
.dseg
taskslot0:
	.byte 10
taskslot1:
	.byte 10
taskslot2:
	.byte 10
task1mem:
	.byte 10
;ソフトウェアタイマ
timer0:
	.byte 3
timer1:
	.byte 2
timer2:
	.byte 2

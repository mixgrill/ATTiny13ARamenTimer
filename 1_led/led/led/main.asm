;
; led.asm
;
; Created: 2021/07/08 0:29:14
; Author : mixgrill
;

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00
.equ TASK1STACK = RAMEND-20
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
	;r2 -- with carry;
	sub r2, r7
	;r3 -= carry
	sbc r3, r6
	;no carry continue
	brcc _isr_tim0_ok
	;set 375 counter 
	mov r2, r14 ;114
	mov r3, r7  ;1 256+ 114 = 374
	;increment 10msec counter
	add r4, r7
	; if (10msec_count >=100){
	;   10msec_count -= 100;
	;	seconds ++
	; } 
	ldi r20, 100
	cp r20, r4
	brne _go_schedule
	sub r4, r20
	add r5, r7
	adc r13, r6
_go_schedule:
	push r8
	push r9
_isr_tim0_ok:
	reti
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

start:
    ldi	r16,RAMEND		; load RAMEND into r16
	out	SPL,r16			; store r16 in stack pointer
	nop
	ldi r16,114
	mov r14,r16
	ldi r16,LOW(schedule)
	mov r8,r16 ;always schedule address
	ldi r16,HIGH(schedule)
	mov r9,r16
	;pin setting PB1を出力用に設定
	clr r16
	mov r5,r16 ;reset 10msec counter high
	mov r4,r16 ;usec 10msec conter low
	mov r6,r16 ;always zero
	mov r7,r16
	mov r15,r16
	inc r7     ;always 1

/* LED カウンタ用の変数の初期化 */
	
	ori r16,1<<DDB1
	out DDRB,r16
	nop
/*	clr r16
	ori r16,1<<PINB1*/
	out PORTB,r16
	nop
	;set 375 counter
	mov r2, r14
	mov r3, r7
/* TCCR0B の設定 */
	ldi r16,TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	ldi r16,1<<TOIE0
	out TIMSK0,r16
	nop
/* ソフトウェアタイマ リセット */
	ldi r27, HIGH(timer0)
	ldi r26, LOW(timer0)
	st X+, r6
	st X, r6
	ldi r27, HIGH(timer1)
	ldi r26, LOW(timer1)
	st X+, r6
	st X, r6
/* idle task */
	ldi r16,3
	mov r10,r16
	ldi r16,LOW(idle)
	push r16
	ldi r16,HIGH(idle)
	push r16
	reti	
idle:
    rjmp idle
schedule:
	;前回のスケジューラが呼ばれたときからの10msec時間を計測する
	mov r21, r4
	sub r21, r15
	brcc _diff_ok
	ldi r20, 100
	add r21, r20
_diff_ok:
	mov r15, r4
	;ソフトウェアタイマ
	ldi r27, HIGH(timer0)
	ldi r26, LOW(timer0)
	ld r16, X+
	ld r17, X
	cp r16, r6
	brne _dec_timer0
	cp r17, r6
	breq _skip_timer0
_dec_timer0:
	sub r16, r7
	sbc r17, r6
	cp r16, r6
	brne _dec_timer0
	cp r17, r6
	breq _skip_timer0
_skip_timr0:
	ldi r29, HIGH(timer0)
	ldi r28, LOW(timer0)


	rjmp schedule
sleep_timeout0:
	ldi r29, HIGH(timer0)
	ldi r28, LOW(timer0)

	ret
led:
	in r18,PORTB
	ldi r19,1<<PINB1
	eor r18,r19
	out PORTB,r19
	ldi r18, LOW(1000)
	ldi r19, HIGH(1000)
	rcall sleep_timeout0
	rjmp led
/*	clr r16
	ori r16,1<<PINB1*/
;r3:r2 375 (countdown) 374 ~ 0までカウントダウンするため設定する値は374
;r5:r4 10msec counter (count up)
;r6 always 0; 
;r7 always 1;
;r8 scheduler address (LOW)
;r9 scheduler address (HIGH)
;r10 running task id
;タスクは0 LED 明滅タスク、1演奏タスク、2、入力タスク、3アイドルタスク
;タスク構造体
;
.dseg
taskslot0:
	.byte 8
taskslot1:
	.byte 8
taskslot2:
	.byte 8
taskslot3:
	.byte 8
;ソフトウェアタイマ
timer0:
	.byte 2
timer1:
	.byte 2

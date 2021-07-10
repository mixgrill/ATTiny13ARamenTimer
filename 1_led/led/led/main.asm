;
; led.asm
;
; Created: 2021/07/08 0:29:14
; Author : mixgrill
;
; 10msec ����萳�m�ɃJ�E���g���邽��375���timeroverflow ���J�E���g���邽�߂̃��W�X�^
.def reg_375ctr_lo = r2
.def reg_375ctr_hi = r3
.def reg_10msec = r4
; �萔���W�X�^�i�g�p�p�x���������̂̓��W�X�^�Ɋ��蓖�Ă���j
.def reg_0 = r5
.def reg_1 = r6
.def reg_100 = r7
.def reg_255 = r8
; �u���b�N�}�X�N���W�X�^
.def reg_status = r21
; ISR�ŗ\��̔ėp���W�X�^
.def reg_isr_gpr0 = r20
.def reg_sch_gpr0 = r16
.def reg_sch_gpr1 = r17
; ���[�U�ŗ\��̔ėp���W�X�^
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
	;375 �J�E���^�̃f�N�������g
	sub reg_375ctr_lo, reg_1
	;���؂�̏���
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
	; blockmask �ɁA�Ȃ�̐ݒ���Ȃ��ꍇ�͑����Ƀ��^�[���i���荞�ݑO�̏����p���j
	cp reg_status, reg_0
	breq _isr_return_done
	; schedule ���̊��荞�݂̏ꍇ�X�P�W���[�����ēx�Ăяo�����A���荞�ݑO�̃X�P�W���[���������p��
	and reg_status, reg_1
	brne _isr_return_done
	; schedule �̊O�ł̊��荞�݂̏ꍇ�ŉ�������̃X�e�[�^�X���������Ă���Ƃ��͏������X�P�W���[���Ɉς˂�B
	ldi reg_isr_gpr0, LOW(schedule)
	push reg_isr_gpr0
	ldi reg_isr_gpr0, HIGH(schedule)
	push reg_isr_gpr0
	; schedule ���s���ł��邱�Ƃ�����
	;�i����ɂ���āA�v���O�����J�E���^�A�X�^�b�N�|�C���^�Ȃǐ؂�ւ��Ă���r���Ń��[�U�^�X�N�����s����Ȃ��悤�ɂ���j
	; ���荞�ݏ����͑����Ă��ǂ�
	sbr reg_status, STAT_IN_SCHEDULE
_isr_return_done:
	reti
start:
	;�X�^�b�N�̏���
    ldi	r16, RAMEND		; load RAMEND into r16
	out	SPL, r16			; store r16 in stack pointer
	nop
	;�萔���W�X�^�̏�����
	ldi r16, 100
	mov reg_100, r16
	ldi r16, 255
	mov reg_255, r16
	clr r16
	mov reg_0, r16 ;always zero
	mov reg_1, reg_0
	inc reg_1
	;����p���W�X�^�̏�����
	mov reg_375ctr_lo, reg_0 ;reset 10msec counter high
	mov reg_375ctr_hi, reg_0 ;usec 10msec conter low
	mov reg_status, reg_0 ; �X�e�[�^�X

	ori r16,1<<DDB1
	out DDRB,r16
	nop
/*	clr r16
	ori r16,1<<PINB1*/
	out PORTB,r16
	nop
    ; TCCR0B �̐ݒ� 
	ldi r16,TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	ldi r16,1<<TOIE0
	out TIMSK0,r16
	nop
/* �\�t�g�E�F�A�^�C�} ���Z�b�g */
/* �^�C�}�O�͂R�o�C�g�̃^�C�}2560���܂őΉ��ł��� */
	ldi r27, HIGH(timer0)
	ldi r26, LOW(timer0)
	st X+, reg_0 
	st X+, reg_0
	st X, reg_0
/* �^�C�}�P�A�^�C�}�Q�͂Q�o�C�g�̃^�C�}�P�O�����x�܂ł����Ή��ł��Ȃ� */
	ldi r27, HIGH(timer1)
	ldi r26, LOW(timer1)
	st X+, reg_0
	st X, reg_0
	ldi r27, HIGH(timer2)
	ldi r26, LOW(timer2)
	st X+, reg_0
	st X, reg_0
	;rcall led_init

	;�^�X�N�X���b�g0��LED�^�X�N���쐬����
	ldi r27, HIGH(taskslot0)
	ldi r26, LOW(taskslot0)
	;�X�e�[�^�X:stopped BlockMask �Ȃ�
	st X+, reg_0
	;�X�^�b�N�g�b�v�̊��蓖�Ă���MCU�̏ꍇSP��HIGH�o�C�g�������Ƃ��Ȃ��B
	ldi r16, LOW(task1mem + 9)
	st X+, r16
	;LED�^�X�N�̃v���O�����J�E���^
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
	;�O��̃X�P�W���[�����Ă΂ꂽ�Ƃ������10msec���Ԃ��v������
	;r15 �ɂ͑O��X�P�W���[�����Ă΂ꂽ�Ƃ���10msec�J�E���g�A�������Ă���r4�ɂ͌��݂�10msec�J�E���g�������Ă���B
	; r21 = r15-r4 �ō��������߂�
	mov r21, r4
	sub r21, r15
	;if (r4 == r15)�̎��A���Ԃ��o�߂��Ă��Ȃ����߁A�^�C�}�֌W�̏����͂Ȃ��B�^�C�}�֌W�̏������΂��B
	breq _timer_mask_ok
	;�L�����[���������Ă����ꍇ�Ar4���I�[�o�t���[���ă��Z�b�g�i�P�O�O�Ń��Z�b�g�����j����Ă������߂ŁA�v�����Ԃ𐳂ɒ�������B
	brcc _diff_ok
	ldi r20, 100
	add r21, r20
_diff_ok:
	;r15 ���݂�10msec �J�E���g���㏑��
	mov r15, r4
	;�\�t�g�E�F�A�^�C�}
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
;r3:r2 375 (countdown) 374 ~ 0�܂ŃJ�E���g�_�E�����邽�ߐݒ肷��l��374
;r5:r4 10msec counter (count up)
;reg_0 always 0; 
;reg_1 always 1;
;r8 scheduler address (LOW)
;r9 scheduler address (HIGH)
;r10 running task id
;�^�X�N��0 LED ���Ń^�X�N�A1���t�^�X�N�A2�A���̓^�X�N�A3�A�C�h���^�X�N
;�^�X�N�\����
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
;�\�t�g�E�F�A�^�C�}
timer0:
	.byte 3
timer1:
	.byte 2
timer2:
	.byte 2

;
; input.asm
;
; Created: 2021/07/31 10:17:40
; Author : mixgrill
;
; 10msec ����萳�m�ɃJ�E���g���邽��375���timeroverflow ���J�E���g���邽�߂̃��W�X�^
.def reg_375ctr_lo = r2
.def reg_375ctr_hi = r3
.def reg_10msec = r4
; �萔���W�X�^�i�g�p�p�x���������̂̓��W�X�^�Ɋ��蓖�Ă���j
.def reg_0 = r5
.def reg_1 = r6
; SREG�̑ޔ�̈�
.def reg_sreg_evac = r7
; ���ݑ����Ă���^�X�NID
.def reg_running_task_id = r8
; ���K�����p���W�X�^
.def reg_add = r9
.def reg_sub = r10
.def reg_remain = r0	
; ISR�ŗ\��̔ėp���W�X�^
.def reg_isr_gpr0 = r20
.def reg_isr_gpr1 = r22
; �X�P�W���[���ŗ\��̔ėp���W�X�^
.def reg_tsw_gpr0 = r16
.def reg_tsw_gpr1 = r17

#define reg_tsw_gpr4 XL
#define reg_tsw_gpr5 XH
; ���[�U�ŗ\��̔ėp���W�X�^
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
.equ OFFSET_STACK = 1 ;PC��STACK�̈�ԏ�ɂ��������Ă���̂ŕۑ����Ȃ��B
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
; PIN�ݒ�
; �{�^��PIN �{�^����PowerDown����̕�������K�v�������邱�Ƃ���INT0���蓖�ĕK�{
.equ DDB_BUTTON = DDB1
.equ PORTB_BUTTON = PORTB1
.equ PINB_BUTTON = PINB1
; LED �� PB2 �Ɋ��蓖��
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
	;SPEAKER �̐M���𔽓]
	ldi reg_isr_gpr1, 1<<PINB_SPK_0
	eor reg_isr_gpr0, reg_isr_gpr1
	;SPEAKER�̔��]�M������������ON�ɂ���
	ori reg_isr_gpr0, 1<<PINB_SPK_1
	;SPEAKER�r�b�g��OFF�̎�SPEAKER�̔��]��ON�̂܂܁ASPEAKER�r�b�g��ON�̎�SPEAKER�̔��]��OFF
	sbrc reg_isr_gpr0, PINB_SPK_0
	cbr reg_isr_gpr0, 1<<PINB_SPK_1
_spk_ok:
	out PORTB, reg_isr_gpr0
	nop
_no_toggle_waveform:
	clt
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
	; �^�X�N�X�C�b�`���Ɋ��荞�݂����������ꍇ�A�^�X�N�X�C�b�`���p������B
	sbrc reg_system_flags, SYSFLG_IN_TASKSWITCH
	rjmp _isr_return_done
	; 10msec �̋��E�ł͂Ȃ��Ȃ�A�������p������B
	brtc _isr_return_done
	; 10msec �̋��E�I�^�X�N�X�C�b�`���s���B
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
	;�N������ɃA�C�h�����[�h�̃W�����p���V���[�g���Ă��邩�ǂ����𒲂ׂ�
	clr r16
	; �S�s����ǂݍ��݂ɐݒ�
	out DDRB, r16
	nop
	; IDLE�W�����p�s���̃v���A�b�v��R��L����
	ori r16, 1 << PORTB_IDLE_JMP
	out PORTB, r16
	nop
	; �����A�V���[�g���Ă���΁APin��Hi-Z�ɖ߂���idle��Ԃɗ�����B
	sbis PORTB, PORTB_IDLE_JMP
	rjmp go_idle
	;�萔���W�X�^�̏�����
	clr r16
	mov reg_0, r16 ;always zero
	mov reg_1, reg_0
	inc reg_1
	;����p���W�X�^�̏�����
	ldi r16, 114
	mov reg_375ctr_lo, r16 ;114
	mov reg_375ctr_hi, reg_1  ;1 256+ 114 = 374
	mov reg_system_flags, reg_0 ; �V�X�e���t���O
	mov reg_remain, reg_0
	mov reg_add, reg_0
	mov reg_sub, reg_0
	mov reg_sreg_evac, reg_0
	;�o�̓s���̐ݒ�
	; LED, SPK+ ,SPK-���o�̓s���ɐݒ�A����ȊO�̃s���͓��͂ɐݒ�
	ldi r16, (1<<DDB_LED) | (1<<DDB_SPK_0) | (1<<DDB_SPK_1)
	out DDRB, r16
	nop
	; �{�^����Pull-Up��L���� Idle �W�����p��Hi-Z�ɕύX
	ldi r16, (1<<PORTB_BUTTON)
	out PORTB, r16
	nop
    ; TCCR0B �̐ݒ� 
	ldi r16, TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	; �^�C�}���荞�݂̗L����
	ldi r16, 1<<TOIE0
	out TIMSK0,r16
	nop
	; �O�������݂̗L�����i�{�^�������j
	; �G�b�W�̐ݒ� ������i�{�^�������j�Ŋ��荞�ݔ���
	ldi r16, (1<<ISC01) | (1<<ISC00)
	out MCUCR, r16
	nop
	; GIMSK�̐ݒ� INT0���荞�݂̗L����
	ldi r16, (1<<INT0)
	out GIMSK, r16
	nop
	;�^�X�N�X���b�g������
	clr r17
	ldi XL, LOW(taskslot0)
	ldi r16, SIZE_TASK_SLOT * 3
	rcall fillx
	
	;�^�X�N�X���b�g1�̃v���O�����J�E���^��main�ɐݒ肷��
	clr XH
	ldi XL, LOW(task1stack + SIZE_USER_STACK - 2)
	ldi r16, HIGH(main)
	st x+, r16
	ldi r16, LOW(main)
	st x+, r16
	;�^�X�N�X���b�g�P�̃X�^�b�N�̒l���v���O�����J�E���^��ݒ肵���ʒu�ɒ���
	ldi r16, LOW(task1stack + SIZE_USER_STACK - 3)
	ldi XL, LOW(taskslot1 + OFFSET_STACK)
	st x+, r16
	;�^�X�N�X���b�g2�̃v���O�����J�E���^��idle�ɐݒ肷��
	clr XH
	ldi XL, LOW(task2stack + SIZE_USER_STACK - 2)
	ldi r16, HIGH(idle)
	st x+, r16
	ldi r16, LOW(idle)
	st x+, r16
	;�^�X�N�X���b�g2�̃X�^�b�N�̒l���v���O�����J�E���^��ݒ肵���ʒu�ɒ���
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
	;SREG �i�[
	st x+, reg_sreg_evac
	;STACK�i�[
	in reg_tsw_gpr0, SPL
	st x+, reg_tsw_gpr0
	;���[�U�^�X�N���蓖�Ẵ��W�X�^�̊i�[
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
	;SREG �̕���
	ld reg_sreg_evac, x+
	;�X�^�b�N�̕���
	ld reg_tsw_gpr0, x+
	cli
	out SPL, reg_tsw_gpr0
	nop
	sei
	;���[�U�^�X�N���蓖�Ẵ��W�X�^�̕���
	ld r11, x+
	ld r12, x+
	ld r18, x+
	ld r19, x+
	ld r28, x+
	ld r29, x+
	; �^�X�N�X�C�b�`�t���O�̏I��
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
;;; �֐��� fillx
;;; ���� 
;;;    XH:XL ���߂�A�h���X
;;;    R16 ���߂�o�C�g��
;;;    R17 ���߂�o�C�g
;;; ����p
;;;    XH:XL �����߂镶����������
;;;    R16 �j��
;;; �X�^�b�N�g�p
;;;    �Ȃ�
fillx:
	cp r16, reg_0
	breq _fillx_done
	st X+, r17
	dec r16
	rjmp fillx
_fillx_done:
	ret
;;;;
;;; �֐��� calc_diff_10msec
;;; ���� 
;;;    r11 �O��� 10msec
;;; ����p
;;;    r18 �ɍ����i�[
;;;    r11 ���݂�10msec �ɏ����ς��
;;; �g�p�X�^�b�N
;;;    �Ȃ�
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
;;; �֐��� n10msec_sleep
;;; ���� 
;;;    r19 count down start �l 127 �ȉ� 0 �ȏ�
;;; ����p
;;;    r19 ���ۂɖ��������Ԃ����������ԁi�}�C�i�X�ɂ͂Ȃ肤��)
;;;    r18 �j��
;;;    r11 ���݂�10msec �ɏ����ς��
;;; �g�p�X�^�b�N
;;;    �Ȃ�
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
;�\�t�g�E�F�A�^�C�}
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
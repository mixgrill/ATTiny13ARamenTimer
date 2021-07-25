;
; sound.asm
;
; Created: 2021/07/18 22:56:47
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
.equ SYSFLG_SOUND_RESTART_REQ = 5
.equ SYSFLG_MSK_MELODY = (1<<SYSFLG_MELODY1) | (1<<SYSFLG_MELODY0)
.equ MELODY_NONE = (0<<SYSFLG_MELODY1)|(0<<SYSFLG_MELODY0)
.equ MELODY_FANFARE = (0<<SYSFLG_MELODY1)|(1<<SYSFLG_MELODY0)

.equ TIMER_CLOCK_NO_PRESCALE = 0 << CS02 | 0<< CS01 | 1 << CS00

.equ STACK_SIZE_USER = 8
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
	;SPEAKER �̐M���𔽓]
	;ldi reg_isr_gpr1, 1<<PINB0
	;eor reg_isr_gpr0, reg_isr_gpr1
	;��R�[�h�ł�����������Ƃ����R�[�h�ߖ�
	eor reg_isr_gpr0, reg_1
	;SPEAKER�̔��]�M������������ON�ɂ���
	sbr reg_isr_gpr0, 1<<PINB4
	;SPEAKER�r�b�g��OFF�̎�SPEAKER�̔��]��ON�̂܂܁ASPEAKER�r�b�g��ON�̎�SPEAKER�̔��]��OFF
	sbrc reg_isr_gpr0, 0
	cbr reg_isr_gpr0, 1<<PINB4
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
	;PIN3 �� HIGH�̎������������[�v������B
	;�iPowerdown�Ƃ����ăv���O���~���O�o���Ȃ��Ȃ����猙������A���J�o���̂��߁j
	in r16, PINB
	nop
	andi r16, 1<<PINB3
	brne start

	ldi r16, LOW(task0stack + STACK_SIZE_USER - 1)
	out SPL, r16
	nop
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
	ldi r16, 213
	mov reg_add, r16
	ldi r16,  5
	mov reg_sub, r16

	clr reg_sreg_evac ;SREG�ޔ�̈�
	clr r16
	; PB4=SPEAKER�̔��]�M�� | PB1 LED | PB0=SPEAKER�ւ̐M��
	ori r16,(1<<DDB4) | (1<<DDB1) | (1<<DDB0)
	out DDRB,r16
	nop
	ldi r16,1<<PB1
	out PORTB,r16
	nop
    ; TCCR0B �̐ݒ� 
	ldi r16,TIMER_CLOCK_NO_PRESCALE 
	out TCCR0B,r16
	nop
	ldi r16,1<<TOIE0
	out TIMSK0,r16
	nop

	;�^�X�N�X���b�g������
	ldi XL, LOW(taskslot0)
	ldi r16, 20
	rcall fillx
/*	�^�X�N�X���b�g0�͏������s�v�i����^�X�N�X�C�b�`���ɂǂ݂̂��v���U�[�u����邩�� 
    ;�^�X�N�X���b�g0���̃X�^�b�N�̐ݒ�
	clr XH
	ldi XL, LOW(taskslot0 + OFFSET_STACK)
	ldi r16, LOW(task0stack + STACK_SIZE_USER - 1)
	st x+, r16
	;�^�X�N�X���b�g0����PC�̐ݒ�
	ldi r16, HIGH(led)
	st x+, r16
	ldi r16, LOW(led)
	st x+, r16*/
	;�^�X�N�X���b�g1���̃X�^�b�N�̐ݒ�
	;��ɃX�^�b�N�̒��Ƀ��^�[���A�h���X��˂�����ł���
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

led:
	;r11 �� �O���10msec�l��ێ�����̂Ɏg��
	clr r11
	;r19 ��sleep ����10msec ��ێ�����̂Ɏg��
	clr r19
led_loop:
	; 50 �~���b LED �����点��
	ldi r18, 5
	add r19, r18
	in r18, PORTB
	sbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	; 950 �~���b LED ����������
	ldi r18, 95
	add r19, r18
	in r18, PORTB
	cbr r18, 1<<PINB1
	out PORTB, r18
	nop
	rcall n10msec_sleep
	
	rjmp led_loop
sound:
	;r11 �� �O���10msec�l��ێ�����̂Ɏg��
	mov r11, reg_10msec
	;�����f�B���擾
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
	;r18�́A���݂�EEPADR�������Ă��邽�߈ꎞ�ޔ�
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
;r3:r2 375 (countdown) 374 ~ 0�܂ŃJ�E���g�_�E�����邽�ߐݒ肷��l��374
;r5:r4 10msec counter (count up)
;reg_0 always 0; 
;reg_1 always 1;
;r8 kernelr address (LOW)
;r9 kernelr address (HIGH)
;r10 running task id
;�^�X�N��0 LED ���Ń^�X�N�A1���t�^�X�N�A2�A���̓^�X�N�A3�A�C�h���^�X�N
;�^�X�N�\����
;
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
;;; �֐��� eep_read012
;;; ���� 
;;;    r18 �ǂݏo��EEPROM�A�h���X
;;; ����p
;;;    eep_in_buff ? 0 �̓��e��ǂ݂������l�ŏ���������
;;;    eep_in_buff ? 1 �̓��e��ǂ݂������l�ŏ���������
;;;    eep_in_buff ? 2 �̓��e��ǂ݂������l�ŏ���������
;;;    r18 �� 3���Z�����
;;;    r19 ���Ō�ɓǂ݂������l
;;;    YH,YL �j��
;;; �g�p�X�^�b�N
;;;    �Ȃ�

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
	.byte 8
taskslot1:
	.byte 8
;�\�t�g�E�F�A�^�C�}
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
	;�`���������y��
	;��(A4,49) 440Hz ���Z�l213 ���Z�l5 250m�b
	.db 213,10,25
	;�V(B4,51) 493.883Hz ���Z�l228 ���Z�l6 250m�b
	.db 228,12,25
	;�h#(C#5,53) 554.365 Hz	1�b
	.db 203,12,100
	;�V(B4,51) 493.883Hz ���Z�l228 ���Z�l6 250m�b
	.db 228,12,25
	;��(A4,49) 440Hz ���Z�l213 ���Z�l5 250m�b
	.db 213,10,25
	;�x��	1�b
	.db 0,0,100
	;��(A4,49) 440Hz ���Z�l213 ���Z�l5 250m�b
	.db 213,10,25
	;�V(B4,51) 493.883Hz ���Z�l228 ���Z�l6 250m�b
	.db 228,12,25
	;�h#(C#5,53) 554.365 Hz	250�b
	.db 203,12,25
	;�V(B4,51) 493.883Hz ���Z�l228 ���Z�l6 250m�b
	.db 228,12,25
	;��(A4,49) 440Hz ���Z�l213 ���Z�l5 250m�b
	.db 213,10,25
	;�V(B4,51) 493.883Hz ���Z�l228 ���Z�l6 1�b
	.db 228,12,100
	;�x��	1.27�b
	.db 0,0,100
	;�x��	1.27�b
	.db 0,0,100
	;�ԕ�
	.db 0,0,0

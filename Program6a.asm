TITLE Program #6a     (Program6a.asm)

; Author: Dan Negovan
; Last Modified: 12/5/18
; OSU email address: negovand@oregonstate.edu
; Course number/section: CS271/400	
; Project Number: 6a                Due Date: 12/8/19
; Description:	The program will get 10 valid integers from the user 
;and store the numeric values into an array. The program will then 
;display the list of integers, their sum, and the average value of the list.
;Program implements macros getString and displayString to get input from 
;the user, and display output.
;Implements ReadVal and WriteVal, which convert strings to decimal values,
; and decimal numbers back to strings, respecitvely
  

INCLUDE Irvine32.inc

STR_SIZE = 100
ARRAY_SIZE = 10
ASCII_0 = 48
ASCII_9 = 57

;----------------------------------------------------------
; MACRO: displays the string located at the provided buffer
; needs to be fed an OFFSET to work
;----------------------------------------------------------
displayString	MACRO	buffer
	push	edx					;Save edx register
	mov		edx, buffer
	call	WriteString
	pop		edx					;Restore edx
ENDM

;----------------------------------------------------------
; MACRO: Reads from standard input into a buffer.
; Receives: OFFSET of prompt to display, and the OFFSET 
; where the user's input will be stored
;----------------------------------------------------------
getString	MACRO	display, inputLoc
	displayString	display		;call displayString macro to show prompt
	push	ecx
	push	edx
	mov		edx, inputLoc 
	mov		ecx, STR_SIZE
	call	ReadString
	pop		edx
	pop		ecx
ENDM



.data
	intro_1			BYTE	"Demonstrating low-level I/O Procedures",0
	intro_2			BYTE	"Programmed by Dan Negovan",0
	intro_3			BYTE	"Please provide 10 decimal integers.",0
	intro_4			BYTE	"Each number needs to be small enough to fit inside a 32 bit register.",0
	intro_5			BYTE	"After you have finished inputting the raw numbers I will display",
							" a list of the integers, their sum, and their average value.",0
	prompt			BYTE	"Please enter an integer number: ",0  	
	numArray		DWORD	ARRAY_SIZE DUP(0)		;to hold entered values
	tempString		BYTE	STR_SIZE DUP(?)
	title_entered	BYTE	"You entered the following numbers:",0
	comma			BYTE	", ",0
	title_sum		BYTE	"The sum of these numbers is: ",0
	title_avg		BYTE	"The average is: ",0
	sum				DWORD	?
	avg				DWORD	?
	error			BYTE	"ERROR: You did not enter an integer number or your number was too big.",0
	bye				BYTE	"Thank you! Goodbye.",0


.code
main PROC
	call	Intro
				
	mov		edi, OFFSET numArray		;fill array with nums using ReadVal		
	mov		ecx, LENGTHOF numArray		;set up fill array loop
fillArray:		
	push	edi							;3 vars on stack for ReadVal
	push	OFFSET prompt
	push	OFFSET tempString
	call	ReadVal	
	add		edi, TYPE numArray			;increment array position
	loop	fillArray					
	
	push	OFFSET avg					;calculate the avg, sum 
	push	OFFSET sum
	push	OFFSET numArray
	call	CalcStats

	call	CrLf
	displayString OFFSET title_entered	;display contents of array
	call	CrLf
	mov		esi, OFFSET numArray		
	mov		ecx, ARRAY_SIZE
displayArray:	
	push	esi							;2 vars on stack for WriteVal
	push	OFFSET tempString
	call	WriteVal
	cmp		ecx, 1						;don't put a comma after last #
	je		afterComma
	displayString	OFFSET comma
afterComma:
	add		esi, TYPE numArray
	loop	displayArray

	call	CrLf
	displayString	OFFSET title_sum	;display stats
	push	OFFSET	sum
	push	OFFSET	tempString
	call	WriteVal
	call	CrLf
	displayString	OFFSET title_avg
	push	OFFSET	avg
	push	OFFSET	tempString
	call	WriteVal
	call	CrLf

	call	Goodbye
	exit	;exit to operating system
main ENDP


;-------------------------------------------------------
;Procedure to introduce the program.
;receives: none
;returns: none
;preconditions:  none
;registers changed: none
;-------------------------------------------------------
Intro	PROC
	displayString	OFFSET intro_1				;Display intro
	call	Crlf
	displayString	OFFSET intro_2
	call	Crlf
	call	Crlf
	displayString	OFFSET intro_3				;Display program instructions
	call	Crlf
	displayString	OFFSET intro_4
	call	Crlf
	displayString	OFFSET intro_5
	call	Crlf
	call	Crlf

	ret
Intro	ENDP


;---------------------------------------------------------
;Procedure to prompt user for a number, receive and validate
;input, convert entered string to decimal value and store
;in provided memory address
;receives:  address of parameters on system stack - a DWORD
;			memory location to store converted value, a
;			prompt's string offset, and an offset to hold the 
;			user-entered string 
;returns: value the user entered in provided location
;preconditions:  none
;registers changed: none
;---------------------------------------------------------
localVar EQU DWORD PTR [ebp-4]			

ReadVal PROC	
	push	ebp							;set up stack frame
	mov		ebp,esp
	sub		esp, 4						;create local variable
	pushad								;save registers

	mov		edi, [ebp+16]				;@ to store int
promptUser:			
	getString [ebp+12],[ebp+8] 			;get string from user													
	mov		esi, [ebp+8]				;address of userString
	add		esi, eax					;points to the 0 byte
	sub		esi, 1						;points to end of string
	mov		ecx, eax					;set up string loop counter
	mov		localVar, 1					;set up power of 10 multiplier

	std									;move backwards through string
stringLoop:	
	mov		eax, 0						;clear eax so al value will be zero extended
	lodsb
	cmp		al, ASCII_0					;validate
	jl		badInput
	cmp		al, ASCII_9
	jg		badInput
	sub		al, ASCII_0					;convert ascii to its digit
	mul		localVar					;multiply digit by power of 10
	add		[edi], eax					;add to current in-progress value
	jc		badInput					;number is too big if carry flag gets set
	mov		eax, localVar				;multiplier x10 for next loop
	mov		ebx, 10
	mul		ebx
	mov		localVar, eax
	loop	stringLoop		
	
	jmp		stringFinished
badInput:
	displayString OFFSET error
	call	CrLf
	jmp		promptUser

stringFinished:
	popad								;restore registers
	mov		esp, ebp					;remove local variable from stack
	pop		ebp							;restore stack
	ret		12
ReadVal ENDP





;---------------------------------------------------------
;Procedure to calculate sum & avg of an array of DWORD ints
;receives: array address on the stack, and two DWORDS by
; reference, also on the stack, to store results
;returns: sum and avg, stored in provided stack variables
;preconditions:  none
;registers changed: none
;---------------------------------------------------------
CalcStats PROC	
	push	ebp							;set up stack frame
	mov		ebp,esp
	pushad								;save registers

	mov		esi, [ebp+8]				;@ of array			
	mov		eax, 0						;blank slate for sum
	mov		ecx, ARRAY_SIZE				;loop counter
sumLoop:	
	mov		ebx, [esi]
	add		eax, ebx
	add		esi, 4	
	loop	sumLoop

	mov		ebx,[ebp+12]
	mov		[ebx], eax					;store sum
	mov		ebx, ARRAY_SIZE				;calc avg
	mov		edx, 0
	div		ebx
	mov		ebx, [ebp+16]
	mov		[ebx], eax					;store avg

	popad								;restore registers
	pop		ebp							;restore stack
	ret		12
CalcStats ENDP




;---------------------------------------------------------
;Procedure to convert numeric values to strings for display
;receives: address of parameters on system stack - the 
;			value to convert and a string offset to store
;			the converted value
;returns: displays provided string after converting from int
;preconditions:  none
;registers changed: none
;---------------------------------------------------------
WriteVal PROC	
	push	ebp							;set up stack frame
	mov		ebp,esp
	pushad								;save registers
	
	mov		edi, [ebp+8]				;to store converted string
	add		edi, STR_SIZE-1				;start from the end
	std									;move backwards 
	mov		al, 0
	stosb								;null terminator for string
	mov		ebx, [ebp+12]				;@ of # to be converted
	mov		eax, [ebx]					;# to be converted

convertLoop:				
	mov		ebx, 10
	mov		edx, 0
	div		ebx
	mov		ebx, eax					;save div result
	add		edx, ASCII_0				;convert remainder to char
	mov		al, dl
	stosb								;store in string
	mov		eax, ebx					;set up next step
	cmp		eax, 0
	je		stringRdy
	jmp		convertLoop

stringRdy:
	inc		edi							;undo final auto-increment to get to beginning of str
	displayString edi
	popad								;restore registers
	pop		ebp							;restore stack
	ret		8
WriteVal ENDP



;-------------------------------------------------------
;Procedure to say goodbye
;receives: none
;returns: none
;preconditions:  none
;registers changed: edx
;-------------------------------------------------------
Goodbye PROC
	call	CrLf
	call	CrLf
	mov		edx, OFFSET bye
	call	WriteString
	call	CrLf
	
	ret
Goodbye ENDP

END main

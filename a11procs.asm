; *****************************************************************
;  Name: Scott T. Koss
;  NSHE_ID: 1013095342
;  Section: 1002
;  Assignment: 11
;  Description: Do all of the things to the images


; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

section	.data

; -----
;  Define standard constants.

LF			equ	10			; line feed
NULL		equ	0			; end of string
SPACE		equ	0x20			; space

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	0			; Successful operation
NOSUCCESS	equ	1			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; system call code for read
SYS_write	equ	1			; system call code for write
SYS_open	equ	2			; system call code for file open
SYS_close	equ	3			; system call code for file close
SYS_fork	equ	57			; system call code for fork
SYS_exit	equ	60			; system call code for terminate
SYS_creat	equ	85			; system call code for file open/create
SYS_time	equ	201			; system call code for get time

O_CREAT		equ	0x40
O_TRUNC		equ	0x200
O_APPEND	equ	0x400

O_RDONLY	equ	000000q			; file permission - read only
O_WRONLY	equ	000001q			; file permission - write only
O_RDWR		equ	000002q			; file permission - read and write

S_IRUSR		equ	00400q
S_IWUSR		equ	00200q
S_IXUSR		equ	00100q

; -----
;  Define program specific constants.

GRAYSCALE	equ	0
BRIGHTEN	equ	1
DARKEN		equ	2

MIN_FILE_LEN	equ	5
BUFF_SIZE	equ	1000000		; buffer size

; -----
;  Local variables for getArguments() function.

eof				db	FALSE

usageMsg		db	"Usage: ./imageCvt <-gr|-br|-dk> <inputFile.bmp> "
				db	"<outputFile.bmp>", LF, NULL
errIncomplete	db	"Error, incomplete command line arguments.", LF, NULL
errExtra		db	"Error, too many command line arguments.", LF, NULL
errOption		db	"Error, invalid image processing option.", LF, NULL
errReadName		db	"Error, invalid source file name.  Must be '.bmp' file.", LF, NULL
errWriteName	db	"Error, invalid output file name.  Must be '.bmp' file.", LF, NULL
errReadFile		db	"Error, unable to open input file.", LF, NULL
errWriteFile	db	"Error, unable to open output file.", LF, NULL

; -----
;  Local variables for processHeaders() function.

HEADER_SIZE	equ	54

errReadHdr	db	"Error, unable to read header from source image file."
			db	LF, NULL
errFileType	db	"Error, invalid file signature.", LF, NULL
errDepth	db	"Error, unsupported color depth.  Must be 24-bit color."
			db	LF, NULL
errCompType	db	"Error, only non-compressed images are supported."
			db	LF, NULL
errSize		db	"Error, bitmap block size inconsistent.", LF, NULL
errWriteHdr	db	"Error, unable to write header to output image file.", LF,
			db	"Program terminated.", LF, NULL

; -----
;  Local variables for getRow() function.

buffMax		dq	BUFF_SIZE
curr		dq	BUFF_SIZE
wasEOF		db	FALSE
pixelCount	dq	0

errRead		db	"Error, reading from source image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for writeRow() function.

errWrite	db	"Error, writting to output image file.", LF,
			db	"Program terminated.", LF, NULL


; Local Variables to store  header information

; -----
;  2 -> BM				(+0)
;  4 file size			(+2)
;  4 skip				(+6)
;  4 header size		(+10)
;  4 skip				(+14)
;  4 width				(+18)
;  4 height				(+22)
;  2 skip				(+26)
;  2 depth (16/24/32)			(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data		(+34)
;  skip remaing header entries

Bm 		dw 0 ; BM
FileS 	dd 0 ; File Size
hdsz 	dd 0 ; header size
ofst    dw 0 ; offset
Wdth	dd 0 ; Width
Hght 	dd 0 ; Height
Plns    dw 0 ; planes
Dpth 	dw 0 ; Depth
Cmprs 	dd 0 ; Compression
PxDt	dd 0 ; Pixel Data
currIdx dd 0 ;
divTwo  dw 2 ; for div 2 mul 2


; ------------------------------------------------------------------------
;  Unitialized data

section	.bss

localBuffer	resb	BUFF_SIZE
header		resb	HEADER_SIZE


; ############################################################################

section	.text

; ***************************************************************
;  Routine to get arguments.
;	Check image conversion options
;	Verify files by atemptting to open the files (to make
;	sure they are valid and available).

;  NOTE:
;	ENUM vaiables are 32-bits.

;  Command Line format:
;	./imageCvt <-gr|-br|-dk> <inputFileName> <outputFileName>

; -----
;  Arguments:
;	argc (value) 		- rdi
;	argv table (address)  - esi
;	image option variable, ENUM type, (address) - rdx
;	read file descriptor (address) - rcx
;	write file descriptor (address) - r8
;  Returns:
;	TRUE or FALSE

global getArguments
getArguments:
	push r12
	push r13
	push r14

	mov r12, rsi
	mov r13, rcx
	mov r14, r8

	; Check # args

	cmp rdi, 1
	je errUsageMessage

	cmp rdi, 4
	jl errIncompleteMessage

	cmp rdi, 4
	jne errExtraMessage

	; ====================== ;

	mov rbx, qword[r12+8]

	mov al, byte[rbx]
	cmp al, '-'
	jne errUsageMessage

	mov al, byte[rbx+1]
	cmp al, 'g'
	je foundG
	cmp al, 'b'
	je foundB
	cmp al, 'd'
	je foundD
	jmp errOptionMessage

	foundG:
		mov al, byte[rbx+2]
		cmp al, 'r'
		je foundGR
		jmp errOptionMessage

	foundB:
		mov al, byte[rbx+2]
		cmp al, 'r'
		je foundBR
		jmp errOptionMessage

	foundD:
		mov al, byte[rbx+2]
		cmp al, 'k'
		je foundDK
		jmp errOptionMessage

	foundGR:
		mov al, byte[rbx+3]
		cmp al, NULL
		jne errOptionMessage
		mov r9, GRAYSCALE
		mov qword[rdx], r9
		jmp enumDone

	foundBR:
		mov al, byte[rbx+3]
		cmp al, NULL
		jne errOptionMessage
		mov r9, BRIGHTEN
		mov qword[rdx], r9
		jmp enumDone

	foundDK:
		mov al, byte[rbx+3]
		cmp al, NULL
		jne errOptionMessage
		mov r9, DARKEN
		mov qword[rdx], r9
		jmp enumDone


	enumDone:

		mov rbx, qword[r12+16]
		mov r10, 0

	checkFileName:

		mov al, byte[rbx+r10]
		cmp al, '.'
		je fileCheck
		cmp al, NULL
		je errReadNameMessage
		inc r10
		jmp checkFileName

		fileCheck:
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'b'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'm'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'p'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, NULL
		jne errReadNameMessage
		

		mov rax, SYS_open
		mov rdi, rbx
		mov rsi, O_RDONLY
		syscall
		
		cmp rax, 0
		jl errReadFileMessage

		mov qword[r13], rax

		mov rbx, qword[r12+24]
		mov r10, 0

		checkFileNameW:
		mov al, byte[rbx+r10]
		cmp al, '.'
		je fileCheck2
		cmp al, NULL
		je errWriteNameMessage
		inc r10
		jmp checkFileNameW

		fileCheck2:
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'b'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'm'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, 'p'
		jne errReadNameMessage
		inc r10
		mov al, byte[rbx+r10]
		cmp al, NULL
		jne errWriteNameMessage

		mov rax, SYS_creat
		mov rdi, rbx
		mov rsi, S_IRUSR | S_IWUSR
		syscall
		
		cmp rax, 0
		jl errWriteFileMessage

		mov qword[r14], rax

	jmp argComplete

;==============================================================================
;======================= Error Handling =======================================
;==============================================================================

	errUsageMessage:
		mov rdi, usageMsg
		jmp printError

	errIncompleteMessage:
		mov rdi, errIncomplete
		jmp printError

	errExtraMessage:
		mov rdi, errExtra
		jmp printError

	errOptionMessage:
		mov rdi, errOption
		jmp printError

	errReadNameMessage:
		mov rdi, errReadName
		jmp printError

	errWriteNameMessage:
		mov rdi, errWriteName
		jmp printError

	errReadFileMessage:
		mov rdi, errReadFile
		jmp printError

	errWriteFileMessage:
		mov rdi, errWriteFile
		jmp printError

	errReadMessage:
		mov rdi, errRead
		jmp printError

	errWriteMessage:
		mov rdi, errWrite
		jmp printError


	printError:
		call printString
		mov rax, FALSE
		jmp errorfin
	
	argComplete:
		mov rax, TRUE
	errorfin:

	pop r14
	pop r13
	pop r12
ret
;	YOUR CODE GOES HERE



; ***************************************************************
;  Read and verify header information
;	status = processHeaders(readFileDesc, writeFileDesc,
;				fileSize, picWidth, picHeight)

; -----
;  2 -> BM				(+0)
;  4 file size			(+2)
;  4 skip				(+6)
;  4 header size		(+10)
;  4 skip				(+14)
;  4 width				(+18)
;  4 height				(+22)
;  2 skip				(+26)
;  2 depth (16/24/32)			(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data		(+34)
;  skip remaing header entries

; -----
;   Arguments:
;	read file descriptor (value)
;	write file descriptor (value)
;	file size (address)
;	image width (address)
;	image height (address)

;  Returns:
;	file size (via reference)
;	image width (via reference)
;	image height (via reference)
;	TRUE or FALSE


;	YOUR CODE GOES HERE

global processHeaders
processHeaders:
	push r12
	push r13
	push r14
	push r15
	push rbx

	mov r12, rdi	; Stores the file desc
	mov r13, rsi	; Stores the write desc
	mov r14, rdx	; stores file size add
	mov r15, rcx	; store img width add
	mov rbx, r8		; stores img height add

	mov rax, SYS_read
	mov rdi, r12
	mov rsi, header
	mov rdx, 54
	syscall

	cmp rax, 0
	jl errReadHdrMessage

	mov ax, word[header]   ; Reads 0 - 2
	cmp ax, 0x4d42
	jne errFileTypeMessage
	mov word [Bm], ax

	mov eax, dword[header+10] ; Reads 6 - 10
	mov dword [hdsz], eax

	mov eax, dword[header+2] ; Reads 2 - 6
	sub eax, dword[hdsz]
	mov dword [FileS], eax

	;skip 4

	
	mov eax, dword[header+14] ; Reads 10 - 14
	mov dword [ofst], eax
	
	mov eax, dword[header+18] ; reads 14 - 18
	mov dword [Wdth], eax

	mov eax, dword[header+22]	  ; header 22 - 24
	mov dword [Hght], eax

	mov ax, word[header+26]
	mov word [Plns], ax
	
	mov ax, word[header+28]   ; reads 28 - 30
	cmp ax, 24
	jne errDepthMessage
	mov word [Dpth], ax
	
	mov eax, dword[header+30]
	cmp eax, 0
	jne errCompTypeMessage
	mov dword [Cmprs], eax
	
	mov eax, dword[header+34]
	mov dword [PxDt], eax

	cmp eax, dword[FileS]
	jne errSizeMessage

	mov eax, dword[FileS]
	mov dword[r14], eax

	mov eax, dword[Wdth]
	mov dword[r15], eax

	mov eax, dword[Hght]
	mov dword[rbx], eax

	mov rax, SYS_write
	mov rdi, r13
	mov rsi, header
	mov rdx, HEADER_SIZE
	syscall

	cmp rax, 0
	jl errWriteHdrMessage

	jmp headerDone

	
	
	;Error Handling Header

	errReadHdrMessage:
		mov rdi, errReadHdr
		jmp printError2

	errWriteHdrMessage:
		mov rdi, errWriteHdr
		jmp printError2

	errFileTypeMessage:
		mov rdi, errFileType
		jmp printError2

	errDepthMessage:
		mov rdi, errDepth
		jmp printError2

	errCompTypeMessage:
		mov rdi, errCompType
		jmp printError2

	errSizeMessage:
		mov rdi, errSize
		jmp printError2

	printError2:
		call printString
		mov rax, FALSE
		jmp errTwoDone

	headerDone:
		mov rax, TRUE

	errTwoDone:

	pop rbx
	pop r15
	pop r14
	pop r13
	pop r12

ret



; ***************************************************************
;  Return a row from read buffer
;	This routine performs all buffer management

; ----
;  HLL Call:
;	status = getRow(readFileDesc, picWidth, rowBuffer);

;   Arguments:
;	read file descriptor (value) - rdi
;	image width (value) - rsi
;	row buffer (address) - rdx
;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been returned
;	and returns FALSE only if there is an
;	error on read (which would not normally occur)
;	or the end of file.

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.


;	YOUR CODE GOES HERE

global getRow
getRow:

; Store registers for use
push r15
push r14
push r13
push r12
push rbx

mov r15, rdi ;file desc
mov r13, rsi ;image width
mov r12, rdx ;row buffer
mov r14, 0 ; i
mov rbx, qword[curr]


		mov rax, r13
		mov r9, 3
		mul r9
		mov qword[pixelCount], rax

	getByte:

		; (RBX = 1,000,000 >= buffMax == 1,000,001) -> False
		; if Curr >= BuffMax CURR < Buffmax
		mov rbx, qword[curr]
		cmp rbx, qword[buffMax]      ; buff MAx
		jb stopGoinBB		  		; curr index >= buffMAX

			; if EOF == TRUE
			mov al, byte[wasEOF]
			cmp al, TRUE
			je isEndofReadingthedamnfilehomie 
			
			; IF Read ERROR
			mov rax, SYS_read 
			mov rdi, r15
			mov rsi, localBuffer
			mov rdx, BUFF_SIZE
			syscall

			; Error Checking from Read File
			cmp rax, 0
			jl errReadMessageR

			;if (actual Rd < requestRd)	
			cmp rax, BUFF_SIZE
			jb setEOF
			jmp newlabel

				setEOF:
					mov r10b, TRUE
					mov byte[wasEOF], r10b
					mov qword[buffMax], rax

	newlabel:
		mov r10, 0
		mov qword[curr], r10 

;mov r15, rdi ;file desc
;mov r13, rsi ;image width
;mov r12, rdx ;row buffer
;mov r14, 0 ; i
;mov rbx, qword[curr]

	stopGoinBB:
		 mov rbx, qword[curr]

			mov rax, 0
		; chr = buffer[curridx]
		  	mov al, byte[localBuffer+rbx]
		; curridx++
			inc rbx
			mov qword[curr], rbx
		; rowBuffer[i] = chr
			mov byte[r12+r14], al
		; i++
			inc r14 
		; is i < pixCnt
			cmp r14, qword[pixelCount]
			jb getByte

	doneReading:
	mov rax, TRUE
	mov qword[curr], rbx
	jmp fin

	isEndofReadingthedamnfilehomie:
	mov rax, FALSE
	jmp fin

;Error Handling;

	errReadMessageR:
		mov rdi, errRead
		jmp printError3

	printError3:
		call printString
		mov rax, FALSE

;fin
fin:

pop rbx
pop r12
pop r13
pop r14
pop r15
ret



; ***************************************************************
;  Write image row to output file.
;	Writes exactly (width*3) bytes to file.
;	No requirement to buffer here.

; -----
;  HLL Call:
;	status = writeRow(writeFileDesc, pciWidth, rowBuffer);

;  Arguments are:
;	write file descriptor (value) rdi
;	image width (value) rsi
;	row buffer (address) rdx

;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been written
;	and returns FALSE only if there is an
;	error on write (which would not normally occur).

;	Yes

global writeRow
writeRow:

	push r12
	push r13
	push r14

	mov r12, rdi ; file desc
	mov r13, rsi ; img wid
	mov r14, rdx ; row buff

	mov r10, 3
	mov rax, r13
	mul r10
	mov rdx, rax

	mov rax, SYS_write
	mov rdi, r12
	mov rsi, r14 
	;
	syscall

	cmp rax, 0
	jl errWriteMessageW
	jmp endW
;Error Handling;

	errWriteMessageW:
		mov rdi, errWrite
		jmp printError4

	printError4:
		call printString
		mov rax, FALSE
		jmp endE

	endW:
	mov rax, TRUE
	endE:
	pop r14
	pop r13
	pop r12
ret

; ***************************************************************
;  Convert pixels to grayscale.

; -----
;  HLL Call:
;	status = imageCvtToBW(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)


;	my code goes here

global imageCvtToBW
imageCvtToBW:
 ; byte = oldred + oldgreen + oldblue / 3

	push r12 ; pic width
	push r13 ; address
	push r14 ; This is to hold 3

	mov r12, rdi
	mov r13, rsi

	mov rax, r12 ; width to rax
	mov r9, 3    ; width x 3
	mul r9       ; width x 3
	mov r10, rax ; move to r10 for loop

	mov r9, 0    ; r9 = i
	mov r14, 3   ; r14 = 3 for division

	bwLoop:
		mov edx, 0
		mov rax, 0
		movzx ax, byte[rsi+r9]
		movzx bx, [rsi+r9+1]			;add ax at spot 0
		add ax, bx        				;add ax at spot 1
		movzx bx, [rsi+r9+2]
		add ax, bx       				;add ax at spot 2

		div r14w						;div 3

		mov [rsi+r9], al			
		mov [rsi+r9+1], al
		mov [rsi+r9+2], al
		inc r9
		inc r9
		inc r9

		cmp r9, r10
		jb bwLoop

	pop r14
	pop r13
	pop r12
ret



; ***************************************************************
;  Update pixels to increase brightness

; -----
;  HLL Call:
;	status = imageBrighten(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)


;	YOUR CODE GOES HERE

global imageBrighten
imageBrighten:

push r12
push r13

	mov r12, rdi ; Image width
	mov r13, rsi ; Row Buffer Address

	; newBrightValue = (oldColorValue / 2) + oldColorValue

	mov rax, r12		; mov width to rax
	mov r9, 3           ; width x 3
	mul r9				; width x 3
	mov r10, rax		; r10 = count stop

	mov r9, 0  			; i
	; r10 = # of its

	brightLoop:
	mov eax, 0			; eax 0 for maff
	mov edx, 0			; edx 0 for div
	mov ebx, 0			; ebx 0 because we can

	movzx ax, byte[rsi+r9]  ; mov value into ax
	div word[divTwo]		; div val by 2

	movzx bx, byte[rsi+r9]		; mov old value into bx for addition
	add ax, bx			; add old value(bx) to dividend(ax)

	cmp ax, 255			; cmp to 255 to check
	jg setaxBright		; if its greater then 255 jump down
	jmp nextBright		; not greater then, go to end
	
	setaxBright:
	mov ax, 255			; set ax to 255 if its greater
	nextBright:

	mov byte[rsi+r9], al
	inc r9
	cmp r9, r10
	jb  brightLoop

pop r13
pop r12


ret



; ***************************************************************
;  Update pixels to darken (decrease brightness)

; -----
;  HLL Call:
;	status = imageDarken(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)


;	YOUR CODE GOES HERE

global imageDarken
imageDarken:

	;newDarkenedValue = oldColorValue / 2
	push r12
	push r13

	mov r12, rdi ; img width
	mov r13, rsi ; row buffer

		mov rax, 0 ; mov rax to 0 for mul
		mov rax, r12 ; mov width to rax
		mov r9, 3  ; set reg for mul
		mul r9 ; mul rax
		mov r10, rax ; mov width X 3 to r10 for counter
		mov r9, 0 ; i
	
	darkLoop:

		mov rax, 0 ; set rax for div/mul
		mov edx, 0 ; set edx (althoughwe really don't care

		movzx ax, byte[r13+r9] ; set byte into ax reg
		div word[divTwo]       ; div by 2
		mov byte[r13+r9], al   ; move the divid back to the byte
		inc r9                 ; increase r10
		cmp r9, r10             ; i < widthx3 do jmp to dark loop
		jl darkLoop
	
	pop r13
	pop r12

ret


; ******************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.

;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	- address, string
;  Returns:
;	nothing

global	printString
printString:
	push	rbx

; -----
;  Count characters in string.

	mov	rbx, rdi			; str addr
	mov	rdx, 0
strCountLoop:
	cmp	byte [rbx], NULL
	je	strCountDone
	inc	rbx
	inc	rdx
	jmp	strCountLoop
strCountDone:

	cmp	rdx, 0
	je	prtDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write			; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
						; EDX=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

prtDone:
	pop	rbx
	ret

; ******************************************************************


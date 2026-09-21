; Atari 800XL Assembly Source File
; Main program file (split into main_p0..p4 for GitHub MCP upload size limits;
; MADS concatenates via icl -- identical object to the former monolithic main.asm)
	icl 'main_p0.asm'
	icl 'main_p1.asm'
	icl 'main_p2.asm'
	icl 'main_p3.asm'
	icl 'main_p4.asm'

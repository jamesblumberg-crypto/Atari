	org monsters_b_colors

	; ribbon 0 (floor 1) - 3 bytes, bit k of byte g = yellow-flag of ribbon char 8g+k
	.byte %00000000
	.byte %00000100
	.byte %11001100

	; ribbon 1 (floor 2) - 3 bytes, bit k of byte g = yellow-flag of ribbon char 8g+k
	.byte %11001100
	.byte %11110000
	.byte %10000111

	; ribbon 2 (floor 3) - 3 bytes, bit k of byte g = yellow-flag of ribbon char 8g+k
	.byte %10000111
	.byte %11001000
	.byte %11110000

	; ribbon 3 (floor 4) - 3 bytes, bit k of byte g = yellow-flag of ribbon char 8g+k
	.byte %11110000
	.byte %11110000
	.byte %11110000


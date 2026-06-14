.global _start

.section .data
.align 8
filename:
    .ascii "../data/records.csv\0"

.align 8
prompt:
    .ascii "Loaded 10 records. Enter search query: "
    prompt_len = . - prompt

.align 8
header:
    .ascii "\nMatching Records:\n--------------------------------------------------\n"
    header_len = . - header

.align 8
footer_start:
    .ascii "--------------------------------------------------\nFound "
    footer_start_len = . - footer_start

.align 8
footer_end:
    .ascii " match(es).\n"
    footer_end_len = . - footer_end

.align 8
comma:
    .byte ','
.align 8
newline:
    .byte '\n'
quote:
    .ascii " - \""
middle_sep:
    .ascii "\" ("
end_sep:
    .ascii ") ["
bracket_close:
    .ascii "]\n"

.section .bss
    .lcomm file_buffer, 8192     # 8KB buffer for loading file
    .lcomm query_buffer, 256     # 256B for storing user search query
    .lcomm matches_str, 32       # Buffer to convert match count to string
    .lcomm out_num_buf, 32       # Temp buffer for printing digits

.section .text
_start:
    # 1. Open File: open(filename, O_RDONLY)
    movq $2, %rax                # sys_open
    movq $filename, %rdi         # pointer to filename
    movq $0, %rsi                # O_RDONLY
    movq $0, %rdx                # mode
    syscall
    
    cmpq $0, %rax
    jl exit_err                  # If file descriptor < 0, error
    movq %rax, %r12              # Save file descriptor in r12

    # 2. Read File: read(fd, file_buffer, 8192)
    movq $0, %rax                # sys_read
    movq %r12, %rdi              # fd
    movq $file_buffer, %rsi      # buffer
    movq $8192, %rdx             # length
    syscall
    movq %rax, %r13              # Save actual bytes read in r13


    # Close File: close(fd)
    movq $3, %rax                # sys_close
    movq %r12, %rdi
    syscall

    # 3. Print Prompt: write(1, prompt, prompt_len)
    movq $1, %rax
    movq $1, %rdi
    movq $prompt, %rsi
    movq $prompt_len, %rdx
    syscall

    # 4. Read Query from Stdin: read(0, query_buffer, 256)
    movq $0, %rax
    movq $0, %rdi
    movq $query_buffer, %rsi
    movq $256, %rdx
    syscall
    
    # Strip newline from query
    decq %rax
    movb $0, query_buffer(,%rax,1)
    movq %rax, %r14              # Save query length in r14

    # 5. Print Header: write(1, header, header_len)
    movq $1, %rax
    movq $1, %rdi
    movq $header, %rsi
    movq $header_len, %rdx
    syscall

    # 6. Parse and Search loop
    # Register Layout:
    # rbx: pointer to current position in file_buffer
    # r15: match counter (initial 0)
    # r8: pointer to start of current line
    # r9: pointer to start of current field
    
    movq $file_buffer, %rbx
    movq $0, %r15
    movq $0, %r10                # Skip header flag (0 = header, 1 = body)

find_lines:
    # Calculate bytes processed
    movq %rbx, %rax
    subq $file_buffer, %rax
    cmpq %r13, %rax              # Check EOF
    jge print_footer

    # Skip blank or newline boundaries
    cmpb $10, (%rbx)
    je skip_char
    cmpb $13, (%rbx)
    je skip_char

    # Start of line
    movq %rbx, %r8
    
    # Find end of line
    movq %rbx, %rcx
find_eol:
    movq %rcx, %rax
    subq $file_buffer, %rax
    cmpq %r13, %rax
    jge found_eol
    cmpb $10, (%rcx)
    je found_eol
    incq %rcx
    jmp find_eol
found_eol:
    # Now %rcx points to EOL or EOF
    # Save EOL char, set to null-terminator for string operations
    movb (%rcx), %dh
    movb $0, (%rcx)

    # If header, skip processing
    cmpq $0, %r10
    jne process_line
    movq $1, %r10
    movq %rcx, %rbx
    incq %rbx
    jmp find_lines

process_line:
    # Parse CSV fields dynamically (Artist, Title, Year, Genre)
    # We locate field boundaries by replacing commas with 0
    # Then we run case-insensitive substring matches against Artist, Title, and Genre fields
    
    # Track fields
    movq %r8, %rsi               # field 1: Artist
    
    # Find first comma
    movq %r8, %rdi
find_c1:
    cmpb $0, (%rdi)
    je next_line                 # Line ends prematurely; skip processing
    cmpb $44, (%rdi)             # ','
    je found_c1
    incq %rdi
    jmp find_c1
found_c1:
    movb $0, (%rdi)
    movq %rdi, %rax
    incq %rax
    movq %rax, %r11              # field 2: Title

    # Find second comma
    movq %r11, %rdi
find_c2:
    cmpb $0, (%rdi)
    je next_line                 # Line ends prematurely; skip
    cmpb $44, (%rdi)
    je found_c2
    incq %rdi
    jmp find_c2
found_c2:
    movb $0, (%rdi)
    movq %rdi, %rax
    incq %rax
    movq %rax, %r9               # field 3: Year

    # Find third comma
    movq %r9, %rdi
find_c3:
    cmpb $0, (%rdi)
    je next_line                 # Line ends prematurely; skip
    cmpb $44, (%rdi)
    je found_c3
    incq %rdi
    jmp find_c3
found_c3:
    movb $0, (%rdi)
    movq %rdi, %rax
    incq %rax
    movq %rax, %r12              # field 4: Genre


    # ── Match Search ──
    # Check Artist (field 1)
    movq %r8, %rdi
    call match_substring
    cmpq $1, %rax
    je do_print_record

    # Check Title (field 2)
    movq %r11, %rdi
    call match_substring
    cmpq $1, %rax
    je do_print_record

    # Check Genre (field 4)
    movq %r12, %rdi
    call match_substring
    cmpq $1, %rax
    je do_print_record

    jmp next_line

do_print_record:
    # Print: Artist - "Title" (Year) [Genre]
    incq %r15                    # Increment match counter

    # Artist
    movq %r8, %rdi
    call print_str
    
    # " - \""
    movq $quote, %rsi
    movq $4, %rdx
    call write_out

    # Title
    movq %r11, %rdi
    call print_str

    # "\" ("
    movq $middle_sep, %rsi
    movq $4, %rdx
    call write_out

    # Year
    movq %r9, %rdi
    call print_str

    # ") ["
    movq $end_sep, %rsi
    movq $4, %rdx
    call write_out

    # Genre
    movq %r12, %rdi
    call print_str

    # "]\n"
    movq $bracket_close, %rsi
    movq $2, %rdx
    call write_out


next_line:
    # Restore the EOL character
    movb %dh, (%rcx)
    movq %rcx, %rbx
    incq %rbx
    movq $1, %r10                # Keep body parse state
    jmp find_lines


skip_char:
    incq %rbx
    jmp find_lines

# Substring Case-Insensitive Match Helper
# Args: %rdi = String to check, %r14 = Query Length
# Returns: %rax = 1 (match), 0 (no match)
match_substring:
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi

    movq %rdi, %rsi              # %rsi: string pointer
    movq $0, %rax                # default failure

    # If query length is 0, return match
    cmpq $0, %r14
    je match_found

    # Length checks
    movq %rsi, %rdi
    call strlen
    cmpq %r14, %rax
    jl match_failed              # If string length < query length, no match
    movq %rax, %rcx              # %rcx: string length

    # Loop string offsets
    movq $0, %rbx                # %rbx: offset index
match_outer:
    movq %rcx, %rdx
    subq %rbx, %rdx
    cmpq %r14, %rdx
    jl match_failed              # remaining chars too short

    # Inner match loop
    movq $0, %rdi                # inner offset
match_inner:
    cmpq %r14, %rdi
    je match_found

    # Get string char
    movq %rbx, %rax
    addq %rdi, %rax
    movzbq (%rsi,%rax,1), %rdx
    
    # Get query char
    movzbq query_buffer(,%rdi,1), %rax

    # Convert both to lowercase to compare
    cmpq $65, %rdx
    jl check_q_lower
    cmpq $90, %rdx
    jg check_q_lower
    addq $32, %rdx               # string char to lower
check_q_lower:
    cmpq $65, %rax
    jl compare_chars
    cmpq $90, %rax
    jg compare_chars
    addq $32, %rax               # query char to lower

compare_chars:
    cmpq %rdx, %rax
    jne match_next_outer
    incq %rdi
    jmp match_inner

match_next_outer:
    incq %rbx
    jmp match_outer

match_found:
    movq $1, %rax
    jmp match_done

match_failed:
    movq $0, %rax

match_done:
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    ret

print_footer:
    # Print footer divider
    movq $1, %rax
    movq $1, %rdi
    movq $footer_start, %rsi
    movq $footer_start_len, %rdx
    syscall

    # Print match count as string
    movq %r15, %rax
    call print_int

    # Print footer end
    movq $1, %rax
    movq $1, %rdi
    movq $footer_end, %rsi
    movq $footer_end_len, %rdx
    syscall

    jmp exit_ok

exit_err:
    movq $60, %rax
    movq $1, %rdi
    syscall

exit_ok:
    movq $60, %rax
    movq $0, %rdi
    syscall

# Utilities
write_out:
    movq $1, %rax
    movq $1, %rdi
    syscall
    ret

print_str:
    pushq %rsi
    pushq %rdx
    pushq %rcx
    pushq %rdi
    movq %rdi, %rsi
    call strlen
    movq %rax, %rdx
    movq $1, %rax
    movq $1, %rdi
    syscall
    popq %rdi
    popq %rcx
    popq %rdx
    popq %rsi
    ret


strlen:
    movq $0, %rax
strlen_loop:
    cmpb $0, (%rdi,%rax,1)
    je strlen_done
    incq %rax
    jmp strlen_loop
strlen_done:
    ret

print_int:
    pushq %rbx
    pushq %rcx
    pushq %rdx
    movq $out_num_buf, %rcx
    addq $30, %rcx               # start filling from the end
    movb $0, (%rcx)              # null-terminator
    movq $10, %rbx
print_int_loop:
    movq $0, %rdx
    divq %rbx                    # divide rax by 10, remainder in rdx
    addb $48, %dl                # convert remainder to ascii
    decq %rcx
    movb %dl, (%rcx)
    testq %rax, %rax
    jnz print_int_loop
    
    # write out the formatted number
    movq %rcx, %rdi
    call print_str
    
    popq %rdx
    popq %rcx
    popq %rbx
    ret

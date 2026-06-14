.global main

# External C/C++ SQLite DB helper symbols
.extern init_db_schema
.extern query_records_sqlite

.section .data
.align 8
server_start_msg:
    .ascii "Assembly SQLite API Server running on port 8080...\n"
    server_start_msg_len = . - server_start_msg

.align 8
http_header:
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\nContent-Length: "
    http_header_len = . - http_header

.align 8
http_header_end:
    .ascii "\r\n\r\n"
    http_header_end_len = . - http_header_end

.align 8
q_param_str:
    .ascii "?q=\0"

.align 8
opt_val:
    .long 1

# Socket address struct for port 8080 (INADDR_ANY)
.align 8
sockaddr_in:
    .word 2                     # sin_family = AF_INET (2 bytes)
    .word 0x901f                # sin_port = 8080 (0x1f90 big-endian -> 0x901f little-endian, 2 bytes)
    .long 0                     # sin_addr = INADDR_ANY (4 bytes)
    .quad 0                     # zero pad (8 bytes)

.section .bss
    .lcomm client_buffer, 2048   # 2KB buffer for incoming HTTP request
    .lcomm json_body, 16384      # 16KB buffer for building JSON database output
    .lcomm header_buffer, 512    # 512B for formatting Content-Length header
    .lcomm query_string, 128     # 128B for storing extracted query

.section .text
main:
    # ── Phase 1: Initialize Database ──
    subq $8, %rsp
    call init_db_schema          # Creates and seeds database music.db if empty
    addq $8, %rsp

    # ── Phase 2: Server Socket Setup ──
    # 1. Create Socket: socket(AF_INET (2), SOCK_STREAM (1), 0)
    movq $41, %rax               # sys_socket
    movq $2, %rdi                # AF_INET
    movq $1, %rsi                # SOCK_STREAM
    movq $0, %rdx
    syscall
    
    cmpq $0, %rax
    jl server_init_fail
    movq %rax, %r12              # r12 = server socket file descriptor

    # Setsockopt (SO_REUSEADDR) to prevent address lockouts
    movq $54, %rax               # sys_setsockopt
    movq %r12, %rdi              # fd
    movq $1, %rsi                # SOL_SOCKET
    movq $2, %rdx                # SO_REUSEADDR
    movq $opt_val, %r10
    movq $4, %r8
    syscall

    # 2. Bind Socket: bind(server_fd, &sockaddr_in, 16)
    movq $49, %rax               # sys_bind
    movq %r12, %rdi
    movq $sockaddr_in, %rsi
    movq $16, %rdx
    syscall
    
    cmpq $0, %rax
    jl server_init_fail

    # 3. Listen: listen(server_fd, 10)
    movq $50, %rax               # sys_listen
    movq %r12, %rdi
    movq $10, %rsi
    syscall
    
    cmpq $0, %rax
    jl server_init_fail

    # Print start message to console
    movq $1, %rax
    movq $1, %rdi
    movq $server_start_msg, %rsi
    movq $server_start_msg_len, %rdx
    syscall

# ── Phase 3: Event Loop ──
accept_loop:
    # Accept connection: accept(server_fd, NULL, NULL)
    movq $43, %rax               # sys_accept
    movq %r12, %rdi
    movq $0, %rsi
    movq $0, %rdx
    syscall
    
    cmpq $0, %rax
    jl accept_loop
    movq %rax, %r13              # r13 = client socket file descriptor

    # Read request: read(client_fd, client_buffer, 2047)
    movq $0, %rax                # sys_read
    movq %r13, %rdi
    movq $client_buffer, %rsi
    movq $2047, %rdx
    syscall

    # Null terminate request buffer
    movb $0, client_buffer(%rax)

    # ── Parse HTTP GET Route ──
    # Scan for "?q=" inside request buffer
    movq $client_buffer, %rdi
    movq $q_param_str, %rsi
    call strstr_asm
    
    cmpq $0, %rax
    je no_query_param

    # Extract query param value (offset query pointer past "?q=")
    addq $3, %rax
    movq %rax, %rsi              # rsi = source start pointer
    movq $query_string, %rdi     # rdi = destination buffer
    
extract_query_loop:
    movb (%rsi), %cl
    cmpb $32, %cl                # Space character triggers end of path string
    je query_extracted
    cmpb $0, %cl
    je query_extracted

    # Mitigate Buffer Overflow: limit query string length to 127 bytes
    movq %rdi, %rax
    subq $query_string, %rax
    cmpq $127, %rax
    jge query_extracted

    movb %cl, (%rdi)
    incq %rsi
    incq %rdi
    jmp extract_query_loop
    
query_extracted:
    movb $0, (%rdi)              # Null terminate query string
    jmp start_response_build

no_query_param:
    movb $0, query_string        # Set query to empty string

start_response_build:
    # ── Query DB via C++ DB helper ──
    # query_records_sqlite(query_string, json_body)
    movq $query_string, %rdi
    movq $json_body, %rsi
    subq $8, %rsp
    call query_records_sqlite
    addq $8, %rsp
    
    movq %rax, %r14              # r14 = length of json_body response

    # ── Send HTTP Response ──
    # 1. Send http_header prefix
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # client fd
    movq $http_header, %rsi
    movq $http_header_len, %rdx
    syscall

    # 2. Format content-length to ascii
    movq %r14, %rdi              # content length
    movq $header_buffer, %rsi    # buffer to write string
    call int_to_ascii_asm
    movq %rax, %rdx              # returned string length

    # Write Content-Length string to socket
    movq $1, %rax                # sys_write
    movq %r13, %rdi
    movq $header_buffer, %rsi
    syscall

    # 3. Write "\r\n\r\n" header footer
    movq $1, %rax                # sys_write
    movq %r13, %rdi
    movq $http_header_end, %rsi
    movq $http_header_end_len, %rdx
    syscall

    # 4. Write json_body payload
    movq $1, %rax                # sys_write
    movq %r13, %rdi
    movq $json_body, %rsi
    movq %r14, %rdx              # json length
    syscall

    # 5. Close client connection
    movq $3, %rax                # sys_close
    movq %r13, %rdi
    syscall
    jmp accept_loop

server_init_fail:
    movq $60, %rax               # sys_exit
    movq $1, %rdi
    syscall

# ── Helper Assembly Routines ──

# Custom strstr assembly helper
strstr_asm:
    pushq %rbp
    movq %rsp, %rbp
strstr_outer:
    movb (%rdi), %al
    cmpb $0, %al
    je strstr_not_found
    
    movq %rdi, %r8               # r8 = current text pointer
    movq %rsi, %r9               # r9 = current pattern pointer
strstr_inner:
    movb (%r9), %cl
    cmpb $0, %cl
    je strstr_found              # reached end of pattern -> match!
    movb (%r8), %dl
    cmpb %cl, %dl
    jne strstr_next
    incq %r8
    incq %r9
    jmp strstr_inner
strstr_next:
    incq %rdi
    jmp strstr_outer
strstr_found:
    movq %rdi, %rax              # return pointer to start of match
    popq %rbp
    ret
strstr_not_found:
    xorq %rax, %rax              # return NULL
    popq %rbp
    ret

# Converts integer in rdi into string in rsi, returns length in rax
int_to_ascii_asm:
    movq %rdi, %rax
    movq $10, %rcx
    pushq $0                     # Null terminator for stack string
    movq %rsp, %r8               # r8 points to end of string on stack
int_to_ascii_loop:
    xorq %rdx, %rdx
    divq %rcx                    # rax = val / 10, rdx = val % 10
    addq $48, %rdx               # convert to ASCII digit
    decq %rsp
    movb %dl, (%rsp)
    cmpq $0, %rax
    jne int_to_ascii_loop
    
    # Copy string from stack to destination buffer
    movq %rsi, %rdi
    movq %rsp, %rsi
    movq %rdi, %r11              # Save original dest pointer
copy_ascii_loop:
    movb (%rsi), %al
    cmpb $0, %al
    je copy_ascii_done
    movb %al, (%rdi)
    incq %rsi
    incq %rdi
    jmp copy_ascii_loop
copy_ascii_done:
    # Cleanup stack
    movq %r8, %rsp
    popq %rax                    # remove dummy Null marker
    
    # Calculate length (rdi - dest_start)
    movq %rdi, %rax
    subq %r11, %rax              # rax = actual string length
    ret

.global main

# External C/C++ parser symbols
.extern parse_csv_line_c
.extern match_record_c

.section .data
.align 8
filename:
    .ascii "../../data/records.csv\0"

.align 8
api_key_str:
    .ascii "X-API-Key: secure123\0"

.align 8
unauth_header:
    .ascii "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\nContent-Length: 24\r\n\r\n\0"

.align 8
unauth_body:
    .ascii "{\"error\":\"Unauthorized\"}\0"

.align 8
server_start_msg:
    .ascii "Assembly API Server running on port 8080...\n"
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
json_empty_array:
    .ascii "[]"

.align 8
json_item_template:
    # Format: {"artist":"%s","title":"%s","year":"%s","genre":"%s"}
    .ascii "{\"artist\":\""
    # then artist string
    # then "\",\"title\":\""
    # then title string
    # etc...

# Socket address struct for port 8080 (INADDR_ANY)
# struct sockaddr_in { sin_family = AF_INET (2), sin_port = 8080 (0x1f90 in network byte order), sin_addr = 0 }
.align 8
sockaddr_in:
    .word 2                     # sin_family = AF_INET (2 bytes)
    .word 0x901f                # sin_port = 8080 (0x1f90 big-endian -> 0x901f little-endian, 2 bytes)
    .long 0                     # sin_addr = INADDR_ANY (0.0.0.0, 4 bytes)
    .quad 0                     # zero pad (8 bytes)

.section .bss
    .lcomm file_buffer, 8192     # 8KB buffer for storing loaded CSV file
    .lcomm client_buffer, 2048   # 2KB buffer for incoming HTTP request
    .lcomm json_body, 4096       # 4KB buffer for building JSON output array
    .lcomm header_buffer, 512    # 512B for formatting Content-Length header
    .lcomm query_string, 128     # 128B for storing extracted query

    # Structured Records array (Static limits: 50 records max)
    # Each record is 336 bytes (128 + 128 + 16 + 64)
    .lcomm records_artist, 6400  # 128 bytes * 50
    .lcomm records_title, 6400   # 128 bytes * 50
    .lcomm records_year, 800     # 16 bytes * 50
    .lcomm records_genre, 3200   # 64 bytes * 50

    .lcomm record_count, 8       # store count of loaded records
    .lcomm temp_artist, 128      # scratch buffers for CSV tokenizer
    .lcomm temp_title, 128
    .lcomm temp_year, 16
    .lcomm temp_genre, 64
    .lcomm json_ptr, 8           # current position pointer in json_body
    .lcomm skip_header_flag, 8   # flag for skipping headers (0 = header, 1 = body)

.section .text
main:
    # ── Phase 1: Load CSV Records into memory using parser_helper C++ ──
    # Open file
    movq $2, %rax                # sys_open
    movq $filename, %rdi
    movq $0, %rsi                # O_RDONLY
    movq $0, %rdx
    syscall
    
    cmpq $0, %rax
    jl server_init_fail
    movq %rax, %r12              # r12 = file descriptor

    # Read file content
    movq $0, %rax                # sys_read
    movq %r12, %rdi
    movq $file_buffer, %rsi
    movq $8192, %rdx
    syscall
    movq %rax, %r13              # r13 = total file bytes

    # Close file
    movq $3, %rax                # sys_close
    movq %r12, %rdi
    syscall

    # Loop file lines and parse using parse_csv_line_c
    movq $file_buffer, %rbx      # rbx = current position in buffer
    movq $0, %r14                # r14 = parsed record counter
    movq $0, skip_header_flag    # Skip header flag (0 = header, 1 = body)

parse_loop:
    movq %rbx, %rax
    subq $file_buffer, %rax
    cmpq %r13, %rax
    jge init_server_socket

    cmpb $10, (%rbx)             # Skip blank/newlines
    je next_char
    cmpb $13, (%rbx)
    je next_char

    # Start of line
    movq %rbx, %r8               # r8 = line pointer
find_eol_char:
    movq %rbx, %rax
    subq $file_buffer, %rax
    cmpq %r13, %rax
    jge parse_line
    cmpb $10, (%rbx)
    je parse_line
    incq %rbx
    jmp find_eol_char

parse_line:
    movb $0, (%rbx)              # Null-terminate current line
    incq %rbx                    # Advance rbx to start of next line
    
    # If header, skip tokenization
    movq skip_header_flag, %rax
    cmpq $0, %rax
    jne do_tokenize
    movq $1, skip_header_flag
    jmp parse_loop

do_tokenize:
    # Set up C++ arguments for parse_csv_line_c(line, artist, title, year, genre)
    movq %r8, %rdi               # 1st arg: line pointer
    movq $temp_artist, %rsi      # 2nd arg: artist buffer
    movq $temp_title, %rdx       # 3rd arg: title buffer
    movq $temp_year, %rcx        # 4th arg: year buffer
    movq $temp_genre, %r8        # 5th arg: genre buffer
    subq $8, %rsp
    call parse_csv_line_c
    addq $8, %rsp
    
    cmpq $0, %rax
    je parse_loop                # If parsing failed, skip to next line

    # Save to records array
    # Target index = r14 * 128, etc.
    movq %r14, %rax
    shlq $7, %rax                # rax = r14 * 128 (Artist/Title offset)
    
    # Copy Artist
    movq $temp_artist, %rsi
    leaq records_artist(%rax), %rdi
    call strcpy_asm

    # Copy Title
    movq $temp_title, %rsi
    leaq records_title(%rax), %rdi
    call strcpy_asm

    # Copy Year (r14 * 16)
    movq %r14, %rax
    shlq $4, %rax                # rax = r14 * 16
    movq $temp_year, %rsi
    leaq records_year(%rax), %rdi
    call strcpy_asm

    # Copy Genre (r14 * 64)
    movq %r14, %rax
    shlq $6, %rax                # rax = r14 * 64
    movq $temp_genre, %rsi
    leaq records_genre(%rax), %rdi
    call strcpy_asm

    incq %r14                    # increment count
    cmpq $50, %r14
    jge init_server_socket       # Static ceiling safety check
    jmp parse_loop

next_char:
    incq %rbx
    jmp parse_loop

# ── Phase 2: Server Socket Setup ──
init_server_socket:
    movq %r14, record_count

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

    # ── Verify API Key ──
    movq $client_buffer, %rdi
    movq $api_key_str, %rsi
    call strstr_asm
    cmpq $0, %rax
    jne auth_success

    # Auth Failed: Send 401 Unauthorized Header
    movq $unauth_header, %rdi
    call strlen_asm
    movq %rax, %rdx              # length
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # client fd
    movq $unauth_header, %rsi
    syscall

    # Send 401 Unauthorized Body
    movq $unauth_body, %rdi
    call strlen_asm
    movq %rax, %rdx              # length
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # client fd
    movq $unauth_body, %rsi
    syscall

    # Close Client connection descriptor: close(client_fd)
    movq $3, %rax                # sys_close
    movq %r13, %rdi
    syscall
    jmp accept_loop

auth_success:
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
    # ── Build JSON response payload ──
    movq $json_body, %rax        # rax = current position pointer in json_body
    movb $91, (%rax)             # Write '[' opening bracket
    incq %rax
    movq %rax, json_ptr
    
    movq $0, %rbx                # rbx = current record iterator index
    movq $0, %r15                # r15 = matches counter

records_search_loop:
    cmpq record_count, %rbx
    jge finalize_json

    # Prep comparison checks
    movq %rbx, %rax
    shlq $7, %rax                # offset = index * 128
    
    # 1. Compare query against Artist
    leaq records_artist(%rax), %rdi
    movq $query_string, %rsi
    subq $8, %rsp
    call match_record_c
    addq $8, %rsp
    cmpq $1, %rax
    je record_matched

    # 2. Compare query against Title
    movq %rbx, %rax
    shlq $7, %rax
    leaq records_title(%rax), %rdi
    movq $query_string, %rsi
    subq $8, %rsp
    call match_record_c
    addq $8, %rsp
    cmpq $1, %rax
    je record_matched

    # 3. Compare query against Genre (index * 64)
    movq %rbx, %rax
    shlq $6, %rax
    leaq records_genre(%rax), %rdi
    movq $query_string, %rsi
    subq $8, %rsp
    call match_record_c
    addq $8, %rsp
    cmpq $1, %rax
    je record_matched

    jmp step_record_loop

record_matched:
    movq json_ptr, %r10          # Restore JSON write pointer
    # Append comma separator if not first item
    cmpq $0, %r15
    je skip_comma
    movb $44, (%r10)             # ','
    incq %r10
skip_comma:
    incq %r15

    # Build entry properties: {"artist":"...","title":"...","year":"...","genre":"..."}
    # Part A: {"artist":"
    movq $part_artist, %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part B: Artist String value
    movq %rbx, %rax
    shlq $7, %rax
    leaq records_artist(%rax), %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part C: ","title":"
    movq $part_title, %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part D: Title String value
    movq %rbx, %rax
    shlq $7, %rax
    leaq records_title(%rax), %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part E: ","year":"
    movq $part_year, %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part F: Year String value (index * 16)
    movq %rbx, %rax
    shlq $4, %rax
    leaq records_year(%rax), %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part G: ","genre":"
    movq $part_genre, %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part H: Genre String value (index * 64)
    movq %rbx, %rax
    shlq $6, %rax
    leaq records_genre(%rax), %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10

    # Part I: "}
    movq $part_end, %rsi
    movq %r10, %rdi
    call strcpy_asm
    movq %rdi, %r10
    movq %r10, json_ptr          # Save updated JSON write pointer

step_record_loop:
    incq %rbx
    jmp records_search_loop

finalize_json:
    movq json_ptr, %rax
    movb $93, (%rax)             # Write ']' closing bracket
    movb $0, 1(%rax)
    incq %rax

    # Calculate final JSON output string length
    movq $json_body, %rdi
    call strlen_asm
    movq %rax, %r14              # r14 = JSON Length

    # ── Format HTTP Content-Length Header ──
    movq $header_buffer, %rdi
    movq $http_header, %rsi
    call strcpy_asm
    
    # Append content length integer to header
    movq $header_buffer, %rdi
    call strlen_asm
    leaq header_buffer(%rax), %rdi
    movq %r14, %rax
    call int_to_ascii_asm

    # Append header endings (\r\n\r\n)
    movq $header_buffer, %rdi
    call strlen_asm
    leaq header_buffer(%rax), %rdi
    movq $http_header_end, %rsi
    call strcpy_asm

    # Send response header to socket
    movq $header_buffer, %rdi
    call strlen_asm
    movq %rax, %rdx              # length
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # client fd
    movq $header_buffer, %rsi    # buffer
    syscall

    # Send response body to socket
    movq $1, %rax                # sys_write
    movq %r13, %rdi
    movq $json_body, %rsi
    movq %r14, %rdx
    syscall

    # Close Client connection descriptor: close(client_fd)
    movq $3, %rax                # sys_close
    movq %r13, %rdi
    syscall

    jmp accept_loop

server_init_fail:
    movq $60, %rax               # exit(1)
    movq $1, %rdi
    syscall

# ── Helper Utilities ──
strcpy_asm:
    pushq %rcx
strcpy_loop:
    movb (%rsi), %cl
    movb %cl, (%rdi)
    testb %cl, %cl
    jz strcpy_done
    incq %rsi
    incq %rdi
    jmp strcpy_loop
strcpy_done:
    popq %rcx
    ret

strlen_asm:
    movq $0, %rax
strlen_loop:
    cmpb $0, (%rdi,%rax,1)
    je strlen_done
    incq %rax
    jmp strlen_loop
strlen_done:
    ret

# Substring finder
strstr_asm:
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    
    movq %rdi, %rax              # text pointer
strstr_outer:
    cmpb $0, (%rax)
    je strstr_fail
    
    movq %rax, %rbx
    movq %rsi, %rcx
strstr_inner:
    cmpb $0, (%rcx)
    je strstr_found              # query end reached, match!
    movb (%rcx), %dl
    cmpb %dl, (%rbx)
    jne strstr_next
    incq %rbx
    incq %rcx
    jmp strstr_inner
strstr_next:
    incq %rax
    jmp strstr_outer
strstr_found:
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    ret
strstr_fail:
    movq $0, %rax
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    ret

int_to_ascii_asm:
    pushq %rbx
    pushq %rcx
    pushq %rdx
    
    movq %rdi, %rcx              # rcx = target string dest
    movq $10, %rbx               # divisor
    
    # Store digits on stack to output in correct order
    movq $0, %rsi                # digit counter
int_loop:
    movq $0, %rdx
    divq %rbx
    addq $48, %rdx
    pushq %rdx
    incq %rsi
    testq %rax, %rax
    jnz int_loop
    
write_digits:
    testq %rsi, %rsi
    jz int_ascii_done
    popq %rax
    movb %al, (%rcx)
    incq %rcx
    decq %rsi
    jmp write_digits
int_ascii_done:
    movb $0, (%rcx)
    popq %rdx
    popq %rcx
    popq %rbx
    ret

.section .data
.align 8
opt_val:
    .long 1

.align 8
q_param_str:
    .ascii "?q=\0"

# JSON templates parts
.align 8
part_artist:
    .ascii "{\"artist\":\"\0"
.align 8
part_title:
    .ascii "\",\"title\":\"\0"
.align 8
part_year:
    .ascii "\",\"year\":\"\0"
.align 8
part_genre:
    .ascii "\",\"genre\":\"\0"
.align 8
part_end:
    .ascii "\"}\0"

.section .data
main_memory:     .space 1024                   
addresse_Arr:    .word 5, 12, 13, 17, 4, 12, 13, 17, 2, 13, 19, 43, 61, 19
cache_blocks:    .word 8                      
cache_data:      .space 32                        @ داده کش (8 بلوک، 2-way set associative)
MRU_Arr:         .space 16                        @ آرایه MRU 
MRU_Index:       .space 16                        @ اندیس MRU
LFU_Arr:         .space 32                        @ آرایه LFU
lfsr_seed:       .word 0x1234              @ مقدار اولیه LFSR  برای رندوم
/*
lfsr_seed:  .word 0xACE1      @ مقدار پیش‌فرض برای LFSR 16 بیتی
lfsr_seed:  .word 0x1234
lfsr_seed:  .word 0xBEEF
lfsr_seed:  .word 0xABCD
lfsr_seed:  .word 0xF00D
*/
.section .text
.global _start

_start:
    MOV R0, #0                      @ hit_count
    MOV R1, #0                      @ miss_count
    MOV R2, #0                      @ hit_rate
    MOV R3, #0                      @ اندیس آرایه آدرس‌ها
    MOV R11,#5					@ 0 = FIFO  1 = LRU 2 = MRU 3 = LFU 4 = MFU 5 = RANDOM
    LDR R5, =addresse_Arr           
	
main_loop:
    CMP R3, #14
    BLT continue_loop
    B calc_hit_rate

continue_loop:
    LDR R4, [R5, R3, LSL #2]
    BL check_address
    ADD R3, R3, #1
    B main_loop

calc_hit_rate:
    ADD R6, R0, R1                  @ hit + miss
    CMP R6, #0
    BEQ zero_hit_rate

    MOV R7, R0                      @ hit_count
    MOV R8, #100
    MUL R7, R7, R8                  @ hit_count * 100
    MOV R2, #0                      @ مقداردهی اولیه درصد hit_rate

div_loop:
    CMP R7, R6
    BLT done
    SUBS R7, R7, R6
    ADD R2, R2, #1
    B div_loop

zero_hit_rate:
    MOV R2, #0

done:
    B done

@ تابع اصلی بررسی آدرس
check_address:
    PUSH {R5-R10, LR}

    LDR R5, =cache_data
    AND R6, R4, #3                  @ محاسبه index ست: address mod 4

    MOV R7, #8
    MUL R7, R6, R7                  @ offset = index * 8 (2 ways × 4 بایت)
    ADD R7, R7, R5                  @ آدرس ست مورد نظر در کش

    LDR R8, [R7]                    @ خواندن راه اول
    CMP R8, R4
    MOVEQ R9, #1                    @  برای مشخص کردن way1
    BEQ calc_hit                    @ اگر تگ برابر بود، hit

    CMP R11, #5
    BEQ insert_random                 @ الگوریتم Random

    CMP R11, #3
    BGE miss_LFU_MFU                @ الگوریتم LFU یا MFU

    CMP R11, #1
    BGE miss_MRU_LRU                @ الگوریتم MRU یا LRU

    B miss_fifo                    @ الگوریتم FIFO

calc_hit:
    CMP R11, #3
	BEQ update_lfu_mfu
	CMP R11, #4
	BEQ update_lfu_mfu      

    @ برای الگوریتم‌های MRU/LRU:
    LDR R10, =MRU_Arr
    STR R7, [R10, R6, LSL #2]    @ ذخیره آدرس بلوک استفاده‌شده

    LDR R2, =MRU_Index
    STR R9, [R2, R6, LSL #2]     @ ذخیره شماره way (1 یا 2)

    B hit_finalize
	
update_lfu_mfu:
    LDR R10, =LFU_Arr
    ADD R10, R10, R6, LSL #3     @ هر set، 8 بایت (2×4) دارد

    CMP R9, #1
    BEQ inc_way1_count           @ اگر hit در way اول
    ADD R10, R10, #4             @ else → way دوم

inc_way2_count:
    LDR R9, [R10]
    ADD R9, R9, #1
    STR R9, [R10]
    B hit_finalize

inc_way1_count:
    LDR R9, [R10]
    ADD R9, R9, #1
    STR R9, [R10]

hit_finalize:
    ADD R0, R0, #1               @ افزایش hit count
    B push_pop
	
miss_fifo:
    ADD R7, R7, #4
    LDR R2, [R7]
    CMP R2, R4
    BNE miss_plus             @ اگر تگ برابر نبود، برو به miss_plus
    B calc_hit                @ در غیر این صورت hit

@ الگوریتم‌های MRU و LRU
miss_MRU_LRU:
/* بررسی هیت بودن برای راه دوم*/
    ADD R7, R7, #4
    LDR R2, [R7]
    CMP R2, R4
    MOVEQ R9, #2
    BEQ calc_hit
	
/* بررسی میکند راه اول خالی هست یا نه*/

    LDR R10, =MRU_Arr
    LDR R2, =MRU_Index
    SUB R7, R7, #4
    LDR R9, [R7]
    CMP R9, #0
    STREQ R7, [R10, R6, LSL #2]
    MOVEQ R9, #1
    STREQ R9, [R2, R6, LSL #2]
    BEQ miss_plus
	
/* اگر راه اول خالی نبود به راه دوم میرود*/
/* اگر هر دو راه پر باشند اتفاقی نمی افتد */ 

    ADD R7, R7, #4
    LDR R9, [R7]
    CMP R9, #0
    LDRNE R7, [R10, R6, LSL #2]
    STREQ R7, [R10, R6, LSL #2]
    MOVEQ R9, #2
    STREQ R9, [R2, R6, LSL #2]
    B miss_plus

@ الگوریتم‌های LFU و MFU
miss_LFU_MFU:
    ADD R7, R7, #4
    LDR R2, [R7]
    CMP R2, R4
    MOVEQ R9, #2
    BEQ calc_hit

    LDR R10, =LFU_Arr
    SUB R7, R7, #4
    LDR R2, [R7]
    CMP R2, #0
    MOVEQ R2, #1
    STREQ R2, [R10, R6, LSL #3]
    BEQ miss_plus

    ADD R7, R7, #4
    LDR R2, [R7]
    CMP R2, #0
    MOVEQ R2, #1
    ADDEQ R10, R10, #4
    STREQ R2, [R10, R6, LSL #3]
    SUBEQ R10, R10, #4
    B miss_plus

@ افزایش شمارش miss و فراخوانی درج جایگزینی
miss_plus:
    ADD R1, R1, #1

    CMP R11, #5
    BEQ insert_random

    CMP R11, #4
    BEQ insert_MFU

    CMP R11, #3
    BEQ insert_LFU

    CMP R11, #2
    BEQ insert_MRU

    CMP R11, #1
    BEQ insert_LRU

    B insert_fifo

/* R7 آدرس way جدیدتر */
@ درج در کش - FIFO
insert_fifo:
    LDR R9, [R7]
    SUB R7, R7, #4
    STR R9, [R7]
    ADD R7, R7, #4
    STR R4, [R7]
    B push_pop


@ درج در cache - MRU
insert_MRU:
    LDR R7, [R10, R6, LSL #2]
    STR R4, [R7]
    B push_pop

@ درج در cache - LRU
insert_LRU:
    /* کدوم بلاک حافظه کمتر استفاده شده*/
    LDR R9, [R2, R6, LSL #2]
    LDR R7, [R10, R6, LSL #2]
    LDR R7, [R7]
	/* آیا مقدار داخل آن خانه کش برابر صفر است یا نه*/
    CMP R7, #0
	/* چون قبلا خراب شده بود */
    LDREQ R7, [R10, R6, LSL #2]
    STREQ R4, [R7]
    BNE LRU_OK
    B push_pop


LRU_OK:
    LDR R7, [R10, R6, LSL #2]
    CMP R9, #1  /* کدام way*/
	/* باعث میشه بفهمم r7 همیشه به آدرس way دیگر اشاره دارد*/
    ADDEQ R7, R7, #4
    SUBNE R7, R7, #4
    STR R4, [R7]
    B push_pop


insert_LFU:
    LDR     R9, [R7]                 @ مقدار way1
    CMP     R9, #0
    BEQ     insert_direct_LFU

    ADD     R10, R10, R6, LSL #3     @ R10 = &LFU_Arr[set_index * 8]
    LDR     R9, [R10]                @ freq1
    LDR     R2, [R10, #4]            @ freq2

    ADD     R5, R5, R6, LSL #3       @ R5 = &cache_data[set_index * 8]
    CMP     R9, R2
    STRLE   R4, [R5]                 @ if freq1 ≤ freq2 → replace way0
    STRGT   R4, [R5, #4]             @ else replace way2
    B       push_pop

insert_direct_LFU:
    STR     R4, [R7]                 @ درج مستقیم در way1
    B       push_pop

insert_MFU:
    LDR     R9, [R7]                 @ خواندن مقدار way1
    CMP     R9, #0
    BEQ     insert_MFU_direct
	
    ADD     R10, R10, R6, LSL #3     @ R10 = &LFU_Arr[set_index * 8]
    LDR     R9, [R10]                @ freq1
    LDR     R2, [R10, #4]            @ freq2

    ADD     R5, R5, R6, LSL #3       @ R5 = &cache_data[set_index * 8]
    CMP     R9, R2
    STRGE   R4, [R5]                 @ اگر freq1 ≥ freq2 → جایگزینی way1
    STRLT   R4, [R5, #4]             @ در غیر این صورت → جایگزینی way2
    B       push_pop

insert_MFU_direct:
    STR     R4, [R7]                 @ درج مستقیم در way1
    B       push_pop

@ (Random Replacement)
insert_random:
	ADD     R1, R1, #1                   

    LDR     R5, =cache_data
    AND     R6, R4, #3                    
    MOV     R7, #8
    MUL     R7, R6, R7                   
    ADD     R7, R7, R5 
	
    @  تولید بیت تصادفی با LFSR
    LDR     R10, =lfsr_seed
    LDR     R9, [R10]                     

    EOR     R2, R9, R9, LSR #2            @ تولید بیت با xor بیت‌های متفاوت
    AND     R2, R2, #1                    @ فقط بیت کم‌ارزش نگه داشته می‌شه
    MOV     R9, R9, LSR #1
    ORR     R9, R9, R2, LSL #31           @ چرخش LFSR
    STR     R9, [R10]                     @ ذخیره seed جدید

    AND     R9, R9, #1                    @ بیت تصمیم‌گیری برای راه تصادفی

    @  درج در way 1 یا way 2 بر اساس بیت تصادفی
    CMP     R9, #0
    BEQ     write_way0

write_way1:
    ADD     R7, R7, #4                    @ رفتن به way2
    STR     R4, [R7]                      @ ذخیره آدرس در way2
    B       push_pop

write_way0:
    STR     R4, [R7]                      @ ذخیره آدرس در way1
    B       push_pop

push_pop:
	POP {R5-R10, LR}
    BX LR

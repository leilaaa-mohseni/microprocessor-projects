.global _start
# Load a matrix element at [row][col] into el
.macro Find_element, Matrix, X, row, col
    ADDI \Matrix, \Matrix, 4         # Skip row count
    LW t1, 0(\Matrix)             # t1 ← number of columns
    ADDI \Matrix, \Matrix, 4         # Skip column count
    ADDI \row, \row, -1
    MUL t0, \row, t1           # t0 = row * num_cols
    ADD t2, t0, \col
    ADDI t2, t2, -1
    LI t0, 4
    MUL t2, t2, t0             # offset = (row * col + col - 1) * 4
    ADD \Matrix, \Matrix, t2
    LW \X, 0(\Matrix)
    ADDI \Matrix, \Matrix, -8
    SUB \Matrix, \Matrix, t2
    ADDI \row, \row, 1
.endm
_start:
    LA s1, first_matrix       
    LA s2, second_matrix     
    LA s6, result             
check_dimensions:
    LW s3, 0(s1)              
    LW s4, 4(s1)              
    LW s7, 0(s2)              
    LW s5, 4(s2)              

    BNE s4, s7, end          
    LI s7, 0                
save_result_dimensions:
    SW s3, 0(s6)             
    ADDI s6, s6, 4
    SW s5, 0(s6)              
    ADDI s6, s6, 4

zarb_matrix:
    LI t3, 1                  # t3 = row_i
loop_row:
    BGT t3, s3, end_loop_row
    LI t4, 1                  # t4 = col_j
loop_col:
    BGT t4, s5, end_loop_col
    LI t5, 1                  # t5 = k
    LI s9, 0                  # s9 = accumulator for result[t3][t4]
loop_k:
    BGT t5, s4, end_loop_k
    # t6 = A[t3][k]
    Find_element s1, t6, t3, t5
    # s7 = B[k][t4]
    Find_element s2, s7, t5, t4
    MUL s8, t6, s7
    ADD s9, s9, s8           
    ADDI t5, t5, 1
    J loop_k
end_loop_k:
    SW s9, 0(s6)              # store result[t3][t4]
    ADDI s6, s6, 4
    ADDI t4, t4, 1
    J loop_col
end_loop_col:
    ADDI t3, t3, 1
    J loop_row
end_loop_row:
    LI t0, 0xffffffff        # marker
    SW t0, 0(s6)
end:
    J end


.data

first_matrix: 
.word 2 ,3
.word 1, 2,3
.word 3 ,2, 1


second_matrix:
.word 3,2 
.word 1, 2 
.word 2 ,1   
.word 1, 2

.word 0xffffffff             # marker before result
result:
.space 64


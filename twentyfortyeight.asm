# CS 21 WFR/HYZ -- S1 AY 2024-2025
# Luis de los Reyes, Krisha Anne Chan -- 12/12/2024
# twentyfortyeight.asm -- a program where we make a 2048 clone! (but it's nxn)

#reads input for movement and game mode selection
.macro read_input
        li $v0, 8
        la $a0, buffer     
        li $a1, 2          
        syscall            
        jal read_enter_no_prompt
.end_macro

#reads integers for determining grid size
.macro read_int(%reg)
        li $v0, 5
        syscall
        move %reg, $v0
.end_macro

.macro print_newline
        print_str(newline) #for printing a newline
.end_macro

#prompt for printing cells if selected mode is 2 (start from state)
.macro print_cell_prompt(%n)
        print_str(cell_prompt)
        print_int(%n)
        print_newline
.end_macro

#generate a random number, used for selecting a random cell on the grid to give a '2'
.macro generate_random_number(%n)
        add $a1, $0, %n #generate number from 0-n
        li $v0, 42 #syscall for rnadom number
        syscall
        move $s3, $a0 #move result to s3 
.end_macro

.macro generate_random_number_2to7
        addi $a1, $0, 5 #generate number from 0-5
        li $v0, 42 #syscall for rnadom number
        syscall
        move $s3, $a0 #move result to s3 
        addi $s3, $s3, 2 #adjust so number generated is from 2-7
.end_macro

.macro generate_random_number_1to4
        addi $a1, $0, 4 #generate number from 0-3
        li $v0, 42 #syscall for rnadom number
        syscall
        move $s3, $a0 #move result to s3 
        addi $s3, $s3, 1 #adjust so number generated is from 1-4 
.end_macro

#macro to print a string
.macro print_str(%str)
        la $a0, %str
        li $v0, 4
        syscall
.end_macro

#macro to print an integer
.macro print_int(%reg)
	move $a0, %reg
	li $v0, 1
        syscall
.end_macro

#save t registers in case more registers are needed to perform a macro
.macro save_t_regs
        la $s5, vault_t
        sw $t0, 0($s5)
        sw $t1, 4($s5)
        sw $t2, 8($s5)
        sw $t3, 12($s5)
        sw $t4, 16($s5)
        sw $t5, 20($s5)
        sw $t6, 24($s5)
        sw $t7, 28($s5)
        sw $t8, 32($s5)
        sw $t9, 36($s5)
.end_macro

#restore the saved t registers
.macro restore_t_regs
        la $s5, vault_t
        lw $t0, 0($s5)
        lw $t1, 4($s5)
        lw $t2, 8($s5)
        lw $t3, 12($s5)
        lw $t4, 16($s5)
        lw $t5, 20($s5)
        lw $t6, 24($s5)
        lw $t7, 28($s5)
        lw $t8, 32($s5)
        lw $t9, 36($s5)
.end_macro

#save s registers in case more registers are needed to perform a macro
.macro save_s_regs
        la $s5, vault_s
        sw $s0, 0($s5)
        sw $s1, 4($s5)
        sw $s2, 8($s5)
        sw $s3, 12($s5)
        sw $s4, 16($s5)
        sw $s6, 24($s5)
        sw $s7, 28($s5)
.end_macro

#restore the saved t registers
.macro restore_s_regs
        la $s5, vault_s
        lw $s0, 0($s5)
        lw $s1, 4($s5)
        lw $s2, 8($s5)
        lw $s3, 12($s5)
        lw $s4, 16($s5)
        lw $s6, 24($s5)
        lw $s7, 28($s5)
.end_macro

#quick macro for creating a new empty grid of size nxn (t1 has the value nxn)
.macro allocate_new_grid(%n)
        li $v0, 9
        mul $a0, $t1, 4
        syscall
        move %n, $v0
.end_macro
 
#allocates a word for flag stores whether or not a merge has been made
.macro allocate_res(%n)
        li $v0, 9
        li $a0, 4
        syscall
        move %n, $v0
.end_macro

#macro for allowing undos
.macro toggle_undo_on
        save_t_regs
        la $t4, can_undo #load can_undo flag from memory
        lw $t3, 0($t4) #get the flag
        li $t3, 1 #set can_undo flag to 1 (true)
        sw $t3, 0($t4) #put back the flag
        restore_t_regs
.end_macro

#macro for not allowing undos
.macro toggle_undo_off
        save_t_regs
        la $t4, can_undo #load can_undo flag from memory
        lw $t3, 0($t4) #get the flag
        li $t3, 0 #set can_undo flag to 0 (false)
        sw $t3, 0($t4) #put back the flag
        restore_t_regs
.end_macro

#macro for copying grid from one register to another; used in getting tranpose of hte grid and reverting to previous state (undo)
#takes in n(size of grid), source grid, destination grid
.macro copy_grid(%n, %source_base_addr, %dest_base_addr)
        save_s_regs
        la $s6, (%source_base_addr) #s6 points to the base address of the source grid
        la $s3, (%dest_base_addr) #s3 points to the base address of the destination array

        li $s0, 0  #index
        mul $s1, %n, %n  #get nxn (number of grid cells)
        mul $s1, $s1, 4  #get total number of bytes for the grid

copy_loop:
        bge $s0, $s1, end_copy_grid  #if index >= total bytes end loop

        #move number from source[i] to destination[i]
        lw $s2, 0($s6)  #load word from source grid
        sw $s2, 0($s3)  #store word in destination array

        addi $s6, $s6, 4  #jump to the next word in source grid
        addi $s3, $s3, 4  #jump to the next word in destination array
        addi $s0, $s0, 4  #increment index by word size
        j copy_loop

end_copy_grid:
        restore_s_regs
.end_macro

#macro for checking if two grids are the same, i.e., containing the same value in each cell
#takes in n(size of grid), two grids that will be compared, result address for storing the merge result (whether a merge occurred or not)
#this is done by checking each element of both grids and comparing them.
.macro compare_grids(%n, %grid1_base_addr, %grid2_base_addr, %result_addr)
        save_s_regs
        save_t_regs
        la $s6, (%grid1_base_addr)  #s6 points to the base address of grid1
        la $t5, (%grid2_base_addr)  #t5 points to the base address of grid2

        li $s0, 0  #index
        mul $s1, %n, %n  #get nxn (number of grid cells)
        mul $s1, $s1, 4  #get total number of bytes for the grid

        li $s2, 0  #initialize result to 0 (no slide)

compare_loop:
        bge $s0, $s1, end_compare_grids  #if index >= total bytes then end the loop

        lw $s3, 0($s6)  #load word from first grid
        lw $s4, 0($t5)  #load word from second grid

        bne $s3, $s4, slide_made  #if words are different, a slide has been made

        addi $s6, $s6, 4  #move to the next word in first grid
        addi $t5, $t5, 4  #move to the next word in second grid
        addi $s0, $s0, 4  #increment index by word size
        j compare_loop

slide_made:
        li $s2, 1  #set result to 1 (slide made)

end_compare_grids:
        sw $s2, 0(%result_addr)  #store the result
        restore_s_regs
        restore_t_regs
.end_macro

#macro for reversing a row on the grid (used for swipe right and down)
########### flow for reverse_array ###########
        #take first and last element of the array and swap their places
        #increment index of first element, decrement element of last element
        #stop when the indices cross each other or are equal
##############################################
.macro reverse_array(%n, %row_base_addr)
        save_s_regs
        move $s6, %row_base_addr  #base address of the array
        addi $s1, %n, -1          #initialize index to n-1
        mul $s1, $s1, 4           #multiply by word width
        add $s1, $s1, $s6         #get address of last element

rev_loop:
        bge $s6, $s1, end_rev  #if base address >= end address, end loop

        #load elements to swap
        lw $s2, 0($s6)         #load first element
        lw $s3, 0($s1)         #load last element

        #swap elements
        sw $s3, 0($s6)         #store last element at first element's position
        sw $s2, 0($s1)         #store first element at last element's position

        addi $s6, $s6, 4       #increment index
        addi $s1, $s1, -4      #decremenet index 

        j rev_loop

end_rev:
        restore_s_regs
.end_macro

#macro that performs merge_l for each row (merge_l only merges one row)
.macro slide_each_row_l(%n)
        save_s_regs
        la $s6, 0($s7)  #s6 will point to the base address of the array

        li $s0, 0               #row index
        mul $s1, %n, 4          #bytes per row

iterate_rows:
        bge $s0, %n, end_slide_each_row_l  #if row index >= n, end the loop

        #get the base address of the current row
        mul $s3, $s0, $s1         #get the offset for the current row
        # print_int($s1)
        # print_space
        # print_int($s3)
        # print_newline
        la $s6, 0($s7)  #reset address to point at the base addr since the offset increases each iteration 
        add $s2, $s6, $s3         #get base address of the current row
        # print_int($s2)
        # print_newline

        slide_l(%n, $s2)            #call slide macro for the current row

        addi $s0, $s0, 1          #increment row index
        j iterate_rows            #repeat for the next row

end_slide_each_row_l:
        restore_s_regs
.end_macro

#slides/pushes all numbers of the row to the left (no merges)
########### general flow for slide_l ###########
        #make a copy of array/row
        #copy all nonzero elemtents from original arr to temporary arr
        #fill the rest of the row with zeros
        #copy the contents of the temp array back to the original array
################################################
.macro slide_l(%n, %row_base_addr)
        save_s_regs
        save_t_regs
        la $s6, (%row_base_addr)  #s6 points to the base address of the specified row
        
        #make temporary array for the row
        li $v0, 9               #syscall for sbrk (allocate memory)
        mul $a0, %n, 4          #allocate 4 * n bytes (size of int array)
        syscall
        move $t9, $v0           #t9 has base address of temp array

copy_loop_init:
        li $t8, 0  #iterator for temp array j
        li $t7, 0  #iterator for original array i
copy_loop:
        bge $t7, %n, fill_zeros  # If i >= n, jump to fill_zeros
        mul $t5, $t7, 4          #multiply by word width (4 bytes)
        add $t4, $s6, $t5        #calculate address of arr[i]

        lw $t1, 0($t4)           #load arr[i]
        beqz $t1, skip_copy      #if arr[i] == 0, i++

        #copy nonzero element to temp[j]
        mul $t5, $t8, 4          #multiply j by 4 to get byte offset
        add $t6, $t9, $t5        #calculate address of temp[j]
        sw $t1, 0($t6)           #store arr[i] in temp[j]
        addi $t8, $t8, 1         #j++

skip_copy:
        addi $t7, $t7, 1         #i++
        j copy_loop

fill_zeros:
        #fill remaining positions in temp arry with zeros
        bge $t8, %n, copy_back  #if j >= n, jump to copy_back
fill_zeros_loop:
        mul $t5, $t8, 4          #multiply j by word width
        add $t6, $t9, $t5        #get address of temp[j]
        sw $0, 0($t6)            #put a 0 in temp[j]
        addi $t8, $t8, 1         #j++
        blt $t8, %n, fill_zeros_loop  #loop until j < n

copy_back:
        li $t7, 0  #reset i = 0
copy_back_loop:
        bge $t7, %n, end_slide_l  #if i >= n, end the macro
        mul $t5, $t7, 4         #multiply i by word width
        add $t4, $s6, $t5       #get address of arr[i]
        add $t6, $t9, $t5       #get address of temp[i]

        lw $t1, 0($t6)          #load temp[i]
        sw $t1, 0($t4)          #store temp[i] in arr[i]
        addi $t7, $t7, 1        #i++
        j copy_back_loop

end_slide_l:
        restore_t_regs
        restore_s_regs
.end_macro

#macro that slides each row to the right, this is done by reversing the row and using slide_l and reversing the row again
.macro slide_each_row_r(%n)
        save_s_regs
        la $s6, 0($s7)  #s6 will point to the base address of the array

        li $s0, 0               #row index
        mul $s1, %n, 4          #row size in bytes (n* word width)

iterate_rows:
        bgt $s0, %n, end_slide_each_row_r  #if row index >= n, end the loop

        #calculate the base address of the current row
        mul $s3, $s0, $s1         #calculate the offset for the current row
        la $s6, 0($s7)  #reset address to point at the base addr since the offset increases each iteration 
        add $s2, $s6, $s3         #calculate the base address of the current row

        reverse_array(%n, $s2)
        slide_l(%n, $s2)            #call the slide macro for the current row
        reverse_array(%n, $s2)

        addi $s0, $s0, 1          #increment row index
        j iterate_rows            #repeat for the next row

end_slide_each_row_r:
        restore_s_regs
.end_macro

#macro for sliding each row up, this is done by getting the tranpose of the matrix and then swiping left
.macro slide_each_row_u
        transpose_matrix($t0, $s7)
        slide_each_row_l($t0)
        merge_each_row_l($t0)
        slide_each_row_l($t0)
        transpose_matrix($t0, $s7)
.end_macro

#macro for sliding each row down. 
#similar to slide_each_row_u above,this is done by getting the tranpose of the matrix, reversing each row
#and then swiping left
.macro slide_each_row_d
        transpose_matrix($t0, $s7)
        slide_each_row_r($t0)
        merge_each_row_r($t0)
        slide_each_row_r($t0)
        transpose_matrix($t0, $s7)
.end_macro

#equivalent to 'slide' macro in project 1, merge seems to be a more appropriate name
#performs a merge in a single row
############ flow/process for merge_l ############
        #loop from 0th to n-1th of the row
        #check if arr[i] == arr[i+1]
        #if equal, add them together, store result in arr[i] and turn arr[i+1] to 0
        #if not, do nothing and go to next iteration
##################################################
.macro merge_l(%n, %row_base_addr)
        save_s_regs
        la $s6, (%row_base_addr)  #s6 points to the base address of the specified row
        li $s7, 0  #iterator for array index i
merge_loop:
        bge $s7, %n, end_merge  #if i >= n, end the merge macro

        #calculate address of arr[i]
        mul $s5, $s7, 4
        add $s4, $s6, $s5
        lw $s1, 0($s4)  #load arr[i]

        addi $s7, $s7, 1
        bge $s7, %n, end_merge  #if i >= n after increment, end the merge macro

        #calculate address of arr[i+1]
        mul $s5, $s7, 4
        add $s4, $s6, $s5
        lw $s2, 0($s4)  #load arr[i+1]

        bne $s1, $s2, skip_merge  #if arr[i] != arr[i+1], skip merging

        #do the merge: arr[i] = arr[i] + arr[i+1]
        add $s1, $s1, $s2
        la $t4, score
        sw $s1, -4($s4)  #store the result back in arr[i]
        toggle_undo_on

        #set arr[i+1] to 0
        sw $0, 0($s4)

skip_merge:
        j merge_loop

end_merge:
        restore_s_regs
.end_macro

#peforms merge_l on each row
.macro merge_each_row_l(%n)
        save_s_regs
        la $s6, 0($s7)  #s6 will point to the base address of the array

        li $s0, 0               #row index
        mul $s1, %n, 4          #row size in bytes (n * word width)

iterate_rows:
        bge $s0, %n, end_merge_each_row_l  #if row index >= n, end the loop

        #calculate the base address of the current row
        mul $s3, $s0, $s1  #calculate the offset for the current row
        la $s6, 0($s7)  #reset address to point at the base addr since the offset increases each iteration
        add $s2, $s6, $s3  #calculate the base address of the current row

        merge_l(%n, $s2)  #call the merge macro for the current row

        addi $s0, $s0, 1  #increment row index
        j iterate_rows  #repeat for the next row

end_merge_each_row_l:
        restore_s_regs
.end_macro

#same as merge_each_row_l but reverses the array before performing merge_l
.macro merge_each_row_r(%n)
        save_s_regs
        la $s6, 0($s7)  #s6 will point to the base address of the array

        li $s0, 0               #row index
        mul $s1, %n, 4          #row size in bytes (word width * n)

iterate_rows:
        bge $s0, %n, end_merge_each_row_r  #if row index >= n, end the loop

        #calculate the base address of the current row
        mul $s3, $s0, $s1  #calculate the offset for the current row
        la $s6, 0($s7)  #reset address to point at the base addr since the offset increases each iteration
        add $s2, $s6, $s3  #calculate the base address of the current row

        reverse_array(%n, $s2)
        merge_l(%n, $s2)  #call the merge macro for the current row
        reverse_array(%n, $s2)

        addi $s0, $s0, 1  #increment row index
        j iterate_rows  #repeat for the next row

end_merge_each_row_r:
        restore_s_regs
.end_macro

#gets the tranpose of the grid; this is used for swiping up and down
########### general flow for getting matrix ###########
#example matrix:
# _     _
#| a b c |
#| d e f |
#| g h i |
# _     _

#the diagonal of the matrix remains the same on both the tranpose and original (a, e, i in the example)
#this means we only need to swap elements outside of the diagonal. in our example above, we will
#swap(b, d), swap(c, g), swap(f, h). this extends for any n*n.

#this is done so that we can simply perform merge_l on the up and down swipes just by
#reshaping the grid so taht merge_l still works as expected.
#once again, in the example above, swiping up (i.e., g -> d -> a) is the same as:
#getting the tranpose so that the first col will now be the first row (a d g),
#and we swipe left which also results in (g -> d -> a) 
#######################################################
.macro transpose_matrix(%n, %matrix_base_addr)
        save_s_regs
        la $s6, (%matrix_base_addr)  #s6 points to the base address of the matrix

        li $s0, 0  #row index
transpose_outer_loop:
        bge $s0, %n, end_transpose  #if row index >= n, end the loop

        addi $s1, $s0, 1  #column index, starting from row index + 1 to avoid swapping diagonal elements
transpose_inner_loop:
        bge $s1, %n, transpose_next_row  #if column index >= n, go to next row

        #calculate address of matrix[s0][s1]
        mul $s2, $s0, %n
        add $s2, $s2, $s1
        mul $s2, $s2, 4
        add $s2, $s2, $s6
        lw $s3, 0($s2)  #load matrix[s0][s1]

        #calculate address of matrix[s1][s0]
        mul $s4, $s1, %n
        add $s4, $s4, $s0
        mul $s4, $s4, 4
        add $s4, $s4, $s6
        lw $s5, 0($s4)  #load matrix[s1][s0]

        #swap matrix[s0][s1] and matrix[s1][s0]
        sw $s5, 0($s2)
        sw $s3, 0($s4)

        addi $s1, $s1, 1  #increment column index
        j transpose_inner_loop

transpose_next_row:
        addi $s0, $s0, 1  #increment row index
        j transpose_outer_loop

end_transpose:
        restore_s_regs
.end_macro

#macro for checking win (check if any cell == 2048)
#this is called for every itreation of the main game loop
###### general flow for check_win ######
        #iterate through whole grid
        #compare if any cell is equal to 208
        #if yes, end game and go to win screen
        #if no cells match 2048, game goes on
###### general flow for check_win ######
.macro check_win(%n)
        save_s_regs
        save_t_regs
        la $s6, 0($s7) #loading the base address of the array

        #set $s5 to 2048
        li $s5, 2048

        #calculate the total number of elements in the nxn grid
        mul $t1, %n, %n

        #initialize the iterator
        li $t8, 0

check_win_loop:
        bge $t8, $t1, end_check_win  #end if all elements have been checked

        #calculate memory address for the current element
        mul $t3, $t8, 4  #multiply by word width
        add $t3, $t3, $s6

        #load value from memory
        lw $t4, 0($t3)

        #check if cell is equal to 2048
        beq $t4, $s5, win_screen

        addi $t8, $t8, 1  #increment iterator
        j check_win_loop 

end_check_win:
        lw $s5, 36($s6) # get back the original value (0 or 1) of $s5
        j no_win  # if no cell is equal to 2048, then no win yet

win_screen:
        show_grid($t0)
        print_str(win_msg)
        print_str(win_ascii)
        j end_game_no_msg

no_win:
        restore_s_regs
        restore_t_regs
.end_macro

#####################################General flow for check_loss############################################
#check if score is zero. if yes, go to losing screen
#1. iterate through grid and check if it is full 
#2. if yes, check if there is any valid merges remaining
#3. if none, player loses
############################################################################################################
.macro check_loss(%n)
        #save registers
        save_s_regs
        update_score($t1)
        la $s4, score
        lw $s3, 0($s4)
        beqz $s3, lose_screen
        save_t_regs

        #1. check if the grid is full by going through each tile and checking if they are equal to zero
        la $s6, 0($s7)
        li $s0, 0          #Initialize row index
        li $s1, 0          #Initialize column index

check_full_loop:
        bge $s0, %n, check_merge  #if row index >= n (i.e., if all cells are nonzero), check for possible merges
        li $s1, 0                 #reset column index for new row

inner_full_loop:
        bge $s1, %n, next_row_full  #if column index >= n, go to next row

        #calculate address of grid[s0][s1]
        mul $t1, $s0, %n
        add $t1, $t1, $s1
        mul $t1, $t1, 4
        add $t1, $t1, $s6

        lw $t2, 0($t1)          #load the value from the selected grid cell
        beqz $t2, no_loss       #if value at that index is 0, game goes on

        addi $s1, $s1, 1        #increment column index
        j inner_full_loop

next_row_full:
        addi $s0, $s0, 1        #increment row index
        j check_full_loop

        #2. check for valid moves by checking if every pair of adjacent tiles cannot be merged together anymore (i.e., unequal)
check_merge:
        la $s6, 0($s7)
        li $s0, 0               #initialize row index

check_merge_row:
        bge $s0, %n, check_merge_col  #if row index >= n, check columns

        li $s1, 0               #reset column index for new row
        addi $t7, %n, -1
        add $t5, $t7, $0            #temporary register for n-1
inner_merge_row:
        bge $s1, $t5, next_row_merge  #if column index >= n-1, go to next row

        #calculate address of grid[s0][s1] and grid[s0][s1+1]
        mul $t1, $s0, %n
        add $t1, $t1, $s1
        mul $t1, $t1, 4
        add $t1, $t1, $s6
        lw $t2, 0($t1)          #load grid[s0][s1]

        addi $s1, $s1, 1
        mul $t3, $s0, %n
        add $t3, $t3, $s1
        mul $t3, $t3, 4
        add $t3, $t3, $s6
        lw $t4, 0($t3)          #load grid[s0][s1+1]

        beq $t2, $t4, no_loss   #if adjacent horizontal tiles are equal, no loss

        addi $s1, $s1, -1       #decrement column index to continue to next cell in row
        addi $s1, $s1, 1        #move to the next column
        j inner_merge_row

next_row_merge:
        addi $s0, $s0, 1        #increment row index
        j check_merge_row

check_merge_col:
        li $s0, 0               #initialize column index

check_merge_col_loop:
        bge $s0, %n, lose_screen  #if column index >= n, player loses

        li $s1, 0               #reset row index for new column
inner_merge_col:
        bge $s1, $t5, next_col_merge  #if row index >= n-1, go to next column

        #calculate address of grid[s1][s0] and grid[s1+1][s0]
        mul $t1, $s1, %n
        add $t1, $t1, $s0
        mul $t1, $t1, 4
        add $t1, $t1, $s6
        lw $t2, 0($t1)          #load grid[s1][s0]

        addi $s1, $s1, 1
        mul $t3, $s1, %n
        add $t3, $t3, $s0
        mul $t3, $t3, 4
        add $t3, $t3, $s6
        lw $t4, 0($t3)          #load grid[s1+1][s0]

        beq $t2, $t4, no_loss   #if adjacent vertical tiles are equal, no loss

        addi $s1, $s1, -1       #decrement row index to continue to next cell in column
        addi $s1, $s1, 1        #move to the next row
        j inner_merge_col

next_col_merge:
        addi $s0, $s0, 1        #increment column index
        j check_merge_col_loop

lose_screen:
        print_str(lose_msg)      
        print_str(lose_msg2)     
        j end_game_no_msg

no_loss:
        restore_t_regs
        restore_s_regs
.end_macro

#macro for printing horizonal gridline since the number of columns can now vary with an n*n
#prints "+----" n times, and adds the last "+" at the end of the row
.macro print_hor_gl(%n)
        add $t5, $0, %n
print_hor_gl_loop:
        beqz $t5, end_print_hor_gl
        print_str(hor_gl_single) #"+----"
        addi $t5, $t5, -1
        j print_hor_gl_loop
end_print_hor_gl:
        print_str(plus)
        print_newline
.end_macro

######## flow for print_cell ########
#check if number has 1, 2, 3 or 4 digits by comparing values against 10, 100, and 1000 
#depending on how many digits the number has, then the number of spaces will vary
#####################################
.macro print_cell(%n)
        bnez %n, print_n
        #if 0 print nothing
        print_space
        print_space
        print_space
        print_space
        j skip_n

print_n: #check if n is 1, 2, 3, or 4 digits
        li $t5, 10
        blt %n, $t5, one_n
        li $t5, 100
        blt %n, $t5, two_n
        li $t5, 1000
        blt %n, $t5, three_n
        j four_n

one_n: #1 digit case
        print_space
        print_space
        print_int(%n)
        print_space
        j skip_n

two_n: #2 digit case
        print_space
        print_int(%n)
        print_space
        j skip_n

three_n: #3 digit case
        print_space
        print_int(%n)
        j skip_n

four_n: #4 digit case
        print_int(%n)

skip_n:
        print_str(ver_gl) #"|"
.end_macro

#display number of moves on screen
.macro show_moves
        print_str(moves_msg)
        la $t4, moves 
        lw $t2, 0($t4) #load moves from memory
        print_int($t2) #print the value
        sw $t2, 0($t4) 
        print_newline
.end_macro

#initialize moves to 0
.macro init_moves
        la $t4, moves
        li $t2, 0
        sw $t2, 0($t4)
.end_macro

#macro to decrement moves when an undo is performed
.macro update_moves_undo
        la $t4, moves
        lw $t2, 0($t4) #load moves from memory
        addi $t2, $t2, -1 #decrement moves
        sw $t2, 0($t4)
.end_macro

#macro to increment moves after a successful slide/merge
.macro update_moves
        la $t4, moves
        lw $t2, 0($t4)
        addi $t2, $t2, 1
        sw $t2, 0($t4)
.end_macro

#display score on screen.
#the score according to the specs is the sum of the value of all tiles on the grid
.macro show_score
        update_score($t1) #update_score performs the addition of all values on the grid. gets called so that the score being displayed is the latest score
        print_str(score_msg)
        la $t4, score
        lw $t3, 0($t4) #load score from memory
        print_int($t3)
        sw $t3, 0($t4)
        print_newline
.end_macro

#initialize score to 0 at the start of the game
.macro init_score
        la $t4, score
        li $t3, 0
        sw $t3, 0($t4)
.end_macro

#update score when undoing
.macro update_score_undo
        update_score($t1)
.end_macro

#macro to update_score
#adds every number on the grid and stores it to the 'score' word
.macro update_score(%n)
        save_t_regs

        la $t4, score          #load address of score
        li $t3, 0              #initialize sum to 0
        li $t7, 0              #initialize index to 0

        la $s6, 0($s7) #load address of the grid

add_loop:
        bge $t7, $t1, end_add  #if index >= n*n, end addition
        mul $t8, $t7, 4        #get byte offset
        add $s5, $s6, $t8      #get address of current grid cell
        lw $t6, 0($s5)         #load value of current grid cell
        add $t3, $t3, $t6      #add value to sum
        addi $t7, $t7, 1       #increment index
        j add_loop

end_add:
        sw $t3, 0($t4)         #store updated score
        restore_t_regs
.end_macro


#compared to project 1, length of side of grid should now be provided, however, flow remains the same
.macro show_grid(%n)
        print_hor_gl(%n)  #print top horizontal gridline
        la $s6, 0($s7)  #s6 has base address of array

sg_outer_loop_init:
        li $t8, 0  #row iterator
        la $t9, 0($s6)  #index

sg_outer_loop:
        bge $t8, %n, end_show_grid  #end loop if all rows have been prnited

        li $t6, 0  #col iterator

        print_str(ver_gl)  #print the initial vertical gridline for the row

sg_inner_loop:
        bge $t6, %n, end_row  #end if all elements in the row have been printed

        #calculate memory address for the current cell
        mul $t3, $t8, %n
        add $t3, $t3, $t6
        mul $t3, $t3, 4  #multiply by word width
        add $t3, $t3, $s6

        #load value from memory
        lw $t4, 0($t3)

        #print cell value (see print_cell macro)
        print_cell($t4)  #t4 has current cell value

        addi $t6, $t6, 1  #col++
        j sg_inner_loop

end_row:
        print_newline  #print newline at the end of each row
        print_hor_gl(%n)  #print the horizontal gridline after the row

        addi $t8, $t8, 1  #increment row index
        j sg_outer_loop

end_show_grid:
        # print_newline
.end_macro

#macro to print strings
.macro print_str(%str)
        la $a0, %str
        li $v0, 4
        syscall
.end_macro

#macro to print space
.macro print_space
        print_str(space)
.end_macro

#macro to print integers
.macro print_int(%reg)
        move $a0, %reg
        li $v0, 1
        syscall
.end_macro

.text
###################################### START OF GAME ######################################
        j get_grid_size #start game by inputting grid size

select_mode:
        print_str(select_mode_msg) #prompt user to select a mode
        read_input

        la $s0, buffer #buffer allocates 2 bytes for 2 characters (input and null terminator '\0')
        lb $s0, 0($s0)

        li $s1, '1' #if input is 1, go to init_new_game
        beq $s0, $s1, init_new_game
        li $s1, '2' #if input is 2, go to start_from_state
        beq $s0, $s1, start_from_state
        li $s1, 'G' #if input is G, go to print_goofy
        beq $s0, $s1, start_goofy
        li $s1, 'g' #if input is g, go to print_goofy
        beq $s0, $s1, start_goofy
        li $s1, 'C' #if input is C, go to show_controls_select_mode
        beq $s0, $s1, show_controls_select_mode
        li $s1, 'c' #if input is c, go to show_controls_select_mode
        beq $s0, $s1, show_controls_select_mode
        li $s1, 'H' #if input is H, go to show_help_select_mode
        beq $s0, $s1, show_help_select_mode
        li $s1, 'h' #if input is h, go to show_help_select_mode
        beq $s0, $s1, show_help_select_mode
        li $s1, 'X' #if input is X, go to end_game
        beq $s0, $s1, end_game
        li $s1, 'x' #if input is x, go to end_game
        beq $s0, $s1, end_game

        #if input doesn't match any of the valid ones above, let the player know and try again
        print_str(invalid_mode)
        print_newline
        j select_mode

#if game mode 1 is selected in select mode
#init_new_game starts a new "normal" 2048 game by spawning two '2' tiles randomly on the grid
init_new_game:
        li $s2, 2                  #we need two numbers; decrement once a '2' has been spawned
        la $s6, 0($s7)             #load address of grid_registers

new_game:
        beqz $s2, init_main        #once two '2's have been spawned, start the main game loop
        
        generate_random_number($t1) #pick random number from 1 - n*n
        # show_grid($t0)
        # print_int($s3)
        # print_newline
        mul $s3, $s3, 4            #multiply by 4 to get byte offset
        add $s5, $s6, $s3          #calculate address of the selected cell
        # print_int($s6)
        # print_newline
        # print_int($s5)
        # print_newline
        lw $s4, 0($s5)             #load the value from the selected grid cell
        # print_int($s4)
        # print_newline

        beqz $s4, set_value        #if value at that index is 0, set it to 2

        #if cell is nonzero, find another index that has a zero
        j new_game

set_value:
        li $s4, 2                  #set value to 2
        sw $s4, 0($s5)             #store the value back into the array
        li $s3, 1 #set s3 to 1 to check if grid size is 1 since this loop spawns two '2's
        beq $t1, $s3, new_game_1x1 #if grid size is 1x1, go to new_game_1x1
        addi $s2, $s2, -1          #decrement s2 after setting a value to a grid spot
        j new_game

#loads a '2' on the only cell
new_game_1x1:
        li $s3, 2
        sw $s3, 0($s7)
        show_moves
        show_score
        show_grid($t0)
        j main

#for input of n < 1
invalid_game:
        la $s6, invalid_game_count
        li $s4, 3 #allow up to 3 times of inputting n < 0
        lw $s3, 0($s6) #load invalid games count form memory
        bge $s3, $s4, why_so_kulit #why so kulit, just put an actual grid number </3
        addi $s3, $s3, 1 #add 1 to invalid_game_count
        sw $s3, 0($s6)
        print_str(grid_size_too_small)
        j get_grid_size

#if user puts invalid grid 3 times, instantiate a 4x4 grid automatically
why_so_kulit:
        print_str(if_you_keep_doing_this_the_game_will_never_start_so_bibigyan_namin_kayo_ng_4x4)
        li $t0, 4
        li $t1, 16

        li $v0, 9              #syscall for sbrk (allocate memory)
        mul $a0, $t1, 4          #number of bytes to allocate
        syscall
        move $s7, $v0          #s7 has main base address of the grid

        j init_new_game

#spawn_new_two; used for new_game and after every successful slide/merge
spawn_new_two:
        la $s6, 0($s7)             #load address of grid_registers

#find a zero-valued tile
find_empty_tile:
        generate_random_number($t1) #generate a random number
        
        mul $s3, $s3, 4             #multiply by 4 to get byte offset
        add $t5, $s6, $s3           #calculate address of the selected cell
        lw $s4, 0($t5)              #load the value from the selected grid cell
        beqz $s4, set_val           #if value at that index is 0, set it to 2

        j find_empty_tile

set_val:
        li $s4, 2                   #set $s4 to 2
        sw $s4, 0($t5)              #change value of array to 2 at that index
        jr $ra                      #return to caller

#displays controls on screen
show_controls_select_mode:
        print_str(controls_msg) #display controls on screen
        jal read_enter #wait for user to press enter
        j select_mode #go back to select mode

#displays help (game description) on screen
show_help_select_mode:
        print_str(help_msg) #display help screen 
        jal read_enter #wait for user to press enter
        j select_mode #go back to select mode

#if game mode 2 is selected from select_mode
start_from_state:
        li $t8, 0 #iterator
        la $s6, 0($s7) #load array from memory

#go through every cell and ask for user to input a value for that cell
input_loop:
        bge $t8, $t1, end_input #if end of grid has been reached, branch out
        addi $t8, $t8, 1 #add 1 to print the 1-indexed grid position
        print_cell_prompt($t8) #print cell number (1-indexed)
        addi $t8, $t8, -1 #go back to actual index of t8
        read_int($s2) #get user input

        sw $s2, 0($s6) #store value in grid

        addi $t8, $t8, 1 #increment index
        addi $s6, $s6, 4 #go to next value on cell

        j input_loop

end_input:
        j init_main

read_enter_no_prompt: #added as a fix to old implementation which did not need Enter to be pressed
        li $v0, 12 # syscode for readchar
        syscall

        move $s4, $v0
        bne $s4, 10, read_enter_no_prompt # repeat if not ENTER

        jr $ra # return to the calling subroutine

#read_enter implementation taken from user Andy's answer in https://stackoverflow.com/questions/49722074/pressing-enter-to-continue-in-program-mips
read_enter: # Ask user to press ENTER to continue
        li $v0, 4
        la $a0, continue_msg
        syscall
        li $v0, 12 # syscode for readchar
        syscall

        move $s4, $v0
        bne $s4, 10, read_enter # repeat if not ENTER

        jr $ra # return to the calling subroutine

.macro set_goofy_on
la $s4, goofy
lw $s3, 0($s4)
li $s3, 1 #set goofy to on
sw $s3, 0($s4)
.end_macro
 
start_goofy:
        generate_random_number_2to7
        la $s4, new_size
        add $t0, $0, $s3
        sw $t0, 0($s4)
        set_goofy_on
        print_str(goofy_on)
        print_str(goofy_art)
        j init_new_game 
print_goofy:
        li $s3, 1
        la $s4, goofy #get goofy flag (on/off)
        lw $s5, 0($s4)
        beq $s3, $s5, set_goofy #don't print goofy_on if goofy is already on
        print_str(goofy_on)
        print_str(goofy_art)
        j set_goofy

set_goofy:
        set_goofy_on
        jal get_goofy
        j init_goofy
get_goofy:
        generate_random_number_2to7
        la $s4, new_size
        add $t0, $0, $s3
        sw $t0, 0($s4)
        jr $ra

#get user input to determine n*n grid
get_grid_size:
        print_str(prompt)
        read_int($t0) #read value for n
        print_newline
        mul $t1, $t0, $t0 #t1 contains n*n
        blez $t0, invalid_game 

        ################## ALLOCATE n*n space FOR GRID ##################
        li $v0, 9 #syscall for sbrk (allocate memory)
        mul $a0, $t1, 4 #number of bytes to allocate
        syscall
        move $s7, $v0 #s7 has main base address of the grid
        #################################################################

        j select_mode

#tile generation modes (on/off)
tile_gen_on:
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile_gen_flag
        li $t9, 1 #set tile_gen flag to 1
        sw $t9, 0($t8) #store tile_gen_flag
        print_str(tile_gen_on_msg) #let player know that tile generation is on
        j main
tile_gen_off:
        la $t8, tile_gen_flag
        lw $t9, 0($t8)
        li $t9, 0 #set tile_gen flag to 0
        sw $t9, 0($t8)
        print_str(tile_gen_off_msg) #let player know that tile generation is off
        j main

#shows controls (during main game loop)
show_controls:
        print_str(controls_msg)
        jal read_enter
        show_moves
        show_score
        show_grid($t0)
        j main

#shows help screen (during main game loop)
show_help:
        print_str(help_msg)
        jal read_enter
        show_moves
        show_score
        show_grid($t0)
        j main

init_goofy:
        la $s4, new_size
        lw $t0, 0($s4)
        mul $t1, $t0, $t0             # t1 contains n*n
        blez $t0, invalid_game

        ################## ALLOCATE n*n SPACE FOR GRID ##################
        li $v0, 9                    # syscall for sbrk (allocate memory)
        mul $a0, $t1, 4              # number of bytes to allocate
        syscall
        move $s5, $v0                # s6 has main base address of the new grid
        #################################################################

        # Copy existing numbers to the new grid
        la $s6, 0($s7) # Load address of old grid
        li $t2, 0                    # Initialize index

copy_old_grid:
        lw $t3, 0($s6)                # Load value from old grid
        beqz $t3, check_next_cell     # Skip if zero (if required)

        mul $t4, $t2, 4
        add $t5, $s5, $t4             # Calculate address of new grid cell
        sw $t3, 0($t5)                # Store value in new grid cell
        
        addi $s6, $s6, 4              # Increment old grid address by 4
        addi $t2, $t2, 1              # Increment index
        blt $t2, $t1, copy_old_grid   # Repeat until we reach new grid size

        j main

check_next_cell:
        addi $s6, $s6, 4
        addi $t2, $t2, 1
        blt $t2, $t1, copy_old_grid
        j main

#initializing flags and grid before main loop
init_main:
        la $t8, tile_gen_flag #tile generation is on by default
        lw $t9, 0($t8)
        show_moves
        show_score
        print_str(starting_grid)
        show_grid($t0)
        init_moves
        init_score
main:
        #t0 has n
        #t1 has n*n
        #t2 has move count
        #t3 has score count
        #t9 has tileagen flag

        check_win($t1)
        check_loss($t0)
        print_str(move_prompt) #prompt user to make a move (swipe), and read their input
        la $s0, autopilot_flag
        lw $s1 0($s0)
        bnez $s1, autopilot
        read_input
        print_newline

        #load the first character from the buffer into $t0
        la $s0, buffer
        lb $s0, 0($s0)

        #check input and swipe in direction based on input (don't do anything if input is invalid)
        #if input is W/w, jump to up movement
        li $s1, 'W' 
        beq $s0, $s1, slide_up
        li $s1, 'w'
        beq $s0, $s1, slide_up

        #if input is A/a, jump to left movement
        li $s1, 'A'
        beq $s0, $s1, slide_left
        li $s1, 'a'
        beq $s0, $s1, slide_left

        #if input is S/s, jump to down movement
        li $s1, 'S'
        beq $s0, $s1, slide_down
        li $s1, 's'
        beq $s0, $s1, slide_down

        #if input is D/d, jump to right movement
        li $s1, 'D'
        beq $s0, $s1, slide_right 
        li $s1, 'd'
        beq $s0, $s1, slide_right

        #if input is G/g, get goofy
        li $s1, 'G'
        beq $s0, $s1, print_goofy 
        li $s1, 'g'
        beq $s0, $s1, print_goofy

        #if input is X/x, end game
        li $s1, 'X'
        beq $s0, $s1, end_game
        li $s1, 'x'
        beq $s0, $s1, end_game

        #if input is Z/z, end game
        li $s1, 'Z'
        beq $s0, $s1, undo
        li $s1, 'z'
        beq $s0, $s1, undo

        # if input is R/r, autopilot
        li $s1, 'R'
        beq $s0, $s1, init_autopilot
        li $s1, 'r'
        beq $s0, $s1, init_autopilot

        # if input is C/c, show controls
        li $s1, 'C'
        beq $s0, $s1, show_controls
        li $s1, 'c'
        beq $s0, $s1, show_controls

        # if input is H/h, show help screen
        li $s1, 'H'
        beq $s0, $s1, show_help
        li $s1, 'h'
        beq $s0, $s1, show_help

        # if input is 3, turn off tile generation
        li $s1, '3'
        beq $s0, $s1, tile_gen_off

        # if input is 4, turn on tile generation
        li $s1, '4'
        beq $s0, $s1, tile_gen_on

        #if key pressed is not W/A/S/D/G/R/X/C/H/3/4, try again
        print_str(invalid) 
        print_newline
        j main

init_autopilot:
        la $s0, autopilot_flag
        lw $s1 0($s0)
        li $s1, 1 #set autopilot flag to true
        sw $s1 0($s0)
        #turn on tile gen so that the game actually ends
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile_gen_flag
        li $t9, 1 #set tile_gen flag to 1
        sw $t9, 0($t8) #store tile_gen_flag
        print_str(tile_gen_on_msg) #let player know that tile generation is on
        print_str(autopilot_msg)
autopilot:
        print_newline
        generate_random_number_1to4
        li $s4, 1 #if number is 1, slide left
        beq $s3, $s4, slide_left
        li $s4, 2 #if number is 2, slide right
        beq $s3, $s4, slide_right
        li $s4, 3 #if number is 3,slide up
        beq $s3, $s4, slide_up
        li $s4, 4 #if number is 4,slide down
        beq $s3, $s4, slide_down

#undo, only limited to one undo consecutively
undo:
        save_t_regs
        la $t4, can_undo 
        lw $t3, 0($t4) #load can_undo flag
        beqz $t3, skip_undo #if can_undo is 0, skip undo 
        restore_t_regs
        lw $t5, old_grid #get previous grid configuration
        copy_grid($t0, $t5, $s7) #copy old grid into current grid
        update_moves_undo #decrement moves
        update_score_undo #update score (just as it normally would)
        # print_str(undo_msg1)
        toggle_undo_off #set can_undo to 0
        # print_str(undo_msg2)
        show_moves
        show_score
        show_grid($t0)
        print_str(undo_msg)
        j main
skip_undo:
        restore_t_regs
        print_str(invalid_undo)
        j main

######################################## MOVEMENT ########################################

slide_left:
        allocate_new_grid($t5) #create new n*n grid of zeros
        sw $t5, old_grid #store previous grid in old_grid
        copy_grid($t0, $s7, $t5) #copy current grid to the newly allocated grid

        #perform slide-merge-slide
        slide_each_row_l($t0)
        merge_each_row_l($t0)
        slide_each_row_l($t0)

        allocate_res($t6) #allocate a byte for result for compare_grids
        compare_grids($t0, $s7, $t5, $t6) #compare grids
        lw $t7, 0($t6) #load result of compare_grids
        la $s4, goofy #load goofy flag
        lw $s6, 0($s4)
        bnez $s6, goofy_l #if goofy is on, get goofy
        j skip_goofy_l
goofy_l:
        jal get_goofy
skip_goofy_l:
        beqz $t7, no_slide #if t7 is 0, no merge occurred
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile gen flag
        beqz $t9, update_l #if tile gen is off, skip to updating the game 
        jal spawn_new_two #if tile gen is on, spawn a new two
update_l:
        update_moves
        show_moves
        show_score
        show_grid($t0)
        print_str(left)
        j main
slide_right:
        allocate_new_grid($t5) #create new n*n grid of zeros
        sw $t5, old_grid #store previous grid in old_grid
        copy_grid($t0, $s7, $t5) #copy current grid to the newly allocated grid

        #perform slide-merge-slide
        slide_each_row_r($t0)
        merge_each_row_r($t0)
        slide_each_row_r($t0)

        allocate_res($t6) #allocate a byte for result for compare_grids
        compare_grids($t0, $s7, $t5, $t6) #compare grids
        lw $t7, 0($t6) #load result of compare_grids
        beqz $t7, no_slide #if t7 is 0, no merge occurred
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile gen flag
        beqz $t9, update_r #if tile gen is off, skip to updating the game 
        jal spawn_new_two #if tile gen is on, spawn a new two
update_r:
        update_moves
        show_moves
        show_score
        show_grid($t0)
        print_str(right)
        j main

slide_up:
        allocate_new_grid($t5) #create new n*n grid of zeros
        sw $t5, old_grid #store previous grid in old_grid
        copy_grid($t0, $s7, $t5) #copy current grid to the newly allocated grid

        slide_each_row_u #perform a swipe up

        allocate_res($t6) #allocate a byte for result for compare_grids
        compare_grids($t0, $s7, $t5, $t6) #compare grids
        lw $t7, 0($t6) #load result of compare_grids
        beqz $t7, no_slide #if t7 is 0, no merge occurred
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile gen flag
        beqz $t9, update_u #if tile gen is off, skip to updating the game 
        jal spawn_new_two #if tile gen is on, spawn a new two
update_u:
        update_moves
        show_moves
        show_score
        show_grid($t0)
        print_str(up)
        j main
slide_down:
        allocate_new_grid($t5) #create new n*n grid of zeros
        sw $t5, old_grid #store previous grid in old_grid
        copy_grid($t0, $s7, $t5) #copy current grid to the newly allocated grid

        slide_each_row_d #perform a swipe down

        allocate_res($t6) #allocate a byte for result for compare_grids
        compare_grids($t0, $s7, $t5, $t6) #compare grids
        lw $t7, 0($t6) #load result of compare_grids
        beqz $t7, no_slide #if t7 is 0, no merge occurred
        la $t8, tile_gen_flag
        lw $t9, 0($t8) #load tile gen flag
        beqz $t9, update_d #if tile gen is off, skip to updating the game 
        jal spawn_new_two #if tile gen is on, spawn a new two
update_d:
        update_moves
        show_moves
        show_score
        show_grid($t0)
        print_str(down)
        j main

no_slide:
        show_moves
        show_score
        show_grid($t0)
        j main

end_game:
        print_str(ty) #print thank you screen
        print_str(cs21) #we love CS21

        #exit program
        li $v0, 10
        syscall

end_game_no_msg:
        # exit program
        li $v0, 10
        syscall

.data
        newline: .asciiz "\n"
        space: .asciiz " "
        prompt: .asciiz "Enter grid size: "
        hor_gl_single: .asciiz "+----"
        plus: .asciiz "+"
        ver_gl: .asciiz "|" # no space for fatter numbers (2 or 3 digits wide)
        vault_t: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 # just to save some values in case, kind of like a vault for t0, t9
        vault_s: .word 0, 0, 0, 0, 0, 0, 0, 0 # just to save some values in case, kind of like a vault for s0-s7
        move_prompt: .asciiz "Enter a move: "
        starting_grid: .asciiz "Starting Grid:\n"
        tile_gen_on_msg: .asciiz "Tile Generation: On\n"
        tile_gen_off_msg: .asciiz "Tile Generation: Off\n"
        controls_msg: .asciiz "\n~~~~~~~~ Game Controls ~~~~~~~~\n[W] - Swipe Up\n[A] - Swipe Left\n[S] - Swipe Down\n[D] - Swipe Right\n[Z] - Undo\n[G] - Enter Goofy Mode\n[R] - Enter Autopilot\n[3] - Turn Tile Generation Off\n[4] - Turn Tile Generation On\n\n[C] - Show Controls\n[H] - Show Help\n[G] - Enter Goofy Mode\n[X] - End Game\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
        help_msg: .asciiz "\n###################################################### 2048 ######################################################\n\nWelcome to 2048, A 2048 mutation where your goal is to reach the 2048 tile!\n\nTo play the game, first specify the size (n) of the grid, then simply press W/A/S/D to move all tiles to\none direction, and when two tiles of the same number touch, they merge into one!\nIf ever you forget the [C]ontrols or need [H]elp, feel free to press [C] or [H] at any point in the game!\n\nGoofy Mode - Get Goofy! This mode randomizes... everything?\n\nAutopilot - Let the game take over!\n\nP.S. Entering Goofy Mode with [G] and Autopilot with [R] will not let you exit those modes until the game ends.\n\nGood luck and have fun!\n\n##################################################################################################################\n\n"
        left:   .asciiz "Swiped Left\n"
        right:  .asciiz "Swiped Right\n"
        up:     .asciiz "Swiped Up\n"
        down:   .asciiz "Swiped Down\n"
        undo_msg:   .asciiz "Undo!\n"
        undo_msg1:   .asciiz "Undo! "
        undo_remaining: .word 0
        undo_msg2:   .asciiz "remaining.\n"
        invalid: .asciiz "Invalid Input\n"
        select_mode_msg: .asciiz "Select an option:\n[1] - New Game\n[2] - Start from a State\n[G] - Start in Goofy Mode\n[C] - Show Controls\n[H] - Show Help\n[X] - End Game\n\n"
        invalid_mode: .asciiz "Invalid Mode!\n"
        ty: .asciiz "\nThank you for playing!\n"
        #gl - gridline
        tile_gen_flag: .word 1
        cell_prompt: .asciiz "Enter value for cell "
        moves_msg: .asciiz "Moves: "
        moves: .word 0 #for keepign track of moves
        score_msg: .asciiz "Score: "
        score: .word 0, 0 #for keepign track of score; second element is for the previously added score
        old_grid: .word 0 #address for immediate previous grid 
        even_older_grids: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 #trying to make multi undos
        can_undo: .word 0 #flag for undoing to prevent going beyond 1 consecutive undos
        invalid_undo: .asciiz "Cannot undo! Make a swipe first!\n"
        grid_size_too_small: .asciiz "n must be greater than 0!\n"
        invalid_game_count: .word 1
        if_you_keep_doing_this_the_game_will_never_start_so_bibigyan_namin_kayo_ng_4x4: .asciiz "If you keep doing this the game will never start. Here, have a 4x4.\n"
        buffer: .space 2  
        main_msg: .asciiz "entered main!\n"
        continue_msg: .asciiz "Press Enter to Continue... "
        win_msg: .asciiz "Congratulations! You have reached the 2048 tile!\n"
        lose_msg: .asciiz "Game Over.\n"
        lose_msg2: .asciiz " __      __   ______   __    __         \n|  \\    /  \\ /      \\ |  \\  |  \\        \n \\$$\\  /  $$|  $$$$$$\\| $$  | $$        \n  \\$$\\/  $$ | $$  | $$| $$  | $$        \n   \\$$  $$  | $$  | $$| $$  | $$        \n    \\$$$$   | $$  | $$| $$  | $$        \n    | $$    | $$__/ $$| $$__/ $$        \n    | $$     \\$$    $$ \\$$    $$        \n     \\$$      \\$$$$$$   \\$$$$$$         \n                                        \n                                        \n                                        \n __        ______    ______   ________  \n|  \\      /      \\  /      \\ |        \\ \n| $$     |  $$$$$$\\|  $$$$$$\\| $$$$$$$$ \n| $$     | $$  | $$| $$___\\$$| $$__     \n| $$     | $$  | $$ \\$$    \\ | $$  \\    \n| $$     | $$  | $$ _\\$$$$$$\\| $$$$$    \n| $$_____| $$__/ $$|  \\__| $$| $$_____  \n| $$     \\\\$$    $$ \\$$    $$| $$     \\ \n \\$$$$$$$$ \\$$$$$$   \\$$$$$$  \\$$$$$$$$ \n"
        cs21: .asciiz " ______           __   ______          \n|      \\         /  \\ /      \\         \n \\$$$$$$        /  $$|  $$$$$$\\        \n  | $$         /  $$  \\$$__| $$        \n  | $$        |  $$    |     $$        \n  | $$         \\$$\\   __\\$$$$$\\        \n _| $$_         \\$$\\ |  \\__| $$        \n|   $$ \\         \\$$\\ \\$$    $$        \n \\$$$$$$          \\$$  \\$$$$$$         \n                                       \n                                       \n                                       \n  ______    ______    ______     __    \n /      \\  /      \\  /      \\  _/  \\   \n|  $$$$$$\\|  $$$$$$\\|  $$$$$$\\|   $$   \n| $$   \\$$| $$___\\$$ \\$$__| $$ \\$$$$   \n| $$       \\$$    \\  /      $$  | $$   \n| $$   __  _\\$$$$$$\\|  $$$$$$   | $$   \n| $$__/  \\|  \\__| $$| $$_____  _| $$_  \n \\$$    $$ \\$$    $$| $$     \\|   $$ \\ \n  \\$$$$$$   \\$$$$$$  \\$$$$$$$$ \\$$$$$$ \n"
        ascii2: .asciiz "______           __   ______          \n|      \\         /  \\ /      \\         \n \\$$$$$$        /  $$|  $$$$$$\\        \n  | $$         /  $$  \\$$__| $$        \n  | $$        |  $$    |     $$        \n  | $$         \\$$\\   __\\$$$$$\\        \n _| $$_         \\$$\\ |  \\__| $$        \n|   $$ \\         \\$$\\ \\$$    $$        \n \\$$$$$$          \\$$  \\$$$$$$         \n                                       \n                                       \n                                       \n  ______    ______    ______     __    \n /      \\  /      \\  /      \\  _/  \\   \n|  $$$$$$\\|  $$$$$$\\|  $$$$$$\\|   $$   \n| $$   \\$$| $$___\\$$ \\$$__| $$ \\$$$$   \n| $$       \\$$    \\  /      $$  | $$   \n| $$   __  _\\$$$$$$\\|  $$$$$$   | $$   \n| $$__/  \\|  \\__| $$| $$_____  _| $$_  \n \\$$    $$ \\$$    $$| $$     \\|   $$ \\ \n  \\$$$$$$   \\$$$$$$  \\$$$$$$$$ \\$$$$$$ \n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
        win_ascii: .asciiz " __      __   ______   __    __  \n|  \\    /  \\ /      \\ |  \\  |  \\ \n \\$$\\  /  $$|  $$$$$$\\| $$  | $$ \n  \\$$\\/  $$ | $$  | $$| $$  | $$ \n   \\$$  $$  | $$  | $$| $$  | $$ \n    \\$$$$   | $$  | $$| $$  | $$ \n    | $$    | $$__/ $$| $$__/ $$ \n    | $$     \\$$    $$ \\$$    $$ \n     \\$$      \\$$$$$$   \\$$$$$$  \n                                 \n                                 \n                                 \n __       __  ______  __    __   \n|  \\  _  |  \\|      \\|  \\  |  \\  \n| $$ / \\ | $$ \\$$$$$$| $$\\ | $$  \n| $$/  $\\| $$  | $$  | $$$\\| $$  \n| $$  $$$\\ $$  | $$  | $$$$\\ $$  \n| $$ $$\\$$\\$$  | $$  | $$\\$$ $$  \n| $$$$  \\$$$$ _| $$_ | $$ \\$$$$  \n| $$$    \\$$$|   $$ \\| $$  \\$$$  \n \\$$      \\$$ \\$$$$$$ \\$$   \\$$  \n"
        new_size: .word 0
        goofy: .word 0
        goofy_on: .asciiz "You have entered Goofy Mode, there is no turning back.\n\n"
        goofy_art: .asciiz "                .;;;.\n               :;;;;:'   .;\n              :;;: .;;;',;;;; ;:\n              :: ,;;;;`;;;:'::;;:,\n               :;;;;;; ;;,$$$c` $L\n               ;;;;;;;`: $$$$$h $$:\n              :;;;;;;;,`J$$$$$$h$$$>\n              ;;;;`;';;`3$$$$$$$$$$N\n              ;;',;:;;;`3$$$$$$$$$$$>                  cc,\n              ',;',;;;;,?$$$$$$$$$$$>                cCC''C\n             .;'.:;;';;:'$$$$$$$$$$$E               cCCC;'>\n           ,;` ';;',$nn`:?$$$$$$$$$$f               CCCCcC\n         ,;`    ':'$$$$$  ?$$$F ?>  >           zdF CCCCC\n        ;;`       '$$???$L ?$P  '  .,ur .d$$ u$$$$$ CCC\",\n      :;;;         $x$h\"i7$L\"h  d$$$F.d$$$\":$$$$$$$$,,c$$\n     :;;;          ?$$$k`$$$$fd$$$$ d$$$$ d$$$$$$$$$$$$$F;$L\n     ;;;'           ?$$$L`$$$$$$$$k$$$$$b$$$$$$$$$$$$$$F;$$E\n    :;;;`          c`\"$$$h`$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n    ;;;;`         cC $$$$$h \"$$$$$$$$$$$$$$$$$FJ$$$P $$$$\"\n   ,;;;;`        ,C $$$$$$$$h \"?$$$$$$$$$$$Cd$.$$F d$P\"\n   :;;;;`       ,C'9$$$$$$$$$$$u '\"?$$$$$$$$$F\"  .,cc>\n   :;;;;'       CC $$$$$$$$$$h'?$$$-....         d$R\"\n   :;;;;;       CC,'$$$$$$$$$$\" ::  $$$$\"\n   ';;;;;       \"CCc  \"\"\"\"\"    :;;\n    :;;;;`        'CC          :;;'\n    `:::'                      ;;;\n                              :;;;\n                             ';;;;\n                             ';;:\n                              `\nCredits to Allen Mullen for the ASCII art. Taken from https://ascii.co.uk/art/goofy\n\n"
        autopilot_flag: .word 0
        autopilot_msg: .asciiz "Autopilot turned on!\n"
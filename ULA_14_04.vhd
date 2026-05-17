----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:14:37 05/12/2026 
-- Design Name: 
-- Module Name:    ULA_Spartan3 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


-- Entity definition with the inputs and outputs
entity ULA_Spartan3 is
    Port (
        clk         : in STD_LOGIC;                         -- Board clock
        btn_confirm : in STD_LOGIC;                         -- Button confirm (South Button)
        SW          : in STD_LOGIC_VECTOR (3 downto 0);     -- Input switches
        led_flags   : out STD_LOGIC_VECTOR (3 downto 0);    -- LEDs for Zero, Negative, Carry and Overflow flags 
        led_result  : out STD_LOGIC_VECTOR (3 downto 0)     -- LEDs for the 4 bit results
    );
end ULA_Spartan3;


architecture Behavioral of ULA_Spartan3 is


    -- State Machine definitions 
    type state_t is (S_WAIT_OPCODE, S_WAIT_OPCODE_CONFIRM,
                     S_WAIT_OPERAND_A, S_WAIT_OPERAND_A_CONFIRM,
                     S_CHECK_OPCODE,
                     S_WAIT_OPERAND_B_OR_N, S_WAIT_OPERAND_B_OR_N_CONFIRM,
                     S_CALCULATE_DISPLAY);
    signal current_state, next_state: state_t := S_WAIT_OPCODE;


    -- Debounce parameters to mitigate the debouncing in the mechanical button
    constant DEBOUNCE_LIMIT : integer := 10000000; --we tested this value
    signal btn_counter      : integer range 0 to DEBOUNCE_LIMIT := 0;
    signal btn_pressed_edge : std_logic := '0';
    signal btn_prev         : std_logic := '0';


    -- Registers to save user input
    signal reg_opcode    : std_logic_vector(2 downto 0) := "000"; --the opcode is only three bits because is eight operations
    signal reg_operand_a : std_logic_vector(3 downto 0) := "0000"; --four bits for A
    signal reg_operand_b : std_logic_vector(3 downto 0) := "0000"; --four bits for B


    -- Clock enables for ther registers
    signal load_opcode_en : std_logic := '0';
    signal load_op_a_en   : std_logic := '0';
    signal load_op_b_en   : std_logic := '0';


    -- Calculated results and outputs
    signal calc_result : std_logic_vector(3 downto 0);
    signal calc_flag_z : std_logic;
    signal calc_flag_n : std_logic;
    signal calc_flag_c : std_logic;
    signal calc_flag_v : std_logic;


begin


    -- Debounce Logic: Cleans the mechanical button bouncing 
    debounce_proc: process(clk)
    begin
        --The code will only run when it detects the rising edge of the clock
        if rising_edge(clk) then
            btn_pressed_edge <= '0'; -- The button state is 0, default to no pulse
            
            --If it detects a state 1 in the rising edge of the clock then
            if btn_confirm = '1' then
                --If the btn counter isn't equal to the debounce limit
                if btn_counter < DEBOUNCE_LIMIT then
                    --The btn counter will add 1 for each state equals 1 that the code reads
                    btn_counter <= btn_counter + 1;
                elsif btn_prev = '0' then --If the previous state of the button was 0
                    btn_pressed_edge <= '1'; -- Generate a single clean pulse 1
                    btn_prev <= '1'; -- Register that the previous state is now 1
                end if;
            else
                btn_counter <= 0; --resets btn_counter
                btn_prev <= '0'; --resets btn_prev
            end if;
        end if;
    end process;


    -- Synchronous Process: Updates State and Registers (state machine)
  
    sync_proc: process(clk)
    begin
        if rising_edge(clk) then --only reads the rising edge of the clock
            current_state <= next_state; -- advance for the next state


            -- Load values into memory ONLY when authorized by the FSM (if the load opcodes are 1)
            if load_opcode_en = '1' then -- if the enable of the operation code equals 1, then register the switches states
                reg_opcode <= SW(2 downto 0); -- saves the switches states to the operation code register
            end if;
            if load_op_a_en = '1' then -- if the enable of the operation A equals 1, then saves the switch states of A to the register A
                reg_operand_a <= SW;
            end if;
            if load_op_b_en = '1' then -- if the enable of the operation B equals 1, then saves the switch state of B to the register B
                reg_operand_b <= SW;
            end if;
        end if;
    end process;

    -- Combinational Finite State Machine Logic: Next State & Enables 
   
    fsm_comb_logic_proc: process(current_state, btn_pressed_edge,  sreg_opcode)
    begin
        --the fsm function will detect any changes to the variables listed between parenthesis
        --default assignments to prevent inferred latches
        
        next_state <= current_state;
        load_opcode_en <= '0';
        load_op_a_en   <= '0';
        load_op_b_en   <= '0';

        --case structure will check which state the fsm is operating on
        case current_state is
            when S_WAIT_OPCODE => --if the fsm is waiting for the operation code then
                if btn_pressed_edge = '1' then --if the user press the button
                    next_state <= S_WAIT_OPCODE_CONFIRM; --confirm that the opcode was inserted by the user
                end if;
                
            when S_WAIT_OPCODE_CONFIRM => --if the fsm received the opcode then
                load_opcode_en <= '1'; --the enable of the opcode is 1
                next_state <= S_WAIT_OPERAND_A; -- the next state will wait for A
            
            when S_WAIT_OPERAND_A => -- if the fsm is waiting for A then
                if btn_pressed_edge = '1' then -- if the user pressed the button
                    next_state <= S_WAIT_OPERAND_A_CONFIRM; --confirm that A was inserted by the user
                end if;
                
            when S_WAIT_OPERAND_A_CONFIRM => --if the fsm received A then
                load_op_a_en <= '1'; --the enable of A is 1
                next_state <= S_CHECK_OPCODE; --the next state will check which operation code was used


            when S_CHECK_OPCODE =>
                -- INC (010) and NEG (110) only require one operand 
                -- if it was inc or neg then
                if reg_opcode = "010" or reg_opcode = "110" then
                    next_state <= S_CALCULATE_DISPLAY; --the next_state will show the result
                else
                    next_state <= S_WAIT_OPERAND_B_OR_N; --if it isn't one of these operations the fsm will wait for B
                end if;


            when S_WAIT_OPERAND_B_OR_N => --the FSM is waiting for B or N
                if btn_pressed_edge = '1' then
                    next_state <= S_WAIT_OPERAND_B_OR_N_CONFIRM; --if the user pressed the button then go to the next state
                end if;
                
            when S_WAIT_OPERAND_B_OR_N_CONFIRM => 
                load_op_b_en <= '1'; -- the B enable is 1
                next_state <= S_CALCULATE_DISPLAY; -- the result will be displayed in the LEDS


            when S_CALCULATE_DISPLAY => --the result was displayed
                if btn_pressed_edge = '1' then --if the user presses the button then
                    next_state <= S_WAIT_OPCODE; -- restart the operation sequence of the fsm
                end if;
                
            when others =>
                next_state <= S_WAIT_OPCODE; --resets
        end case;
    end process;


    -- 4. Arithmetic Logic Unit (Combinational Core) 

    --if opcode, or a, or b changes calculate again
    calculation_proc: process(reg_opcode, reg_operand_a, reg_operand_b)
        variable add_in_A   : std_logic_vector(3 downto 0);
        variable add_in_B   : std_logic_vector(3 downto 0);
        variable add_cin    : std_logic;
        variable c        : std_logic_vector(3 downto 0); -- Fios do Carry interno
        variable sum      : std_logic_vector(3 downto 0); -- Resultado da soma
        
        -- variables to export the results
        variable res_4bit : std_logic_vector(3 downto 0);
        variable v_flag_v : std_logic;
        variable out_c    : std_logic;

    begin
       
    ----------------------------------------------------------------------------------------
    -- =====================================================================================
    -- ALU TRUTH TABLE
    -- =====================================================================================
    -- Opcode | Operation | Description              | Results (4 bits) | Flags
    -- -------|----------|------------------------|--------------------|--------------------
    --  000   | ADD      | Sum A + B             | A + B              | Z, N, C, V
    --  001   | SUB      | Subtraction A - B        | A - B              | Z, N, C, V
    --  010   | INC      | Increment A (A + 1)   | A + 1              | Z, N, C=0, V
    --  011   | OR       | OR (A or B)     | A or B             | Z, N, C=0, V=0
    --  100   | AND      | AND (A and B)     | A and B            | Z, N, C=0, V=0
    --  101   | XOR      | XOR (A xor B)   | A xor B            | Z, N, C=0, V=0
    --  110   | NEG      | Invert (2 comp) | (not A) + 1        | Z, N, C=0, V
    --  111   | SHL      | Shift left  | A(2 downto 0) & '0'| Z, N, C(MSB de A), V=0
    --
    -- LEGENDA DAS FLAGS DE STATUS:
    -- [Z] Zero     : Receives 1 if the final result is '0000'
    -- [N] Negative : Receives the MSB of the Result (Result(3)).
    -- [C] Carry    : Receives the Carry from the operations or the MSB from the SHL.
    -- [V] Overflow : Receives 1 if the operations overflows the 2 complement (-8 to +7).
    -- =====================================================================================
    ----------------------------------------------------------------------------------------

        case reg_opcode is 
            when "000" => -- ADD: A + B
                add_in_A := reg_operand_a;
                add_in_B := reg_operand_b;
                add_cin  := '0';
                
            when "001" => -- SUB: A + (not B) + 1
                add_in_A := reg_operand_a;
                add_in_B := not reg_operand_b;
                add_cin  := '1';
                
            when "010" => -- INC: A + 0 + 1
                add_in_A := reg_operand_a;
                add_in_B := "0000";
                add_cin  := '1';
                
            when "110" => -- NEG: (not A) + 0 + 1
                add_in_A := not reg_operand_a;
                add_in_B := "0000";
                add_cin  := '1';
                
            when others => -- Para as lógicas, o somador fica ocioso
                add_in_A := "0000";
                add_in_B := "0000";
                add_cin  := '0';
        end case;

        --full adder
        -------------------------------------------------------------------------
        -- ======================================================================
        -- 3-BIT XOR GATE TRUTH TABLE (FULL ADDER SUM LOGIC)
        -- ======================================================================
        -- The XOR gate acts as an "Odd Parity Checker". 
        -- The output (S) will be '1' ONLY if there is an ODD number of '1's 
        -- among the inputs (A, B, Cin).
        -- ----------------------------------------------------------------------
        --   A   |   B   |  Cin  |  S (A xor B xor Cin)
        -- ------|-------|-------|-----------------------
        --   0   |   0   |   0   |          0
        --   0   |   0   |   1   |          1
        --   0   |   1   |   0   |          1
        --   0   |   1   |   1   |          0
        --   1   |   0   |   0   |          1
        --   1   |   0   |   1   |          0
        --   1   |   1   |   0   |          0
        --   1   |   1   |   1   |          1
        -- ======================================================================
        -------------------------------------------------------------------------

        -- bit 0
        sum(0) := add_in_A(0) xor add_in_B(0) xor add_cin; 

        --if A and B equals 1, in the sum we will need a carry
        -- or if A or B equals 1, but if add_cin (the carry) is 1, then A (or B) + 1 will result 1 + carry
        c(0)   := (add_in_A(0) and add_in_B(0)) or (add_cin and (add_in_A(0) xor add_in_B(0)));

        -- bit 1
        sum(1) := add_in_A(1) xor add_in_B(1) xor c(0);
        c(1)   := (add_in_A(1) and add_in_B(1)) or (c(0) and (add_in_A(1) xor add_in_B(1)));
        
        -- bit 2
        sum(2) := add_in_A(2) xor add_in_B(2) xor c(1);
        c(2)   := (add_in_A(2) and add_in_B(2)) or (c(1) and (add_in_A(2) xor add_in_B(2)));
        
        -- bit 3
        sum(3) := add_in_A(3) xor add_in_B(3) xor c(2);
        c(3)   := (add_in_A(3) and add_in_B(3)) or (c(2) and (add_in_A(3) xor add_in_B(3)));

        -- 3. MULTIPLEXADOR DE SAÍDA E CÁLCULO DAS FLAGS V E C
        v_flag_v := '0';
        out_c    := '0';

        case reg_opcode is 
            when "000" | "001" | "010" | "110" => -- arithmetical operations
                res_4bit := sum;
                out_c    := c(3); -- carry flag is the c(3) of sum(3) (carry of the MSB)
                
                -- overflow for arithmetical operations
                -- if the most significant bit for A and B have the same signal but the most significant of A is different from the most
                -- significant bit of the result, it's a overflow
                -- example: 5 = 0101 and 4 = 0100
                -- 5 + 4 -> 0101 + 0100 = 1001
                -- 1001 == -7 in two complement's (overflow)

                if (add_in_A(3) = add_in_B(3)) and (add_in_A(3) /= sum(3)) then
                    v_flag_v := '1';
                end if;

            when "011" => -- OR 
                res_4bit := reg_operand_a or reg_operand_b;

            when "100" => -- AND 
                res_4bit := reg_operand_a and reg_operand_b;

            when "101" => -- XOR 
                res_4bit := reg_operand_a xor reg_operand_b;

            when "111" => -- SHL (Shifter left)
                res_4bit := reg_operand_a(2 downto 0) & '0'; -- extracts the bits 2, 1 and 0 and concatenats an 0 to their right or least significant bit
                out_c    := reg_operand_a(3); -- the carry captures the most significant bit that was shifted

            when others =>
                res_4bit := "0000"; --default
        end case;


        -- Assign calculated values to combinational signals
        calc_result <= res_4bit; --saves the 4 bit results
        calc_flag_c <= out_c; --save the out_carry result (1 or 0)
        calc_flag_n <= res_4bit(3); --save the most significant bit of the number
        calc_flag_v <= v_flag_v; --save the overflow flag


        -- Zero Flag calculation
        -- if the whole 4 bit number is 0, then the zero flag is 1
        if res_4bit = "0000" then
            calc_flag_z <= '1';
        else
            calc_flag_z <= '0';
        end if;
    end process;


   
    -- 5. LED Driver logic 
    
    led_driver_proc: process(current_state, calc_flag_z, calc_flag_n, calc_flag_c, calc_flag_v, calc_result)
    begin
        -- Default to off
        led_flags  <= "0000";
        led_result <= "0000";


        case current_state is
            when S_WAIT_OPCODE => 
                led_result(0) <= '1'; -- LED 0 indicates waiting for Opcode
            when S_WAIT_OPCODE_CONFIRM => 
                led_result(1) <= '1'; -- LED 1 confirms
            when S_WAIT_OPERAND_A => 
                led_result(2) <= '1'; -- LED 2 indicates waiting for Operand A
            when S_WAIT_OPERAND_A_CONFIRM => 
                led_result(3) <= '1'; -- LED 3 confirms
            when S_CHECK_OPCODE => 
                led_flags(0) <= '1';
            when S_WAIT_OPERAND_B_OR_N => 
                led_flags(1) <= '1';  -- LED indicates waiting for Operand B
            when S_WAIT_OPERAND_B_OR_N_CONFIRM => 
                led_flags(2) <= '1';
            when S_CALCULATE_DISPLAY =>
                -- Show Final Result and Flags!
                led_flags(3) <= calc_flag_z;
                led_flags(2) <= calc_flag_n;
                led_flags(1) <= calc_flag_c;
                led_flags(0) <= calc_flag_v;
                led_result   <= calc_result;
            when others =>
                led_flags  <= "1111";
                led_result <= "1111";
        end case;
    end process;


end Behavioral;
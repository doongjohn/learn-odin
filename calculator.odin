package main

// TODO:
// - [x] multi-digit numbers
// - [x] +- prefixed numbers
// - [x] floating point numbers
// - [x] operator precedence
// - [x] grouping with parentheses
// - [x] predefined constants
// - [ ] custom math functions

// References:
// https://en.wikipedia.org/wiki/Shunting-yard_algorithm
// https://en.wikipedia.org/wiki/Operator-precedence_parser

import "core:io"
import "core:os"
import "core:math"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:unicode/utf8"

main :: proc() {
    for {
        fmt.print("calculator > ")

        input_builder := read_from_stdin()
        defer strings.destroy_builder(&input_builder)

        input := strings.trim_space(strings.to_string(input_builder))
        if input == "exit" {
            return
        }

        result, ok := calculate(input)
        if ok {
            fmt.printf("[result]: {:.6f}\n", result)
        }
        fmt.println()
    }
}

calculate :: proc(input: string) -> (result: f32, ok: bool) {
    print_error_prefix :: proc(input: string, pos: ^int) {
        fmt.printf("[error]: {}\n", input)
        for _ in 0 .. pos^ + len("[error]:") { fmt.print(" ") }
        fmt.print("└> ")
    }

    parse_const :: proc(str: string, sign: bool) -> (i: int, num: f32, is_valid: bool) {
        // parse predefined constants
        // return: i      => index where parsing is ended   
        // return: num    => value of the constant
        // return: is_valid => is an input successfully parsed as constant

        str_len := len(str)

        if str_len == 0 {
            return 0, 0, false
        }

        if sign && strings.index_byte(".0123456789*/^", str[0]) >= 0 {
            return 0, 0, false
        }

        if !sign && strings.index_byte(".0123456789+-*/^", str[0]) >= 0 {
            return 0, 0, false
        }

        for i < str_len - 1 {
            i += 1
            if strings.index_byte("+-*/^ ", str[i]) >= 0 {
                i -= 1
                break
            }
        }
        i += 1

        switch str[:i] {
        case "pi", "+pi":
            return i, 3.141592, true
        case "-pi":
            return i, -3.141592, true
        
        case "e", "+e":
            return i, 2.71828182846, true
        case "-e":
            return i, -2.71828182846, true
        }
        return 0, 0, false
    }

    parse_number :: proc(str: string) -> (i: int, num: f32, is_num: bool) {
        // parse string as f32 number
        // NOTE: +- prefix is part of the number
        // return: i      => index where parsing is ended
        // return: num    => parsed number
        // return: is_num => is an input successfully parsed as f32

        str_len := len(str)

        // check +- prefix
        if strings.index_byte("+-", str[0]) >= 0 && (str_len == 1 || strings.index_byte(".0123456789", str[1]) < 0) {
            return 0, 0, false
        }
        
        for i < str_len {
            i += 1
            num, is_num = strconv.parse_f32(str[:i]) // can be optimized
            if !is_num {
                if i == 1 {
                    return 0, 0, false
                } else {
                    return i - 1, num, true
                }
            }
        }

        return i, num, true
    }

    parse_paren :: proc(str: string) -> (i: int, is_matched: bool) {
        // parse parentheses
        // return: i          => index where parsing is ended
        // return: is_matched => is parentheses match

        str_len := len(str)
        opened: uint = 1

        if str_len < 2 || str[0] != '(' {
            return 0, false
        }

        for i < str_len - 1 {
            i += 1

            if opened == 0 {
                return i, true
            }

            if str[i] == '(' {
                opened += 1
                continue
            }

            if str[i] == ')' {
                opened -= 1
                if opened < 0 {
                    return i, false
                }
                continue
            }
        }

        if opened == 0 {
            return i + 1, true
        }
        return i + 1, false
    }

    // calculation functions
    calc_add :: proc(nums: [2]f32) -> f32 { return nums[0] + nums[1] }
    calc_sub :: proc(nums: [2]f32) -> f32 { return nums[0] - nums[1] }
    calc_mul :: proc(nums: [2]f32) -> f32 { return nums[0] * nums[1] }
    calc_div :: proc(nums: [2]f32) -> f32 { return nums[0] / nums[1] }
    calc_pow :: proc(nums: [2]f32) -> f32 { return math.pow(nums[0], nums[1]) }

    // parentheses data
    paren_sign: f32 = 1

    // number data
    nums_i := -1
    nums := [2]f32{0, 0}
    prev_was_num := false

    // func precedence top
    func_top: proc(nums: [2]f32) -> f32

    // func precedence 1
    func1_lhs: f32
    func1: proc(nums: [2]f32) -> f32

    // func precedence 0
    func0_lhs: f32
    func0: proc(nums: [2]f32) -> f32

    pos, offset := 0, 0
    ch: u8
    if len(input) == 0 {
        print_error_prefix(input, &pos)
        fmt.print("No input.\n")
        return 0, false
    }

    // loop
    for pos < len(input) {
        // increase position
        defer {
            pos += offset == 0 ? 1 : offset
            offset = 0
        }

        // current byte
        ch = input[pos]

        // DEBUG
        // fmt.printf("[{}], char: {}\n", pos, input[pos:pos+1])
        
        // ignore space
        if ch == ' ' { continue }

        // parse +- prefixed parentheses
        paren_sign = 1
        if !prev_was_num && pos < len(input) - 1 && strings.index_byte("+-", ch) >= 0 && input[pos+1] == '(' {
            pos += 1
            if ch == '-' { paren_sign = -1 }
            ch = input[pos]
        }

        // parse parentheses
        if ch == '(' {
            if prev_was_num {
                print_error_prefix(input, &pos)
                fmt.print("Expected infix operator before the parentheses.\n")
                return 0, false
            }

            paren_offset, is_matched := parse_paren(input[pos:])
            if is_matched {
                offset = paren_offset
                
                // DEBUG
                // fmt.println(input[pos+1:pos+paren_offset-1])
                
                paren_result, paren_ok := calculate(input[pos+1:pos+paren_offset-1])
                if paren_ok {
                    // update numbers
                    nums_i += 1
                    nums[nums_i] = paren_sign * paren_result
                    prev_was_num = true
                    continue
                } else {
                    print_error_prefix(input, &pos)
                    fmt.print("Expression does not return a number.\n")
                    return 0, false
                }
            } else {
                print_error_prefix(input, &pos)
                fmt.print("Unmatched parentheses.\n")
                return 0, false
            }
        }
        

        // parse constant
        const_offset, const_num, is_const := parse_const(input[pos:], !prev_was_num)

        if is_const {
            offset = const_offset
            // check infix operator
            if prev_was_num {
                print_error_prefix(input, &pos)
                fmt.printf("Expected infix operator before the number \"{}\".\n", input[pos:pos+offset])
                return 0, false
            }
            // update numbers
            nums_i += 1
            nums[nums_i] = const_num
            prev_was_num = true
            continue
        }

        // parse number
        num_offset, num, is_num := parse_number(input[pos:])

        // check +- operator
        if nums_i == 0 && func_top == nil && strings.index_byte("+-", ch) >= 0 {
            is_num = false
        }

        if is_num {
            // set offset
            offset = num_offset

            // DEBUG
            // fmt.println(input[pos:pos+offset])

            // update numbers
            nums_i += 1
            nums[nums_i] = num
            prev_was_num = true

            // if there are 2 numbers
            if nums_i == 1 {
                // reset nums length
                nums_i = 0

                // check valid infix operator
                if func_top == nil {
                    print_error_prefix(input, &pos)
                    fmt.printf("Expected infix operator before the number \"{}\".\n", input[pos:pos+offset])
                    return 0, false
                }

                // calculate top precedence operator
                nums[0] = func_top(nums)
                func_top = nil
            }
        } else {
            // check valid operator
            if (strings.index_byte("+-*/^", ch) < 0) {
                print_error_prefix(input, &pos)
                fmt.printf("\"{}\" is not a valid operator.\n", input[pos:pos+1])
                return 0, false
            }

            // check valid infix function
            if nums_i < 0 || !prev_was_num {
                print_error_prefix(input, &pos)
                fmt.print("Expected number before the infix operator.\n")
                return 0, false
            }

            // calculate precedence 1
            if strings.index_byte("+-*/", ch) >= 0 && func1 != nil {
                nums[0] = func1([2]f32{func1_lhs, nums[0]})
                func1 = nil
            }

            // calculate precedence 0
            if strings.index_byte("+-", ch) >= 0 && func0 != nil {
                nums[0] = func0([2]f32{func0_lhs, nums[0]})
                func0 = nil
            }

            // reset nums index
            if strings.index_byte("+-*/", ch) >= 0 {
                nums_i = -1
            }

            // set calculation function
            switch ch {
            case '+':
                func0_lhs = nums[0]
                func0 = calc_add
            case '-':
                func0_lhs = nums[0]
                func0 = calc_sub
            case '*':
                func1_lhs = nums[0]
                func1 = calc_mul
            case '/':
                func1_lhs = nums[0]
                func1 = calc_div
            case '^':
                func_top = calc_pow
            }

            prev_was_num = false
        }
    }

    // calculate top precedence operator
    if func_top != nil && nums_i == 1 {
        nums[0] = func_top(nums)
        func_top = nil
    }

    // check valid infix function
    if func_top != nil || (func_top == nil && nums_i < 0) {
        pos_high := len(input) - 1
        print_error_prefix(input, &pos_high)
        fmt.print("Expected number after the infix operator.\n")
        return 0, false
    }

    // calculate precedence 1
    if func1 != nil {
        nums[0] = func1([2]f32{func1_lhs, nums[0]})
    }

    // calculate precedence 0
    if func0 != nil {
        nums[0] = func0([2]f32{func0_lhs, nums[0]})
    }

    // return calculation result
    return nums[0], true
}

read_from_stdin :: proc() -> strings.Builder {
    stdin_stream := os.stream_from_handle(os.stdin)
    stdin_reader := io.to_byte_reader(stdin_stream)
    input_builder := strings.make_builder_none()

    ch: u8
    err: io.Error
    for {
        ch, err = io.read_byte(stdin_reader)
        if ch == '\n' || err != .None { break }
        strings.write_byte(&input_builder, ch)
    }

    return input_builder
}
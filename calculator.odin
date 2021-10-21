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
        fmt.print("calculator >>> ")

        input_builder := read_from_stdin()
        defer strings.destroy_builder(&input_builder)

        input := strings.trim_space(strings.to_string(input_builder))
        switch input {
        case "exit", "quit":
            return
        case "test":
            test_calculate("10", 10)
            test_calculate("1 + 2", 3)
            test_calculate("2 * (2 + 10)", 24)
            test_calculate("10 * pi * 2", 10 * math.PI * 2)
        case:
            print_calculate(input)
        }
    }
}

test_calculate :: proc(input: string, expected_res: f64) {
    fmt.println(input)
    result, ok := calculate(input)
    if ok {
        fmt.printf("[result]: {:.6f}\n", result)
        if result == expected_res {
            fmt.println("[test]: passed\n")
            return
        }
    }
    fmt.println("[test]: failed\n")
}

print_calculate :: proc(input: string) {
    result, ok := calculate(input)
    if ok {
        fmt.printf("[result]: {:.6f}\n", result)
    }
    fmt.println()
}

calculate :: proc(input: string) -> (result: f64, ok: bool) {
    print_error_prefix :: proc(input: string, pos: ^int) {
        fmt.printf("[error]: {}\n", input)
        for _ in 0 .. pos^ + len("[error]:") { fmt.print(" ") }
        fmt.print("└> ")
    }

    parse_const :: proc(str: string, sign: bool) -> (i: int, num: f64, is_valid: bool) {
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
            return i, math.PI, true
        case "-pi":
            return i, -math.PI, true
        
        case "tau", "+tau":
            return i, math.TAU, true
        case "-tau":
            return i, -math.TAU, true

        case "e", "+e":
            return i, math.E, true
        case "-e":
            return i, -math.E, true
        }
        return 0, 0, false
    }

    parse_number :: proc(str: string, sign: bool) -> (i: int, num: f64, is_num: bool) {
        // parse string as f64 number
        // NOTE: +- prefix is part of the number
        // return: i      => index where parsing is ended
        // return: num    => parsed number
        // return: is_num => is an input successfully parsed as f64

        str_len := len(str)

        if !sign && strings.index_byte("+-", str[0]) >= 0 {
            return 0, 0, false
        }

        // check +- prefix
        if sign && strings.index_byte("+-", str[0]) >= 0 && (str_len == 1 || strings.index_byte(".0123456789", str[1]) < 0) {
            return 0, 0, false
        }
        
        for i < str_len {
            i += 1
            num, is_num = strconv.parse_f64(str[:i]) // can be optimized
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

    // input data
    input_len := len(input)
    input_high := input_len - 1
    pos, offset, ch := 0, 0, u8(0)
    if input_len == 0 {
        print_error_prefix(input, &pos)
        fmt.print("No input.\n")
        return 0, false
    }

    // parentheses data
    paren_sign: f64 = 1

    // number data
    nums_i := -1
    nums := [2]f64{0, 0}
    prev_was_num := false

    // calculation functions
    calc_add :: proc(nums: [2]f64) -> f64 { return nums[0] + nums[1] }
    calc_sub :: proc(nums: [2]f64) -> f64 { return nums[0] - nums[1] }
    calc_mul :: proc(nums: [2]f64) -> f64 { return nums[0] * nums[1] }
    calc_div :: proc(nums: [2]f64) -> f64 { return nums[0] / nums[1] }
    calc_pow :: proc(nums: [2]f64) -> f64 { return math.pow(nums[0], nums[1]) }

    // func precedence top
    func_top: proc(nums: [2]f64) -> f64

    // func precedence 1
    func1_lhs: f64
    func1: proc(nums: [2]f64) -> f64

    // func precedence 0
    func0_lhs: f64
    func0: proc(nums: [2]f64) -> f64

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

        // parse parentheses
        {
            paren_sign = 1
            if !prev_was_num && pos < input_high && strings.index_byte("+-", ch) >= 0 && input[pos+1] == '(' {
                pos += 1
                if ch == '-' { paren_sign = -1 }
                ch = input[pos]
            }
            if ch == '(' {
                if prev_was_num {
                    print_error_prefix(input, &pos)
                    fmt.print("Expected infix operator before the expression.\n")
                    return 0, false
                }

                parse_len, is_matched := parse_paren(input[pos:])
                if is_matched {
                    offset = parse_len
                    
                    // DEBUG
                    // fmt.println(input[pos+1:pos+parse_len-1])
                    
                    paren_result, paren_ok := calculate(input[pos+1:pos+parse_len-1])
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
        }

        // parse constant
        {
            parse_len, parse_res, ok := parse_const(input[pos:], !prev_was_num)
            if ok {
                offset = parse_len

                // check infix operator
                if prev_was_num {
                    print_error_prefix(input, &pos)
                    fmt.printf("Expected infix operator before the number \"{}\".\n", input[pos:pos+offset])
                    return 0, false
                }
                
                // add number
                nums_i += 1
                nums[nums_i] = parse_res
                prev_was_num = true
                continue
            }
        }
        
        // parse number
        {
            parse_len, parse_res, ok := parse_number(input[pos:], !prev_was_num)
            if ok {
                offset = parse_len

                // DEBUG
                // fmt.println(input[pos:pos+offset])

                // add number
                nums_i += 1
                nums[nums_i] = parse_res
                prev_was_num = true

                // if there are 2 numbers
                if nums_i == 1 {
                    // check valid infix operator
                    if func_top == nil {
                        print_error_prefix(input, &pos)
                        fmt.printf("Expected infix operator before the number \"{}\".\n", input[pos:pos+offset])
                        return 0, false
                    }

                    nums_i = 0

                    // calculate top precedence operator
                    nums[0] = func_top(nums)
                    func_top = nil
                }
                continue
            }
        }

        // parse operator
        {
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

            prev_was_num = false

            // calculate precedence 1
            if strings.index_byte("+-*/", ch) >= 0 && func1 != nil {
                nums[0] = func1({func1_lhs, nums[0]})
                func1 = nil
            }

            // calculate precedence 0
            if strings.index_byte("+-", ch) >= 0 && func0 != nil {
                nums[0] = func0({func0_lhs, nums[0]})
                func0 = nil
            }

            // clear nums
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
        }
    }

    // final calculation
    {
        // calculate top precedence operator
        if func_top != nil {
            if nums_i == 1 {
                nums[0] = func_top(nums)
            } else {
                print_error_prefix(input, &input_high)
                fmt.print("Expected number after the infix operator.\n")
                return 0, false
            }
        }

        // calculate precedence 1
        if func1 != nil { nums[0] = func1({func1_lhs, nums[0]}) }

        // calculate precedence 0
        if func0 != nil { nums[0] = func0({func0_lhs, nums[0]}) }
    }

    // return calculation result
    return nums[0], true
}

// NOTE: maybe replace this with readline or linenoise...
read_from_stdin :: proc() -> strings.Builder {
    stdin_stream := os.stream_from_handle(os.stdin)
    stdin_reader := io.to_byte_reader(stdin_stream)
    input_builder := strings.make_builder_none()

    ch, err := u8(0), io.Error.None
    for {
        ch, err = io.read_byte(stdin_reader)
        if ch == '\n' || err != .None { break }
        strings.write_byte(&input_builder, ch)
    }

    return input_builder
}
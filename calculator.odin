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
    fmt.printf("input      >>> {}\n", input)
    result, ok := calculate(input)
    if ok {
        fmt.printf("result     >>> {:.6f}\n", result)
        if result == expected_res {
            fmt.println("test       >>> passed\n")
            return
        }
    }
    fmt.println("test       >>> failed\n")
}

print_calculate :: proc(input: string) {
    result, ok := calculate(input)
    if ok {
        fmt.printf("result     >>> {:.6f}\n", result)
    }
    fmt.println()
}

calculate :: proc(input: string) -> (result: f64, ok: bool) {
    print_error_prefix :: proc(input: string, pos: ^int) {
        fmt.print("error      >>>")
        for _ in 0 .. pos^ { fmt.print(" ") }
        fmt.print("└> ")
    }

    parse_const :: proc(str: string) -> (i: int, num: f64, ok: bool) {
        // parse predefined constants
        // return: i      => index where parsing is ended   
        // return: num    => value of the constant
        // return: ok     => is an input successfully parsed as constant

        str_len := len(str)

        if str_len == 0 || strings.index_byte(".0123456789*/^", str[0]) >= 0 {
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
        case "pi", "+pi"   : return i, +math.PI, true
        case "-pi"         : return i, -math.PI, true

        case "tau", "+tau" : return i, +math.TAU, true
        case "-tau"        : return i, -math.TAU, true
        
        case "e", "+e"     : return i, +math.E, true
        case "-e"          : return i, -math.E, true
        }
        return 0, 0, false
    }

    parse_number :: proc(str: string) -> (i: int, num: f64, ok: bool) {
        // parse string as f64 number
        // NOTE: +- prefix is part of the number
        // return: i      => index where parsing is ended
        // return: num    => parsed number
        // return: ok     => is an input successfully parsed as f64

        str_len := len(str)
        
        if strings.index_byte("+-", str[0]) >= 0 && (str_len == 1 || strings.index_byte(".0123456789", str[1]) < 0) {
            return 0, 0, false
        }
        
        for i < str_len {
            i += 1
            num, ok = strconv.parse_f64(str[:i]) // can be optimized
            if !ok {
                if i == 1 {
                    return 0, 0, false
                } else {
                    return i - 1, num, true
                }
            }
        }

        return i, num, true
    }

    parse_paren :: proc(str: string) -> (i: int, ok: bool) {
        // parse parentheses
        // return: i          => index where parsing is ended
        // return: ok         => is parentheses match

        str_len := len(str)
        opened: uint = 1

        if str_len < 2 || str[0] != '(' {
            return 0, false
        }

        for i < str_len - 1 {
            i += 1

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

        return i + 1, opened == 0
    }

    // input data
    input_len := len(input)
    input_high := input_len - 1
    pos, offset := 0, 0
    ch: u8 = 0
    if input_len == 0 {
        print_error_prefix(input, &pos)
        fmt.print("Empty expression.\n")
        return 0, false
    }

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
    for pos < input_len {
        // increase position
        defer {
            pos += offset == 0 ? 1 : offset
            offset = 0
        }

        // current character (byte)
        ch = input[pos]

        // ignore empty space
        if ch == ' ' { continue }

        // parse operator
        if prev_was_num {
            // check valid operator
            if (strings.index_byte("+-*/^", ch) < 0) {
                print_error_prefix(input, &pos)
                fmt.printf("Expected operator. (\"{}\" is not a valid operator.)\n", input[pos:pos+1])
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
            if strings.index_byte("^", ch) < 0 {
                nums_i = -1
            }

            // set calculation function
            // top => ^
            // 1   => * /
            // 0   => + -
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
            continue
        }

        // parse parentheses
        {
            prefixed := pos < input_high && (input[pos:pos+2] == "-(" || input[pos:pos+2] == "+(")
            if ch == '(' || prefixed {
                sign: f64 = ch == '-' ? -1 : 1
                exper_start := pos + (prefixed ? 1 : 0)

                parse_len, is_matched := parse_paren(input[exper_start:])
                if !is_matched {
                    print_error_prefix(input, &pos)
                    fmt.print("Unmatched parentheses.\n")
                    return 0, false
                }

                // set offset
                offset = parse_len + (prefixed ? 1 : 0)

                // extract expression
                exper_str := input[exper_start+1:exper_start+parse_len-1]

                // calculate expression
                num, ok := calculate(exper_str)
                if !ok {
                    print_error_prefix(input, &pos)
                    fmt.print("Invalid expression.\n")
                    return 0, false
                }

                // update numbers
                nums_i += 1
                nums[nums_i] = sign * num
                prev_was_num = true
                continue
            }
        }

        // parse constant
        {
            parse_len, num, ok := parse_const(input[pos:]);
            if ok {
                // set offset
                offset = parse_len
                
                // add number
                nums_i += 1
                nums[nums_i] = num
                prev_was_num = true
                continue
            }
        }
        
        // parse number
        {
            parse_len, num, ok := parse_number(input[pos:])
            if ok {
                // set offset
                offset = parse_len

                // add number
                nums_i += 1
                nums[nums_i] = num
                prev_was_num = true

                // if there are 2 numbers
                if nums_i == 1 {
                    // set nums index to first
                    nums_i = 0

                    // calculate top precedence operator
                    if func_top != nil {
                        nums[0] = func_top(nums)
                        func_top = nil
                    } else {
                        print_error_prefix(input, &pos)
                        fmt.println("Unreachable error!")
                        return 0, false
                    }
                }
                continue
            }
        }

        // invalid number
        print_error_prefix(input, &pos)
        fmt.print("Expected number.\n")
        return 0, false
    }

    // check valid infix operator
    if !prev_was_num {
        print_error_prefix(input, &input_high)
        fmt.print("Expected number after the infix operator.\n")
        return 0, false
    }

    // final calculation
    if func_top != nil { nums[0] = func_top(nums) }              // calculate top precedence
    if func1 != nil    { nums[0] = func1({func1_lhs, nums[0]}) } // calculate precedence 1
    if func0 != nil    { nums[0] = func0({func0_lhs, nums[0]}) } // calculate precedence 0

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

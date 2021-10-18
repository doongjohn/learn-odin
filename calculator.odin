package main

// TODO:
// - [x] multi-digit numbers
// - [x] +- prefixed numbers
// - [x] floating point numbers
// - [x] operator precedence
// - [ ] grouping with parentheses
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

        fmt.printf("[input]: \"{}\"\n", input)

        result, ok := calculate(input)
        if ok {
            fmt.printf("[result]: {}\n", result)
        }
    }
}

calculate :: proc(input: string) -> (result: f32, ok: bool) {
    
    print_error_prefix :: proc(input: string, pos: ^int) {
        fmt.printf("[error]: {}\n", input)
        for _ in 0 .. pos^ + len("[error]:") { fmt.print(" ") }
        fmt.print("└> ")
    }

    parse_number :: proc(slice: string) -> (i: int, num: f32, is_num: bool) {
        if strings.index_byte("+-", slice[0]) >= 0 && (len(slice) == 1 || strings.index_byte(".0123456789", slice[1]) < 0) {
            return 0, 0, false
        }
        for i < len(slice) {
            i += 1
            num, is_num = strconv.parse_f32(slice[:i])
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

    // calculation functions
    calc_add :: proc(nums: [2]f32) -> f32 { return nums[0] + nums[1] }
    calc_sub :: proc(nums: [2]f32) -> f32 { return nums[0] - nums[1] }
    calc_mul :: proc(nums: [2]f32) -> f32 { return nums[0] * nums[1] }
    calc_div :: proc(nums: [2]f32) -> f32 { return nums[0] / nums[1] }
    calc_pow :: proc(nums: [2]f32) -> f32 { return math.pow(nums[0], nums[1]) }

    // number data
    nums_i := -1
    nums := [2]f32{0, 0}
    prev_is_num := false

    // func precedence top
    func_top: proc(nums: [2]f32) -> f32

    // func precedence 1
    func1_lhs: f32
    func1: proc(nums: [2]f32) -> f32

    // func precedence 0
    func0_lhs: f32
    func0: proc(nums: [2]f32) -> f32

    // loop
    pos, offset := 0, 0
    ch: u8
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

        // parse number
        num_offset, num, is_num := parse_number(input[pos:])

        // check +- operator
        if nums_i == 0 && strings.index_byte("+-", ch) >= 0 {
            is_num = false
        }

        if is_num {
            prev_is_num = true

            // set offset
            offset = num_offset

            // DEBUG
            // fmt.println(input[pos:pos+offset])

            // update numbers
            nums_i += 1
            nums[nums_i] = num

            // if there are 2 numbers
            if nums_i == 1 {
                // reset nums length
                nums_i = 0

                // check valid infix operator
                if func_top == nil {
                    print_error_prefix(input, &pos)
                    fmt.printf("can not find any infix operator before \"{}\".\n", input[pos:pos+offset])
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
            if nums_i < 0 || !prev_is_num {
                print_error_prefix(input, &pos)
                fmt.print("There must be a number before the infix operator.\n")
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

            prev_is_num = false
        }
    }

    // check valid infix function
    if func_top != nil || (func_top == nil && nums_i < 0) {
        print_error_prefix(input, &pos)
        fmt.print("There must be a number after the infix operator.\n")
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
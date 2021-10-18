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
    // parsed numbers
    nums_i := -1
    nums := [2]f32{0, 0}

    // claculation proc
    func1: proc(nums: [2]f32) -> f32

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
        num_offset, num, is_num := calc_parse_number(input[pos:])

        // check +- operator
        if nums_i == 0 && strings.index_byte("+-", ch) >= 0 {
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

            // if there are 2 numbers
            if nums_i == 1 {
                // reset nums length
                nums_i = 0

                // check valid infix operator
                if func1 == nil {
                    print_error_prefix(input, &pos)
                    fmt.printf("can not find any infix operator before \"{}\".\n", input[pos:pos+offset])
                    return 0, false
                }

                // calculate mul & div
                nums[0] = func1(nums)
                func1 = nil

                // 1 + 2 * 2
                // ^^^^^
                //     this is a plus: func0_lhs = `1`, func0 = `+`
                //     func0 is nil: do nothing
                
                // 1 + 2 * 2
                //     ^^^^^
                //         this is a multiplication. do it!
                //         func0 is not nil: calc func0

                // higher precedence gets executed before lower precedence
                // func1 == operator precedence 2
                // func0 == operator precedence 1
            }
        } else {
            // check valid operator
            if (strings.index_byte("+-*/", ch) < 0) {
                print_error_prefix(input, &pos)
                fmt.printf("\"{}\" is not a valid operator.\n", input[pos:pos+1])
                return 0, false
            }

            // check valid infix function
            if nums_i < 0 {
                print_error_prefix(input, &pos)
                fmt.print("There must be a number before the infix operator.\n")
                return 0, false
            }

            // calculate add & sub
            if (strings.index_byte("+-", ch) >= 0 && func0 != nil) {
                nums[0] = func0([2]f32{func0_lhs, nums[0]})
            }

            // set calculation function
            switch ch {
            case '+':
                nums_i = -1
                func0_lhs = nums[0]
                func0 = func_add
            case '-':
                nums_i = -1
                func0_lhs = nums[0]
                func0 = func_sub
            case '*':
                func1 = func_mul
            case '/':
                func1 = func_div
            }

            // DEBUG
            // fmt.println(func0)
        }
    }

    // check valid infix function
    if func1 != nil {
        print_error_prefix(input, &pos)
        fmt.print("There must be a number after the infix operator.\n")
        return 0, false
    }

    // calculate add & sub
    if func0 != nil {
        // DEBUG
        // fmt.printf("func0_lhs: {}, nums[0]: {}\n", func0_lhs, nums[0])

        nums[0] = func0([2]f32{func0_lhs, nums[0]})
        func0_lhs = 0
        func0 = nil
        func1 = nil
    }

    // return calculation result
    return nums[0], true
}


calc_parse_number :: proc(slice: string) -> (i: int, num: f32, is_num: bool) {
    if strings.index_byte("+-", slice[0]) >= 0 {
        if len(slice) == 1 || strings.index_byte(".0123456789", slice[1]) < 0 {
            return 0, 0, false
        }
    }

    for i < len(slice) {
        i += 1
        num, is_num = strconv.parse_f32(slice[:i])
        if !is_num {
            if i == 1 {
                return 0, 0, false
            } else {
                return i-1, num, true
            }
        }
    }
    return i, num, true
}


func_add :: proc(nums: [2]f32) -> f32 {
    return nums[0] + nums[1]
}

func_sub :: proc(nums: [2]f32) -> f32 {
    return nums[0] - nums[1]
}

func_mul :: proc(nums: [2]f32) -> f32 {
    return nums[0] * nums[1]
}

func_div :: proc(nums: [2]f32) -> f32 {
    return nums[0] / nums[1]
}


print_error_prefix :: proc(input: string, pos: ^int) {
    fmt.printf("[error]: {}\n", input)
    for _ in 0 .. pos^ + len("[error]:") { fmt.print(" ") }
    fmt.print("└> ")
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
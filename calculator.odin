package main

// TODO:
// - [x] multi-digit numbers
// - [x] +- prefixed numbers
// - [x] floating point numbers
// - [ ] operator precedence
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
    nums_len := -1
    nums := [2]f32{0, 0}
    
    // claculation proc
    func: proc(nums: [2]f32) -> f32

    // TODO:
    // kept data for operator precedence
    kept_num: f32
    kept_func: proc(nums: [2]f32) -> f32

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
        if nums_len == 0 && func == nil && strings.index_byte("+-", ch) >= 0 {
            is_num = false

            // DEBUG
            // fmt.println("it's op")
        }

        if is_num {
            // set offset
            offset = num_offset

            // DEBUG
            // fmt.println(input[pos:pos+offset])

            // update numbers
            nums_len += 1
            nums[nums_len] = num

            // if there are 2 numbers
            if nums_len == 1 {
                // reset nums length
                nums_len = 0

                // check valid infix operator
                if func == nil {
                    print_error_prefix(input, &pos)
                    fmt.printf("can not find any infix operator before \"{}\".\n", input[pos:pos+offset])
                    return 0, false
                }

                // 1 + 2 * 2
                // ^^^^^
                //     this is a plus: kept_num = `1`, kept_func = `+`
                //     kept_func is nil: do nothing
                
                // 1 + 2 * 2
                //     ^^^^^
                //         this is a multiplication. do it!
                //         kept_func is not nil: calc kept_func

                // when mul & div
                if func == func_mul || func == func_div {
                    nums[0] = func(nums)
                    func = nil

                    if kept_func != nil {
                        nums[0] = kept_func([2]f32{kept_num, nums[0]})
                        kept_num = 0
                        kept_func = nil
                    }
                    continue
                }

                // when add & sub
                if kept_func != nil {
                    nums[0] = kept_func([2]f32{kept_num, nums[0]})
                    kept_num = 0
                    kept_func = nil
                }

                kept_num = nums[0]
                kept_func = func
            }
        } else {
            // parse operator
            is_op := strings.index_byte("+-*/", ch) >= 0

            // check valid operator
            if (!is_op) {
                print_error_prefix(input, &pos)
                fmt.printf("\"{}\" is not a valid operator.\n", input[pos:pos+1])
                return 0, false
            }

            // check valid infix function
            if nums_len < 0 {
                print_error_prefix(input, &pos)
                fmt.print("There must be a number before the infix operator.\n")
                return 0, false
            }

            // set calculation function
            switch ch {
            case '+': func = func_add
            case '-': func = func_sub
            case '*': func = func_mul
            case '/': func = func_div
            }
        }
    }

    // check valid infix function
    if func != nil {
        print_error_prefix(input, &pos)
        fmt.print("There must be a number after the infix operator.\n")
        return 0, false
    }

    // return calculation result
    return nums[0], true
}


calc_parse_number :: proc(slice: string) -> (i: int, num: f32, is_num: bool) {
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
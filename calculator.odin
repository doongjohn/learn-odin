package main

// TODO:
// - [x] multi-digit numbers
// - [x] +- prefixed numbers
// - [ ] operator precedence
// - [ ] grouping with parentheses
// - [ ] custom math functions

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

        result, ok := calculate(input)
        fmt.printf("input: \"{}\"\n", input)
        if ok {
            fmt.printf("result: {}\n", result)
        }
    }
}

calculate :: proc(input: string) -> (result: f32, ok: bool) {
    // parsed numbers
    nums_len := -1
    nums := [2]f32{0, 0}

    // token data
    prev_num: f32
    prev_num_pos := -1
    
    // claculation proc
    func: proc(nums: [2]f32) -> f32

    // loop
    pos := 0
    offset := 0
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
        // fmt.printf("pos: {}, char: {}\n", pos, input[pos:pos+1])
        
        if ch == ' ' { continue }

        // parse number
        num_offset, is_num := calc_get_number(input[pos:])
        // check sign prefix
        if nums_len == 0 && func == nil && strings.index_byte("+-", ch) >= 0 {
            is_num = false
        }

        if is_num {
            // set offset
            offset = num_offset

            // convert to f32
            num, ok := strconv.parse_f32(input[pos:pos+offset])

            // DEBUG
            // fmt.println(input[pos:pos+offset])

            if !ok {
                fmt.print("[Error]: can not parse number.")
                fmt.printf("(at {})\n", pos)
                return 0, false
            }

            // update numbers
            nums_len += 1
            nums[nums_len] = num

            if nums_len == 1 {
                // check operator
                if func == nil {
                    fmt.printf("[Error]: can not find any operator after \"{}\".", prev_num)
                    fmt.printf("(at {})\n", prev_num_pos)
                    return 0, false
                }

                // run calculation function
                nums_len = 0
                nums[0] = func(nums)
                func = nil
            }

            // save previous num
            prev_num_pos = pos
            prev_num = num
        } else {
            // parse operator
            is_op := strings.index_byte("+-*/", ch) >= 0

            // check valid operator
            if (!is_op) {
                fmt.printf("[Error]: \"{}\" is not a valid operator.", ch)
                fmt.printf("(at {})\n", pos)
                return 0, false
            }

            // check valid infix function
            if nums_len < 0 {
                fmt.print("[Error]: There must be a number before the infix operator.")
                fmt.printf("(at {})\n", pos)
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
        fmt.print("[Error]: There must be a number after the infix operator.")
        fmt.printf("(at {})\n", pos)
        return 0, false
    }

    // return calculation result
    return nums[0], true
}

calc_get_number :: proc(slice: string) -> (i: int, is_num: bool) {
    if strings.index_byte("+-", slice[0]) >= 0 {
        if len(slice) == 1 || strings.index_byte("0123456789", slice[1]) < 0 {
            return 0, false
        } else {
            i += 1
        }
    }
    for i < len(slice) {
        if strings.index_byte("0123456789", slice[i]) < 0 {
            return i, i > 0
        }
        i += 1
    }
    return i, true
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


read_from_stdin :: proc() -> strings.Builder {
    stdin_stream := os.stream_from_handle(os.stdin)
    stdin_reader := io.to_byte_reader(stdin_stream)
    input_builder := strings.make_builder_none()

    b : u8
    err : io.Error

    for {
        b, err = io.read_byte(stdin_reader)
        if b == '\n' || err != .None { break }
        strings.write_byte(&input_builder, b)
    }

    return input_builder
}
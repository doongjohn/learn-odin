package main

// TODO:
// - [x] 여러자리 숫자
// - [ ] +- 프리픽스
// - [ ] 연산자 우선순위
// - [ ] 괄호 그룹
// - [ ] 함수

import "core:io"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:unicode/utf8"

main :: proc() {
    fmt.print("input math: ")

    input_builder := read_from_stdin()
    input := strings.to_string(input_builder)
    defer strings.destroy_builder(&input_builder)

    result, ok := calculate(input)
    if ok {
        fmt.printf("result: {}\n", result)
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
    for pos < len(input) {
        ch := input[pos]

        // DEBUG
        // fmt.printf("pos: {}, char: {}\n", pos, input[pos:pos+1])

        if ch == ' ' {
            pos += 1
            continue
        }

        is_num := strings.index_byte("0123456789", ch) >= 0

        if is_num {
            // get number u8 count
            num_u8_count := get_num_u8_count(input[pos:])
            // fmt.printf("num u8 count: {}\n", num_u8_count)

            // convert to f32
            num, ok := strconv.parse_f32(input[pos:pos+num_u8_count])
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

                // show nums
                fmt.println(nums)
            }

            prev_num_pos = pos
            prev_num = num
            pos += num_u8_count
            continue
        }

        is_op := strings.index_byte("+-*/", ch) >= 0

        // check valid operator
        if (!is_op) {
            fmt.printf("[Error]: \"{}\" is not a valid operator.", ch)
            fmt.printf("(at {})\n", pos)
            return 0, false
        }

        // check valid infix function
        if nums_len < 0 {
            fmt.print("[Error]: There must be a number before the operator.")
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

        pos += 1
    }

    return nums[0], true
}

get_num_u8_count :: proc(slice: string) -> int {
    i := 0
    for i < len(slice) {
        if strings.index_byte("0123456789", slice[i]) < 0 {
            return i
        }
        i += 1
    }
    return i
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
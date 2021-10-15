package main

// TODO:
// 여러자리 숫자
// +- 프리픽스
// 연산자 우선순위
// 함수

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

    fmt.println(input)
    fmt.printf("result: {}\n", calculate(input))
}


calc_add :: proc(nums: [2]f32) -> f32 {
    return nums[0] + nums[1]
}

calc_sub :: proc(nums: [2]f32) -> f32 {
    return nums[0] - nums[1]
}

calc_mul :: proc(nums: [2]f32) -> f32 {
    return nums[0] * nums[1]
}

calc_div :: proc(nums: [2]f32) -> f32 {
    return nums[0] / nums[1]
}

calculate :: proc(input: string) -> f32 {
    i := -1
    nums := [2]f32{ 0, 0 }
    calc := proc(nums: [2]f32) -> f32 { return 0 }

    for ch in input {
        str := utf8.runes_to_string({ch})
        num, is_num := strconv.parse_f32(str)

        if strings.contains_rune("+-*/", ch) >= 0 {
            is_num = false
        }
        
        if is_num {
            i += 1
            nums[i] = num
            if i == 1 {
                i = 0
                nums[0] = calc(nums)
                fmt.println(nums)
            }
        } else {
            if i < 0 {
                fmt.println("연산자의 좌측에는 숫자가 있어야 합니다")
                continue
            }

            switch ch {
            case '+': calc = calc_add
            case '-': calc = calc_sub
            case '*': calc = calc_mul
            case '/': calc = calc_div
            }
        }
    }
    return nums[0]
}


read_from_stdin :: proc() -> strings.Builder {
    stdin_stream := os.stream_from_handle(os.stdin)
    stdin_reader := io.to_byte_reader(stdin_stream)
    input_builder := strings.make_builder_none()

    b : byte
    err : io.Error

    for {
        b, err = io.read_byte(stdin_reader)
        if b == '\n' || err != .None { break }
        strings.write_byte(&input_builder, b)
    }

    return input_builder
}
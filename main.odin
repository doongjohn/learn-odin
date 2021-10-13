package main

import "core:fmt"
import "core:unicode/utf8"

main :: proc() {
    str : string
    str = "안녕"
    
    count := utf8.rune_count_in_string(str)
    fmt.println("rune length: {0}", count)

    for c in str {
        fmt.println(c)
    }

    p : ^int
    p = new(int)
    defer free(p)

    fmt.println(p^) // always zero
    p^ = 10
    fmt.println(p^)
}

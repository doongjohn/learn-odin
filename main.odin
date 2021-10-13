package main

import "core:fmt"
import "core:unicode/utf8"

main :: proc() {
    str : string
    str = "안녕"
    
    count := utf8.rune_count_in_string(str)
    fmt.println("rune length: {0}", count)

    for r in str {
        fmt.println(r)
    }
}

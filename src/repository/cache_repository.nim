import std/tables
    , ../model/cache


proc createCache*(c: var MemCache, key,value: string) =
    c[key] = value

proc deleteCache*(c: var MemCache,key: string) =
    c.del(key)

proc getCache*(c: var MemCache, key: string): string =
    return c[key]
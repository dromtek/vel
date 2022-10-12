import std/tables
    , ../model/cache


proc createCache*(c: ref MemCache, key,value: string) =
    c[key] = value

proc deleteCache*(c: ref MemCache,key: string) =
    c.del(key)

proc getCache*(c: ref MemCache, key: string): string =
    return c[key]
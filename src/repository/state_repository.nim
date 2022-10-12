import 
    std/db_sqlite
    , std/strutils 
    , ../model/state
    , ../model/cache
    , options
    , cache_repository
    , std/tables

type 
    stateRepository* = object
        sqlDb: DbConn
        cacheDb: ref MemCache
    stateRepository2* = object
        sqlDb: DbConn
        cacheDb: var MemCache

proc findStateByStateQuery*(s: stateRepository,q: stateQuery) : Option[stateData] =
    let cacheKey = "$1|$2|$3".format(q.context,q.key,q.guildID)
    try:
        return some  newStateData(
            q.context
            , q.key
            , s.cacheDb[cacheKey]
            , q.guildID
        )
    except KeyError:
        echo "no cache, continuing"
    finally:
        echo "Error"

    try:
        let preparedStatement = s.sqlDb.prepare("SELECT context, key,value,guild_id FROM states WHERE context = ? and key = ? and guild_id = ? LIMIT 1")
        preparedStatement.bindParams(
            "$1".format(q.context)
            , q.key
            , q.guildID
        )

        let dbRows = s.sqlDb.getAllRows(preparedStatement)
        if dbRows.len <= 0:
            return none(stateData)
        else:
            let data : stateData = newStateData(
                parseEnum[StateContext](dbRows[0][0])
                , dbRows[0][1]
                , dbRows[0][2]
                , dbRows[0][3]
            )

            return some data
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        echo "Got exception ", repr(e), " with message ", msg
        return none(stateData)
            
proc createState*(s: stateRepository,d: stateData) : bool =
    let preparedStatement = s.sqlDb.prepare(
        "INSERT INTO states(context,key,value,guild_id) VALUES (?,?,?,?)"
    )
    preparedStatement.bindParams(
        "$1".format(d.context)
        , d.key
        , d.value
        , d.guildID
    )
    let rowCount = s.sqlDb.execAffectedRows(preparedStatement) == 1
    if rowCount:
        let cacheKey = "$1|$2|$3".format(d.context,d.key,d.guildID)
        s.cacheDb.createCache(cacheKey,d.value)
        return true
    return false



proc destroyStateByStateQuery*(s: stateRepository,q: stateQuery): bool =
    let preparedStatement = s.sqlDb.prepare(
        "DELETE FROM states WHERE context = ? AND key = ? AND guild_id = ?"
    )
    preparedStatement.bindParams(
        "$1".format(q.context)
        , q.key
        , q.guildID
    )
    let deleted = s.sqlDb.execAffectedRows(preparedStatement) > 0
    if deleted:
        s.cacheDb.deleteCache("$1|$2|$3".format(q.context,q.key,q.guildID))
    return deleted

proc newStateRepo*(db: DbConn, cache: ref MemCache) : stateRepository =
    return stateRepository(sqlDb: db, cacheDb: cache) 
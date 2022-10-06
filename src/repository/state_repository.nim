import 
    std/db_sqlite
    , std/strutils 
    , ../model/state
    , options

type 
    stateRepository* = object
        sqlDb: DbConn

proc findStateByStateQuery*(s: stateRepository,q: stateQuery) : Option[stateData] =
    let preparedStatement = s.sqlDb.prepare("SELECT context, key,value,guild_id FROM states WHERE context = ? and key = ? and guild_bot = ? LIMIT 1")
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
    return s.sqlDb.execAffectedRows(preparedStatement) == 1

proc destroyStateByStateQuery*(s: stateRepository,q: stateQuery): bool =
    return false

proc newStateRepository*(db: DbConn) : stateRepository =
    return stateRepository(sqlDb: db) 
import 
    std/db_sqlite
    , options

# This way to make key value like using SQL for feature configuration
type 
    StateContext* {. pure .} = enum 
        ctxMemberVerification = "ctxMemberVerification"

    StateLabel* {. pure .} = enum
        MemberVerificationRole = "memberVerificationRole"
        MemberVerificationMessage = "memberVerificationMessage"
    
    stateData* = object 
        context*: StateContext
        key*: string
        value*: string
        guildID*: string

    stateQuery* = object 
        context*: StateContext
        key*: string
        guildID*: string

    IStateRepository* = concept s
        s.sqlDb is DbConn
        s.findStateByStateQuery(q: stateQuery) is Option[stateData]
        s.createState(d: stateData) is bool
        s.destroyStateByStateQuery(q: stateQuery) is bool

proc newStateData*(context: StateContext, key,value,guildID: string) : stateData = 
    result.context = context
    result.key = key
    result.value = value
    result.guildID = guildID